import 'package:flutter/material.dart';
import 'signup_page.dart'; // Ensure this file exists
import 'user_info_page.dart'; // Your post-login/home page
import 'db_helper.dart'; // ✅ Our local DB

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _appPasswordController = TextEditingController();

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final enteredPassword = _appPasswordController.text.trim();
    final storedPassword = await DBHelper.getAppPassword(email);

    if (storedPassword == null || storedPassword != enteredPassword) {
      _showMessage('Wrong password');
    } else {
      _showMessage('Login successful!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UserInfoPage(userEmail: email), // ✅ pass email to load data
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'MealMind',
              style: TextStyle(fontSize: 32, color: Colors.blue, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Your body, your goals, your pace',
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _appPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'App Password'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text('Login'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupPage()),
                );
              },
              child: const Text("New user? Sign up here."),
            ),
          ],
        ),
      ),
    );
  }
}











