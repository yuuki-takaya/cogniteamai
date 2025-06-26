from firebase_admin import firestore
from ..models import User, UserCreate # Pydantic models
from datetime import date

# This service interacts with the 'users' collection in Firestore.

class UserService:

    def __init__(self, db_client: firestore.client):
        self.db = db_client

    # Note: generate_prompt_from_user_data can remain a static method if it doesn't need self.db
    # or any other instance state. For consistency, it can also be an instance method.
    # Let's make it an instance method for now, though it doesn't use `self`.
    def generate_prompt_from_user_data(self, user_data_dict: dict) -> str:
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

    async def create_user_in_firestore(self, user_id: str, user_email:str, user_data_dict: dict, prompt: str) -> User | None:
        """
        Creates a user profile document in Firestore.
        user_id: Firebase UID.
        user_email: User's email.
        user_data_dict: Dictionary of user profile data (from UserCreate model, excluding password).
        prompt: Generated prompt string.
        Returns a Pydantic User model instance if successful, None otherwise.
        """
        users_collection = self.db.collection('users')
        try:
            firestore_user_data = {
                "user_id": user_id,
                "email": user_email,
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
            }
            firestore_user_data_cleaned = {k: v for k, v in firestore_user_data.items() if v is not None}

            users_collection.document(user_id).set(firestore_user_data_cleaned)
            print(f"Successfully created user profile in Firestore for UID: {user_id}")

            return User(**firestore_user_data_cleaned)

        except Exception as e:
            print(f"Error creating user profile in Firestore for UID {user_id}: {e}")
            return None

    async def get_user_by_id(self, user_id: str) -> dict | None:
        """
        Fetches a user profile from Firestore by user_id (Firebase UID).
        Returns user data as a dictionary if found, None otherwise.
        """
        users_collection = self.db.collection('users')
        try:
            doc = users_collection.document(user_id).get()

            if doc.exists:
                user_data = doc.to_dict()
                if 'birth_date' in user_data and isinstance(user_data['birth_date'], str):
                    try:
                        user_data['birth_date'] = date.fromisoformat(user_data['birth_date'])
                    except ValueError:
                        print(f"Warning: Could not parse birth_date string '{user_data['birth_date']}' for user {user_id}")
                        user_data['birth_date'] = None
                return user_data
            return None
        except Exception as e:
            print(f"Error fetching user {user_id} from Firestore: {e}")
            return None

    async def update_user_in_firestore(self, user_id: str, update_data_dict: dict) -> User | None:
        """
        Updates a user's profile in Firestore.
        update_data_dict should contain only the fields to be updated.
        """
        users_collection = self.db.collection('users')
        try:
            current_user_data_dict = await self.get_user_by_id(user_id) # Uses self.db via the method call
            if not current_user_data_dict:
                return None

            merged_data_for_prompt = current_user_data_dict.copy()
            merged_data_for_prompt.update(update_data_dict)

            prompt_relevant_fields = ["name", "sex", "birth_date", "mbti", "company", "division", "department", "section", "role"]
            if any(key in update_data_dict for key in prompt_relevant_fields):
                new_prompt = self.generate_prompt_from_user_data(merged_data_for_prompt) # Call instance method
                update_data_dict['prompt'] = new_prompt

            if 'birth_date' in update_data_dict and isinstance(update_data_dict['birth_date'], date):
                update_data_dict['birth_date'] = update_data_dict['birth_date'].isoformat()

            users_collection.document(user_id).update(update_data_dict)
            print(f"Successfully updated user profile in Firestore for UID: {user_id}")

            updated_user_data_dict = await self.get_user_by_id(user_id) # Re-fetch
            if updated_user_data_dict:
                return User(**updated_user_data_dict)
            return None

        except Exception as e:
            print(f"Error updating user {user_id} in Firestore: {e}")
            return None

    async def get_user_prompt(self, user_id: str) -> str | None:
        """Fetches only the prompt for a given user."""
        user_data = await self.get_user_by_id(user_id) # Uses self.db
        return user_data.get('prompt') if user_data else None

```
