from fastapi import APIRouter, Depends, HTTPException, status
# from fastapi.security import OAuth2PasswordRequestForm # Not used if client handles Firebase login and sends ID token

from ..services.auth_service import AuthService
# UserService is used by AuthService internally for profile creation.
from ..models import UserCreate, UserResponse, IdTokenRequest, User # Pydantic models
from ..dependencies import get_current_user, get_auth_service # Import service dependencies
# from firebase_admin import firestore, auth # Not directly used here now

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)

@router.post("/signup", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def signup_new_user(
    user_data: UserCreate,
    auth_service: AuthService = Depends(get_auth_service) # Inject AuthService
):
    """
    **Register a new user.**

    This endpoint allows a new user to sign up for the service.
    Upon successful registration:
    - A new user is created in Firebase Authentication.
    - A corresponding user profile is created in Firestore, including an initial agent prompt
      generated based on the provided profile information.

    Request body should conform to the `UserCreate` schema, including:
    - `email`: User's email address (must be unique).
    - `password`: User's chosen password (min length requirements may apply).
    - `name`: User's full name.
    - `sex`: User's sex.
    - `birth_date`: User's birth date (YYYY-MM-DD).
    - `mbti` (optional): User's MBTI type.
    - `company` (optional): User's company name.
    - `division` (optional): User's division.
    - `department` (optional): User's department.
    - `section` (optional): User's section or team.
    - `role` (optional): User's role or job title.

    Returns the created user's profile information (excluding password) as `UserResponse`.
    Raises HTTPException (400) if email already exists or input data is invalid.
    Raises HTTPException (500) for internal server errors during registration.
    """
    try:
        created_user = await auth_service.register_new_user(user_data)
        return UserResponse(**created_user.model_dump())
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"Unexpected error during signup: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred during user registration: {str(e)}"
        )


@router.post("/login", response_model=UserResponse)
async def login_with_id_token(
    token_data: IdTokenRequest,
    auth_service: AuthService = Depends(get_auth_service) # Inject AuthService
):
    """
    **Authenticate a user and retrieve their profile using a Firebase ID Token.**

    The client application (e.g., Flutter app) is responsible for:
    1. Signing in the user with Firebase Authentication (e.g., using email/password, Google Sign-In).
    2. Obtaining the Firebase ID Token from the authenticated Firebase User object.
    3. Sending this ID Token in the request body to this endpoint.

    This endpoint will:
    - Verify the received Firebase ID Token.
    - If the token is valid, fetch the user's full profile from Firestore.

    Request body should conform to `IdTokenRequest` schema:
    - `id_token`: The Firebase ID token string.

    Returns the user's profile information as `UserResponse` if authentication is successful.
    Raises HTTPException (401) if the token is invalid or expired.
    Raises HTTPException (404) if the user profile is not found in Firestore for an authenticated user.
    Raises HTTPException (500) for other internal server errors.
    """
    try:
        decoded_token = await AuthService.verify_firebase_id_token(token_data.id_token)
        uid = decoded_token.get("uid")
        if not uid:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid ID token: UID not found.")

        user_profile = await auth_service.get_user_by_firebase_uid(uid)

        if not user_profile:
            email = decoded_token.get("email", "N/A")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"User profile not found for authenticated user {email} (UID: {uid})."
            )

        return UserResponse(**user_profile.model_dump())

    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"Unexpected error during login with ID token: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred during login: {str(e)}"
        )

@router.get("/me", response_model=UserResponse, summary="Get current authenticated user's profile")
async def get_my_profile(current_user: User = Depends(get_current_user)):
    """
    **Retrieve the profile of the currently authenticated user.**

    This endpoint requires a valid Firebase ID Token to be passed in the
    `Authorization: Bearer <ID_TOKEN>` header.
    The `get_current_user` dependency handles token verification and fetches
    the user data from Firestore.

    Returns the authenticated user's profile information as `UserResponse`.
    Raises HTTPException (401) if authentication fails.
    Raises HTTPException (404) if user profile not found after successful token verification.
    """
    return UserResponse(**current_user.model_dump())
```
