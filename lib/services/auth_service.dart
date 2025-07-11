import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final Logger _logger = Logger('AuthService');
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;

  // Check if user is logged in
  static bool get isLoggedIn => _auth.currentUser != null;

  // Stream of auth state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  static Future<User?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required Map<String, dynamic> userProfile,
  }) async {
    try {
      _logger.info('Attempting to create user with email: $email');

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user != null) {
        // Create user profile in Firestore
        await _createUserProfile(
            userId: user.uid, email: email, userProfile: userProfile);

        _logger.info('User created successfully: ${user.uid}');
        return user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      _logger.severe('Firebase Auth Error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      _logger.severe('Unexpected error during sign up: $e');
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Sign in with email and password
  static Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _logger.info('Attempting to sign in user with email: $email');

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user != null) {
        // Update login information
        await _updateLoginInfo(user.uid);
        _logger.info('User signed in successfully: ${user.uid}');
        return user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      _logger.severe('Firebase Auth Error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      _logger.severe('Unexpected error during sign in: $e');
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  static Future<User?> signUpWithUsername({
    required String username,
    required String password,
    required UserProfile userProfile,
  }) async {
    try {
      // Check if username already exists
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        throw 'Username already exists. Please choose a different username.';
      }

      // Create temp email for Firebase Auth
      final tempEmail = '$username@kapwa.local';

      // Use existing sign up method
      return await signUpWithEmailAndPassword(
        email: tempEmail,
        password: password,
        userProfile: userProfile.toJson(),
      );
    } catch (e) {
      _logger.severe('Username sign up error: $e');
      rethrow;
    }
  }

  static Future<User?> signInWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      // Find user by username
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (usernameQuery.docs.isEmpty) {
        throw 'Username not found. Please check your username.';
      }

      final userData = usernameQuery.docs.first.data();
      final email = userData['email'] as String;

      // Use existing sign in method
      return await signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _logger.severe('Username sign in error: $e');
      rethrow;
    }
  }

  static Future<void> _updateLoginInfo(String userId) async {
    try {
      // Get current login count
      final doc = await _firestore.collection('users').doc(userId).get();
      int currentLoginCount = 0;
      if (doc.exists) {
        currentLoginCount = doc.data()?['loginCount'] ?? 0;
      }

      await _firestore.collection('users').doc(userId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'loginCount': currentLoginCount + 1,
      });
    } catch (e) {
      _logger.warning('Failed to update login info: $e');
    }
  }

  // Phone authentication - send verification code
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
      throw 'Phone verification failed. Please try again.';
    }
  }

  // Sign in with phone credential
  static Future<User?> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
    Map<String, dynamic>? userProfile, // For new users
  }) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final UserCredential result =
          await _auth.signInWithCredential(credential);
      final User? user = result.user;

      if (user != null) {
        // Check if this is a new user
        if (result.additionalUserInfo?.isNewUser == true &&
            userProfile != null) {
          // Create profile for new phone user
          await _createUserProfile(
            userId: user.uid,
            email: user.email ?? '',
            userProfile: userProfile,
            phoneNumber: user.phoneNumber,
          );
        } else {
          // Update last login for existing user
          await _updateLastLogin(user.uid);
        }

        _logger.info('User signed in with phone successfully: ${user.uid}');
        return user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      _logger.severe('Phone sign in error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      _logger.severe('Unexpected error during phone sign in: $e');
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      _logger.info('Attempting to sign out user');
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      _logger.info('User signed out successfully');
    } catch (e) {
      _logger.severe('Error during sign out: $e');
      throw 'Failed to sign out. Please try again.';
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
        'uid': userId,
        'email': email,
        'phoneNumber': phoneNumber ?? userProfile['phoneNumber'] ?? '',
        'name': userProfile['name'] ?? '',
        'workLocation': userProfile['workLocation'] ?? '',
        'occupation': userProfile['occupation'] ?? '',
        'isMarried': userProfile['isMarried'] ?? false,
        'gender': userProfile['gender'] ?? '',
        'language': userProfile['language'] ?? 'english',
        'birthYear': userProfile['birthYear'] ?? DateTime.now().year,
        'educationalAttainment': userProfile['educationalAttainment'] ?? '',
        'userType': 'ofw',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isOnline': true,
        'profileCompleted': true,
        // Add these for better user management
        'loginCount': 0,
        'deviceInfo': userProfile['deviceInfo'] ?? {},
        'preferences': {
          'notifications': true,
          'language': userProfile['language'] ?? 'english',
          'theme': 'dark',
        },
      };

      await _firestore.collection('users').doc(userId).set(profileData);
      _logger.info('User profile created in Firestore: $userId');
    } catch (e) {
      _logger.severe('Error creating user profile: $e');
      throw 'Failed to create user profile. Please try again.';
    }
  }

  // Update last login time
  static Future<void> _updateLastLogin(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.warning('Failed to update last login time: $e');
    }
  }

  // Get user profile from Firestore
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      _logger.severe('Error fetching user profile: $e');
      return null;
    }
  }

  // Update user profile
  static Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _logger.info('User profile updated: $userId');
    } catch (e) {
      _logger.severe('Error updating user profile: $e');
      throw 'Failed to update profile. Please try again.';
    }
  }

  // Handle Firebase Auth exceptions
  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'invalid-phone-number':
        return 'The phone number format is invalid.';
      case 'invalid-verification-code':
        return 'The verification code is invalid.';
      case 'invalid-verification-id':
        return 'The verification ID is invalid.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _logger.info('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      _logger.severe(
          'Error sending password reset email: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      _logger.severe('Unexpected error sending password reset email: $e');
      throw 'Failed to send password reset email. Please try again.';
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return doc.data();
        }
      }
      return null;
    } catch (e) {
      _logger.severe('Error fetching current user profile: $e');
      return null;
    }
  }

  // Add method to update user activity
  static Future<void> updateUserActivity() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'lastActiveAt': FieldValue.serverTimestamp(),
          'isOnline': true,
        });
      }
    } catch (e) {
      _logger.warning('Failed to update user activity: $e');
    }
  }

  // This is the flexible signup method.
  static Future<User?> signUpFlexible({
    required String username,
    required String password,
    required UserProfile userProfile,
    String? email, // Optional email
  }) async {
    try {
      // Check if username already exists
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        throw 'Username already exists. Please choose a different username.';
      }

      // Use real email if provided, otherwise use temp email
      final authEmail =
          email?.isNotEmpty == true ? email! : '$username@kapwa.local';

      // Create user profile data
      final profileData = userProfile.toJson();
      profileData['username'] = username;
      profileData['hasRealEmail'] = email?.isNotEmpty == true;

      // Use existing sign up method
      return await signUpWithEmailAndPassword(
        email: authEmail,
        password: password,
        userProfile: profileData,
      );
    } catch (e) {
      _logger.severe('Flexible sign up error: $e');
      rethrow;
    }
  }

  // Add method to set user offline
  static Future<void> setUserOffline() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'lastActiveAt': FieldValue.serverTimestamp(),
          'isOnline': false,
        });
      }
    } catch (e) {
      _logger.warning('Failed to set user offline: $e');
    }
  }

  // This is the correct reset password method.
  static Future<void> resetPasswordByUsername(String username) async {
    try {
      _logger.info('Password reset requested for username: $username');

      // Find user by username to verify it exists
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (usernameQuery.docs.isEmpty) {
        throw 'Username not found. Please check your username.';
      }

      final userData = usernameQuery.docs.first.data();
      final userId = usernameQuery.docs.first.id;

      // Create a password reset request
      await _firestore.collection('password_reset_requests').add({
        'username': username,
        'userId': userId,
        'userInfo': {
          'name': userData['name'],
          'workLocation': userData['workLocation'],
          'phoneNumber': userData['phoneNumber'],
        },
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'requestSource': 'mobile_app',
      });

      _logger.info('Password reset request submitted for username: $username');
    } catch (e) {
      _logger.severe('Error submitting password reset request: $e');
      if (e is String) {
        rethrow;
      } else {
        throw 'Failed to submit password reset request. Please try again.';
      }
    }
  }
}
