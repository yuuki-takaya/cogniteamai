from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from firebase_admin import firestore

from ..models import ChatGroup, ChatGroupCreate, Message, User, Mission, MissionCreate # Pydantic models
from ..services.chat_group_service import ChatGroupService
from ..dependencies import get_current_user # For authentication
from ..utils.firebase_setup import initialize_firebase_admin

router = APIRouter(
    prefix="/chat_groups",
    tags=["Chat Groups"],
    dependencies=[Depends(get_current_user)] # All routes here require authentication
)

@router.post("/", response_model=ChatGroup, status_code=status.HTTP_201_CREATED)
async def create_new_chat_group(
    group_data: ChatGroupCreate,
    current_user: User = Depends(get_current_user) # Injects the authenticated user
):
    """
    Creates a new chat group with the specified agents.
    The authenticated user will be the creator and an initial member.
    """
    initialize_firebase_admin() # Ensure initialized
    db = firestore.client()

    try:
        new_group = await ChatGroupService.create_chat_group(
            group_data=group_data,
            creator_user_id=current_user.user_id,
            db_client=db
        )
        if not new_group:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Could not create chat group due to an internal error.")
        return new_group
    except Exception as e:
        # More specific error handling could be added here based on ChatGroupService behavior
        print(f"Error in POST /chat_groups by user {current_user.user_id}: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"An unexpected error occurred: {str(e)}")


@router.get("/{group_id}", response_model=ChatGroup)
async def get_single_chat_group(group_id: str, current_user: User = Depends(get_current_user)):
    """
    Retrieves details of a specific chat group by its ID.
    (Future enhancement: check if current_user is a member of the group).
    """
    initialize_firebase_admin()
    db = firestore.client()

    group = await ChatGroupService.get_chat_group_by_id(group_id, db_client=db)
    if not group:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Chat group with ID {group_id} not found.")

    # Basic authorization: Check if the current user is part of the group
    # This assumes 'member_user_ids' field exists and is populated in your ChatGroup model and Firestore documents.
    # If ChatGroup model from service doesn't include member_user_ids directly, adjust logic.
    # Current ChatGroup model does have member_user_ids.
    if current_user.user_id not in group.member_user_ids:
         # Also allow if the user is the creator, even if not explicitly in member_user_ids (though creator should be a member)
        if current_user.user_id != group.created_by:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is not authorized to access this chat group.")

    return group


@router.get("/{group_id}/messages", response_model=List[Message])
async def get_messages_for_a_group(
    group_id: str,
    current_user: User = Depends(get_current_user),
    limit: int = 50 # Optional query parameter for pagination
):
    """
    Retrieves messages for a specific chat group.
    (Future enhancement: check if current_user is a member of the group).
    """
    initialize_firebase_admin()
    db = firestore.client()

    # First, verify group existence and user's access to it (similar to get_single_chat_group)
    group = await ChatGroupService.get_chat_group_by_id(group_id, db_client=db)
    if not group:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Chat group with ID {group_id} not found.")
    if current_user.user_id not in group.member_user_ids and current_user.user_id != group.created_by:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is not authorized to access messages for this chat group.")

    messages = await ChatGroupService.get_messages_for_group(group_id, db_client=db, limit=limit)
    # No need to check if messages is empty, an empty list is a valid response.
    return messages


# Placeholder for listing groups a user is part of
@router.get("/", response_model=List[ChatGroup])
async def list_my_chat_groups(current_user: User = Depends(get_current_user)):
    """
    Lists all chat groups the current authenticated user is a member of.
    (This requires extending ChatGroupService to query groups by member_user_ids)
    """
    initialize_firebase_admin()
    db = firestore.client()

    # This service method needs to be implemented in ChatGroupService
    # For example: groups = await ChatGroupService.get_chat_groups_for_user(current_user.user_id, db)
    # For now, returning a placeholder:
    # print(f"Placeholder: User {current_user.user_id} requested their chat groups. This feature needs ChatGroupService.get_chat_groups_for_user.")
    # Example of how it might be implemented in ChatGroupService:
    # query = db.collection('chat_groups').where('member_user_ids', 'array_contains', current_user.user_id).stream()
    # groups = [ChatGroup(**doc.to_dict()) for doc in query]
    # return groups

    # Simulating the query for now directly here:
    try:
        # Corrected synchronous iteration:
        docs = db.collection('chat_groups').where(filter=firestore.FieldFilter('member_user_ids', 'array_contains', current_user.user_id)).stream()
        user_groups_list = [ChatGroup(**doc.to_dict()) for doc in docs]
        return user_groups_list
    except Exception as e:
        print(f"Error listing chat groups for user {current_user.user_id}: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to retrieve user's chat groups.")


@router.post("/{group_id}/mission", response_model=Mission)
async def set_mission_for_chat_group(
    group_id: str,
    mission_data: MissionCreate, # Expects only mission_text
    current_user: User = Depends(get_current_user) # Ensure user is authenticated
):
    """
    Sets or updates the mission for a specific chat group.
    Only users who are members of the group (or creators) can set a mission.
    """
    initialize_firebase_admin()
    db = firestore.client()

    # Verify group existence and user's access
    group = await ChatGroupService.get_chat_group_by_id(group_id, db_client=db)
    if not group:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Chat group with ID {group_id} not found.")
    if current_user.user_id not in group.member_user_ids and current_user.user_id != group.created_by:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is not authorized to set a mission for this chat group.")

    mission = await ChatGroupService.set_or_update_mission(
        group_id=group_id,
        mission_text=mission_data.mission_text,
        db_client=db
    )
    if not mission:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to set or update mission for the group.")

    return mission
```
