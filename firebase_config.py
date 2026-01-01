import firebase_admin
from firebase_admin import credentials, firestore

def init_firestore():
    """
    Initializes Firebase Admin SDK and returns a Firestore client.
    """
    # ⚠️ UPDATE THIS PATH to your downloaded Firebase Admin SDK JSON key
    cred = credentials.Certificate(r"C:\Users\shrey\Desktop\meal_planner_ai\Backend\serviceAccountKey.json")

    # Initialize only once to avoid 'duplicate app' errors
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)

    return firestore.client()




