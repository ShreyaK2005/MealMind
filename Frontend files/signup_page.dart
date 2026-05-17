import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import 'user_info_page.dart';
final _formKey = GlobalKey<FormState>();

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // Single reusable GoogleSignIn instance
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final TextEditingController _setAppPasswordController =
      TextEditingController();
  final TextEditingController _confirmAppPasswordController =
      TextEditingController();

  static const int _minPasswordLength = 6;
  static const double _paddingValue = 24.0;
  static const double _spacingSmall = 16.0;
  static const double _spacingMedium = 20.0;

  String? _email;
  bool _isGoogleSignedIn = false;
  bool _isLoading = false;
  bool _signInFailed = false;

  @override
  void dispose() {
    // Prevent memory leaks by disposing controllers
    _setAppPasswordController.dispose();
    _confirmAppPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signInWithGoogle() async {
    try {
      await _googleSignIn.signOut(); // Ensure a fresh sign-in prompt
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        if (!mounted) return;
        setState(() => _signInFailed = true);
        _showMessage('Sign-in cancelled.');
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      setState(() {
        _isGoogleSignedIn = true;
        _email = userCredential.user?.email;
        _signInFailed = false;
      });

      _showMessage('Google sign-in successful! Now set your app password.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _signInFailed = true);
      _showMessage('Google sign-in failed. Please try again.');
    }
  }

  Future<void> _submitAppPassword() async {
    final appPassword = _setAppPasswordController.text.trim();
    final confirmPassword = _confirmAppPasswordController.text.trim();

    if (appPassword.length < _minPasswordLength) {
      _showMessage(
          'Password must be at least $_minPasswordLength characters.');
      return;
    }

    if (appPassword != confirmPassword) {
      _showMessage("Passwords don't match.");
      return;
    }

    if (_email == null) {
      _showMessage('Google sign-in not completed.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await DBHelper.saveUser(_email!, appPassword);
      await _googleSignIn.signOut();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UserInfoPage(userEmail: _email!),
        ),
      );
    } catch (e) {
      _showMessage('Failed to save user: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(_paddingValue),
        child: Column(
          children: [
            if (_signInFailed) ...[
              const Text(
                'Sign-in failed.',
                style: TextStyle(color: Colors.red),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Home'),
              ),
            ] else if (!_isGoogleSignedIn) ...[
              ElevatedButton.icon(
                onPressed: _signInWithGoogle,
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
              ),
            ] else ...[
              Text('Signed in as: $_email'),
              const SizedBox(height: _spacingSmall),
              TextField(
                controller: _setAppPasswordController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Set App Password'),
              ),
              TextFormField(
                controller: _confirmAppPasswordController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm Password'),
              ),
              const SizedBox(height: _spacingMedium),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submitAppPassword,
                      child: const Text('Continue'),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

















