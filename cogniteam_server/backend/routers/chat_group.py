from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
# from firebase_admin import firestore # No longer needed directly

from ..models import ChatGroup, ChatGroupCreate, Message, User, Mission, MissionCreate
from ..services.chat_group_service import ChatGroupService
from ..dependencies import get_current_user, get_chat_group_service # Import get_chat_group_service
# from ..utils.firebase_setup import initialize_firebase_admin # Not needed directly

router = APIRouter(
    prefix="/chat_groups",
    tags=["Chat Groups"],
    dependencies=[Depends(get_current_user)]
)

@router.post("/", response_model=ChatGroup, status_code=status.HTTP_201_CREATED)
async def create_new_chat_group(
    group_data: ChatGroupCreate,
    current_user: User = Depends(get_current_user),
    chat_group_service: ChatGroupService = Depends(get_chat_group_service)
):
    try:
        new_group = await chat_group_service.create_chat_group(
            group_data=group_data,
            creator_user_id=current_user.user_id
        )
        if not new_group:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Could not create chat group.")
        return new_group
    except Exception as e:
        print(f"Error in POST /chat_groups by user {current_user.user_id}: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"An unexpected error occurred: {str(e)}")

@router.get("/{group_id}", response_model=ChatGroup)
async def get_single_chat_group(
    group_id: str,
    current_user: User = Depends(get_current_user),
    chat_group_service: ChatGroupService = Depends(get_chat_group_service)
):
    group = await chat_group_service.get_chat_group_by_id(group_id)
    if not group:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Chat group with ID {group_id} not found.")

    if current_user.user_id not in group.member_user_ids and current_user.user_id != group.created_by:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is not authorized for this group.")
    return group

@router.get("/{group_id}/messages", response_model=List[Message])
async def get_messages_for_a_group(
    group_id: str,
    current_user: User = Depends(get_current_user),
    chat_group_service: ChatGroupService = Depends(get_chat_group_service),
    limit: int = 50
):
    group = await chat_group_service.get_chat_group_by_id(group_id)
    if not group:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Chat group with ID {group_id} not found.")
    if current_user.user_id not in group.member_user_ids and current_user.user_id != group.created_by:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is not authorized for messages in this group.")

    messages = await chat_group_service.get_messages_for_group(group_id, limit=limit)
    return messages

@router.get("/", response_model=List[ChatGroup])
async def list_my_chat_groups(
    current_user: User = Depends(get_current_user),
    chat_group_service: ChatGroupService = Depends(get_chat_group_service)
):
    try:
        user_groups_list = await chat_group_service.get_chat_groups_for_user(current_user.user_id)
        return user_groups_list
    except Exception as e:
        print(f"Error listing chat groups for user {current_user.user_id}: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to retrieve user's chat groups.")

@router.post("/{group_id}/mission", response_model=Mission)
async def set_mission_for_chat_group(
    group_id: str,
    mission_data: MissionCreate,
    current_user: User = Depends(get_current_user),
    chat_group_service: ChatGroupService = Depends(get_chat_group_service)
):
    group = await chat_group_service.get_chat_group_by_id(group_id)
    if not group:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Chat group with ID {group_id} not found.")
    if current_user.user_id not in group.member_user_ids and current_user.user_id != group.created_by:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is not authorized to set mission for this group.")

    mission = await chat_group_service.set_or_update_mission(
        group_id=group_id,
        mission_data=mission_data
    )
    if not mission:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to set or update mission.")
    return mission
```
