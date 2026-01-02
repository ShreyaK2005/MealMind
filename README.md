# MealMind - An AI-based app for effective and inclusive meal planning

MealMind is an AI-based meal planning system designed to generate personalized meal
recommendations while being mindful.

The project focuses on **healthy relationships with food**, offering flexible meal
suggestions catering to user's health goals and specifications like nationality, health conditions, allergies, etc.

---

## Key Features
- Personalized meal recommendations
- Supports vegetarian, vegan, non-vegetarian diets
- Considers medical conditions like diabetes, hypertension, etc.
- BMI-based logic for goal-aware planning (weight loss/weight gain)
- Dataset-driven recommendation logic

---

## Tech Stack
- **Python**
- **Pandas**
- **Firebase Firestore** (backend deployment)
- **Kaggle datasets** (food, BMI, diet recommendations)
- **Flutter** (frontend)

---

## Project Structure
Backend files (Python)
├── meal_engine.py (main meal geeration logic)
├── meal_generator.py (user inputs for testing meal accurate meal generation)
├── main.py
├── firebase_config.py (integration with Firebase to store user information like app password, information such as height, weight, nationality, allergy, health goal, etc)

Frontend files (Python)
├── db_helper (for database management)
├── google_auth (Password verification for mail id provided by user)
├── main (Basic homepage of app, with options of login (old users) and signup (new users)
├── login_page (Basic login page for old users)
├── signup_page (Page for new users to signup)
├── user_info_page (User enters information like height, weight, nationality, health goal, etc and preferences like veg/non-veg/vegan.
├── meal_plan_screen (Final meal plan displayed)






