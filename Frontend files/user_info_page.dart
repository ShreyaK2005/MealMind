import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'dart:convert';
import 'meal_plan_screen.dart';
import 'package:http/http.dart' as http;

// TODO: Move to a config file or environment variable before production.
const String kBackendBaseUrl = "http://192.168.1.9:8000";

class UserInfoPage extends StatefulWidget {
  final String userEmail;
  const UserInfoPage({super.key, required this.userEmail});

  @override
  State<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightChangeController = TextEditingController();
  final _allergiesController = TextEditingController();

  String _selectedGender = 'Female';
  String _selectedBudget = 'Medium';
  String _selectedCondition = 'None';
  String _selectedGoal = 'Lose Weight';
  String _selectedCountry = 'India';
  String _selectedDiet = 'Veg';

  bool _isLoading = false;

  final List<String> _dietTypes = ['Veg', 'Non-Veg', 'Vegan'];
  final List<String> _genders = ['Female', 'Male', 'Other / Prefer not to say'];
  final List<String> _budgets = ['Low', 'Medium', 'High'];
  final List<String> _conditions = [
    'None', 'Diabetes', 'Hypertension', 'High Cholesterol',
    'PCOS / PCOD', 'Thyroid Issues', 'Celiac Disease / Gluten Intolerance',
    'Lactose Intolerance', 'IBS', 'GERD / Acid Reflux',
    'Heart Disease', 'Kidney Disease', 'Eating Disorders',
    'Underweight', 'Overweight', 'Obese',
  ];
  final List<String> _goals = [
    'Lose Weight', 'Gain Weight', 'Maintain Weight', 'Build Muscle',
    'Improve Energy Levels', 'Regulate Hormones', 'Manage Blood Sugar',
    'Support Gut Health', 'Balanced Eating', 'Recovery from Eating Disorder',
    'General Wellness',
  ];
  final List<String> _countries = [
    'India', 'United States', 'United Kingdom', 'Canada', 'Australia',
    'Nigeria', 'Philippines', 'Germany', 'France', 'Japan',
    'China', 'Brazil', 'Mexico', 'South Africa', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedUserInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _weightChangeController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUserInfo() async {
    final data = await DBHelper.getUserInfo(widget.userEmail);
    if (data != null) {
      _nameController.text = data['name'] ?? '';
      _ageController.text = data['age'] ?? '';
      _weightController.text = data['weight'] ?? '';
      _heightController.text = data['height'] ?? '';
      _allergiesController.text = data['allergies'] ?? '';
      _weightChangeController.text = data['weightChange'] ?? '';

      setState(() {
        _selectedGender = data['gender'] ?? 'Female';
        _selectedBudget = data['budget'] ?? 'Medium';
        _selectedCondition = data['condition'] ?? 'None';
        _selectedGoal = data['goal'] ?? 'Lose Weight';
        _selectedCountry = data['country'] ?? 'India';
        _selectedDiet = data['dietType'] ?? 'Veg';
      });
    }
  }

  Future<void> _saveUserInfo() async {
    await DBHelper.saveUserInfo(
      email: widget.userEmail,
      name: _nameController.text.trim(),
      age: _ageController.text.trim(),
      weight: _weightController.text.trim(),
      height: _heightController.text.trim(),
      gender: _selectedGender,
      budget: _selectedBudget,
      condition: _selectedCondition,
      allergies: _allergiesController.text.trim(),
      goal: _selectedGoal,
      weightChange: _weightChangeController.text.trim(),
      country: _selectedCountry,
      dietType: _selectedDiet,
    );
  }

  Future<void> _sendDataToBackend() async {
    final url = Uri.parse("$kBackendBaseUrl/generate_meal_plan");

    final body = {
      "age": int.parse(_ageController.text.trim()),
      "gender": _selectedGender.toLowerCase(),
      "height": double.parse(_heightController.text.trim()),
      "weight": double.parse(_weightController.text.trim()),
      "goal": _selectedGoal.toLowerCase().replaceAll(" ", "_"),
      "diet_type": _selectedDiet.toLowerCase(),
      "health_conditions": [_selectedCondition],
      "allergies": _allergiesController.text.trim().isEmpty
          ? []
          : _allergiesController.text.trim().split(",").map((e) => e.trim()).toList(),
      "country": _selectedCountry,
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final mealPlan = data["meal_plan"];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MealPlanScreen(mealPlan: mealPlan),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error ${response.statusCode}: Could not generate meal plan.")),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _saveUserInfo();
      await _sendDataToBackend();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Something went wrong: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tell Us About You")),
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextField(_nameController, 'Name'),
                _buildDropdown("Gender", _selectedGender, _genders,
                    (val) => setState(() => _selectedGender = val!)),
                _buildTextField(_ageController, 'Age',
                    keyboardType: TextInputType.number),
                _buildTextField(_weightController, 'Weight (kg)',
                    keyboardType: TextInputType.number),
                _buildTextField(_heightController, 'Height (m)',
                    keyboardType: TextInputType.number),
                _buildDropdown("Diet Type", _selectedDiet, _dietTypes,
                    (val) => setState(() => _selectedDiet = val!)),
                _buildDropdown("Health Condition", _selectedCondition, _conditions,
                    (val) => setState(() => _selectedCondition = val!)),
                _buildTextField(_allergiesController, 'Food Allergies (comma-separated)',
                    maxLines: 2),
                _buildDropdown("Health Goal", _selectedGoal, _goals,
                    (val) => setState(() => _selectedGoal = val!)),
                _buildTextField(_weightChangeController, 'Desired Weight Change (kg)',
                    keyboardType: TextInputType.number),
                _buildDropdown("Budget", _selectedBudget, _budgets,
                    (val) => setState(() => _selectedBudget = val!)),
                _buildDropdown("Country", _selectedCountry, _countries,
                    (val) => setState(() => _selectedCountry = val!)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Generate Meal Plan"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
          validator: (value) {
  if (value == null || value.isEmpty) {
    return 'Please enter Age';
  }

  if (int.tryParse(value) == null) {
    return 'Enter a valid number';
  }

  return null;
},
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String currentValue,
    List<String> items,
    void Function(String?)? onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        items: items
            .map((val) => DropdownMenuItem(value: val, child: Text(val)))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}









