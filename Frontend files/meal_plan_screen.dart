import 'package:flutter/material.dart';

class MealPlanScreen extends StatelessWidget {
  final Map mealPlan;
  const MealPlanScreen({super.key, required this.mealPlan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Your Meal Plan")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: mealPlan.entries.map((e) {
          return Card(
            child: ListTile(
              title: Text(e.key.toUpperCase()),
              subtitle: Text(e.value.toString()),
            ),
          );
        }).toList(),
      ),
    );
  }
}
