from firebase_admin import auth, firestore
from models import UserCreate, User # Pydantic models
from services.user_service import UserService
from services.agent_engine_service import AgentEngineService
from fastapi import HTTPException, status
from utils.firebase_setup import initialize_firebase_admin # Ensure initialized
from config import settings

# Ensure Firebase is initialized before this module is heavily used.
# Typically, initialization happens at app startup.
# If initialize_firebase_admin() isn't called yet, this might error if db/auth are accessed at import time.
# However, db and auth client are typically requested dynamically within methods.

class AuthService:

    # db = firestore.client() # Get Firestore client instance

    @staticmethod
    async def register_new_user(user_data: UserCreate) -> User:
        """
        Registers a new user in Firebase Authentication and then saves their profile to Firestore.
        Also creates a Google AI Agent and registers it with Vertex AI Agent Engine.
        """
        print(f"AuthService: Starting register_new_user for email: {user_data.email}")
        initialize_firebase_admin() # Ensure it's initialized, though ideally done once at startup
        db = firestore.client() # Get Firestore client instance

        try:
            print(f"AuthService: Attempting to create Firebase user for email: {user_data.email}")
            firebase_user_record = auth.create_user(
                email=user_data.email,
                password=user_data.password,
                display_name=user_data.name  # Optional: set display name in Firebase Auth
            )
            uid = firebase_user_record.uid
            print(f"AuthService: Successfully created new user in Firebase Auth: {uid} for email: {user_data.email}")
        except auth.EmailAlreadyExistsError as e:
            print(f"AuthService: EmailAlreadyExistsError for email: {user_data.email}")
            print(f"AuthService: Error details: {e}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered."
            )
        except Exception as e:
            print(f"AuthService: Error creating user in Firebase Auth: {e}")
            print(f"AuthService: Error type: {type(e)}")
            import traceback
            print(f"AuthService: Full traceback: {traceback.format_exc()}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Could not create user in Firebase Authentication: {e}"
            )

        # Prepare user data for Firestore, excluding password
        user_profile_data = user_data.model_dump(exclude={"password"})

        # Generate prompt (this might be better placed in UserService or called by it)
        prompt = UserService.generate_prompt_from_user_data(user_profile_data)

        # Create Google AI Agent and register with Vertex AI Agent Engine
        agent_engine_endpoint = None
        if settings.VERTEX_AI_AGENT_ENGINE_ENABLED and not settings.VERTEX_AI_AGENT_ENGINE_SKIP_CREATION:
            print(f"AuthService: Agent Engine is enabled, attempting to create agent for user {uid}")
            try:
                import asyncio
                agent_engine_service = AgentEngineService()
                
                print(f"AuthService: Starting Agent Engine creation with timeout...")
                
                # Set timeout for Agent Engine creation (10 minutes)
                agent_result = await asyncio.wait_for(
                    agent_engine_service.create_and_register_agent(
                        name=user_data.name,
                        description=str(user_data.model_dump()),
                        instruction=prompt
                    ),
                    timeout=600.0  # 10 minutes timeout
                )
                agent_engine_endpoint = agent_result["endpoint_url"]
                print(f"AuthService: Successfully created and registered agent for user {uid}. Endpoint: {agent_engine_endpoint}")
            except asyncio.TimeoutError:
                print(f"AuthService: Agent Engine creation timed out for user {uid}. Continuing without agent.")
                agent_engine_endpoint = None
            except Exception as e:
                print(f"AuthService: Warning: Failed to create/register agent for user {uid}: {e}")
                print(f"AuthService: Error type: {type(e)}")
                import traceback
                print(f"AuthService: Full traceback: {traceback.format_exc()}")
                # Continue with user creation even if agent creation fails
                # The user can still use the system, just without a personalized agent
                agent_engine_endpoint = None
        elif settings.VERTEX_AI_AGENT_ENGINE_SKIP_CREATION:
            print(f"AuthService: Agent Engine creation is skipped (VERTEX_AI_AGENT_ENGINE_SKIP_CREATION=true). Skipping agent creation for user {uid}")
        else:
            print(f"AuthService: Agent Engine is disabled (VERTEX_AI_AGENT_ENGINE_ENABLED=false). Skipping agent creation for user {uid}")

        try:
            # Create user profile in Firestore using UserService
            # The UserService.create_user_in_firestore should return a Pydantic User model instance or dict
            created_user_profile = await UserService.create_user_in_firestore(
                user_id=uid,
                user_email=user_data.email, # Pass email to be stored in Firestore user doc
                user_data_dict=user_profile_data, # Pass the full Pydantic model data as dict
                prompt=prompt,
                agent_engine_endpoint=agent_engine_endpoint, # Pass the endpoint URL
                db_client=db # Pass the Firestore client
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

    @staticmethod
    async def verify_firebase_id_token(id_token: str) -> dict:
        """
        Verifies a Firebase ID token.
        Returns the decoded token (which includes user UID, email, etc.) if valid.
        Raises HTTPException if invalid.
        """
        initialize_firebase_admin() # Ensure initialized
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

    @staticmethod
    async def get_user_by_firebase_uid(uid: str, db_client=None) -> User | None:
        """
        Helper to get user from Firestore by Firebase UID.
        This might be better suited in UserService but placed here if auth logic needs it directly.
        """
        if not db_client:
            initialize_firebase_admin()
            db_client = firestore.client()

        user_dict = await UserService.get_user_by_id(uid, db_client)
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
