from meal_engine import generate_meal_plan
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field, field_validator


# ---------------------------------------------------------------------------
# Lifespan (startup / shutdown)
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Handle application startup and shutdown events."""
    print("MealMind API starting up...")
    yield
    print("MealMind API shutting down...")


# ---------------------------------------------------------------------------
# App initialisation
# ---------------------------------------------------------------------------

app = FastAPI(
    title="MealMind API",
    description=(
        "AI-powered personalised meal plan generator. "
        "Provide user health metrics and dietary preferences to receive "
        "a custom meal plan tailored to individual goals."
    ),
    version="1.0.0",
    lifespan=lifespan,
)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class UserInput(BaseModel):
    """Input schema representing a user's health profile and dietary preferences."""

    age: int = Field(..., ge=1, le=120, description="User's age in years.")
    gender: str = Field(..., min_length=1, description="User's gender (e.g. 'male', 'female', 'other').")
    height: float = Field(..., gt=0, description="User's height in metres.")
    weight: float = Field(..., gt=0, description="User's weight in kilograms.")
    goal: str = Field(..., min_length=1, description="Fitness/health goal (e.g. 'weight loss', 'muscle gain').")
    diet_type: str = Field(..., min_length=1, description="Dietary preference (e.g. 'vegan', 'keto', 'balanced').")
    health_conditions: list[str] = Field(default=[], description="List of existing health conditions.")
    allergies: list[str] = Field(default=[], description="List of food allergies or intolerances.")
    country: str = Field(..., min_length=1, description="User's country, used to localise meal suggestions.")

    @field_validator("gender", "goal", "diet_type", "country", mode="before")
    @classmethod
    def strip_and_lowercase(cls, value: str) -> str:
        """Normalise string fields to stripped lowercase."""
        return value.strip().lower()

    @field_validator("health_conditions", "allergies", mode="before")
    @classmethod
    def lowercase_list(cls, values: list) -> list[str]:
        """Normalise list items to stripped lowercase strings."""
        return [str(v).strip().lower() for v in values]

    model_config = {
        "json_schema_extra": {
            "example": {
                "age": 28,
                "gender": "female",
                "height": 165.0,
                "weight": 62.0,
                "goal": "weight loss",
                "diet_type": "vegetarian",
                "health_conditions": ["thyroid"],
                "allergies": ["gluten"],
                "country": "India",
            }
        }
    }


class MealPlanResponse(BaseModel):
    """Response schema wrapping the generated meal plan."""

    meal_plan: dict


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/health", status_code=status.HTTP_200_OK, tags=["Health"])
def health_check() -> dict:
    """Lightweight liveness probe to confirm the API is running."""
    return {"status": "ok", "service": "MealMind API"}


@app.post(
    "/generate_meal_plan",
    response_model=MealPlanResponse,
    status_code=status.HTTP_200_OK,
    tags=["Meal Plan"],
    summary="Generate a personalised meal plan",
)
def get_meal_plan(user: UserInput) -> MealPlanResponse:
    """
    Accept a user's health profile and return a personalised meal plan.

    - Validates all input fields before processing.
    - Delegates plan generation to the `meal_engine` module.
    - Returns a structured meal plan or a 500 error if generation fails.
    """
    try:
        from meal_engine import generate_meal_plan
        user_data = user.model_dump()
        meal_plan = generate_meal_plan(user_data)
        return MealPlanResponse(meal_plan=meal_plan)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Meal plan generation failed: {str(exc)}",
        ) from exc
