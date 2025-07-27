import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/services/auth_service.dart';
import 'package:kapwa_companion_basic/widgets/feedback_widget.dart';
import 'package:kapwa_companion_basic/widgets/loading_state_widget.dart';
import 'dart:async';

class EmailVerificationBanner extends StatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  State<EmailVerificationBanner> createState() => _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner> {
  bool _isResending = false;
  bool _isDismissed = false;
  Timer? _verificationTimer;

  @override
  void initState() {
    super.initState();
    // Email verification monitoring is now handled globally by EmailVerificationService
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    // Don't show if user is null, email is verified, or banner is dismissed
    if (user == null || user.emailVerified || _isDismissed) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[800],
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Email Verification Required',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isDismissed = true;
                  });
                },
                icon: const Icon(
                  Icons.close,
                  color: Colors.orange,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your email and click the verification link, then log in again to activate your 7-day trial.',
            style: TextStyle(
              color: Colors.orange.shade300,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Email: ${user.email}',
            style: TextStyle(
              color: Colors.blue[300],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              LoadingButton(
                onPressed: _resendVerification,
                isLoading: _isResending,
                loadingText: 'Sending...',
                child: const Text(
                  'Resend Email',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () async {
                  // Sign out so user can log in again after verification
                  await AuthService.signOut();
                  if (mounted) {
                    FeedbackManager.showInfo(
                      context,
                      message: 'After verifying your email, please log in again to activate your trial.',
                      duration: const Duration(seconds: 4),
                    );
                  }
                },
                child: const Text(
                  'Go to Login',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerification() async {
    setState(() {
      _isResending = true;
    });

    try {
      await AuthService.sendEmailVerification();
      if (mounted) {
        FeedbackManager.showSuccess(
          context,
          message: 'Verification email sent! Please check your inbox.',
        );
      }
    } catch (e) {
      if (mounted) {
        FeedbackManager.showError(
          context,
          message: 'Failed to send verification email: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }
}