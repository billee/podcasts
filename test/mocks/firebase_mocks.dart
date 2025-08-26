import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;

// Generate mocks for Firebase services
@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  User,
  UserCredential,
  DocumentReference,
  DocumentSnapshot,
  CollectionReference,
  Query,
  QuerySnapshot,
  QueryDocumentSnapshot,
  AdditionalUserInfo,
])
import 'firebase_mocks.mocks.dart';

/// Factory class for creating Firebase mocks with common configurations
class FirebaseMockFactory {
  /// Creates a mock FirebaseAuth with common authentication scenarios
  static auth_mocks.MockFirebaseAuth createMockAuth({
    User? currentUser,
    bool shouldThrowOnSignIn = false,
    bool shouldThrowOnSignUp = false,
    bool shouldThrowOnSignOut = false,
  }) {
    final mockAuth = auth_mocks.MockFirebaseAuth(
      mockUser: currentUser as auth_mocks.MockUser?,
      signedIn: currentUser != null,
    );

    // Note: firebase_auth_mocks handles most authentication scenarios automatically
    // Custom behavior can be configured if needed

    return mockAuth;
  }

  /// Creates a FakeFirebaseFirestore with pre-populated test data
  static FakeFirebaseFirestore createMockFirestore({
    bool withTestData = true,
  }) {
    final firestore = FakeFirebaseFirestore();

    if (withTestData) {
      _populateTestData(firestore);
    }

    return firestore;
  }

  /// Creates a mock user with customizable properties
  static auth_mocks.MockUser createMockUser({
    String uid = 'test-uid-123',
    String email = 'test@example.com',
    String displayName = 'Test User',
    bool isEmailVerified = true,
  }) {
    return auth_mocks.MockUser(
      uid: uid,
      email: email,
      displayName: displayName,
      isEmailVerified: isEmailVerified,
    );
  }

  /// Creates a mock UserCredential for authentication testing
  static MockUserCredential createMockUserCredential({
    User? user,
    AdditionalUserInfo? additionalUserInfo,
  }) {
    final mockCredential = MockUserCredential();
    when(mockCredential.user).thenReturn(user);
    when(mockCredential.additionalUserInfo).thenReturn(additionalUserInfo);
    return mockCredential;
  }

  /// Populates Firestore with test data for consistent testing
  static void _populateTestData(FakeFirebaseFirestore firestore) {
    // Add test user data
    firestore.collection('users').doc('test-uid-123').set({
      'uid': 'test-uid-123',
      'email': 'test@example.com',
      'username': 'testuser',
      'emailVerified': true,
      'createdAt': DateTime.now(),
      'lastLoginAt': DateTime.now(),
    });

    // Add test trial history
    firestore.collection('trial_history').doc('test@example.com').set({
      'userId': 'test-uid-123',
      'email': 'test@example.com',
      'trialStartDate': DateTime.now(),
      'trialEndDate': DateTime.now().add(const Duration(days: 7)),
      'createdAt': DateTime.now(),
    });

    // Add test subscription data
    firestore.collection('subscriptions').doc('test@example.com').set({
      'email': 'test@example.com',
      'isActive': true,
      'cancelled': false,
      'subscriptionStartDate': DateTime.now(),
      'subscriptionEndDate': DateTime.now().add(const Duration(days: 30)),
      'monthlyPrice': 3.0,
    });
  }
}

/// Common Firebase exception scenarios for testing
class FirebaseExceptionScenarios {
  static FirebaseAuthException get userNotFound => FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user found for that email.',
      );

  static FirebaseAuthException get wrongPassword => FirebaseAuthException(
        code: 'wrong-password',
        message: 'Wrong password provided for that user.',
      );

  static FirebaseAuthException get emailAlreadyInUse => FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'The account already exists for that email.',
      );

  static FirebaseAuthException get weakPassword => FirebaseAuthException(
        code: 'weak-password',
        message: 'The password provided is too weak.',
      );

  static FirebaseAuthException get invalidEmail => FirebaseAuthException(
        code: 'invalid-email',
        message: 'The email address is not valid.',
      );

  static FirebaseAuthException get networkRequestFailed =>
      FirebaseAuthException(
        code: 'network-request-failed',
        message: 'A network error has occurred.',
      );

  static FirebaseException get firestorePermissionDenied => FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message:
            'The caller does not have permission to execute the specified operation.',
      );

  static FirebaseException get firestoreUnavailable => FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'The service is currently unavailable.',
      );
}

/// Helper class for creating fake query snapshots
class FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  FakeQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => [];

  @override
  SnapshotMetadata get metadata => MockSnapshotMetadata();

  @override
  int get size => _docs.length;
}

/// Mock SnapshotMetadata for testing
class MockSnapshotMetadata implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;

  @override
  bool get isFromCache => false;
}
