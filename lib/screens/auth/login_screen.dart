import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/screens/auth/signup_screen.dart';
import 'package:kapwa_companion_basic/services/auth_service.dart';
import 'package:logging/logging.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final Logger _logger = Logger('LoginScreen');
  final _formKey = GlobalKey<FormState>();
  final _loginController =
      TextEditingController(); // Changed from _usernameController
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final loginInput = _loginController.text.trim();

      // Determine if input is email or username
      bool isEmail = loginInput.contains('@') && loginInput.contains('.');

      if (isEmail) {
        // Sign in with email
        await AuthService.signInWithEmailAndPassword(
          email: loginInput,
          password: _passwordController.text,
        );
      } else {
        // Sign in with username
        await AuthService.signInWithUsername(
          username: loginInput,
          password: _passwordController.text,
        );
      }

      // Navigation is handled by AuthWrapper
      _logger.info('User signed in successfully');
    } catch (e) {
      setState(() {
        _errorMessage = _extractErrorMessage(e.toString());
        _isLoading = false;
      });
      _logger.severe('Sign in error: $e');
    }
  }

  String _extractErrorMessage(String error) {
    // Extract user-friendly error messages
    if (error.contains('user-not-found') ||
        error.contains('username-not-found') ||
        error.contains('Username not found')) {
      return 'Account not found. Please check your username or email.';
    } else if (error.contains('wrong-password') ||
        error.contains('invalid-password')) {
      return 'Incorrect password.';
    } else if (error.contains('user-disabled')) {
      return 'This account has been disabled.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    } else if (error.contains('invalid-credential')) {
      return 'Invalid username/email or password.';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email format.';
    } else {
      return 'Sign in failed. Please try again.';
    }
  }

  Future<void> _resetPassword() async {
    if (_loginController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your username or email first'),
        ),
      );
      return;
    }

    try {
      final loginInput = _loginController.text.trim();
      bool isEmail = loginInput.contains('@') && loginInput.contains('.');

      if (isEmail) {
        // Reset password using email
        await AuthService.resetPassword(loginInput);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset email sent. Check your inbox.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        // Reset password using username
        await AuthService.resetPasswordByUsername(loginInput);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Password reset request submitted. Our support team will contact you soon.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // App Logo/Title
              Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color: Colors.blue[800],
              ),
              const SizedBox(height: 16),

              Text(
                'Kapwa Companion',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                'Welcome back! Please sign in to continue.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Login Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Username/Email Field
                    TextFormField(
                      controller: _loginController,
                      keyboardType: TextInputType.text,
                      autofillHints: null,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Username or Email',
                        hintText: 'Enter your username or email',
                        prefixIcon:
                            const Icon(Icons.person, color: Colors.white70),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintStyle: const TextStyle(color: Colors.white54),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your username or email';
                        }
                        if (value.length < 3) {
                          return 'Username or email must be at least 3 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: null,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon:
                            const Icon(Icons.lock, color: Colors.white70),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        labelStyle: const TextStyle(color: Colors.white70),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 8),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Error Message
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          // ignore: deprecated_member_use
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Sign Up Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: Colors.white70),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
