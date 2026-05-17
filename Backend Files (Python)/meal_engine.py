import os
import random

import pandas as pd

from firebase_config import init_firestore

# ----------------- CONFIGURATION -----------------

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

# Calorie adjustment multipliers per fitness goal
CALORIE_MULTIPLIERS = {
    "weight_loss": 0.85,
    "weight_gain": 1.15,
    "maintenance": 1.0,
}

NON_VEG_KEYWORDS = [
    "anchovy", "anchovies", "arctic char", "bacalao", "bacon", "bass",
    "beef", "bluefish", "branzino", "chicken", "cod", "crab", "fillet",
    "finnan haddie", "flounder", "grouper", "haddock", "hake", "halibut",
    "lamb", "lobster", "lox", "mackerel", "mahi mahi", "mahi-mahi", "mahimahi",
    "mussels", "mutton", "orange roughy", "pompano", "pork", "prawn",
    "salmon", "sardine", "scallop", "shrimp", "smelt", "snapper", "sole",
    "steak", "tilapia", "trout", "tuna", "veal",
]

SIMPLE_VEG_CATEGORIES = {"fruits", "vegetables", "grains", "snacks"}

MEAL_TYPES = ["Breakfast", "Lunch", "Snack", "Dinner"]

# ----------------- FIRESTORE SETUP -----------------

db = init_firestore()


_DISH_ALIASES = {"dish", "food_item", "food name", "food_name", "title", "item", "food"}


def standardize_dish_column(df: pd.DataFrame) -> pd.DataFrame:
    """Rename the dish-like column to a canonical 'Dish' label (in-place)."""
    for col in df.columns:
        if col.strip().lower() in _DISH_ALIASES:
            df.rename(columns={col: "Dish"}, inplace=True)
            break
    return df

# ----------------- LOAD DATASETS -----------------

def _load(filename: str) -> pd.DataFrame:
    """Load a CSV from DATA_DIR and standardize its dish column."""
    df = pd.read_csv(os.path.join(DATA_DIR, filename))
    return standardize_dish_column(df)


bmi_df       = _load("BMI_dataset.csv")
mega_df      = _load("Mega_dataset.csv")
vegan_df     = _load("vegan_dataset.csv")
simple_df    = _load("Simple_foods.csv")
diet_reco_df = _load("diet_recommendations_dataset.csv")
diabetes_df  = _load("Diabetes_Indian.csv")

# Normalize simple_df category column to lowercase
if "Category" in simple_df.columns and "category" not in simple_df.columns:
    simple_df.rename(columns={"Category": "category"}, inplace=True)

# ----------------- UTILITY FUNCTIONS -----------------

def calculate_bmi(weight_kg: float, height_m: float) -> float:
    """Calculate Body Mass Index (kg/m²)."""
    return weight_kg / (height_m ** 2)


def calculate_bmr(weight_kg: float, height_cm: float, age: int, gender: str) -> float:
    """
    Calculate Basal Metabolic Rate using the Mifflin-St Jeor equation.

    Args:
        weight_kg:  Body weight in kilograms.
        height_cm:  Height in centimetres.
        age:        Age in years.
        gender:     'male' or 'female' (case-insensitive).

    Returns:
        BMR in kcal/day.
    """
    base = 10 * weight_kg + 6.25 * height_cm - 5 * age
    return base + 5 if gender.lower() == "male" else base - 161


def determine_calorie_goal(bmr: float, goal: str) -> float:
    """
    Adjust BMR according to the user's fitness goal.

    Args:
        bmr:  Basal Metabolic Rate in kcal/day.
        goal: One of 'weight_loss', 'weight_gain', or 'maintenance'.

    Returns:
        Target daily calorie intake.
    """
    multiplier = CALORIE_MULTIPLIERS.get(goal.lower(), 1.0)
    return bmr * multiplier


def _meta(user: dict) -> dict:
    """Compute and return BMI and calorie-target metadata for a user."""
    bmi = calculate_bmi(user["weight"], user["height"])
    bmr = calculate_bmr(
        user["weight"],
        user["height"] * 100,
        user["age"],
        user["gender"],
    )
    calorie_target = determine_calorie_goal(bmr, user.get("goal", "maintenance"))
    return {
        "BMI": round(bmi, 2),
        "Total_Calories_Target": round(calorie_target, 2),
    }


def _save_to_firestore(meal_plan: dict) -> None:
    """Persist a meal plan document to Firestore."""
    db.collection("meal_plans").add(meal_plan)
    print("✅ Meal Plan saved to Firestore!")

# ----------------- COLUMN STANDARDIZATION -----------------


# ----------------- FILTERING HELPERS -----------------

def filter_non_veg(df: pd.DataFrame) -> pd.DataFrame:
    """Remove rows whose any column contains a non-vegetarian ingredient keyword."""
    pattern = "|".join(NON_VEG_KEYWORDS)
    mask = df.astype(str).apply(
        lambda col: col.str.contains(pattern, case=False, na=False)
    ).any(axis=1)
    return df[~mask]


