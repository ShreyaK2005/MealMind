import 'package:flutter/material.dart';

/// Displays the AI-generated weekly meal plan grouped by meal type.
/// Expects [mealPlan] as a map of meal labels → food descriptions.
class MealPlanScreen extends StatelessWidget {
  final Map<String, dynamic> mealPlan;

  const MealPlanScreen({super.key, required this.mealPlan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Your Meal Plan")),
      body: mealPlan.isEmpty
          ? const Center(
              child: Text(
                'No meal plan generated yet.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: mealPlan.entries.map((e) {
                final displayValue = e.value is List
                    ? (e.value as List).join(', ')
                    : e.value.toString();
                final icon = _iconForMeal(e.key);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(icon, size: 28),
                    title: Text(
                      e.key.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(displayValue),
                  ),
                );
              }).toList(),
            ),
    );
  }

  IconData _iconForMeal(String meal) {
    switch (meal.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast_outlined;
      case 'lunch':
        return Icons.lunch_dining_outlined;
      case 'dinner':
        return Icons.dinner_dining_outlined;
      case 'snack':
        return Icons.apple_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }
}
