import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/services/auth_service.dart';
import 'package:kapwa_companion_basic/models/user.dart';
import 'package:logging/logging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    _occupationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _extractErrorMessage(String error) {
    if (error.contains('username-already-exists') ||
        error.contains('Username already exists')) {
      return 'Username already taken. Please choose a different username.';
    } else if (error.contains('email-already-in-use')) {
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
      return _formKey.currentState!.validate();
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
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: Row(
            children: [
              Icon(Icons.email, color: Colors.blue[800]),
              const SizedBox(width: 8),
              const Text(
                'Verify Your Email',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Account created successfully!',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We\'ve sent a verification email to:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                _emailController.text.trim(),
                style: TextStyle(
                  color: Colors.blue[300],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please check your email and click the verification link to activate your account.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              const Text(
                'You can sign in after verifying your email.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                
                // Sign out the user since they need to verify email first
                await FirebaseAuth.instance.signOut();
                _logger.info('User signed out after registration - email verification required');
                
                // Navigate back to login screen
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('OK'),
            ),
          ],
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
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
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

            // Full Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: const Icon(Icons.person, color: Colors.white70),
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
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Username
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username *',
                helperText: 'This will be used to log in',
                helperStyle: const TextStyle(color: Colors.white54),
                prefixIcon:
                    const Icon(Icons.alternate_email, color: Colors.white70),
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

            // Email Field (now mandatory)
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address *',
                helperText: 'Required for account recovery and notifications',
                helperStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.email, color: Colors.white70),
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

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password *',
              helperText: 'At least 6 characters',
              helperStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.lock, color: Colors.white70),
              suffixIcon: IconButton(
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

          // Confirm Password
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password *',
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
              suffixIcon: IconButton(
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