def _remove_excluded(df: pd.DataFrame, exclude: list[str]) -> pd.DataFrame:
    """Drop rows whose 'Dish' value appears in *exclude* or contains 'water'."""
    if "Dish" not in df.columns:
        return df
    return df[
        ~df["Dish"].isin(exclude) &
        ~df["Dish"].str.contains("water", case=False, na=False)
    ]

# ----------------- MEAL PICKING -----------------

def pick_meals(
    df: pd.DataFrame,
    meal_type: str,
    exclude_dishes: list[str] | None = None,
    n_options: int = 3,
    allow_fallback: bool = True,
) -> list[str]:
    """
    Sample *n_options* dish names for a given meal type from *df*.

    Falls back to simple_df when the filtered pool is empty and
    *allow_fallback* is True.

    Args:
        df:             Source DataFrame (must have a 'Dish' column).
        meal_type:      One of 'Breakfast', 'Lunch', 'Snack', 'Dinner'.
        exclude_dishes: Dish names already selected (to avoid repeats).
        n_options:      Number of dishes to pick.
        allow_fallback: Whether to fall back to simple_df on empty pool.

    Returns:
        List of dish name strings, or ['Not available'] when nothing matches.
    """
    exclude_dishes = exclude_dishes or []

    subset = (
        df[df["Meal"].str.lower() == meal_type.lower()]
        if "Meal" in df.columns
        else df.copy()
    )
    subset = _remove_excluded(subset, exclude_dishes)

    if subset.empty and allow_fallback:
        subset = simple_df.copy()
        subset = _remove_excluded(subset, exclude_dishes)
        subset = subset[~subset["Dish"].str.contains("butter|cheese", case=False, na=False)]

    if subset.empty:
        return ["Not available"]

    n_options = min(n_options, len(subset))
    return subset.sample(n=n_options, replace=False)["Dish"].tolist()


def pick_indian_meals_with_fallback(
    user: dict,
    df_indian: pd.DataFrame,
    n_options: int = 3,
) -> dict:
    """
    Build a meal plan for Indian users using a three-tier fallback strategy:
      1. One dish from the Indian-specific dataset.
      2. Remaining dishes from mega_df.
      3. Any remainder from simple_df.

    Args:
        user:      User profile dict (must include 'diet_type').
        df_indian: Pre-filtered Indian meal DataFrame.
        n_options: Dishes to select per meal.

    Returns:
        Dict mapping meal names to lists of dish strings.
    """
    diet_type = user.get("diet_type", "").lower().strip()
    used_dishes: list[str] = []
    meal_plan: dict = {}

    for meal in MEAL_TYPES:
        selected: list[str] = []

        # --- Tier 1: Indian dataset ---
        indian_pool = (
            df_indian[df_indian["Meal"].str.lower() == meal.lower()]
            if "Meal" in df_indian.columns
            else df_indian.copy()
        )
        indian_pool = indian_pool[~indian_pool["Dish"].isin(used_dishes)]
        if not indian_pool.empty:
            selected.extend(indian_pool.sample(n=1, replace=False)["Dish"].tolist())

        # --- Tier 2: mega_df ---
        if len(selected) < n_options:
            needed = n_options - len(selected)
            mega_pool = _remove_excluded(mega_df.copy(), used_dishes + selected)
            mega_pool = mega_pool[
                ~mega_pool["Dish"].str.contains("butter|cheese", case=False, na=False)
            ]
            if diet_type == "veg":
                mega_pool = filter_non_veg(mega_pool)
            if not mega_pool.empty:
                selected.extend(
                    mega_pool.sample(n=min(needed, len(mega_pool)), replace=False)["Dish"].tolist()
                )

        # --- Tier 3: simple_df ---
        if len(selected) < n_options:
            needed = n_options - len(selected)
            simple_pool = _remove_excluded(simple_df.copy(), used_dishes + selected)
            simple_pool = simple_pool[
                ~simple_pool["Dish"].str.contains("butter|cheese", case=False, na=False)
            ]
            if diet_type == "veg" and "category" in simple_pool.columns:
                simple_pool = simple_pool[
                    simple_pool["category"].str.lower().isin(SIMPLE_VEG_CATEGORIES)
                ]
            if not simple_pool.empty:
                selected.extend(
                    simple_pool.sample(n=min(needed, len(simple_pool)), replace=False)["Dish"].tolist()
                )

        meal_plan[meal] = selected or ["Not available"]
        used_dishes.extend(selected)

    return meal_plan

# ----------------- VEGAN MEAL PLAN -----------------

