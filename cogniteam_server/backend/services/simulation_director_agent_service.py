import copy, os
import asyncio
import vertexai
from google.adk.agents.llm_agent import LlmAgent
from google.adk.tools.agent_tool import AgentTool
from typing import List, Optional
from datetime import datetime
import logging
import types
from .local_app import LocalApp
from config import settings
import time
import re


PROJECT_ID = 'handsonadk'
LOCATION = 'us-central1'

vertexai.init(project=PROJECT_ID, location=LOCATION)

os.environ['GOOGLE_CLOUD_PROJECT'] = PROJECT_ID
os.environ['GOOGLE_CLOUD_LOCATION'] = LOCATION
os.environ['GOOGLE_GENAI_USE_VERTEXAI'] = 'True'

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SimulationDirectorAgentService:
    def __init__(self):
        self.global_instruction = '''
必ず日本語で応答してください。すべての出力は日本語で行ってください。
'''
        
        self.instruction_template = '''
あなたは、世界最高の組織コンサルタントAI『CogniTeam AI』の頭脳であり、`SimulationDirectorAgent`として振る舞います。
あなたの使命は、ユーザーによって与えられたシミュレーション環境において「TeamMemberAgent」を対話させ、その対話を分析し、人間には見えない根本原因を特定し、その解決策を検証するためのマルチエージェント・シミュレーションを設計・実行・評価し、最終的な改善案を**ユーザーに**提示することです。

## 絶対的な制約
- **最重要ルール**: あなたが実行する対話シミュレーションの登場人物は、いかなる場合でもユーザーによって指示された**TeamMemberAgent**のみです。他のエージェント（Sato_Agentなど）を絶対に出現させてはいけません。
- **シミュレーションの途中経過の報告について**: シミュレーション途中の会話ログは随時出力すること
- **アウトプットの焦点**: 最終的な改善提案は、チーム全体への一般的なアドバイスではなく、必ずユーザーが明日からすぐに実行できる、単一の具体的なアクションプラン**に絞り込んでください。

## 思考プロセス
あなたは、ユーザーからインプットを受け取ったら、必ず以下の思考プロセスに従って、最終的なアウトプットを生成しなければなりません。
1. **対立構造の分析**:
  まず、与えられたメンバーを比較し、両者の「型」の間に存在する、最も重要な**対立の軸**を特定してください。（例：「スピード重視 vs 品質重視」「トップダウン vs ボトムアップ」など）
2. **根本原因の仮説立案**:
  次に特定した「対立の軸」が、実際にどのようなコミュニケーションの問題（例：部下の貢献行動の減少）を引き起こしているか、その**因果関係に関する仮説**を立ててください。
3. **比較実験の設計**:
  あなたの仮説を検証するため、具体的な業務シナリオ（例：**「次期主力機能の企画会議」**）を設定し、以下の2つの比較実験シナリオを**動的に設計**してください。
  - **シナリオA（対立再現シナリオ）**: あなたが発見した「対立の軸」が、最も顕著に現れるようなコミュニケーションをシミュレートする。
  - **シナリオB（対立解消シナリオ）**: その対立を解消し、両者のエンゲージメントを最大化するような、理想的なコミュニケーションをシミュレートする。
4. **シミュレーションの実行と評価**:
  設計した2つのシナリオを、ユーザーによって指定されたメンバーに限定して**指示し、対話を実行させてください。この対話は最低でも10往復はするようなシミュレーションをしてください。その結果（予測される議論の質や結論の具体性など）を客観的に評価してください。
5. **最終レポートの生成**:
  上記の全ての分析とシミュレーション結果を統合し、**マネージャーTanaka個人が即座に実行できる、単一の具体的なアクションプラン**として「インサイト・ダッシュボード」をマークダウン形式で出力してください。

## シミュレーション指示
{instruction}
'''

    def _create_participant_agent_tool(self, agent_id: str, agent_name: str = None, user_id: str = None) -> types.FunctionType:
        """
        参加者エージェント用のツール関数を動的に作成します。
        
        Args:
            agent_id: エージェントID
            agent_name: エージェント名（オプション）
            user_id: ユーザーID（オプション）
            
        Returns:
            ツール関数
        """
        logger.info(f"Creating participant agent tool for agent_id: {agent_id}, agent_name: {agent_name}, user_id: {user_id}")
        
        if agent_name is None:
            agent_name = f"Agent_{agent_id[:8]}"  # 短縮版のIDを使用
        
        # user_idが指定されていない場合は、agent_idを使用
        if user_id is None:
            user_id = agent_id
        else:
            # ユーザーIDを単純な形式に変更（Vertex AIの制限を回避）
            # Firebase UIDから数字部分を抽出、または短縮
            if len(user_id) > 10:
                # 数字とアルファベットのみを抽出して短縮
                alphanumeric = re.sub(r'[^a-zA-Z0-9]', '', user_id)
                user_id = f"u{alphanumeric[:8]}"
            else:
                user_id = f"u{user_id}"
        
        def participant_agent_tool(query: str) -> str:
            """
            Get an answer to a question from {agent_name}

            Args:
                query: question
               
            Returns:
                str: An answer from {agent_name}
            """
            import vertexai
            from vertexai import agent_engines

            PROJECT_ID = 'handsonadk' # 実際のプロジェクト ID に変更
            AGENT_ID = agent_id
            LOCATION = 'us-central1'
            vertexai.init(project=PROJECT_ID, location=LOCATION)

            print(f"AGENT_ID: {AGENT_ID}, USER_ID: {user_id}")

            # レート制限回避のための遅延（1分間に10リクエスト制限のため、最低6秒間隔）
            time.sleep(6)

            remote_agent = agent_engines.get(AGENT_ID)
            
            # セッション作成をリトライ
            max_retries = 3
            session = None
            final_user_id = user_id  # 最終的に使用されたuser_idを記録
            
            for attempt in range(max_retries):
                try:
                    session = remote_agent.create_session(user_id=user_id)
                    break
                except Exception as e:
                    if attempt < max_retries - 1:
                        logger.warning(f"Session creation failed for agent {AGENT_ID}, attempt {attempt + 1}/{max_retries}: {e}")
                        time.sleep(10)  # 10秒待機してリトライ
                    else:
                        logger.error(f"Session creation failed for agent {AGENT_ID} after {max_retries} attempts: {e}")
                        # 最後の試行として固定ユーザーIDを使用
                        try:
                            logger.info(f"Trying with fixed user_id for agent {AGENT_ID}")
                            session = remote_agent.create_session(user_id="default_user")
                            final_user_id = "default_user"  # 固定ユーザーIDを使用した場合
                            break
                        except Exception as e2:
                            logger.error(f"Session creation failed even with fixed user_id for agent {AGENT_ID}: {e2}")
                            raise e  # 元のエラーを再発生
            
            if session is None:
                raise Exception(f"Failed to create session for agent {AGENT_ID}")
            
            try:
                events = remote_agent.stream_query(
                            user_id=final_user_id,
                            session_id=session['id'],
                            message=query,
                         )
                result = []
                for event in events:
                    if ('content' in event and 'parts' in event['content']):
                        response = '\n'.join(
                            [p['text'] for p in event['content']['parts'] if 'text' in p]
                        )
                        if response:
                            result.append(response)
                return '\n'.join(result)

            finally:
                remote_agent.delete_session(
                    user_id=final_user_id,
                    session_id=session['id'],
                )
        
        # 関数のdocstringを設定
        participant_agent_tool.__doc__ = f"""
        Get an answer to a question from {agent_name}

        Args:
            query: question
           
        Returns:
            str: An answer from {agent_name}
        """
        
        return participant_agent_tool

    def create_simulation_director_agent(self, instruction: str, participant_agent_ids: List[str], participant_user_ids: List[str] = None) -> LlmAgent:
        """
        SimulationDirectorAgentを作成します。
        
        Args:
            instruction: シミュレーションの指示
            participant_agent_ids: 参加するエージェントのIDリスト
            participant_user_ids: 参加するユーザーのIDリスト（オプション）
            
        Returns:
            SimulationDirectorAgent
        """
        try:
            # 指示テンプレートに実際の指示を埋め込み
            final_instruction = self.instruction_template.format(instruction=instruction)
            
            logger.info(f"Creating SimulationDirectorAgent with {len(participant_agent_ids)} participants")
            logger.info(f"Participant agent IDs: {participant_agent_ids}")
            logger.info(f"Participant user IDs: {participant_user_ids}")
            
            # 参加エージェントのツール関数を動的に作成
            tools = []
            for i, agent_id in enumerate(participant_agent_ids):
                logger.info(f"Creating tool for agent {i+1}: {agent_id}")
                # ユーザーIDが指定されている場合は使用、そうでなければagent_idを使用
                user_id = participant_user_ids[i] if participant_user_ids and i < len(participant_user_ids) else agent_id
                agent_tool = self._create_participant_agent_tool(agent_id, f"Participant_{i+1}", user_id)
                # 関数のname属性を設定
                agent_tool.__name__ = f"participant_{i+1}_tool"
                tools.append(agent_tool)
            
            simulation_director_agent = LlmAgent(
                model='gemini-2.0-flash-001',
                name='SimulationDirectorAgent',
                description=(
                    '''
世界最高の組織コンサルタントAI『CogniTeam AI』の頭脳であり、`SimulationDirectorAgent`として振る舞います。
自身に与えられたシミュレーション環境において、ユーザーによって指示された**TeamMemberAgent**を対話させ、その対話を分析し、人間には見えない根本原因を特定し、その解決策を検証するためのマルチエージェント・シミュレーションを設計・実行・評価し、最終的な改善案を**ユーザーに**提示します。
'''
                ),
                global_instruction=self.global_instruction,
                instruction=final_instruction,
                tools=tools
            )
            
            logger.info(f"SimulationDirectorAgent created successfully with {len(tools)} participant tools")
            return simulation_director_agent
            
        except Exception as e:
            logger.error(f"Error creating SimulationDirectorAgent: {str(e)}")
            raise

    async def execute_simulation(self, instruction: str, participant_agent_ids: List[str], participant_user_ids: List[str] = None) -> str:
        """
        シミュレーションを実行します。
        
        Args:
            instruction: シミュレーションの指示
            participant_agent_ids: 参加するエージェントのIDリスト
            participant_user_ids: 参加するユーザーのIDリスト（オプション）
            
        Returns:
            シミュレーション結果（markdown形式）
        """
        try:
            logger.info("Starting simulation execution")
            logger.info(f"Participant agent IDs: {participant_agent_ids}")
            logger.info(f"Participant user IDs: {participant_user_ids}")
            
            # SimulationDirectorAgentを作成
            director_agent = self.create_simulation_director_agent(instruction, participant_agent_ids, participant_user_ids)
            client = LocalApp(director_agent)
            DEBUG = False
            result_detail = await client.stream(instruction)
            # シミュレーション実行
            # 注意: 実際のADK APIの呼び出し方法は、ADKの実装に依存します
            # ここでは仮の実装として、非同期で実行する想定
            
            # TODO: 実際のADK API呼び出しを実装
            # result = await director_agent.run(instruction)
            
            
            # 仮の結果（実際のADKからの結果に置き換える必要があります）
            result = f"""
# シミュレーション結果
## 実行指示
{instruction}

## 参加エージェント
{', '.join([f'Agent_{aid[:8]}' for aid in participant_agent_ids])}

## 分析結果
このシミュレーションでは、指定されたメンバー間の対立構造を分析し、改善案を提示しました。

## 推奨アクション
1. **即座に実行可能な改善策**: チーム内のコミュニケーション改善のための具体的なアクションプラン
2. **長期的な改善策**: 組織文化の改善に向けた継続的な取り組み

{result_detail}
"""
            
            logger.info("Simulation execution completed successfully")
            return result
            
        except Exception as e:
            logger.error(f"Error executing simulation: {str(e)}")
            raise

    async def validate_participants(self, participant_user_ids: List[str]) -> bool:
        """
        参加者のエージェントが存在するかどうかを検証します。
        
        Args:
            participant_user_ids: 参加者のユーザーIDリスト
            
        Returns:
            全参加者のエージェントが存在する場合はTrue
        """
        try:
            # TODO: 実際のユーザーエージェント検証ロジックを実装
            # ここでは仮の実装として、常にTrueを返す
            logger.info(f"Validating participants: {participant_user_ids}")
            return True
            
        except Exception as e:
            logger.error(f"Error validating participants: {str(e)}")
            return False 