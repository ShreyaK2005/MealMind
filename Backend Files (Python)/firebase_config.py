import os
import firebase_admin
from firebase_admin import credentials, firestore


def init_firestore() -> firestore.Client:
    """
    Initializes the Firebase Admin SDK and returns a Firestore client.

    The path to the service account key is read from the environment variable
    FIREBASE_CREDENTIALS_PATH, falling back to 'serviceAccountKey.json' in
    the current working directory.

    Returns:
        firestore.Client: An authenticated Firestore client instance.

    Raises:
        FileNotFoundError: If the credentials file does not exist at the resolved path.
    """
    cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "serviceAccountKey.json")

    if not os.path.exists(cred_path):
        raise FileNotFoundError(
            f"Firebase credentials file not found at: '{cred_path}'. "
            "Set the FIREBASE_CREDENTIALS_PATH environment variable to the correct path."
        )

    if not firebase_admin._apps:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)

    return firestore.client()


