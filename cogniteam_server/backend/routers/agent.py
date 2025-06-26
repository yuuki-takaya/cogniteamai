from fastapi import APIRouter, Depends, HTTPException
from typing import List
from firebase_admin import firestore # For db client dependency or direct use

from ..services.agent_service import AgentService
from ..models import Agent # Pydantic model
# from ..dependencies import get_current_user # Uncomment if authentication is needed

router = APIRouter(
    prefix="/agents",
    tags=["Agents"],
    # dependencies=[Depends(get_current_user)] # Uncomment to secure this endpoint
)

@router.get("/", response_model=List[Agent])
async def list_all_system_agents():
    """
    Retrieves a list of all available system agents.
    These agents can be selected to participate in chat groups.
    """
    # In a real application, you might want to inject the db client
    # using FastAPI's dependency injection system for services.
    # For simplicity here, we'll get it directly if services don't manage it.
    # initialize_firebase_admin() # Ensure initialized (done at startup)
    db = firestore.client()

    try:
        agents = await AgentService.get_all_agents(db_client=db)
        if not agents:
            # If AgentService.ensure_default_agents was run, this should ideally not be empty
            # unless there was an issue or it was cleared.
            # Consider if returning 404 is appropriate or just an empty list.
            # For now, returning an empty list is acceptable.
            print("No agents found in the system.")
            # raise HTTPException(status_code=404, detail="No agents found in the system.")
        return agents
    except Exception as e:
        print(f"Error retrieving agents: {e}")
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred while retrieving agents: {str(e)}")

```
