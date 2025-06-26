from fastapi import APIRouter, Depends, HTTPException
from typing import List
# from firebase_admin import firestore # No longer needed directly

from ..services.agent_service import AgentService
from ..models import Agent # Pydantic model
from ..dependencies import get_agent_service # Import the dependency
# from ..dependencies import get_current_user # Uncomment if authentication is needed

router = APIRouter(
    prefix="/agents",
    tags=["Agents"],
    # dependencies=[Depends(get_current_user)] # Uncomment to secure this endpoint
)

@router.get("/", response_model=List[Agent])
async def list_all_system_agents(
    agent_service: AgentService = Depends(get_agent_service) # Inject AgentService
):
    """
    Retrieves a list of all available system agents.
    These agents can be selected to participate in chat groups.
    """
    try:
        # Use the injected agent_service instance
        agents = await agent_service.get_all_agents() # db_client is handled by the instance
        if not agents:
            print("No agents found in the system.")
            # Returning an empty list is generally fine.
        return agents
    except Exception as e:
        print(f"Error retrieving agents: {e}")
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred while retrieving agents: {str(e)}")
```
