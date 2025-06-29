from fastapi import APIRouter, Depends, HTTPException, status
# from fastapi.security import OAuth2PasswordRequestForm # Not used if client handles Firebase login and sends ID token

from services.auth_service import AuthService
# UserService is used by AuthService internally for profile creation.
from models import UserCreate, UserResponse, IdTokenRequest, User # Pydantic models
from dependencies import get_current_user # For authenticated endpoints if needed elsewhere
from firebase_admin import firestore, auth # For type hinting or specific exceptions
from config import settings # For agent engine configuration

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)

@router.post("/signup", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def signup_new_user(user_data: UserCreate):
    """
    Registers a new user.
    - Creates user in Firebase Authentication.
    - Creates user profile in Firestore with a generated initial prompt.
    - If user already exists, attempts to sign them in instead.
    """
    print(f"Starting signup process for email: {user_data.email}")
    try:
        # AuthService.register_new_user handles both Firebase Auth and Firestore profile creation.
        created_user = await AuthService.register_new_user(user_data)
        if not created_user: # Should be handled by exceptions in AuthService, but as a safeguard
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="User registration failed unexpectedly.")

        # Convert User model to UserResponse model if necessary, or ensure UserResponse fields are present
        # Assuming User model from AuthService has all necessary fields for UserResponse
        print(f"Successfully created new user: {created_user.email}")
        print(f"User UID: {created_user.user_id}")
        print(f"User profile created in Firestore successfully")
        return UserResponse(**created_user.model_dump())
    except HTTPException as e:
        print(f"HTTPException during signup: status_code={e.status_code}, detail={e.detail}")
        # If the error is "Email already registered", check if it's a real existing user or a failed previous signup
        if e.status_code == status.HTTP_400_BAD_REQUEST and "Email already registered" in str(e.detail):
            print(f"User {user_data.email} already exists, checking Firebase and Firestore status...")
            try:
                # Check if the user actually exists in Firebase
                firebase_user = auth.get_user_by_email(user_data.email)
                uid = firebase_user.uid
                print(f"Found existing Firebase user with UID: {uid}")
                
                # Check if user profile exists in Firestore
                db = firestore.client()
                user_profile = await AuthService.get_user_by_firebase_uid(uid, db_client=db)
                
                if user_profile:
                    print(f"User {user_data.email} already has a complete profile. This is a duplicate signup attempt.")
                    # Return existing user profile instead of creating a new one
                    return UserResponse(**user_profile.model_dump())
                else:
                    # User exists in Firebase but not in Firestore - this indicates a failed previous signup
                    print(f"User {user_data.email} exists in Firebase but profile missing in Firestore. Creating missing profile...")
                    try:
                        # Prepare user data for Firestore, excluding password
                        user_profile_data = user_data.model_dump(exclude={"password"})
                        print(f"User profile data prepared: {user_profile_data}")
                        
                        # Generate prompt
                        from services.user_service import UserService
                        prompt = UserService.generate_prompt_from_user_data(user_profile_data)
                        print(f"Generated prompt: {prompt[:100]}...")  # Show first 100 chars
                        
                        # Create Google AI Agent and register with Vertex AI Agent Engine (same as new user creation)
                        agent_engine_endpoint = None
                        if settings.VERTEX_AI_AGENT_ENGINE_ENABLED and not settings.VERTEX_AI_AGENT_ENGINE_SKIP_CREATION:
                            try:
                                import asyncio
                                from services.agent_engine_service import AgentEngineService
                                
                                print(f"Starting Agent Engine creation for existing user {uid} with timeout...")
                                
                                # Set timeout for Agent Engine creation (10 minutes)
                                agent_engine_service = AgentEngineService()
                                agent_result = await asyncio.wait_for(
                                    agent_engine_service.create_and_register_agent(
                                        name=user_data.name,
                                        description=str(user_data.model_dump()),
                                        instruction=prompt
                                    ),
                                    timeout=600.0  # 10 minutes timeout
                                )
                                agent_engine_endpoint = agent_result["endpoint_url"]
                                agent_engine_id = agent_result["agent_id"]
                                print(f"Successfully created and registered agent for existing user {uid}. Endpoint: {agent_engine_endpoint}")
                            except asyncio.TimeoutError:
                                print(f"Agent Engine creation timed out for existing user {uid}. Continuing without agent.")
                                agent_engine_endpoint = None
                            except Exception as e:
                                print(f"Warning: Failed to create/register agent for existing user {uid}: {e}")
                                print(f"Error type: {type(e)}")
                                import traceback
                                print(f"Full traceback: {traceback.format_exc()}")
                                # Continue with user profile creation even if agent creation fails
                                # The user can still use the system, just without a personalized agent
                                agent_engine_endpoint = None
                        elif settings.VERTEX_AI_AGENT_ENGINE_SKIP_CREATION:
                            print(f"Agent Engine creation is skipped (VERTEX_AI_AGENT_ENGINE_SKIP_CREATION=true). Skipping agent creation for existing user {uid}")
                        else:
                            print(f"Agent Engine is disabled. Skipping agent creation for existing user {uid}")
                        
                        # Create user profile in Firestore
                        print(f"Attempting to create user profile in Firestore for UID: {uid}")
                        created_user_profile = await UserService.create_user_in_firestore(
                            user_id=uid,
                            user_email=user_data.email,
                            user_data_dict=user_profile_data,
                            prompt=prompt,
                            agent_engine_endpoint=agent_engine_endpoint,  # Pass the endpoint URL
                            agent_engine_id=agent_engine_id,  # Pass the agent ID
                            db_client=db
                        )
                        
                        if created_user_profile:
                            print(f"Successfully created missing user profile for {user_data.email}")
                            if isinstance(created_user_profile, dict):
                                return UserResponse(**created_user_profile)
                            return UserResponse(**created_user_profile.model_dump())
                        else:
                            print(f"UserService.create_user_in_firestore returned None for UID: {uid}")
                            raise HTTPException(
                                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                                detail="Failed to create missing user profile."
                            )
                    except Exception as profile_creation_error:
                        print(f"Error creating missing user profile: {profile_creation_error}")
                        print(f"Error type: {type(profile_creation_error)}")
                        import traceback
                        print(f"Full traceback: {traceback.format_exc()}")
                        raise HTTPException(
                            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                            detail=f"Failed to create missing user profile: {str(profile_creation_error)}"
                        )
            except auth.UserNotFoundError:
                # This shouldn't happen if we got the "Email already registered" error
                print(f"UserNotFoundError: Email {user_data.email} was reported as already registered but not found in Firebase")
                # This indicates a Firebase configuration issue or the user was deleted
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Email registration failed due to Firebase configuration issue. Please try again or contact support."
                )
            except Exception as signin_error:
                print(f"Error checking existing user: {signin_error}")
                print(f"Error type: {type(signin_error)}")
                import traceback
                print(f"Full traceback: {traceback.format_exc()}")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"Failed to check existing user status: {str(signin_error)}"
                )
        else:
            # Re-raise other HTTPException to let FastAPI handle it
            print(f"Re-raising HTTPException: {e.detail}")
            raise e
    except Exception as e:
        # Catch any other unexpected errors during signup
        print(f"Unexpected error during signup: {e}")
        print(f"Error type: {type(e)}")
        import traceback
        print(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred during user registration: {str(e)}"
        )


