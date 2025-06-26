from firebase_admin import auth, firestore
from ..models import UserCreate, User # Pydantic models
from .user_service import UserService
from fastapi import HTTPException, status
from ..utils.firebase_setup import initialize_firebase_admin # Ensure initialized

# Ensure Firebase is initialized before this module is heavily used.
# Typically, initialization happens at app startup.
# If initialize_firebase_admin() isn't called yet, this might error if db/auth are accessed at import time.
# However, db and auth client are typically requested dynamically within methods.

class AuthService:
    def __init__(self, db_client: firestore.client):
        self.db = db_client
        self.user_service = UserService(db_client) # Instantiate UserService here

    # register_new_user becomes an instance method
    async def register_new_user(self, user_data: UserCreate) -> User:
        """
        Registers a new user in Firebase Authentication and then saves their profile to Firestore.
        """
        # initialize_firebase_admin() # Should be done at startup, not per call
        # db = self.db # Use instance db client

        try:
            firebase_user_record = auth.create_user(
                email=user_data.email,
                password=user_data.password,
                display_name=user_data.name  # Optional: set display name in Firebase Auth
            )
            uid = firebase_user_record.uid
            print(f"Successfully created new user in Firebase Auth: {uid} for email: {user_data.email}")
        except auth.EmailAlreadyExistsError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered."
            )
        except Exception as e:
            print(f"Error creating user in Firebase Auth: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Could not create user in Firebase Authentication: {e}"
            )

        # Prepare user data for Firestore, excluding password
        user_profile_data = user_data.model_dump(exclude={"password"})

        # Generate prompt using the user_service instance
        prompt = self.user_service.generate_prompt_from_user_data(user_profile_data)

        try:
            # Create user profile in Firestore using the user_service instance
            created_user_profile = await self.user_service.create_user_in_firestore(
                user_id=uid,
                user_email=user_data.email,
                user_data_dict=user_profile_data,
                prompt=prompt
                # db_client is handled by self.user_service internally now
            )
            if not created_user_profile:
                # Rollback: Delete the user from Firebase Authentication if Firestore profile creation fails
                try:
                    auth.delete_user(uid)
                    print(f"Rolled back Firebase Auth user creation for UID: {uid} due to Firestore profile error.")
                except Exception as e_auth_delete:
                    print(f"Critical error: Failed to rollback Firebase Auth user {uid}. Manual cleanup required. Error: {e_auth_delete}")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to store user profile after Firebase Auth creation. User creation rolled back."
                )
            # Assuming created_user_profile is already a Pydantic User model instance or a dict that User can parse
            if isinstance(created_user_profile, dict):
                return User(**created_user_profile)
            return created_user_profile # Should be User instance

        except Exception as e:
            print(f"Error creating user profile in Firestore for UID {uid}: {e}")
            # Rollback Firebase Auth user
            try:
                auth.delete_user(uid)
                print(f"Rolled back Firebase Auth user creation for UID: {uid} due to Firestore profile error: {e}")
            except Exception as e_auth_delete:
                print(f"Critical error: Failed to rollback Firebase Auth user {uid}. Manual cleanup required. Error: {e_auth_delete}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Could not store user profile in Firestore: {e}"
            )

    @staticmethod # This method does not require instance state (self) or db access
    async def verify_firebase_id_token(id_token: str) -> dict:
        """
        Verifies a Firebase ID token.
        Returns the decoded token (which includes user UID, email, etc.) if valid.
        Raises HTTPException if invalid.
        """
        # initialize_firebase_admin() # Should be done at startup
        try:
            decoded_token = auth.verify_id_token(id_token)
            return decoded_token
        except auth.ExpiredIdTokenError:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="ID token has expired. Please log in again.")
        except auth.InvalidIdTokenError:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid ID token. Please log in again.")
        except Exception as e:
            print(f"An unexpected error occurred during token verification: {e}")
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Could not verify authentication token.")

    # Note: Login with email/password to get an ID token is typically handled by the Firebase Client SDKs (Flutter, JS, etc.).
    # The backend's role for login is usually to *receive* this ID token and verify it, then perhaps issue its own session token/cookie if needed.
    # If you were to implement a custom token minting process (e.g., for server-to-server auth or custom sessions),
    # you might use `auth.create_custom_token(uid)`.
    # For this project, we'll assume the client (Flutter app) handles Firebase login and sends the ID token.
    # So, a specific "login" method here might just be a wrapper around verify_firebase_id_token if the goal is just to validate.
    # Or it could fetch user details from Firestore after validation.

    async def get_user_by_firebase_uid(self, uid: str) -> User | None:
        """
        Helper to get user from Firestore by Firebase UID using the UserService instance.
        """
        # db_client is handled by self.user_service
        user_dict = await self.user_service.get_user_by_id(uid)
        if user_dict:
            return User(**user_dict)
        return None

# Placeholder for JWT creation if the backend were to issue its own tokens after Firebase auth.
# from jose import jwt
# from datetime import datetime, timedelta
# from ..config import settings
#
# def create_backend_access_token(data: dict, expires_delta: timedelta | None = None):
#     to_encode = data.copy()
#     if expires_delta:
#         expire = datetime.utcnow() + expires_delta
#     else:
#         expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
#     to_encode.update({"exp": expire})
#     encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
#     return encoded_jwt
```
