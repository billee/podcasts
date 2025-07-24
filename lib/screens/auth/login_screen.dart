import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/screens/auth/signup_screen.dart';
import 'package:kapwa_companion_basic/screens/auth/email_verification_screen.dart';
import 'package:kapwa_companion_basic/screens/auth/forgot_password_screen.dart';
import 'package:kapwa_companion_basic/screens/main_screen.dart';
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
      
      // Reset loading state and force a small delay to ensure auth state propagates
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Add a small delay to ensure Firebase Auth state has time to propagate
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Force check current user to ensure auth state is updated
        final currentUser = FirebaseAuth.instance.currentUser;
        _logger.info('Current user after sign-in: ${currentUser?.uid}');
        
        // Check email verification status
        if (currentUser != null) {
          await currentUser.reload(); // Refresh user data
          final updatedUser = FirebaseAuth.instance.currentUser;
          
          if (updatedUser != null && !updatedUser.emailVerified) {
            _logger.info('User email not verified, navigating to verification screen');
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const EmailVerificationScreen()),
            );
          } else {
            _logger.info('Email verified, navigating to MainScreen...');
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          }
        }
      }
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
    _logger.info('Processing error: $error'); // Debug log
    
    if (error.contains('No account found with this email') ||
        error.contains('No account found with this username') ||
        error.contains('user-not-found') ||
        error.contains('User not found')) {
      return 'No account found with this email. Please sign up first.';
    } else if (error.contains('Incorrect password')) {
      return 'Incorrect password. Please try again or use "Forgot Password?" to reset it.';
    } else if (error.contains('wrong-password') ||
        error.contains('invalid-password')) {
      return 'Incorrect password. Please try again or use "Forgot Password?" to reset it.';
    } else if (error.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many failed attempts. Please try again later.';
    } else if (error.contains('invalid-credential')) {
      return 'Invalid credentials. Please check your email and password, or sign up if you don\'t have an account.';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email format. Please enter a valid email address.';
    } else {
      return 'Sign in failed. Please check your credentials or sign up if you don\'t have an account.';
    }
  }

  Future<void> _resetPassword() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ForgotPasswordScreen(),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[800],
              title: Row(
                children: [
                  Icon(Icons.lock_reset, color: Colors.blue[800]),
                  const SizedBox(width: 8),
                  const Text(
                    'Reset Password',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your email address to reset your password.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'Enter your email address',
                      prefixIcon: const Icon(Icons.email, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.grey[700],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintStyle: const TextStyle(color: Colors.white54),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    final email = resetController.text.trim();
                    if (email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter your email address'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid email address'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      isLoading = true;
                    });

                    try {
                      await AuthService.resetPassword(email);

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password reset email sent! Please check your inbox.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    } catch (e) {
                      setState(() {
                        isLoading = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Send Reset Email'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEmailVerificationWarning(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[800]),
              const SizedBox(width: 8),
              const Text(
                'Email Not Verified',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your email address is not verified yet.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Text(
                'Email: $email',
                style: TextStyle(
                  color: Colors.blue[300],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please check your email and click the verification link. If you didn\'t receive the email, you can resend it.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Sign out the user since they're not verified
                FirebaseAuth.instance.signOut();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _resendVerificationEmail();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
              ),
              child: const Text('Resend Email'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await AuthService.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Please check your inbox.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: $e'),
            backgroundColor: Colors.red,
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
                    // Email Field (preferred) or Username
                    TextFormField(
                      controller: _loginController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'Enter your email address',
                        prefixIcon:
                            const Icon(Icons.email, color: Colors.white70),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintStyle: const TextStyle(color: Colors.white54),
                        helperText: 'You can also use your username',
                        helperStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email address';
                        }
                        if (value.length < 3) {
                          return 'Email must be at least 3 characters';
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
