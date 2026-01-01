# run_meal_generator.py
from meal_engine import generate_meal_plan
user = {
    "age": 70,
    "gender": "male",
    "height": 2.00, "weight": 110,
    "goal": "weight_loss",
    "diet_type": "veg",
    "health_conditions": ["Hypertension"],
    "allergies": ["Peanuts"],
    "country": "China"
      }
meal_plan = generate_meal_plan(user)
print("\nFinal Meal Plan:\n", meal_plan)

