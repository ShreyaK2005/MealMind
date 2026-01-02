from fastapi import FastAPI
from pydantic import BaseModel
from meal_engine import generate_meal_plan

app = FastAPI()

class UserInput(BaseModel):
    age: int
    gender: str
    height: float
    weight: float
    goal: str
    diet_type: str
    health_conditions: list
    allergies: list
    country: str

@app.post("/generate_meal_plan")
def get_meal_plan(user: UserInput):
    user_data = user.dict()
    meal_plan = generate_meal_plan(user_data)
    return {"meal_plan": meal_plan}

