
import pandas as pd
from firebase_config import init_firestore
import os
import random


# ----------------- LOAD DATASETS -----------------
DATA_DIR = r"C:\Users\shrey\Desktop\meal_planner_ai\Backend\data"

bmi_df = pd.read_csv(os.path.join(DATA_DIR, "BMI_dataset.csv"))
mega_df = pd.read_csv(os.path.join(DATA_DIR, "Mega_dataset.csv"))
vegan_df = pd.read_csv(os.path.join(DATA_DIR, "vegan_dataset.csv"))
simple_df = pd.read_csv(os.path.join(DATA_DIR, "Simple_foods.csv"))
diet_reco_df = pd.read_csv(os.path.join(DATA_DIR, "diet_recommendations_dataset.csv"))
diabetes_df = pd.read_csv(os.path.join(DATA_DIR, "Diabetes_Indian.csv"))

# ----------------- FIRESTORE SETUP -----------------
db = init_firestore()

# ----------------- UTILITY FUNCTIONS -----------------
def calculate_bmi(weight, height):
    return weight / (height ** 2)

def calculate_bmr(weight, height_cm, age, gender):
    if gender.lower() == "male":
        return 10 * weight + 6.25 * height_cm - 5 * age + 5
    else:
        return 10 * weight + 6.25 * height_cm - 5 * age - 161

def determine_calorie_goal(bmr, goal):
    if goal == "weight_loss":
        return bmr * 0.85
    elif goal == "weight_gain":
        return bmr * 1.15
    else:
        return bmr

# ----------------- STANDARDIZE DISH COLUMN -----------------
def standardize_dish_column(df):
    for col in df.columns:
        if col.strip().lower() in ["dish", "food_item", "food name", "food_name", "title", "item", "food"]:
            df.rename(columns={col: "Dish"}, inplace=True)
            break
    return df

for dataset in [bmi_df, mega_df, vegan_df, simple_df, diet_reco_df, diabetes_df]:
    standardize_dish_column(dataset)

# Normalize simple_df category column
if "Category" in simple_df.columns and "category" not in simple_df.columns:
    simple_df.rename(columns={"Category": "category"}, inplace=True)

# ----------------- NON-VEG FILTER -----------------
NON_VEG_KEYWORDS = [
    "chicken", "beef", "pork", "lamb", "salmon", "tuna", "fish", "cod",
    "shrimp", "crab", "lobster", "anchovy", "sardine", "halibut",
    "sablefish", "bluefish", "bass", "mutton", "steak", "bacon",
    "prawn", "trout", "veal", "anchovies", "sole", "anchoïade",
    "pompano", "bacalao", "tilapia", "scallop", "arctic char", "Find the book", "Branzino", "branzino", "Mahi Mahi", "mahi mahi",
    "Mahi-Mahi", "Snapper", "snapper", "Baked Flounder with Parmesan Crumbs", "Flounder", "Grouper", "Nova Lox", "Haddock",
    "Orange Roughy", "Roughy", "roughy", "Donna Hay", "mussels", "Mussels", "Lox", "lox" "Mackerel", "mackerel", "Smelt",
    "smelt", "Hake Fillet", "Mahimahi", "Home", "Corvina Traditional", "Corvina", "corvina", "fillet", "Fillet", "Finnan Haddie"
    "Findon Haddock", "haddock", "Haddock", "Finnan Haddie with Spinach and Pancetta"
]

def filter_non_veg(df):
    pattern = "|".join(NON_VEG_KEYWORDS)
    return df[~df.astype(str).apply(lambda x: x.str.contains(pattern, case=False, na=False)).any(axis=1)]

# ----------------- PICK MEALS -----------------
def pick_meals(df, meal_type, exclude_dishes=None, n_options=3, allow_fallback=True):
    exclude_dishes = exclude_dishes or []

    subset = df[df["Meal"].str.lower() == meal_type.lower()] if "Meal" in df.columns else df

    if "Dish" in subset.columns:
        subset = subset[~subset["Dish"].isin(exclude_dishes)]
        subset = subset[~subset["Dish"].str.contains("water", case=False, na=False)]

    if subset.empty and allow_fallback:
        subset = simple_df.copy()
        if "Dish" in subset.columns:
            subset = subset[~subset["Dish"].isin(exclude_dishes)]
            subset = subset[~subset["Dish"].str.contains("water", case=False, na=False)]
            subset = subset[~subset["Dish"].str.contains("butter", case=False, na=False)]
            subset = subset[~subset["Dish"].str.contains("cheese", case=False, na=False)]

    if subset.empty:
        return ["Not available"]

    n_options = min(n_options, len(subset))
    return subset.sample(n=n_options, replace=False)["Dish"].tolist()