def generate_vegan_meal_plan(user: dict, options_per_meal: int = 3) -> dict:
    """
    Generate a vegan meal plan for non-Indian (or Indian vegan) users.

    Combines simple_df (fruits/vegetables/grains) with vegan_df,
    removes any non-veg items, then samples per meal type.

    Args:
        user:            User profile dict.
        options_per_meal: Number of dish options to return per meal.

    Returns:
        Meal plan dict including BMI and calorie-target metadata.
    """
    # Build vegan-only pool from simple_df
    simple_vegan = simple_df.copy()
    simple_vegan.columns = [c.lower().strip() for c in simple_vegan.columns]
    if "category" in simple_vegan.columns:
        simple_vegan = simple_vegan[
            simple_vegan["category"].isin({"fruits", "vegetables", "grains"})
        ]

    # Build vegan-only pool from vegan_df
    vegan_only = vegan_df.copy()
    vegan_only.columns = [c.lower().strip() for c in vegan_only.columns]
    if "diet_type" in vegan_only.columns:
        vegan_only = vegan_only[vegan_only["diet_type"].str.lower() == "vegan"]

    df = pd.concat([simple_vegan, vegan_only], ignore_index=True)
    df = filter_non_veg(df)
    df = standardize_dish_column(df)

    used_dishes: list[str] = []
    meal_plan: dict = {}
    for meal in MEAL_TYPES:
        options = pick_meals(df, meal, exclude_dishes=used_dishes, n_options=options_per_meal)
        meal_plan[meal] = options
        used_dishes.extend(options)

    meal_plan.update(_meta(user))
    meal_plan["Diet_Type"] = "vegan"

    _save_to_firestore(meal_plan)
    return meal_plan

# ----------------- MAIN ENTRY POINT -----------------

def generate_meal_plan(user: dict, options_per_meal: int = 3) -> dict:
    """
    Generate a personalised meal plan based on the user's profile.

    Routing logic:
      - Indian + vegan           → vegan pipeline
      - Indian + veg / non-veg  → Indian pipeline with diabetic filter
      - Non-Indian + vegan       → vegan pipeline
      - Non-Indian + veg         → vegetarian-filtered mega/simple pool
      - Non-Indian + non-veg     → full mega/simple pool

    Args:
        user:            Dict with keys: weight, height, age, gender, goal,
                         diet_type, health_conditions, country.
        options_per_meal: Number of dish options per meal slot.

    Returns:
        Meal plan dict with per-meal dish lists and metadata fields
        (BMI, Total_Calories_Target, Diet_Type).
    """
    diet_type        = user.get("diet_type", "").lower().strip()
    health_conditions = [h.lower().strip() for h in user.get("health_conditions", [])]
    country          = user.get("country", "").lower().strip()

    # ── Indian users ──────────────────────────────────────────────────────────
    if country == "india":
        if diet_type == "vegan":
            return generate_vegan_meal_plan(user, options_per_meal)

        df_indian = diabetes_df.copy()

        group = "diabetic_active" if "diabetes" in health_conditions else "diabetic_notactive"
        df_indian = df_indian[df_indian["Group"].str.lower() == group]

        veg_flag = "veg" if diet_type == "veg" else "non-veg"
        df_indian = df_indian[df_indian["Veg/Non-Veg"].str.lower() == veg_flag]

        meal_plan = pick_indian_meals_with_fallback(user, df_indian, n_options=options_per_meal)
        meal_plan.update(_meta(user))
        meal_plan["Diet_Type"] = diet_type

        _save_to_firestore(meal_plan)
        return meal_plan

    # ── Non-Indian users ──────────────────────────────────────────────────────
    if diet_type == "vegan":
        return generate_vegan_meal_plan(user, options_per_meal)

    if diet_type == "veg":
        mega_veg = mega_df.copy()
        if "vegetarian" in mega_veg.columns:
            mega_veg["vegetarian"] = mega_veg["vegetarian"].astype(str).str.lower().str.strip()
            mega_veg = mega_veg[mega_veg["vegetarian"] == "true"]

        simple_veg = simple_df.copy()
        simple_veg.columns = [c.lower().strip() for c in simple_veg.columns]
        if "category" in simple_veg.columns:
            simple_veg = simple_veg[
                simple_veg["category"].isin(SIMPLE_VEG_CATEGORIES)
            ]

        df = pd.concat([mega_veg, simple_veg], ignore_index=True)
        df = filter_non_veg(df)
    else:
        df = pd.concat([mega_df.copy(), simple_df.copy()], ignore_index=True)

    used_dishes: list[str] = []
    meal_plan: dict = {}
    for meal in MEAL_TYPES:
        options = pick_meals(df, meal, exclude_dishes=used_dishes, n_options=options_per_meal)
        meal_plan[meal] = options
        used_dishes.extend(options)

    meal_plan.update(_meta(user))
    meal_plan["Diet_Type"] = diet_type

    _save_to_firestore(meal_plan)
    return meal_plan
