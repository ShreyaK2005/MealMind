import 'package:flutter/material.dart';
import 'db_helper.dart';


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

  String _selectedCondition = 'None';
  String _selectedGoal = 'Lose Weight';
  String _selectedCountry = 'India';

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
    'China', 'Brazil', 'Mexico', 'South Africa', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedUserInfo();
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
        _selectedCondition = data['condition'] ?? 'None';
        _selectedGoal = data['goal'] ?? 'Lose Weight';
        _selectedCountry = data['country'] ?? 'India';
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      await DBHelper.saveUserInfo(
        email: widget.userEmail,
        name: _nameController.text.trim(),
        age: _ageController.text.trim(),
        weight: _weightController.text.trim(),
        height: _heightController.text.trim(),
        condition: _selectedCondition,
        allergies: _allergiesController.text.trim(),
        goal: _selectedGoal,
        weightChange: _weightChangeController.text.trim(),
        country: _selectedCountry,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User info saved successfully!")),
      );
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
            child: Column(children: [
              _buildTextField(_nameController, 'Name'),
              _buildTextField(_ageController, 'Age', keyboardType: TextInputType.number),
              _buildTextField(_weightController, 'Weight (kg)', keyboardType: TextInputType.number),
              _buildTextField(_heightController, 'Height (cm)', keyboardType: TextInputType.number),
              _buildDropdown("Health Condition", _selectedCondition, _conditions, (val) => setState(() => _selectedCondition = val!)),
              _buildTextField(_allergiesController, 'Food Allergies (if any)', maxLines: 2),
              _buildDropdown("Health Goal", _selectedGoal, _goals, (val) => setState(() => _selectedGoal = val!)),
              _buildTextField(_weightChangeController, 'Desired Weight Change (kg)', keyboardType: TextInputType.number),
              _buildDropdown("Country", _selectedCountry, _countries, (val) => setState(() => _selectedCountry = val!)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text("Submit"),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
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
        validator: (value) => (value == null || value.isEmpty)
            ? 'Please enter $label'
            : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String currentValue, List<String> items, void Function(String?)? onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        items: items.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}








