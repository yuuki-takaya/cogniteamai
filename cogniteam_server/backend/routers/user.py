from fastapi import APIRouter, Depends, HTTPException, status
from firebase_admin import firestore
from typing import List

from models import UserUpdate, UserResponse, User # Pydantic models
from services.user_service import UserService
from dependencies import get_current_user
from utils.firebase_setup import initialize_firebase_admin # Ensure initialized

router = APIRouter(
    prefix="/users",
    tags=["User Profile"],
    dependencies=[Depends(get_current_user)] # All routes in this router require authentication
)

# GET /users/me is effectively handled by /auth/me in auth.py router for now.
# If a separate one is desired here, it would be:
# @router.get("/me", response_model=UserResponse)
# async def read_users_me(current_user: User = Depends(get_current_user)):
#     """
#     Get current authenticated user's profile.
#     """
#     return UserResponse(**current_user.model_dump())


@router.get("/", response_model=List[UserResponse])
async def get_all_users(current_user: User = Depends(get_current_user)):
    """
    Get all users (excluding the current user).
    This endpoint is used for selecting users to add to chat groups.
    """
    initialize_firebase_admin()
    db = firestore.client()

    try:
        users = await UserService.get_all_users(db_client=db, exclude_user_id=current_user.user_id)
        return [UserResponse(**user.model_dump()) for user in users]
    except Exception as e:
        print(f"Error fetching users: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to fetch users.")


@router.put("/me", response_model=UserResponse)
async def update_current_user_profile(
    user_update_data: UserUpdate,
    current_user: User = Depends(get_current_user) # Gets the existing User object
):
    """
    Update the current authenticated user's profile.
    Only fields provided in the request body will be updated.
    The user's prompt will be regenerated if relevant fields are changed.
    """
    initialize_firebase_admin() # Ensure Firebase is initialized
    db = firestore.client()     # Get Firestore client

    # Convert Pydantic model to dict, excluding unset fields to only update provided values
    update_data_dict = user_update_data.model_dump(exclude_unset=True)

    if not update_data_dict:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No update data provided.")

    try:
        updated_user = await UserService.update_user_in_firestore(
            user_id=current_user.user_id, # current_user is User model from get_current_user
            update_data_dict=update_data_dict,
            db_client=db
        )
        if not updated_user:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found or update failed.")

        return UserResponse(**updated_user.model_dump())
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"Unexpected error updating user profile for {current_user.user_id}: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"An unexpected error occurred: {str(e)}")


@router.get("/me/prompt", response_model=dict) # Using dict for simplicity, could be a Pydantic model e.g. UserPromptResponse
async def get_my_agent_prompt(current_user: User = Depends(get_current_user)):
    """
    Get the current authenticated user's generated agent prompt.
    """
    initialize_firebase_admin()
    db = firestore.client()

    prompt = await UserService.get_user_prompt(user_id=current_user.user_id, db_client=db)

    if prompt is None: # Could be empty string if user has no prompt-generating data, or truly None if user/prompt field missing
        # Distinguish between "no prompt data" vs "user not found" (though get_current_user should prevent user not found)
        # For now, if prompt is None from service, assume it means not set or not applicable.
        return {"user_id": current_user.user_id, "prompt": None, "message": "Prompt not available or not set."}

    return {"user_id": current_user.user_id, "prompt": prompt}
