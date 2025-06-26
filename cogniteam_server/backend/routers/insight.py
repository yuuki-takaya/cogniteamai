from fastapi import APIRouter, Depends, HTTPException, status, Query
# from firebase_admin import firestore # No longer needed directly

from ..models import Insight as InsightResponseModel, User as UserModel
from ..services.insight_service import InsightService
from ..services.chat_group_service import ChatGroupService
from ..dependencies import get_current_user, get_insight_service, get_chat_group_service # Import dependencies
# from ..utils.firebase_setup import initialize_firebase_admin # Not needed directly

router = APIRouter(
    prefix="/insights",
    tags=["Insights"],
    dependencies=[Depends(get_current_user)]
)

# Removed old helper `get_insight_service` as it's now in dependencies.py

@router.get("/{group_id}", response_model=InsightResponseModel)
async def get_insights_for_chat_group(
    group_id: str,
    insight_type: str = Query("summary", enum=["summary", "sentiment", "keywords", "no_data"]),
    current_user: UserModel = Depends(get_current_user),
    insight_service: InsightService = Depends(get_insight_service), # Injected
    chat_group_service: ChatGroupService = Depends(get_chat_group_service) # Injected
):
    """
    Generates and retrieves insights for a specific chat group.
    - `group_id`: The ID of the chat group.
    - `insight_type`: Optional query parameter to specify the type of insight.
      Defaults to "summary". Allowed values: "summary", "sentiment", "keywords", "no_data".

    The user must be a member of the group to request insights.
    """
    # 1. Verify group existence and user's access to it
    # db_client for chat_group_service is handled by its instance
    group = await chat_group_service.get_chat_group_by_id(group_id)
    if not group:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Chat group with ID {group_id} not found.")

    if current_user.user_id not in group.member_user_ids and current_user.user_id != group.created_by:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is not authorized to access insights for this chat group.")

    # 2. Generate or fetch insight using the injected insight_service
    try:
        # insight_service already has its dependencies (db, chat_group_service) injected
        insight_data = await insight_service.generate_insight_for_group(group_id, insight_type=insight_type)
        if not insight_data: # This case should be handled by InsightService returning a "no_data" insight or raising.
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Could not generate or retrieve insights for group {group_id} and type '{insight_type}'.")

        return insight_data
    except HTTPException as e: # Catch HTTPExceptions raised by services or this router
        raise e
    except Exception as e: # Catch any other unexpected errors
        print(f"Unexpected error generating insight for group {group_id} (user: {current_user.user_id}): {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"An unexpected error occurred: {str(e)}")

```
