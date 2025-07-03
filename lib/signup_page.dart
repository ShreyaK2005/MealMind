import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import 'user_info_page.dart';


class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _setAppPasswordController = TextEditingController();
  final TextEditingController _confirmAppPasswordController = TextEditingController();

  String? _email;
  bool _isGoogleSignedIn = false;
  bool _isLoading = false;
  bool _signInFailed = false;

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signInWithGoogle() async {
    try {
      await GoogleSignIn().signOut(); // always fresh
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _signInFailed = true);
        _showMessage("Sign-in cancelled.");
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      setState(() {
        _isGoogleSignedIn = true;
        _email = userCredential.user?.email;
        _signInFailed = false;
      });

      _showMessage('Google sign-in successful! Now set your app password.');
    } catch (e) {
      setState(() => _signInFailed = true);
      _showMessage('Google sign-in failed.');
    }
  }

  Future<void> _submitAppPassword() async {
    final appPassword = _setAppPasswordController.text.trim();
    final confirmPassword = _confirmAppPasswordController.text.trim();

    if (appPassword != confirmPassword) {
      _showMessage("Passwords don't match");
      return;
    }

    if (_email == null) {
      _showMessage("Google sign-in not completed");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await DBHelper.saveUser(_email!, appPassword);
      await GoogleSignIn().signOut();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UserInfoPage(userEmail: _email!), // ✅ pass email
        ),
      );
    } catch (e) {
      _showMessage('Failed to save user: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (_signInFailed) ...[
              const Text('Sign-in failed', style: TextStyle(color: Colors.red)),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Back to HomePage?"),
              ),
            ] else if (!_isGoogleSignedIn) ...[
              ElevatedButton.icon(
                onPressed: _signInWithGoogle,
                icon: const Icon(Icons.login),
                label: const Text("Sign in with Google"),
              ),
            ] else ...[
              Text("Signed in as: $_email"),
              const SizedBox(height: 16),
              TextField(
                controller: _setAppPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Set App Password'),
              ),
              TextField(
                controller: _confirmAppPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _submitAppPassword,
                child: const Text("Continue"),
              ),
            ]
          ],
        ),
      ),
    );
  }
}


















