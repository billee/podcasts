// lib/screens/banned_user_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/services/auth_service.dart';
import 'package:kapwa_companion_basic/services/ban_service.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart'; 
import 'package:intl/date_symbol_data_local.dart'; 

class BannedUserScreen extends StatefulWidget {
  final String? userId;
  final Map<String, dynamic>? banDetails;
  
  const BannedUserScreen({
    super.key,
    this.userId,
    this.banDetails,
  });

  @override
  State<BannedUserScreen> createState() => _BannedUserScreenState();
}

class _BannedUserScreenState extends State<BannedUserScreen> {
  static final Logger _logger = Logger('BannedUserScreen');
  Map<String, dynamic>? _banDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fil', null).then((_) {
    _loadBanDetails();
    });
  }

  Future<void> _loadBanDetails() async {
    try {
      if (widget.banDetails != null) {
        _banDetails = widget.banDetails;
      } else {
        final userId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          _banDetails = await BanService.getBanDetails(userId);
        }
      }
      // Keep this for debugging if needed:
      print('Ban Details Loaded: $_banDetails'); 
    } catch (e) {
      _logger.severe('Error loading ban details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
    } catch (e) {
      _logger.severe('Error signing out: $e');
    }
  }

  String _formatBanDate() {
    if (_banDetails?['banned_at'] != null) {
      final bannedAt = _banDetails!['banned_at'];
      if (bannedAt is DateTime) {
        return DateFormat('MMMM d, yyyy', 'fil').format(bannedAt);
      }
      try {
        final timestamp = bannedAt.toDate() as DateTime;
        return DateFormat('MMMM d, yyyy', 'fil').format(timestamp);
      } catch (e) {
        return 'Unknown';
      }
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.blue[900],
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.blue[900],
        body: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.block,
                            size: 100,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 24),
                          
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.blue[800],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue[600]!, width: 2),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Ang inyong account ay na-suspend',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                
                      // Fix: Added crossAxisAlignment: CrossAxisAlignment.start to this Column
                      Column( 
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                                if (_banDetails != null) ...[
                                  _buildDetailColumn('Petsa ng Suspension:', _formatBanDate()),
                                  const SizedBox(height: 12),
                                  _buildDetailRow('Dahilan:', _banDetails!['reason'] ?? 'Paglabag sa mga tuntunin'),
                                ] else ...[
                                  Text(
                                    'Dahilan: Paglabag sa mga tuntunin at kondisyon',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                      ],
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[700],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Hindi kayo makakapag-access sa application habang naka-suspend ang inyong account.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                          ),
                          
                          const SizedBox(height: 32),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}