import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/services/auth_service.dart';
import 'package:kapwa_companion_basic/models/user.dart';
import 'package:logging/logging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final Logger _logger = Logger('SignUpScreen');
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Controllers
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _occupationController = TextEditingController();

  // Form state
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  int _currentPage = 0;

  // Real-time validation states
  bool _isNameValid = false;
  bool _isUsernameValid = false;
  bool _isEmailValid = false;
  bool _isPasswordValid = false;
  bool _isConfirmPasswordValid = false;
  String? _nameValidationError;
  String? _usernameValidationError;
  String? _emailValidationError;
  String? _passwordValidationError;
  String? _confirmPasswordValidationError;
  
  // Email checking state
  bool _isCheckingEmail = false;
  Timer? _emailCheckTimer;
  
  // Password strength
  int _passwordStrength = 0; // 0-4 scale

  // Email is now mandatory for all OFWs
  bool _hasEmail = true;

  // Profile data
  String? _selectedWorkLocation;
  String? _selectedGender;
  String _selectedLanguage = 'tagalog';
  String? _selectedEducation;
  bool _isMarried = false;
  bool _hasChildren = false;
  int _birthYear = DateTime.now().year - 25;

  // Dropdown options
  final List<String> _workLocations = [
    'Saudi Arabia',
    'UAE',
    'Qatar',
    'Kuwait',
    'Bahrain',
    'Oman',
    'Hong Kong',
    'Singapore',
    'Taiwan',
    'Japan',
    'South Korea',
    'Italy',
    'Germany',
    'UK',
    'Canada',
    'Australia',
    'New Zealand',
    'USA',
    'Other'
  ];

  final List<String> _genders = ['Male', 'Female', 'Prefer not to say'];
  final List<String> _educationLevels = [
    'Elementary',
    'High School',
    'Vocational/Technical',
    'College Graduate',
    'Post Graduate',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    // Set default values for dropdowns
    _selectedWorkLocation = _workLocations.first;
    _selectedGender = _genders.first;
    _selectedEducation = _educationLevels.first;
    _selectedLanguage = 'tagalog'; // Set default language to Tagalog
    // Set reasonable birth year default
    _birthYear = DateTime.now().year - 25;
    _isMarried = false;
    _hasChildren = false;

    // Add real-time validation listeners
    _nameController.addListener(_validateName);
    _usernameController.addListener(_validateUsername);
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validateConfirmPassword);
  }

  @override
  void dispose() {
    // Remove listeners
    _nameController.removeListener(_validateName);
    _usernameController.removeListener(_validateUsername);
    _emailController.removeListener(_validateEmail);
    _passwordController.removeListener(_validatePassword);
    _confirmPasswordController.removeListener(_validateConfirmPassword);

    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _occupationController.dispose();
    _pageController.dispose();
    
    // Cancel email check timer
    _emailCheckTimer?.cancel();
    
    super.dispose();
  }

  // Real-time validation methods
  void _validateName() {
    final name = _nameController.text.trim();
    setState(() {
      if (name.isEmpty) {
        _nameValidationError = null;
        _isNameValid = false;
      } else if (name.length < 2) {
        _nameValidationError = 'Name must be at least 2 characters';
        _isNameValid = false;
      } else {
        _nameValidationError = null;
        _isNameValid = true;
      }
    });
  }

  void _validateUsername() {
    final username = _usernameController.text.trim();
    setState(() {
      if (username.isEmpty) {
        _usernameValidationError = null;
        _isUsernameValid = false;
      } else if (username.length < 3) {
        _usernameValidationError = 'Username must be at least 3 characters';
        _isUsernameValid = false;
      } else {
      // Removed uniqueness constraint and special character restrictions
        _usernameValidationError = null;
        _isUsernameValid = true;
      }
    });
  }

  void _validateEmail() {
    final email = _emailController.text.trim();
    
    // Cancel previous timer if exists
    _emailCheckTimer?.cancel();
    
    setState(() {
      if (email.isEmpty) {
        _emailValidationError = null;
        _isEmailValid = false;
        _isCheckingEmail = false;
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _emailValidationError = 'Invalid email format';
        _isEmailValid = false;
        _isCheckingEmail = false;
      } else {
        // Email format is valid, now check if it exists in database
        _emailValidationError = null;
        _isEmailValid = false; // Set to false until database check completes
        _isCheckingEmail = true;
        
        // Debounce the database check by 800ms
        _emailCheckTimer = Timer(const Duration(milliseconds: 800), () {
          _checkEmailExists(email);
        });
      }
    });
  }
  
  Future<void> _checkEmailExists(String email) async {
    try {
      // Check in Firestore users collection
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (mounted) {
        setState(() {
          _isCheckingEmail = false;
          if (userQuery.docs.isNotEmpty) {
            _emailValidationError = 'This email address is already registered. Please use a different email or try signing in.';
            _isEmailValid = false;
          } else {
            _emailValidationError = null;
            _isEmailValid = true;
          }
        });
      }
    } catch (e) {
      _logger.warning('Error checking email existence: $e');
      if (mounted) {
        setState(() {
          _isCheckingEmail = false;
          // On error, assume email is available but show a warning
          _emailValidationError = 'Unable to verify email availability. Please try again.';
          _isEmailValid = false;
        });
      }
    }
  }

  void _validatePassword() {
    final password = _passwordController.text;
    setState(() {
      if (password.isEmpty) {
        _passwordValidationError = null;
        _isPasswordValid = false;
        _passwordStrength = 0;
      } else {
        _passwordStrength = _calculatePasswordStrength(password);
        if (password.length < 6) {
          _passwordValidationError = 'Password must be at least 6 characters';
          _isPasswordValid = false;
        } else {
          _passwordValidationError = null;
          _isPasswordValid = true;
        }
      }
      // Re-validate confirm password when password changes
      _validateConfirmPassword();
    });
  }

  void _validateConfirmPassword() {
    final confirmPassword = _confirmPasswordController.text;
    final password = _passwordController.text;
    setState(() {
      if (confirmPassword.isEmpty) {
        _confirmPasswordValidationError = null;
        _isConfirmPasswordValid = false;
      } else if (confirmPassword != password) {
        _confirmPasswordValidationError = 'Passwords do not match';
        _isConfirmPasswordValid = false;
      } else {
        _confirmPasswordValidationError = null;
        _isConfirmPasswordValid = true;
      }
    });
  }

  int _calculatePasswordStrength(String password) {
    int strength = 0;
    
    // Length check
    if (password.length >= 8) strength++;
    
    // Contains lowercase
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    
    // Contains uppercase
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    
    // Contains numbers
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    
    // Contains special characters
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;
    
    return strength > 4 ? 4 : strength;
  }

  String _getPasswordStrengthText() {
    switch (_passwordStrength) {
      case 0:
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return 'Weak';
    }
  }

  Color _getPasswordStrengthColor() {
    switch (_passwordStrength) {
      case 0:
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  bool _canProceedToNext() {
    switch (_currentPage) {
      case 0:
        return _isNameValid && _isUsernameValid && _isEmailValid && !_isCheckingEmail;
      case 1:
        return _isPasswordValid && _isConfirmPasswordValid;
      case 2:
        return _occupationController.text.isNotEmpty;
      default:
        return false;
    }
  }

  String _extractErrorMessage(String error) {
  // Removed username uniqueness check
  if (error.contains('email-already-in-use')) {
      return 'Email already registered. Please use a different email.';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak. Please use a stronger password.';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email format.';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your connection.';
    } else {
      return 'Registration failed. Please try again.';
    }
  }

  Future<void> _handleSignUp() async {
    if (!_validateAllPages()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userProfileData = {
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(), // Explicitly include email
        'workLocation': _selectedWorkLocation!,
        'occupation': _occupationController.text.trim(),
        'gender': _selectedGender!,
        'language': 'tagalog', // Fixed to Tagalog
        'educationalAttainment': _selectedEducation!,
        'isMarried': _isMarried,
        'hasChildren': _hasChildren,
        'birthYear': _birthYear,
      };

      await AuthService.signUpFlexible(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        userProfile: userProfileData,
        email: _emailController.text.trim(),
      );

      _logger.info('User registered successfully');

      if (mounted) {
        // Reset loading state before showing dialog
        setState(() {
          _isLoading = false;
        });
        
        // Show email verification dialog
        _showEmailVerificationDialog();
      }
    } catch (e) {
      setState(() {
        _errorMessage = _extractErrorMessage(e.toString());
        _isLoading = false;
      });
      _logger.severe('Registration error: $e');
    }
  }

  bool _validateAllPages() {
    // Manually trigger form save
    if (_currentPage == 0) {
      _formKey.currentState?.save();
    }

    // Page 0: Personal Info
    if (_nameController.text.isEmpty) {
      _pageController.jumpToPage(0);
      _showValidationError('Please enter your full name');
      return false;
    }

    if (_usernameController.text.isEmpty) {
      _pageController.jumpToPage(0);
      _showValidationError('Please enter a username');
      return false;
    } else if (_usernameController.text.length < 3) {
      _pageController.jumpToPage(0);
      _showValidationError('Username must be at least 3 characters');
      return false;
    } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(_usernameController.text)) {
      _pageController.jumpToPage(0);
      _showValidationError(
          'Username can only contain letters, numbers, and underscores');
      return false;
    }

    if (_emailController.text.isEmpty) {
      _pageController.jumpToPage(0);
      _showValidationError('Please enter your email address');
      return false;
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
            .hasMatch(_emailController.text)) {
      _pageController.jumpToPage(0);
      _showValidationError('Please enter a valid email address');
      return false;
    } else if (_isCheckingEmail) {
      _pageController.jumpToPage(0);
      _showValidationError('Please wait while we verify your email address');
      return false;
    } else if (!_isEmailValid) {
      _pageController.jumpToPage(0);
      _showValidationError(_emailValidationError ?? 'Please enter a valid email address');
      return false;
    }



    // Page 1: Security
    if (_passwordController.text.isEmpty ||
        _passwordController.text.length < 6) {
      _pageController.jumpToPage(1);
      _showValidationError('Password must be at least 6 characters');
      return false;
    }

    if (_confirmPasswordController.text != _passwordController.text) {
      _pageController.jumpToPage(1);
      _showValidationError('Passwords do not match');
      return false;
    }

    // Page 2: Work Info
    if (_occupationController.text.isEmpty) {
      _pageController.jumpToPage(2);
      _showValidationError('Please enter your occupation');
      return false;
    }

    if (_selectedWorkLocation == null) {
      _pageController.jumpToPage(2);
      _showValidationError('Please select your work location');
      return false;
    }

    if (_selectedGender == null) {
      _pageController.jumpToPage(2);
      _showValidationError('Please select your gender');
      return false;
    }

    if (_selectedEducation == null) {
      _pageController.jumpToPage(2);
      _showValidationError('Please select your education level');
      return false;
    }

    return true;
  }

  void _nextPage() {
    if (_currentPage < 2 && _validateCurrentPage()) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentPage() {
    if (_currentPage == 0) {
      // First validate the form fields
      if (!_formKey.currentState!.validate()) {
        return false;
      }
      
      // Then check email validation state
      if (_isCheckingEmail) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait while we verify your email address'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }
      
      if (!_isEmailValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_emailValidationError ?? 'Please enter a valid email address'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
      
      return true;
    }
    if (_currentPage == 1) {
      if (_passwordController.text.isEmpty ||
          _passwordController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }
      if (_confirmPasswordController.text != _passwordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }
      return true;
    }
    if (_currentPage == 2) {
      return true; // Final validation happens in _handleSignUp
    }
    return false;
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        
        return Dialog(
          backgroundColor: Colors.grey[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: screenWidth * 0.85,
              maxHeight: screenHeight * 0.6, // Limit height to 60% of screen
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[750],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.email, color: Colors.blue[800], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Verify Your Email',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Success message
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            const SizedBox(width: 6),
                            const Text(
                              'Account created!',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Email info
                        const Text(
                          'Verification email sent to:',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _emailController.text.trim(),
                            style: TextStyle(
                              color: Colors.blue[300],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Instructions
                        const Text(
                          'Please check your email and click the verification link to activate your account. You can sign in after verifying.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.3,
                          ),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[750],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () async {
                          Navigator.of(context).pop(); // Close dialog
                          
                          // Sign out the user since they need to verify email first
                          await FirebaseAuth.instance.signOut();
                          _logger.info('User signed out after registration - email verification required');
                          
                          // Navigate back to login screen
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Account',
          style:
              TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? Colors.blue[800]
                            : Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                physics:
                    const NeverScrollableScrollPhysics(), // Prevent swiping
                children: [
                  _buildPersonalInfoPage(),
                  _buildSecurityPage(),
                  _buildWorkInfoPage(),
                ],
              ),
            ),

            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _previousPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Previous'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              if (_currentPage < 2) {
                                _nextPage();
                              } else {
                                // Manually save form state before validation
                                if (_currentPage == 0) {
                                  _formKey.currentState?.save();
                                }

                                if (_validateAllPages()) {
                                  await _handleSignUp();
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoading 
                            ? Colors.grey[600] 
                            : _canProceedToNext()
                                ? Colors.blue[800]
                                : Colors.blue[800]?.withOpacity(0.7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: _isLoading ? 0 : 2,
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(_currentPage < 2 ? 'Processing...' : 'Creating Account...'),
                              ],
                            )
                          : Text(_currentPage < 2 ? 'Next' : 'Create Account'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Let\'s start with your basic information. Email address is required for all OFWs.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 32),

            // Full Name with real-time validation
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(
                  Icons.person, 
                  color: _isNameValid ? Colors.green : Colors.white70
                ),
                suffixIcon: _nameController.text.isNotEmpty
                    ? Icon(
                        _isNameValid ? Icons.check_circle : Icons.error,
                        color: _isNameValid ? Colors.green : Colors.red,
                        size: 20,
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _nameValidationError != null 
                        ? Colors.red.withOpacity(0.5)
                        : _isNameValid 
                            ? Colors.green.withOpacity(0.5)
                            : Colors.transparent,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _nameValidationError != null 
                        ? Colors.red
                        : _isNameValid 
                            ? Colors.green
                            : Colors.blue,
                    width: 2,
                  ),
                ),
                labelStyle: const TextStyle(color: Colors.white70),
                helperText: _nameValidationError,
                helperStyle: TextStyle(
                  color: _nameValidationError != null ? Colors.red : Colors.white54, 
                  fontSize: 12
                ),
              ),
              style: const TextStyle(color: Colors.white),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Username with real-time validation
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username *',
                helperText: _usernameValidationError ?? '',
                helperStyle: TextStyle(
                  color: _usernameValidationError != null ? Colors.red : Colors.white54,
                  fontSize: 12
                ),
                prefixIcon: Icon(
                  Icons.alternate_email, 
                  color: _isUsernameValid ? Colors.green : Colors.white70
                ),
                suffixIcon: _usernameController.text.isNotEmpty
                    ? Icon(
                        _isUsernameValid ? Icons.check_circle : Icons.error,
                        color: _isUsernameValid ? Colors.green : Colors.red,
                        size: 20,
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _usernameValidationError != null 
                        ? Colors.red.withOpacity(0.5)
                        : _isUsernameValid 
                            ? Colors.green.withOpacity(0.5)
                            : Colors.transparent,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _usernameValidationError != null 
                        ? Colors.red
                        : _isUsernameValid 
                            ? Colors.green
                            : Colors.blue,
                    width: 2,
                  ),
                ),
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a username';
                }
                if (value.trim().length < 3) {
                  return 'Username must be at least 3 characters';
                }
                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                  return 'Username can only contain letters, numbers, and underscores';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Email Field with real-time validation
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address *',
                helperText: _isCheckingEmail 
                    ? 'Checking email availability...'
                    : (_emailValidationError ?? 'Required for account recovery and notifications'),
                helperStyle: TextStyle(
                  color: _isCheckingEmail 
                      ? Colors.blue
                      : (_emailValidationError != null ? Colors.red : Colors.white54),
                  fontSize: 12
                ),
                prefixIcon: Icon(
                  Icons.email, 
                  color: _isEmailValid ? Colors.green : Colors.white70
                ),
                suffixIcon: _emailController.text.isNotEmpty
                    ? _isCheckingEmail
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                            ),
                          )
                        : Icon(
                            _isEmailValid ? Icons.check_circle : Icons.error,
                            color: _isEmailValid ? Colors.green : Colors.red,
                            size: 20,
                          )
                    : null,
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _isCheckingEmail
                        ? Colors.blue.withOpacity(0.5)
                        : (_emailValidationError != null 
                            ? Colors.red.withOpacity(0.5)
                            : _isEmailValid 
                                ? Colors.green.withOpacity(0.5)
                                : Colors.transparent),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _isCheckingEmail
                        ? Colors.blue
                        : (_emailValidationError != null 
                            ? Colors.red
                            : _isEmailValid 
                                ? Colors.green
                                : Colors.blue),
                    width: 2,
                  ),
                ),
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email address';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),


          ],
        ),
      ),
    );
  }

  Widget _buildSecurityPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Security',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a secure password for your account',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),

          // Password with strength indicator
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password *',
              helperText: _passwordValidationError ?? 'At least 6 characters',
              helperStyle: TextStyle(
                color: _passwordValidationError != null ? Colors.red : Colors.white54,
                fontSize: 12
              ),
              prefixIcon: Icon(
                Icons.lock, 
                color: _isPasswordValid ? Colors.green : Colors.white70
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_passwordController.text.isNotEmpty)
                    Icon(
                      _isPasswordValid ? Icons.check_circle : Icons.error,
                      color: _isPasswordValid ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ],
              ),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _passwordValidationError != null 
                      ? Colors.red.withOpacity(0.5)
                      : _isPasswordValid 
                          ? Colors.green.withOpacity(0.5)
                          : Colors.transparent,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _passwordValidationError != null 
                      ? Colors.red
                      : _isPasswordValid 
                          ? Colors.green
                          : Colors.blue,
                  width: 2,
                ),
              ),
              labelStyle: const TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),

          const SizedBox(height: 8),

          // Password strength indicator
          if (_passwordController.text.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded( 
                      child: Row(
                        children: [
                          Text(
                            'Password Strength: ',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _getPasswordStrengthText(),
                            style: TextStyle(
                              color: _getPasswordStrengthColor(),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(4, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: index < _passwordStrength 
                              ? _getPasswordStrengthColor()
                              : Colors.grey[600],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Confirm Password with real-time validation
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password *',
              helperText: _confirmPasswordValidationError,
              helperStyle: TextStyle(
                color: _confirmPasswordValidationError != null ? Colors.red : Colors.white54,
                fontSize: 12
              ),
              prefixIcon: Icon(
                Icons.lock_outline, 
                color: _isConfirmPasswordValid ? Colors.green : Colors.white70
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_confirmPasswordController.text.isNotEmpty)
                    Icon(
                      _isConfirmPasswordValid ? Icons.check_circle : Icons.error,
                      color: _isConfirmPasswordValid ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ],
              ),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _confirmPasswordValidationError != null 
                      ? Colors.red.withOpacity(0.5)
                      : _isConfirmPasswordValid 
                          ? Colors.green.withOpacity(0.5)
                          : Colors.transparent,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _confirmPasswordValidationError != null 
                      ? Colors.red
                      : _isConfirmPasswordValid 
                          ? Colors.green
                          : Colors.blue,
                  width: 2,
                ),
              ),
              labelStyle: const TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),

          const SizedBox(height: 24),

          // Password strength indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Password Tips:',
                  style: TextStyle(
                    color: Colors.blue[300],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Use at least 6 characters\n'
                  '• Mix letters and numbers\n'
                  '• Avoid using personal information',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Work & Personal Details',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Help us connect you with relevant support',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),

          // Work Location
          DropdownButtonFormField<String>(
            value: _selectedWorkLocation,
            decoration: InputDecoration(
              labelText: 'Work Location *',
              prefixIcon: const Icon(Icons.location_on, color: Colors.white70),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              labelStyle: const TextStyle(color: Colors.white70),
            ),
            dropdownColor: Colors.grey[800],
            style: const TextStyle(color: Colors.white),
            items: _workLocations.map((location) {
              return DropdownMenuItem(
                value: location,
                child: Text(location),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedWorkLocation = value;
              });
            },
          ),

          const SizedBox(height: 16),

          // Occupation
          TextFormField(
            controller: _occupationController,
            decoration: InputDecoration(
              labelText: 'Occupation *',
              prefixIcon: const Icon(Icons.work, color: Colors.white70),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              labelStyle: const TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),

          const SizedBox(height: 16),

          // Gender
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: InputDecoration(
              labelText: 'Gender *',
              prefixIcon:
                  const Icon(Icons.person_outline, color: Colors.white70),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              labelStyle: const TextStyle(color: Colors.white70),
            ),
            dropdownColor: Colors.grey[800],
            style: const TextStyle(color: Colors.white),
            items: _genders.map((gender) {
              return DropdownMenuItem(
                value: gender,
                child: Text(gender),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedGender = value;
              });
            },
          ),



          const SizedBox(height: 16),

          // Education
          DropdownButtonFormField<String>(
            value: _selectedEducation,
            decoration: InputDecoration(
              labelText: 'Educational Attainment *',
              prefixIcon: const Icon(Icons.school, color: Colors.white70),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              labelStyle: const TextStyle(color: Colors.white70),
            ),
            dropdownColor: Colors.grey[800],
            style: const TextStyle(color: Colors.white),
            items: _educationLevels.map((education) {
              return DropdownMenuItem(
                value: education,
                child: Text(education),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedEducation = value;
              });
            },
          ),

          const SizedBox(height: 16),

          // Birth Year
          Row(
            children: [
              const Icon(Icons.cake, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Birth Year',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Slider(
                      value: _birthYear.toDouble(),
                      min: 1950,
                      max: 2010,
                      divisions: 60,
                      activeColor: Colors.blue[800],
                      inactiveColor: Colors.grey[600],
                      onChanged: (value) {
                        setState(() {
                          _birthYear = value.round();
                        });
                      },
                    ),
                    Text(
                      _birthYear.toString(),
                      style: TextStyle(
                          color: Colors.blue[300], fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Marital Status
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text(
                'Married',
                style: TextStyle(color: Colors.white),
              ),
              value: _isMarried,
              onChanged: (value) {
                setState(() {
                  _isMarried = value;
                });
              },
              activeColor: Colors.blue[800],
            ),
          ),

          const SizedBox(height: 8),

          // Has Children
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text(
                'Have Children',
                style: TextStyle(color: Colors.white),
              ),
              value: _hasChildren,
              onChanged: (value) {
                setState(() {
                  _hasChildren = value;
                });
              },
              activeColor: Colors.blue[800],
            ),
          ),
        ],
      ),
    );
  }
}