# ----------------- PICK MEALS (INDIAN USERS WITH FALLBACKS, NO REPETITIONS) -----------------
def pick_indian_meals_with_fallback(user, df_indian, n_options=3):
    diet_type = user.get("diet_type", "").lower().strip()
    used_dishes = []
    meal_plan = {}

    for meal in ["Breakfast", "Lunch", "Snack", "Dinner"]:
        selected = []

        # Step 1: pick 1 from Indian dataset
        indian_pool = df_indian[df_indian["Meal"].str.lower() == meal.lower()] if "Meal" in df_indian.columns else df_indian
        indian_pool = indian_pool[~indian_pool["Dish"].isin(used_dishes)]
        if not indian_pool.empty:
            chosen_indian = indian_pool.sample(n=1, replace=False)["Dish"].tolist()
            selected.extend(chosen_indian)

        # Step 2: pick remaining from mega_df
        if len(selected) < n_options:
            fallback_needed = n_options - len(selected)
            mega_pool = mega_df.copy()
            mega_pool = standardize_dish_column(mega_pool)
            mega_pool = mega_pool[~mega_pool["Dish"].isin(used_dishes + selected)]
            mega_pool = mega_pool[~mega_pool["Dish"].str.contains("water", case=False, na=False)]
            mega_pool = mega_pool[~mega_pool["Dish"].str.contains("butter|cheese", case=False, na=False)]

            if diet_type == "veg":
                mega_pool = filter_non_veg(mega_pool)

            if not mega_pool.empty:
                mega_selected = mega_pool.sample(n=min(fallback_needed, len(mega_pool)), replace=False)["Dish"].tolist()
                selected.extend(mega_selected)

        # Step 3: pick remaining from simple_df
        if len(selected) < n_options:
            fallback_needed = n_options - len(selected)
            simple_pool = simple_df.copy()
            simple_pool = standardize_dish_column(simple_pool)
            simple_pool = simple_pool[~simple_pool["Dish"].isin(used_dishes + selected)]
            simple_pool = simple_pool[~simple_pool["Dish"].str.contains("water", case=False, na=False)]
            simple_pool = simple_pool[~simple_pool["Dish"].str.contains("butter|cheese", case=False, na=False)]

            if diet_type == "veg" and "category" in simple_pool.columns:
                simple_pool = simple_pool[simple_pool["category"].str.lower().isin(["fruits","vegetables","grains","snacks"])]

            if not simple_pool.empty:
                simple_selected = simple_pool.sample(n=min(fallback_needed, len(simple_pool)), replace=False)["Dish"].tolist()
                selected.extend(simple_selected)

        # Step 4: final fallback check
        if not selected:
            selected = ["Not available"]

        meal_plan[meal] = selected
        used_dishes.extend(selected)

    return meal_plan

# ----------------- NON-INDIAN / VEGAN MEAL PLAN FUNCTION -----------------
def generate_vegan_meal_plan(user, options_per_meal=3):
    bmi = calculate_bmi(user["weight"], user["height"])
    bmr = calculate_bmr(user["weight"], user["height"] * 100, user["age"], user["gender"])
    calorie_target = determine_calorie_goal(bmr, user.get("goal", "").lower())

    df_simple_filtered = simple_df.copy()
    df_simple_filtered.columns = [c.lower().strip() for c in df_simple_filtered.columns]
    if "category" in df_simple_filtered.columns:
        df_simple_filtered = df_simple_filtered[
            df_simple_filtered["category"].isin(["fruits", "vegetables", "grains"])
        ]
    df_vegan_filtered = vegan_df.copy()
    df_vegan_filtered.columns = [c.lower().strip() for c in df_vegan_filtered.columns]
    if "diet_type" in df_vegan_filtered.columns:
        df_vegan_filtered = df_vegan_filtered[df_vegan_filtered["diet_type"].str.lower() == "vegan"]

    df = pd.concat([df_simple_filtered, df_vegan_filtered], ignore_index=True)
    df = filter_non_veg(df)
    df = standardize_dish_column(df)

    used_dishes = []
    meal_plan = {}
    for meal in ["Breakfast", "Lunch", "Snack", "Dinner"]:
        meal_options = pick_meals(df, meal, exclude_dishes=used_dishes, n_options=options_per_meal, allow_fallback=True)
        meal_plan[meal] = meal_options
        used_dishes.extend(meal_options)

    # Replace "Fried Eel" if present
    for meal, dishes in meal_plan.items():
        meal_plan[meal] = ["Fried Eel Veg" if d == "Fried Eel" else d for d in dishes]

    # Add meta info
    meal_plan["Total_Calories_Target"] = round(calorie_target, 2)
    meal_plan["BMI"] = round(bmi, 2)
    meal_plan["Diet_Type"] = "vegan"

    db.collection("meal_plans").add(meal_plan)
    print("✅ Vegan Meal Plan saved to Firestore!")

    return meal_plan

