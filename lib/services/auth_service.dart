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
        await _updateLoginInfo(result.user!.uid);
        return result.user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      _logger.severe('Auth Error: ${e.code} - ${e.message}');
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
        throw 'Username not found. Please check your username.';
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
    await Future.delayed(const Duration(seconds: 1));
    try {
      final profileData = {
        ...userProfile,
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
        'loginCount': 0,
        'deviceInfo': userProfile['deviceInfo'] ?? {},
        'preferences': {
          'notifications': true,
          'language': userProfile['language'] ?? 'english',
          'theme': 'dark',
        },
        'subscription': {
          'isTrialActive': true,
          'trialStartDate': FieldValue.serverTimestamp(),
          'plan': 'trial',
          'gptQueriesUsed': 0,
          'videoMinutesUsed': 0,
          'lastResetDate': FieldValue.serverTimestamp(),
        },
      };

      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        throw 'User not authenticated properly';
      }

      await _firestoreService.createUserProfile(
        userId: userId,
        email: email,
        userProfile: userProfile,
        phoneNumber: phoneNumber,
      );

      await _firestore.collection('users').doc(userId).set(profileData);
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

  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      _logger.severe('Password reset error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    }
  }

  static Future<void> resetPasswordByUsername(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isEmpty) throw 'Username not found';

      await _firestore.collection('password_reset_requests').add({
        'username': username,
        'userId': query.docs.first.id,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      _logger.severe('Username password reset error: $e');
      rethrow;
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
        return 'Password is too weak';
      case 'email-already-in-use':
        return 'Email already in use';
      case 'user-not-found':
        return 'User not found';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email';
      case 'user-disabled':
        return 'Account disabled';
      case 'too-many-requests':
        return 'Too many attempts';
      case 'invalid-phone-number':
        return 'Invalid phone number';
      case 'invalid-verification-code':
        return 'Invalid verification code';
      default:
        return e.message ?? 'Authentication failed';
    }
  }

  // Flexible Signup (Combines email/username)
  static Future<User?> signUpFlexible({
    required String username,
    required String password,
    required Map<String, dynamic> userProfile,
    String? email,
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

      final authEmail = email ?? '$username@kapwa.local';
      final profileData = {
        ...userProfile,
        'username': username,
        'hasRealEmail': email != null,
      };

      return await signUpWithEmailAndPassword(
        email: authEmail,
        password: password,
        userProfile: profileData,
      );
    } catch (e) {
      _logger.severe('Flexible signup error: $e');
      rethrow;
    }
  }
}
