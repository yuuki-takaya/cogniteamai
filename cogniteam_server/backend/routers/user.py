from fastapi import APIRouter, Depends, HTTPException, status
# from firebase_admin import firestore # No longer needed directly here

from ..models import UserUpdate, UserResponse, User # Pydantic models
from ..services.user_service import UserService
from ..dependencies import get_current_user, get_user_service # Import get_user_service
# from ..utils.firebase_setup import initialize_firebase_admin # Not needed directly

router = APIRouter(
    prefix="/users",
    tags=["User Profile"],
    dependencies=[Depends(get_current_user)] # All routes in this router require authentication
)

@router.put("/me", response_model=UserResponse)
async def update_current_user_profile(
    user_update_data: UserUpdate,
    current_user: User = Depends(get_current_user), # Gets the existing User object
    user_service: UserService = Depends(get_user_service) # Inject UserService
):
    """
    Update the current authenticated user's profile.
    Only fields provided in the request body will be updated.
    The user's prompt will be regenerated if relevant fields are changed.
    """
    # initialize_firebase_admin() # Done at startup
    # db = firestore.client() # Handled by get_user_service

    update_data_dict = user_update_data.model_dump(exclude_unset=True)

    if not update_data_dict:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No update data provided.")

    try:
        # Use the injected user_service instance
        updated_user = await user_service.update_user_in_firestore(
            user_id=current_user.user_id,
            update_data_dict=update_data_dict
            # db_client is handled by user_service instance
        )
        if not updated_user: # Should raise an exception from service if user_id not found
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="User profile update failed unexpectedly.")

        return UserResponse(**updated_user.model_dump())
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"Unexpected error updating user profile for {current_user.user_id}: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"An unexpected error occurred: {str(e)}")


@router.get("/me/prompt", response_model=dict)
async def get_my_agent_prompt(
    current_user: User = Depends(get_current_user),
    user_service: UserService = Depends(get_user_service) # Inject UserService
):
    """
    Get the current authenticated user's generated agent prompt.
    """
    # initialize_firebase_admin() # Done at startup
    # db = firestore.client() # Handled by get_user_service

    prompt = await user_service.get_user_prompt(user_id=current_user.user_id) # db_client handled by instance

    # The prompt field in User model is Optional[str].
    # So, current_user.prompt could be None.
    # The get_user_prompt method also returns Optional[str].
    # We can directly use current_user.prompt if get_current_user ensures the User model is fresh.
    # However, calling user_service.get_user_prompt might be slightly more explicit if prompt generation
    # logic is complex and not always reflected in the immediate User object from get_current_user.
    # For now, using the service method is fine.

    if prompt is None: # This implies the prompt field itself is None in the user's document
        return {"user_id": current_user.user_id, "prompt": None, "message": "Prompt is not set or not applicable for this user."}

    return {"user_id": current_user.user_id, "prompt": prompt}
```