# ----------------- MAIN MEAL GENERATION -----------------
def generate_meal_plan(user, options_per_meal=3):
    diet_type = user.get("diet_type", "").lower().strip()
    health_conditions = [h.lower().strip() for h in user.get("health_conditions", [])]
    country = user.get("country", "").lower().strip()

    # ------------------- INDIAN VEGAN USERS -------------------
    if country == "india" and diet_type == "vegan":
        # Use the vegan logic for Indian vegans as well
        return generate_vegan_meal_plan(user, options_per_meal)

    # ------------------- INDIAN NON-VEGAN USERS -------------------
    if country == "india":
        df_indian = diabetes_df.copy()
        df_indian = standardize_dish_column(df_indian)

        # 1) Diabetic / Non-diabetic
        if "diabetes" in health_conditions:
            df_indian = df_indian[df_indian["Group"].str.lower() == "diabetic_active"]
        else:
            df_indian = df_indian[df_indian["Group"].str.lower() == "diabetic_notactive"]

        # 2) Veg / Non-Veg
        if diet_type == "veg":
            df_indian = df_indian[df_indian["Veg/Non-Veg"].str.lower() == "veg"]
        else:
            df_indian = df_indian[df_indian["Veg/Non-Veg"].str.lower() == "non-veg"]

        # Pick meals using fallback logic
        meal_plan = pick_indian_meals_with_fallback(user, df_indian, n_options=options_per_meal)

        # Add meta info
        bmi = calculate_bmi(user["weight"], user["height"])
        bmr = calculate_bmr(user["weight"], user["height"] * 100, user["age"], user["gender"])
        calorie_target = determine_calorie_goal(bmr, user.get("goal", "").lower())

        meal_plan["Total_Calories_Target"] = round(calorie_target, 2)
        meal_plan["BMI"] = round(bmi, 2)
        meal_plan["Diet_Type"] = diet_type

        db.collection("meal_plans").add(meal_plan)
        print("✅ Meal Plan saved to Firestore!")
        return meal_plan

    # ------------------- NON-INDIAN USERS -------------------
    allow_fallback = True
    df = None

    if diet_type == "vegan":
        return generate_vegan_meal_plan(user, options_per_meal)

    elif diet_type == "veg":
        df_mega_filtered = mega_df.copy()
        if "vegetarian" in df_mega_filtered.columns:
            df_mega_filtered["vegetarian"] = df_mega_filtered["vegetarian"].astype(str).str.lower().str.strip()
            df_mega_filtered = df_mega_filtered[df_mega_filtered["vegetarian"] == "true"]

        df_simple_filtered = simple_df.copy()
        df_simple_filtered.columns = [c.lower().strip() for c in df_simple_filtered.columns]
        if "category" in df_simple_filtered.columns:
            df_simple_filtered = df_simple_filtered[
                df_simple_filtered["category"].isin(["fruits", "vegetables", "grains", "snacks"])
            ]
        df = pd.concat([df_mega_filtered, df_simple_filtered], ignore_index=True)
        df = filter_non_veg(df)

    else:
        df = pd.concat([mega_df.copy(), simple_df.copy()], ignore_index=True)

    used_dishes = []
    meal_plan = {}
    for meal in ["Breakfast", "Lunch", "Snack", "Dinner"]:
        meal_options = pick_meals(df, meal, exclude_dishes=used_dishes, n_options=options_per_meal, allow_fallback=allow_fallback)
        meal_plan[meal] = meal_options
        used_dishes.extend(meal_options)
    for meal, dishes in meal_plan.items():
        meal_plan[meal] = ["Fried Eel Veg" if d == "Fried Eel" else d for d in dishes]

    # BMI / Calories
    bmi = calculate_bmi(user["weight"], user["height"])
    bmr = calculate_bmr(user["weight"], user["height"] * 100, user["age"], user["gender"])
    calorie_target = determine_calorie_goal(bmr, user.get("goal", "").lower())

    meal_plan["Total_Calories_Target"] = round(calorie_target, 2)
    meal_plan["BMI"] = round(bmi, 2)

    db.collection("meal_plans").add(meal_plan)
    print("✅ Meal Plan saved to Firestore!")

    return meal_plan

