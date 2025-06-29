from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional
from models import SimulationCreate, SimulationResponse, SimulationListResponse
from services.simulation_service import SimulationService
from dependencies import get_current_user, User

router = APIRouter(prefix="/simulations", tags=["simulations"])

@router.post("/", response_model=SimulationResponse)
async def create_simulation(
    simulation_data: SimulationCreate,
    current_user: User = Depends(get_current_user),
    simulation_service: SimulationService = Depends()
):
    """
    新しいシミュレーションを作成します。
    """
    try:
        # 参加者の検証
        if not simulation_data.participant_user_ids:
            raise HTTPException(status_code=400, detail="At least one participant is required")
        
        if len(simulation_data.participant_user_ids) < 1:
            raise HTTPException(status_code=400, detail="At least one participant is required")

        simulation = await simulation_service.create_simulation(
            simulation_data, 
            current_user.user_id
        )
        return simulation
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/", response_model=SimulationListResponse)
async def get_simulations(
    limit: int = Query(50, ge=1, le=100, description="Number of simulations to return"),
    offset: int = Query(0, ge=0, description="Number of simulations to skip"),
    current_user: User = Depends(get_current_user),
    simulation_service: SimulationService = Depends()
):
    """
    ユーザーが作成したシミュレーション一覧を取得します。
    """
    try:
        simulations = await simulation_service.get_simulations_by_user(
            current_user.user_id,
            limit=limit,
            offset=offset
        )
        return simulations
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/{simulation_id}", response_model=SimulationResponse)
async def get_simulation(
    simulation_id: str,
    current_user: User = Depends(get_current_user),
    simulation_service: SimulationService = Depends()
):
    """
    シミュレーションの詳細を取得します。
    """
    try:
        simulation = await simulation_service.get_simulation(simulation_id)
        
        if not simulation:
            raise HTTPException(status_code=404, detail="Simulation not found")
            
        # 作成者のみアクセス可能
        if simulation.created_by != current_user.user_id:
            raise HTTPException(status_code=403, detail="Access denied")
            
        return simulation
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.delete("/{simulation_id}")
async def delete_simulation(
    simulation_id: str,
    current_user: User = Depends(get_current_user),
    simulation_service: SimulationService = Depends()
):
    """
    シミュレーションを削除します。
    """
    try:
        success = await simulation_service.delete_simulation(
            simulation_id, 
            current_user.user_id
        )
        
        if not success:
            raise HTTPException(status_code=404, detail="Simulation not found")
            
        return {"message": "Simulation deleted successfully"}
        
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.post("/{simulation_id}/rerun", response_model=SimulationResponse)
async def rerun_simulation(
    simulation_id: str,
    current_user: User = Depends(get_current_user),
    simulation_service: SimulationService = Depends()
):
    """
    シミュレーションを再実行します。
    """
    try:
        simulation = await simulation_service.rerun_simulation(
            simulation_id, 
            current_user.user_id
        )
        return simulation
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}") 