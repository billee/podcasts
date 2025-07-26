import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';

/// Global test configuration and setup
class TestConfig {
  static bool _initialized = false;

  /// Initialize test environment with necessary configurations
  static Future<void> initialize() async {
    if (_initialized) return;

    // Ensure Flutter binding is initialized
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock Firebase initialization
    setupFirebaseAuthMocks();

    // Set up method channel mocks for platform-specific functionality
    _setupMethodChannelMocks();

    // Configure test timeouts
    _configureTestTimeouts();

    _initialized = true;
  }

  /// Set up method channel mocks for platform-specific features
  static void _setupMethodChannelMocks() {
    // Mock Firebase Core
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_core'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'Firebase#initializeCore') {
          return [
            {
              'name': '[DEFAULT]',
              'options': {
                'apiKey': 'test-api-key',
                'appId': 'test-app-id',
                'messagingSenderId': 'test-sender-id',
                'projectId': 'test-project-id',
              },
              'pluginConstants': {},
            }
          ];
        }
        return null;
      },
    );

    // Mock Firebase Auth
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_auth'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'Auth#registerIdTokenListener':
          case 'Auth#registerAuthStateListener':
            return {'user': null};
          case 'Auth#signOut':
            return null;
          default:
            return null;
        }
      },
    );

    // Mock Cloud Firestore
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/cloud_firestore'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    // Mock shared preferences
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return null;
      },
    );

    // Mock path provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '/tmp/test_documents';
        }
        return null;
      },
    );
  }

  /// Configure test timeouts for different test types
  static void _configureTestTimeouts() {
    // Test timeouts are configured per test group or individual test
    // Default timeout is handled by the test framework
  }

  /// Clean up test environment
  static Future<void> cleanup() async {
    // Clear method channel handlers
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_core'),
      null,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_auth'),
      null,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/cloud_firestore'),
      null,
    );

    _initialized = false;
  }
}

/// Mock Firebase initialization for testing
void setupFirebaseAuthMocks() {
  // This function is used by firebase_auth_mocks
  // It's called automatically when using MockFirebaseAuth
}

/// Test environment configuration
class TestEnvironment {
  static const String testApiKey = 'test-api-key';
  static const String testProjectId = 'test-project-id';
  static const String testAppId = 'test-app-id';
  static const String testSenderId = 'test-sender-id';

  /// Check if running in test environment
  static bool get isTestEnvironment => 
      const bool.fromEnvironment('FLUTTER_TEST', defaultValue: false);

  /// Get test-specific configuration values
  static Map<String, String> get testConfig => {
    'API_KEY': testApiKey,
    'PROJECT_ID': testProjectId,
    'APP_ID': testAppId,
    'SENDER_ID': testSenderId,
  };
}

/// Test data constants
class TestData {
  // User test data
  static const String testEmail = 'test@example.com';
  static const String testPassword = 'testPassword123';
  static const String testUsername = 'testuser';
  static const String testUid = 'test-uid-123';
  static const String testDisplayName = 'Test User';

  // Subscription test data
  static const double testMonthlyPrice = 3.0;
  static const int testTrialDays = 7;
  static const int testSubscriptionDays = 30;

  // Error messages
  static const String networkErrorMessage = 'Network error occurred';
  static const String authErrorMessage = 'Authentication failed';
  static const String firestoreErrorMessage = 'Database operation failed';

  // Success messages
  static const String registrationSuccessMessage = 'Registration successful';
  static const String loginSuccessMessage = 'Login successful';
  static const String subscriptionSuccessMessage = 'Subscription activated';
}

/// Test utilities for common operations
class TestUtils {
  /// Generate a unique test email
  static String generateTestEmail() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'test$timestamp@example.com';
  }

  /// Generate a unique test username
  static String generateTestUsername() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'testuser$timestamp';
  }

  /// Generate a unique test UID
  static String generateTestUid() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'test-uid-$timestamp';
  }

  /// Create a future date for testing
  static DateTime futureDate({int days = 7}) {
    return DateTime.now().add(Duration(days: days));
  }

  /// Create a past date for testing
  static DateTime pastDate({int days = 7}) {
    return DateTime.now().subtract(Duration(days: days));
  }

  /// Wait for a specific duration in tests
  static Future<void> wait({int milliseconds = 100}) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }
}