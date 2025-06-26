from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer # For extracting token from Authorization header
from firebase_admin import firestore, auth

from .services.auth_service import AuthService # For token verification logic
from .services.user_service import UserService   # For fetching user profile from Firestore
from .models import User                         # Pydantic User model
from .utils.firebase_setup import initialize_firebase_admin # Ensure initialized

# This scheme will look for an "Authorization" header with a "Bearer" token.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login") # tokenUrl is for documentation, not directly used by this dependency if token is passed in header.

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    """
    Dependency to get the current user based on a Firebase ID token.
    - Extracts token from "Authorization: Bearer <token>" header.
    - Verifies the Firebase ID token.
    - Fetches the user's profile from Firestore.
    - Returns the Pydantic User model instance.
    Raises HTTPException if authentication fails or user not found.
    """
    initialize_firebase_admin() # Ensure Firebase is initialized
    db = firestore.client()     # Get Firestore client

    try:
        decoded_token = await AuthService.verify_firebase_id_token(token)
        uid = decoded_token.get("uid")
        if not uid:
            # This should ideally be caught by verify_firebase_id_token, but as a safeguard:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid ID token: UID not found after verification.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Fetch user from Firestore using the UID
        user_data_dict = await UserService.get_user_by_id(uid, db_client=db)

        if not user_data_dict:
            # This case might happen if a Firebase Auth user exists but their Firestore profile is missing.
            # This indicates an inconsistency.
            email = decoded_token.get("email", "N/A") # Get email from token for error message
            print(f"User with UID {uid} (Email: {email}) authenticated via Firebase, but profile not found in Firestore.")
            # Depending on policy, could attempt to auto-create profile here if sufficient info in token.
            # For now, treat as an error requiring profile to exist.
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"User profile not found for authenticated user (UID: {uid}). The user may exist in Firebase Auth but not in the application's database.",
                headers={"WWW-Authenticate": "Bearer"}, # Added header for consistency
            )

        # Assuming user_data_dict can be parsed into User model
        return User(**user_data_dict)

    except HTTPException as e:
        # Re-raise HTTPExceptions (e.g., from token verification or user not found)
        raise e
    except Exception as e:
        # Catch-all for other unexpected errors
        print(f"Unexpected error in get_current_user dependency: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred while authenticating: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    """
    Placeholder for a dependency that gets the current user and checks if they are "active".
    For now, it just returns the current_user.
    You could extend User model and this function to support active/inactive states.
    """
    # if not current_user.is_active: # Example if User model had an is_active field
    #     raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

# Example of how get_current_user_id might be implemented if needed:
# async def get_current_user_id(current_user: User = Depends(get_current_user)) -> str:
#    return current_user.user_id
```