@router.post("/login", response_model=UserResponse)
async def login_with_id_token(token_data: IdTokenRequest):
    """
    Authenticates a user based on a Firebase ID token obtained from the client.
    - Verifies the Firebase ID token.
    - If valid, fetches the user's profile from Firestore.
    - Returns the user's profile.

    The client (Flutter app) is responsible for:
    1. Signing in the user with Firebase Authentication (e.g., email/password).
    2. Getting the ID token from the Firebase User object.
    3. Sending this ID token to this backend endpoint.
    """
    print(f"Login endpoint called with token data: {token_data}")
    print(f"Token length: {len(token_data.id_token)}")
    print(f"Token starts with: {token_data.id_token[:20]}...")
    
    try:
        decoded_token = await AuthService.verify_firebase_id_token(token_data.id_token)
        uid = decoded_token.get("uid")
        if not uid:
            print("Login: UID not found in decoded token")
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid ID token: UID not found.")

        print(f"Login: Token verified successfully for UID: {uid}")

        # Fetch user from Firestore using the UID
        # We need a Firestore client instance here. It's better if services handle their own db client needs.
        # For now, let's assume AuthService can provide this or it's passed around.
        # initialize_firebase_admin() # Should be done at startup
        db = firestore.client()
        user_profile = await AuthService.get_user_by_firebase_uid(uid, db_client=db) # Or use UserService directly

        if not user_profile:
            # This case might happen if a Firebase Auth user exists but their Firestore profile is missing.
            # This indicates an inconsistency. Depending on policy, could try to recreate profile or error.
            print(f"User with UID {uid} authenticated via Firebase, but profile not found in Firestore.")
            # For now, treat as an error. Could also attempt to create a profile if email is in decoded_token.
            email = decoded_token.get("email", "N/A")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"User profile not found for authenticated user {email}. Please contact support or try signing up again if this is a new account."
            )

        print(f"Login: User profile found successfully for UID: {uid}")
        return UserResponse(**user_profile.model_dump())

    except HTTPException as e:
        print(f"Login: HTTPException occurred: {e.status_code} - {e.detail}")
        raise e # Re-raise known HTTPExceptions (e.g., from token verification)
    except Exception as e:
        print(f"Login: Unexpected error during login with ID token: {e}")
        print(f"Login: Error type: {type(e)}")
        import traceback
        print(f"Login: Full traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred during login: {str(e)}"
        )

# Example of a protected route, though not strictly part of login/signup itself:
@router.get("/me", response_model=UserResponse, summary="Get current authenticated user's profile")
async def get_my_profile(current_user: User = Depends(get_current_user)):
    """
    Retrieves the profile of the currently authenticated user.
    The `get_current_user` dependency handles ID token verification from the Authorization header.
    """
    # current_user is already a Pydantic User model instance from get_current_user
    return UserResponse(**current_user.model_dump())
