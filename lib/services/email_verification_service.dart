import 'package:logging/logging.dart';

/// Email verification is now handled directly in AuthService.checkEmailVerification()
/// This service is kept for potential future use but is currently not active
class EmailVerificationService {
  static final Logger _logger = Logger('EmailVerificationService');

  /// Email verification is now handled directly in AuthService.checkEmailVerification()
  /// This service is kept as a placeholder for potential future enhancements
  static void info() {
    _logger.info('Email verification is handled directly in AuthService.checkEmailVerification()');
  }
}