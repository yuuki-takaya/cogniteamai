from firebase_admin import firestore
from models import User, UserCreate # Pydantic models
from datetime import date

# This service interacts with the 'users' collection in Firestore.

class UserService:

    @staticmethod
    def generate_prompt_from_user_data(user_data_dict: dict) -> str:
        """
        Generates a personalized agent prompt based on user information.
        user_data_dict is expected to be a dictionary-like object (e.g., from Pydantic model .model_dump()).
        """
        prompt_lines = [
            "You are a conversational AI agent representing a user with the following characteristics:"
        ]
        if user_data_dict.get("name"):
            prompt_lines.append(f"- Name: {user_data_dict['name']}")
        if user_data_dict.get("sex"):
            prompt_lines.append(f"- Sex: {user_data_dict['sex']}")

        birth_date_val = user_data_dict.get("birth_date")
        if birth_date_val:
            if isinstance(birth_date_val, date):
                prompt_lines.append(f"- Birth Date: {birth_date_val.isoformat()}")
            else: # Assuming it's already a string if not a date object
                prompt_lines.append(f"- Birth Date: {str(birth_date_val)}")

        if user_data_dict.get("mbti"):
            prompt_lines.append(f"- MBTI: {user_data_dict['mbti']}")

        company_info = []
        if user_data_dict.get("company"):
            company_info.append(f"Company: {user_data_dict['company']}")
        if user_data_dict.get("division"):
            company_info.append(f"Division: {user_data_dict['division']}")
        if user_data_dict.get("department"):
            company_info.append(f"Department: {user_data_dict['department']}")
        if user_data_dict.get("section"):
            company_info.append(f"Section/Team: {user_data_dict['section']}")
        if user_data_dict.get("role"):
            company_info.append(f"Role: {user_data_dict['role']}")

        if company_info:
            prompt_lines.append("- Professional Background:")
            for info in company_info:
                prompt_lines.append(f"  - {info.strip()}") # Ensure no leading/trailing whitespace in info items

        prompt_lines.append("\nBased on this profile, engage in conversations naturally, reflecting these traits and background.")
        prompt_lines.append("Your responses should be consistent with this persona. Maintain this persona throughout the conversation.")
        return "\n".join(prompt_lines)

    @staticmethod
    async def create_user_in_firestore(user_id: str, user_email:str, user_data_dict: dict, prompt: str, db_client) -> User | None:
        """
        Creates a user profile document in Firestore.
        user_id: Firebase UID.
        user_email: User's email.
        user_data_dict: Dictionary of user profile data (from UserCreate model, excluding password).
        prompt: Generated prompt string.
        db_client: Firestore client instance.
        Returns a Pydantic User model instance if successful, None otherwise.
        """
        print(f"UserService: Starting create_user_in_firestore for UID: {user_id}")
        print(f"UserService: User email: {user_email}")
        print(f"UserService: User data dict: {user_data_dict}")
        print(f"UserService: Prompt length: {len(prompt)}")
        
        users_collection = db_client.collection('users')
        try:
            # Prepare the document data for Firestore
            # Ensure all fields of the User model are covered.
            firestore_user_data = {
                "user_id": user_id, # This is the Firebase UID, also the document ID
                "email": user_email,
                "display_name": user_data_dict.get("name"), # Use name as display_name
                "name": user_data_dict.get("name"),
                "sex": user_data_dict.get("sex"),
                "birth_date": user_data_dict.get("birth_date").isoformat() if isinstance(user_data_dict.get("birth_date"), date) else str(user_data_dict.get("birth_date")),
                "mbti": user_data_dict.get("mbti"),
                "company": user_data_dict.get("company"),
                "division": user_data_dict.get("division"),
                "department": user_data_dict.get("department"),
                "section": user_data_dict.get("section"),
                "role": user_data_dict.get("role"),
                "prompt": prompt,
                "created_at": date.today().isoformat(), # Add created_at field
                # Add any other fields from User model that should be initialized
                # "created_at": firestore.SERVER_TIMESTAMP, # Optional: server-side timestamp
            }
            print(f"UserService: Prepared Firestore data: {firestore_user_data}")
            
            # Filter out None values to keep Firestore document clean, unless None is a valid explicit value
            firestore_user_data_cleaned = {k: v for k, v in firestore_user_data.items() if v is not None}
            print(f"UserService: Cleaned Firestore data: {firestore_user_data_cleaned}")

            print(f"UserService: Attempting to write to Firestore document: {user_id}")
            users_collection.document(user_id).set(firestore_user_data_cleaned)
            print(f"Successfully created user profile in Firestore for UID: {user_id}")

            # Return a Pydantic User model instance
            print(f"UserService: Creating User model from data")
            user_model = User(**firestore_user_data_cleaned)
            print(f"UserService: Successfully created User model: {user_model}")
            return user_model

        except Exception as e:
            print(f"UserService: Error creating user profile in Firestore for UID {user_id}: {e}")
            print(f"UserService: Error type: {type(e)}")
            import traceback
            print(f"UserService: Full traceback: {traceback.format_exc()}")
            # The caller (AuthService) should handle rollback of Firebase Auth user if this fails.
            return None

    @staticmethod
    async def get_user_by_id(user_id: str, db_client) -> dict | None:
        """
        Fetches a user profile from Firestore by user_id (Firebase UID).
        Returns user data as a dictionary if found, None otherwise.
        """
        users_collection = db_client.collection('users')
        try:
            # Standard firebase-admin SDK's get() is synchronous.
            # FastAPI will run this in a thread pool if the endpoint is async.
            doc = users_collection.document(user_id).get()

            if doc.exists:
                user_data = doc.to_dict()
                # Ensure date is parsed correctly if stored as string/timestamp
                if 'birth_date' in user_data and isinstance(user_data['birth_date'], str):
                    try:
                        user_data['birth_date'] = date.fromisoformat(user_data['birth_date'])
                    except ValueError:
                        print(f"Warning: Could not parse birth_date string '{user_data['birth_date']}' for user {user_id}")
                        # Decide on fallback: None, or keep as string, or error
                        user_data['birth_date'] = None # Or some other default handling
                
                # Ensure display_name field exists (for backward compatibility)
                if 'display_name' not in user_data and 'name' in user_data:
                    user_data['display_name'] = user_data['name']
                
                # Ensure created_at field exists (for backward compatibility)
                if 'created_at' not in user_data:
                    user_data['created_at'] = date.today()
                elif isinstance(user_data['created_at'], str):
                    try:
                        user_data['created_at'] = date.fromisoformat(user_data['created_at'])
                    except ValueError:
                        user_data['created_at'] = date.today()
                
                return user_data
            return None
        except Exception as e:
            print(f"Error fetching user {user_id} from Firestore: {e}")
            return None

    @staticmethod
    async def update_user_in_firestore(user_id: str, update_data_dict: dict, db_client) -> User | None:
        """
        Updates a user's profile in Firestore.
        update_data_dict should contain only the fields to be updated.
        It's assumed that if profile fields relevant to the prompt change, the prompt is regenerated.
        """
        users_collection = db_client.collection('users')
        try:
            # Fetch current user data to regenerate prompt if necessary
            current_user_data_dict = await UserService.get_user_by_id(user_id, db_client)
            if not current_user_data_dict:
                return None # User not found

            # Merge current data with updates for prompt regeneration
            # Pydantic models can be useful here: User(**current_user_data_dict).model_copy(update=update_data_dict)
            merged_data_for_prompt = current_user_data_dict.copy()
            merged_data_for_prompt.update(update_data_dict) # update_data_dict fields will overwrite current_user_data_dict fields

            # Check if any data relevant to prompt generation has changed
            prompt_relevant_fields = ["name", "sex", "birth_date", "mbti", "company", "division", "department", "section", "role"]
            if any(key in update_data_dict for key in prompt_relevant_fields):
                new_prompt = UserService.generate_prompt_from_user_data(merged_data_for_prompt)
                update_data_dict['prompt'] = new_prompt

            # Convert date object to string if present in update_data_dict
            if 'birth_date' in update_data_dict and isinstance(update_data_dict['birth_date'], date):
                update_data_dict['birth_date'] = update_data_dict['birth_date'].isoformat()

            # Perform the update in Firestore
            users_collection.document(user_id).update(update_data_dict)
            print(f"Successfully updated user profile in Firestore for UID: {user_id}")

            # Get the fully updated user data and return as User model
            updated_user_data_dict = await UserService.get_user_by_id(user_id, db_client)
            if updated_user_data_dict:
                return User(**updated_user_data_dict)
            return None # Should ideally not happen if update was successful

        except Exception as e:
            print(f"Error updating user {user_id} in Firestore: {e}")
            return None

    @staticmethod
    async def get_user_prompt(user_id: str, db_client) -> str | None:
        """Fetches only the prompt for a given user."""
        user_data = await UserService.get_user_by_id(user_id, db_client)
        return user_data.get('prompt') if user_data else None
