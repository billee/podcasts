import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';

class AuthService {
  static final Logger _logger = Logger('AuthService');
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirestoreService _firestoreService = FirestoreService();

  // Current User Accessors
  static User? get currentUser => _auth.currentUser;
  static String? get currentUserId => _auth.currentUser?.uid;
  static bool get isLoggedIn => _auth.currentUser != null;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Core Authentication Methods
  static Future<User?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required Map<String, dynamic> userProfile,
  }) async {
    try {
      _logger.info('Creating user with email: $email');
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        await _createUserProfile(
          userId: result.user!.uid,
          email: email,
          userProfile: userProfile,
        );
        return result.user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      _logger.severe('Auth Error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      _logger.severe('Unexpected error: $e');
      throw 'Registration failed. Please try again.';
    }
  }

  static Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user != null) {
        // Check and update email verification status
        await result.user!.reload();
        final updatedUser = _auth.currentUser;
        if (updatedUser != null && updatedUser.emailVerified) {
          // Update Firestore if email is verified
          await _firestore.collection('users').doc(updatedUser.uid).update({
            'emailVerified': true,
            'emailVerifiedAt': FieldValue.serverTimestamp(),
          }).catchError((e) {
            _logger.warning('Failed to update email verification status in Firestore: $e');
          });
        }
        
        // Update login info in background, don't block sign-in
        _updateLoginInfo(result.user!.uid).catchError((e) {
          _logger.warning('Login info update failed, but sign-in succeeded: $e');
        });
        return result.user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      _logger.severe('Auth Error: ${e.code} - ${e.message}');
      
      // Provide more specific error for invalid-credential
      if (e.code == 'invalid-credential') {
        // Check if user exists in our Firestore database
        try {
          final userQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          
          if (userQuery.docs.isEmpty) {
            throw 'No account found with this email. Please sign up first.';
          } else {
            throw 'Incorrect password. Please try again.';
          }
        } catch (firestoreError) {
          // If Firestore check fails, fall back to generic message
          _logger.warning('Firestore user check failed: $firestoreError');
          throw 'No account found with this email. Please sign up first.';
        }
      }
      
      throw _handleAuthException(e);
    }
  }

  // Username-based Authentication
  static Future<User?> signUpWithUsername({
    required String username,
    required String password,
    required Map<String, dynamic> userProfile,
  }) async {
    try {
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        throw 'Username already exists';
      }

      final tempEmail = '$username@kapwa.local';
      return await signUpWithEmailAndPassword(
        email: tempEmail,
        password: password,
        userProfile: userProfile,
      );
    } catch (e) {
      _logger.severe('Username signup error: $e');
      rethrow;
    }
  }

  static Future<User?> signInWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (usernameQuery.docs.isEmpty) {
        throw 'No account found with this username. Please sign up first or check your username.';
      }

      final email = usernameQuery.docs.first['email'] as String;
      return await signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _logger.severe('Username signin error: $e');
      rethrow;
    }
  }

  // Phone Authentication
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      _logger.severe('Phone verification error: $e');
      throw 'Phone verification failed';
    }
  }

  static Future<User?> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final UserCredential result =
          await _auth.signInWithCredential(credential);
      if (result.user != null) {
        if (result.additionalUserInfo?.isNewUser == true &&
            userProfile != null) {
          await _createUserProfile(
            userId: result.user!.uid,
            email: result.user!.email ?? '',
            userProfile: userProfile,
            phoneNumber: result.user!.phoneNumber,
          );
        } else {
          await _updateLastLogin(result.user!.uid);
        }
        return result.user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      _logger.severe('Phone signin error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    }
  }

  // Create user profile in Firestore
  static Future<void> _createUserProfile({
    required String userId,
    required String email,
    required Map<String, dynamic> userProfile,
    String? phoneNumber,
  }) async {
    try {
      final profileData = {
        ...userProfile,
        'uid': userId,
        'email': email, // Ensure email is saved
        'name': userProfile['name'] ?? '',
        'username': userProfile['username'] ?? '',
        'workLocation': userProfile['workLocation'] ?? '',
        'occupation': userProfile['occupation'] ?? '',
        'isMarried': userProfile['isMarried'] ?? false,
        'hasChildren': userProfile['hasChildren'] ?? false,
        'gender': userProfile['gender'] ?? '',
        'language': 'tagalog', // Fixed to Tagalog
        'birthYear': userProfile['birthYear'] ?? DateTime.now().year,
        'educationalAttainment': userProfile['educationalAttainment'] ?? '',
        'userType': 'ofw',
        'hasRealEmail': true, // Always true since email is mandatory
        'emailVerified': userProfile['emailVerified'] ?? false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isOnline': true,
        'profileCompleted': true,
        'loginCount': 1,
        'deviceInfo': userProfile['deviceInfo'] ?? {},
        'preferences': {
          'notifications': true,
          'language': 'tagalog', // Fixed to Tagalog
          'theme': 'dark',
          'emailNotifications': true,
          'pushNotifications': true,
        },
        'subscription': {
          'isTrialActive': true,
          'trialStartDate': FieldValue.serverTimestamp(),
          'plan': 'trial',
          'gptQueriesUsed': 0,
          'lastResetDate': FieldValue.serverTimestamp(),
        },
        'metadata': {
          'registrationSource': 'mobile_app',
          'platform': 'flutter',
          'version': '1.0.0',
        },
      };

      // Save to Firestore users collection
      await _firestore.collection('users').doc(userId).set(profileData);
      
      _logger.info('OFW profile created successfully for user: $userId with email: $email');

      // Also use FirestoreService for additional operations if needed
      try {
        await _firestoreService.createUserProfile(
          userId: userId,
          email: email,
          userProfile: userProfile,
        );
      } catch (e) {
        _logger.warning('FirestoreService profile creation failed: $e');
        // Don't throw here as main profile creation succeeded
      }
    } catch (e) {
      _logger.severe('Profile creation error: $e');
      throw 'Failed to create profile';
    }
  }

  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) throw 'User profile not found';
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      _logger.severe('Error fetching profile: $e');
      throw 'Failed to fetch profile';
    }
  }

  static Future<void> _updateLoginInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final currentCount = doc.exists
          ? (doc.data() as Map<String, dynamic>)['loginCount'] ?? 0
          : 0;

      await _firestore.collection('users').doc(userId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'loginCount': currentCount + 1,
      });
    } catch (e) {
      _logger.warning('Login info update failed: $e');
    }
  }

  static Future<void> _updateLastLogin(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.warning('Last login update failed: $e');
    }
  }

  // Account Management
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
    } catch (e) {
      _logger.severe('Sign out error: $e');
      throw 'Sign out failed';
    }
  }
  
  // Delete current user (for admin/testing purposes)
  static Future<void> deleteCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userId = user.uid;
        
        // Delete from Firestore first
        try {
          await _firestore.collection('users').doc(userId).delete();
          _logger.info('User profile deleted from Firestore: $userId');
        } catch (e) {
          _logger.warning('Error deleting user profile from Firestore: $e');
        }
        
        // Then delete from Authentication
        await user.delete();
        _logger.info('User authentication record deleted: $userId');
      } else {
        throw 'No user is currently signed in';
      }
    } catch (e) {
      _logger.severe('Error deleting user: $e');
      throw 'Failed to delete user: $e';
    }
  }

  static Future<void> resetPassword(String email) async {
    try {
      // First check if user exists in our database
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw 'No account found with this email address. Please check your email or sign up first.';
      }

      // Send password reset email
      await _auth.sendPasswordResetEmail(email: email);
      _logger.info('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      _logger.severe('Password reset error: ${e.code} - ${e.message}');
      if (e.code == 'user-not-found') {
        throw 'No account found with this email address. Please check your email or sign up first.';
      }
      throw _handleAuthException(e);
    } catch (e) {
      _logger.severe('Password reset error: $e');
      rethrow;
    }
  }

  static Future<void> resetPasswordByUsername(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw 'No account found with this username. Please check your username or sign up first.';
      }

      // Get the email associated with this username
      final userData = query.docs.first.data() as Map<String, dynamic>;
      final email = userData['email'] as String?;

      if (email == null || email.isEmpty) {
        throw 'No email associated with this username. Please contact support.';
      }

      // Send password reset email using the associated email
      await _auth.sendPasswordResetEmail(email: email);
      _logger.info('Password reset email sent to: $email for username: $username');
    } catch (e) {
      _logger.severe('Username password reset error: $e');
      rethrow;
    }
  }

  // Email Verification Management
  static Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _logger.info('Email verification sent to: ${user.email}');
      } else if (user?.emailVerified == true) {
        throw 'Email is already verified';
      } else {
        throw 'No user is currently signed in';
      }
    } catch (e) {
      _logger.severe('Email verification error: $e');
      rethrow;
    }
  }

  static Future<bool> checkEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        final updatedUser = _auth.currentUser;
        if (updatedUser != null && updatedUser.emailVerified) {
          await _firestore.collection('users').doc(updatedUser.uid).update({
            'emailVerified': true,
            'emailVerifiedAt': FieldValue.serverTimestamp(),
          });
          _logger.info('Email verification status updated for user: ${updatedUser.uid}');
          return true;
        }
      }
      return false;
    } catch (e) {
      _logger.warning('Email verification check failed: $e');
      return false;
    }
  }

  static Future<bool> isEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        return _auth.currentUser?.emailVerified ?? false;
      }
      return false;
    } catch (e) {
      _logger.warning('Email verification status check failed: $e');
      return false;
    }
  }

  // User Status Management
  static Future<void> updateUserActivity() async {
    try {
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({
          'lastActiveAt': FieldValue.serverTimestamp(),
          'isOnline': true,
        });
      }
    } catch (e) {
      _logger.warning('Activity update failed: $e');
    }
  }

  static Future<void> setUserOffline() async {
    try {
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({
          'lastActiveAt': FieldValue.serverTimestamp(),
          'isOnline': false,
        });
      }
    } catch (e) {
      _logger.warning('Offline status update failed: $e');
    }
  }

  // Helper Methods
  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in or use a different email.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email format. Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'invalid-phone-number':
        return 'Invalid phone number format.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials and try again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  // OFW Signup (Email is now mandatory)
  static Future<User?> signUpFlexible({
    required String username,
    required String password,
    required Map<String, dynamic> userProfile,
    required String email,
  }) async {
    try {
      // Check if username already exists
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        throw 'Username already exists';
      }

      // Check if email already exists
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        throw 'Email already registered';
      }

      // Ensure email is explicitly included in the profile data
      final profileData = {
        ...userProfile,
        'username': username,
        'email': email, // Explicitly include email
        'hasRealEmail': true,
        'emailVerified': false,
        'language': 'tagalog', // Fixed to Tagalog
      };

      final user = await signUpWithEmailAndPassword(
        email: email,
        password: password,
        userProfile: profileData,
      );

      // Send email verification
      if (user != null) {
        await user.sendEmailVerification();
        _logger.info('Email verification sent to: $email');
        
        // Double-check that email was saved to Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'email': email,
        });
      }

      return user;
    } catch (e) {
      _logger.severe('OFW signup error: $e');
      rethrow;
    }
  }
}
