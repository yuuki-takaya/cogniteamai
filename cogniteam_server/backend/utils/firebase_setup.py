import firebase_admin
from firebase_admin import credentials
import os
from ..config import settings

def initialize_firebase_admin():
    """
    Initializes the Firebase Admin SDK.
    It prioritizes GOOGLE_APPLICATION_CREDENTIALS environment variable.
    If not set, it tries to use FIREBASE_SERVICE_ACCOUNT_KEY_PATH from .env.
    """
    if firebase_admin._apps:
        print("Firebase Admin SDK already initialized.")
        return

    try:
        # Firebase Admin SDK automatically checks for GOOGLE_APPLICATION_CREDENTIALS env var.
        # If it's set, it will be used.
        cred_object = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

        if cred_object:
            print("Initializing Firebase Admin SDK using GOOGLE_APPLICATION_CREDENTIALS.")
            # When GOOGLE_APPLICATION_CREDENTIALS is set, passing no args to initialize_app works,
            # or you can explicitly pass credentials.Certificate(cred_object) if it's a path.
            # However, the SDK handles the env var directly if no explicit cred is passed.
            firebase_admin.initialize_app()
        elif settings.FIREBASE_SERVICE_ACCOUNT_KEY_PATH:
            if os.path.exists(settings.FIREBASE_SERVICE_ACCOUNT_KEY_PATH):
                print(f"Initializing Firebase Admin SDK using service account key from: {settings.FIREBASE_SERVICE_ACCOUNT_KEY_PATH}")
                cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_KEY_PATH)
                firebase_admin.initialize_app(cred)
            else:
                print(f"Error: FIREBASE_SERVICE_ACCOUNT_KEY_PATH is set to '{settings.FIREBASE_SERVICE_ACCOUNT_KEY_PATH}', but the file does not exist.")
                print("Firebase Admin SDK NOT initialized.")
                return # Or raise an error
        else:
            print("Warning: Neither GOOGLE_APPLICATION_CREDENTIALS env var nor FIREBASE_SERVICE_ACCOUNT_KEY_PATH in .env is set/valid.")
            print("Attempting to initialize Firebase Admin SDK with default credentials (may work in some GCP environments).")
            try:
                firebase_admin.initialize_app() # For environments like Cloud Run with service account identity
                print("Firebase Admin SDK initialized with default credentials.")
            except Exception as e_default:
                print(f"Failed to initialize Firebase Admin SDK with default credentials: {e_default}")
                print("Firebase Admin SDK NOT initialized. Please check your credential configuration.")
                return # Or raise an error

        print("Firebase Admin SDK initialization attempt completed.")

    except Exception as e:
        print(f"An unexpected error occurred during Firebase Admin SDK initialization: {e}")
        # Depending on the application's needs, you might want to raise the exception
        # or handle it by disabling Firebase-dependent features.
        # For now, we'll print the error and potentially let the app continue if possible,
        # though most Firebase-dependent features will fail.
        # raise # Uncomment to make Firebase initialization critical

# Example usage (typically called from main.py or equivalent startup script)
# if __name__ == "__main__":
#     # This requires settings to be loadable, ensure .env is in the correct place relative to this script if run directly
#     # Or that environment variables are already set.
#     print("Attempting to initialize Firebase directly from firebase_setup.py (for testing)")
#     initialize_firebase_admin()
#     if firebase_admin._apps:
#         from firebase_admin import firestore
#         db = firestore.client()
#         print("Firestore client obtained successfully after initialization.")
#     else:
#         print("Firebase not initialized, Firestore client cannot be obtained.")
