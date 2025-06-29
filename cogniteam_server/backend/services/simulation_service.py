import asyncio
from typing import List, Optional
from datetime import datetime
import logging
from firebase_admin import firestore
from models import Simulation, SimulationCreate, SimulationResponse, SimulationListResponse
from services.simulation_director_agent_service import SimulationDirectorAgentService

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SimulationService:
    def __init__(self):
        self.db = firestore.client()
        self.simulation_director_service = SimulationDirectorAgentService()
        self.simulations_collection = self.db.collection('simulations')

    async def create_simulation(self, simulation_data: SimulationCreate, created_by: str) -> SimulationResponse:
        """
        新しいシミュレーションを作成します。
        
        Args:
            simulation_data: シミュレーション作成データ
            created_by: 作成者のユーザーID
            
        Returns:
            作成されたシミュレーションのレスポンス
        """
        try:
            # 参加者の検証
            is_valid = await self.simulation_director_service.validate_participants(
                simulation_data.participant_user_ids
            )
            if not is_valid:
                raise ValueError("Invalid participants: Some users do not have valid agents")

            # シミュレーションオブジェクトを作成
            simulation = Simulation(
                simulation_name=simulation_data.simulation_name,
                instruction=simulation_data.instruction,
                participant_user_ids=simulation_data.participant_user_ids,
                created_by=created_by
            )

            # Firestoreに保存
            doc_ref = self.simulations_collection.document(simulation.simulation_id)
            doc_ref.set({
                'simulation_name': simulation.simulation_name,
                'instruction': simulation.instruction,
                'participant_user_ids': simulation.participant_user_ids,
                'created_by': simulation.created_by,
                'status': simulation.status,
                'created_at': simulation.created_at,
                'started_at': simulation.started_at,
                'completed_at': simulation.completed_at,
                'result_summary': simulation.result_summary,
                'error_message': simulation.error_message
            })

            logger.info(f"Simulation created successfully: {simulation.simulation_id}")
            
            # バックグラウンドでシミュレーションを実行
            asyncio.create_task(self._execute_simulation_background(simulation.simulation_id))
            
            return SimulationResponse(
                simulation_id=simulation.simulation_id,
                simulation_name=simulation.simulation_name,
                instruction=simulation.instruction,
                participant_user_ids=simulation.participant_user_ids,
                status=simulation.status,
                created_at=simulation.created_at,
                started_at=simulation.started_at,
                completed_at=simulation.completed_at,
                result_summary=simulation.result_summary,
                error_message=simulation.error_message,
                created_by=simulation.created_by
            )

        except Exception as e:
            logger.error(f"Error creating simulation: {str(e)}")
            raise

    async def get_simulation(self, simulation_id: str) -> Optional[SimulationResponse]:
        """
        シミュレーションの詳細を取得します。
        
        Args:
            simulation_id: シミュレーションID
            
        Returns:
            シミュレーションの詳細、存在しない場合はNone
        """
        try:
            doc_ref = self.simulations_collection.document(simulation_id)
            doc = doc_ref.get()
            
            if not doc.exists:
                return None
                
            data = doc.to_dict()
            return SimulationResponse(
                simulation_id=simulation_id,
                simulation_name=data['simulation_name'],
                instruction=data['instruction'],
                participant_user_ids=data['participant_user_ids'],
                status=data['status'],
                created_at=data['created_at'],
                started_at=data.get('started_at'),
                completed_at=data.get('completed_at'),
                result_summary=data.get('result_summary'),
                error_message=data.get('error_message'),
                created_by=data['created_by']
            )

        except Exception as e:
            logger.error(f"Error getting simulation: {str(e)}")
            raise

    async def get_simulations_by_user(self, user_id: str, limit: int = 50, offset: int = 0) -> SimulationListResponse:
        """
        ユーザーが作成したシミュレーション一覧を取得します。
        
        Args:
            user_id: ユーザーID
            limit: 取得件数制限
            offset: オフセット
            
        Returns:
            シミュレーション一覧
        """
        try:
            # ユーザーが作成したシミュレーションをクエリ（インデックスなしでフィルタリングのみ）
            query = self.simulations_collection.where('created_by', '==', user_id)
            docs = query.stream()
            
            # メモリ上でソート・ページネーション
            simulations = []
            for doc in docs:
                data = doc.to_dict()
                simulation = SimulationResponse(
                    simulation_id=doc.id,
                    simulation_name=data['simulation_name'],
                    instruction=data['instruction'],
                    participant_user_ids=data['participant_user_ids'],
                    status=data['status'],
                    created_at=data['created_at'],
                    started_at=data.get('started_at'),
                    completed_at=data.get('completed_at'),
                    result_summary=data.get('result_summary'),
                    error_message=data.get('error_message'),
                    created_by=data['created_by']
                )
                simulations.append(simulation)
            
            # created_atで降順ソート
            simulations.sort(key=lambda x: x.created_at, reverse=True)
            
            # ページネーション適用
            total_count = len(simulations)
            simulations = simulations[offset:offset + limit]

            return SimulationListResponse(
                simulations=simulations,
                total_count=total_count
            )

        except Exception as e:
            logger.error(f"Error getting simulations by user: {str(e)}")
            raise

    async def delete_simulation(self, simulation_id: str, user_id: str) -> bool:
        """
        シミュレーションを削除します。
        
        Args:
            simulation_id: シミュレーションID
            user_id: 削除を実行するユーザーID（作成者のみ削除可能）
            
        Returns:
            削除成功時はTrue
        """
        try:
            doc_ref = self.simulations_collection.document(simulation_id)
            doc = doc_ref.get()
            
            if not doc.exists:
                return False
                
            data = doc.to_dict()
            if data['created_by'] != user_id:
                raise ValueError("Only the creator can delete the simulation")
                
            doc_ref.delete()
            logger.info(f"Simulation deleted successfully: {simulation_id}")
            return True

        except Exception as e:
            logger.error(f"Error deleting simulation: {str(e)}")
            raise

    async def rerun_simulation(self, simulation_id: str, user_id: str) -> SimulationResponse:
        """
        シミュレーションを再実行します。
        
        Args:
            simulation_id: シミュレーションID
            user_id: 再実行を実行するユーザーID（作成者のみ再実行可能）
            
        Returns:
            更新されたシミュレーションのレスポンス
        """
        try:
            # 既存のシミュレーションを取得
            existing_simulation = await self.get_simulation(simulation_id)
            if not existing_simulation:
                raise ValueError("Simulation not found")
                
            if existing_simulation.created_by != user_id:
                raise ValueError("Only the creator can rerun the simulation")

            # ステータスをpendingにリセット
            doc_ref = self.simulations_collection.document(simulation_id)
            doc_ref.update({
                'status': 'pending',
                'started_at': None,
                'completed_at': None,
                'result_summary': None,
                'error_message': None
            })

            # バックグラウンドでシミュレーションを再実行
            asyncio.create_task(self._execute_simulation_background(simulation_id))
            
            # 更新されたシミュレーションを返す
            updated_simulation = await self.get_simulation(simulation_id)
            return updated_simulation

        except Exception as e:
            logger.error(f"Error rerunning simulation: {str(e)}")
            raise

    async def _execute_simulation_background(self, simulation_id: str):
        """
        バックグラウンドでシミュレーションを実行します。
        
        Args:
            simulation_id: シミュレーションID
        """
        try:
            # ステータスをrunningに更新
            doc_ref = self.simulations_collection.document(simulation_id)
            doc_ref.update({
                'status': 'running',
                'started_at': datetime.utcnow()
            })

            # シミュレーションデータを取得
            simulation = await self.get_simulation(simulation_id)
            if not simulation:
                raise ValueError("Simulation not found")

            # TODO: 参加者のエージェントIDを取得するロジックを実装
            # participant_agent_ids = await self._get_participant_agent_ids(simulation.participant_user_ids)
            
            # 仮の実装（実際のエージェントID取得ロジックに置き換える必要があります）
            # ここでは、ユーザーIDをそのままエージェントIDとして使用（実際の実装では異なる可能性があります）
            participant_agent_ids = simulation.participant_user_ids

            # シミュレーション実行
            result = await self.simulation_director_service.execute_simulation(
                simulation.instruction,
                participant_agent_ids
            )

            # 結果を保存
            doc_ref.update({
                'status': 'completed',
                'completed_at': datetime.utcnow(),
                'result_summary': result
            })

            logger.info(f"Simulation completed successfully: {simulation_id}")

        except Exception as e:
            logger.error(f"Error executing simulation in background: {str(e)}")
            
            # エラー状態を保存
            doc_ref = self.simulations_collection.document(simulation_id)
            doc_ref.update({
                'status': 'failed',
                'completed_at': datetime.utcnow(),
                'error_message': str(e)
            })

    async def _get_participant_agent_ids(self, participant_user_ids: List[str]) -> List[str]:
        """
        参加者のエージェントIDを取得します。
        
        Args:
            participant_user_ids: 参加者のユーザーIDリスト
            
        Returns:
            参加者のエージェントIDリスト
        """
        # TODO: 実際のエージェントID取得ロジックを実装
        # ここでは仮の実装として、ユーザーIDをそのまま返す
        # 実際の実装では、ユーザーIDからエージェントIDを取得する必要があります
        return participant_user_ids 