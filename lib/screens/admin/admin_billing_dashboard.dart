import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
import '../../services/billing_service.dart';
import '../../services/billing_scheduler_service.dart';
import '../../services/payment_service.dart';

class AdminBillingDashboard extends StatefulWidget {
  const AdminBillingDashboard({Key? key}) : super(key: key);

  @override
  State<AdminBillingDashboard> createState() => _AdminBillingDashboardState();
}

class _AdminBillingDashboardState extends State<AdminBillingDashboard>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger('AdminBillingDashboard');
  late TabController _tabController;

  // Dashboard data
  Map<String, dynamic> _billingStats = {};
  Map<String, int> _pendingCounts = {};
  List<BillingHistory> _recentBillings = [];
  List<RefundRequest> _pendingRefunds = [];
  List<Map<String, dynamic>> _failedPayments = [];
  List<Map<String, dynamic>> _recentPayments = [];
  Map<String, dynamic> _paymentStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        BillingSchedulerService.getBillingStatistics(),
        BillingSchedulerService.getPendingBillingCounts(),
        _getRecentBillings(),
        _getPendingRefunds(),
        _getFailedPayments(),
        _getRecentPayments(),
        _getPaymentStats(),
      ]);

      setState(() {
        _billingStats = results[0] as Map<String, dynamic>;
        _pendingCounts = results[1] as Map<String, int>;
        _recentBillings = results[2] as List<BillingHistory>;
        _pendingRefunds = results[3] as List<RefundRequest>;
        _failedPayments = results[4] as List<Map<String, dynamic>>;
        _recentPayments = results[5] as List<Map<String, dynamic>>;
        _paymentStats = results[6] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      _logger.severe('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<List<BillingHistory>> _getRecentBillings() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('billing_history')
          .orderBy('billingDate', descending: true)
          .limit(20)
          .get();

      return query.docs.map((doc) => BillingHistory.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      _logger.severe('Error getting recent billings: $e');
      return [];
    }
  }

  Future<List<RefundRequest>> _getPendingRefunds() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('refund_requests')
          .where('status', isEqualTo: RefundStatus.pending.name)
          .orderBy('requestDate', descending: true)
          .get();

      return query.docs.map((doc) => RefundRequest.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      _logger.severe('Error getting pending refunds: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getFailedPayments() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('billing_config')
          .where('status', isEqualTo: BillingStatus.pastDue.name)
          .get();

      List<Map<String, dynamic>> failedPayments = [];
      for (var doc in query.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        failedPayments.add(data);
      }

      return failedPayments;
    } catch (e) {
      _logger.severe('Error getting failed payments: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getRecentPayments() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('payment_transactions')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      List<Map<String, dynamic>> payments = [];
      for (var doc in query.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        payments.add(data);
      }

      return payments;
    } catch (e) {
      _logger.severe('Error getting recent payments: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _getPaymentStats() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Get today's payments
      final todayQuery = await FirebaseFirestore.instance
          .collection('payment_transactions')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      // Get this week's payments
      final weekQuery = await FirebaseFirestore.instance
          .collection('payment_transactions')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .get();

      // Get this month's payments
      final monthQuery = await FirebaseFirestore.instance
          .collection('payment_transactions')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();

      // Calculate stats
      double todayRevenue = 0;
      double weekRevenue = 0;
      double monthRevenue = 0;
      int todayCount = 0;
      int weekCount = 0;
      int monthCount = 0;
      int todaySuccessful = 0;
      int weekSuccessful = 0;
      int monthSuccessful = 0;

      Map<String, int> paymentMethods = {};
      Map<String, int> paymentStatuses = {};

      for (var doc in monthQuery.docs) {
        final data = doc.data();
        final amount = data['amount'] as double? ?? 0.0;
        final status = data['status'] as String? ?? 'unknown';
        final method = data['paymentMethod'] as String? ?? 'unknown';
        final createdAt = data['createdAt'] as Timestamp?;

        if (createdAt != null) {
          final date = createdAt.toDate();
          
          // Month stats
          monthCount++;
          if (status == 'succeeded') {
            monthRevenue += amount;
            monthSuccessful++;
          }

          // Week stats
          if (date.isAfter(startOfWeek)) {
            weekCount++;
            if (status == 'succeeded') {
              weekRevenue += amount;
              weekSuccessful++;
            }
          }

          // Today stats
          if (date.isAfter(startOfDay)) {
            todayCount++;
            if (status == 'succeeded') {
              todayRevenue += amount;
              todaySuccessful++;
            }
          }

          // Payment method stats
          paymentMethods[method] = (paymentMethods[method] ?? 0) + 1;
          
          // Status stats
          paymentStatuses[status] = (paymentStatuses[status] ?? 0) + 1;
        }
      }

      return {
        'today': {
          'revenue': todayRevenue,
          'count': todayCount,
          'successful': todaySuccessful,
          'successRate': todayCount > 0 ? (todaySuccessful / todayCount * 100).round() : 0,
        },
        'week': {
          'revenue': weekRevenue,
          'count': weekCount,
          'successful': weekSuccessful,
          'successRate': weekCount > 0 ? (weekSuccessful / weekCount * 100).round() : 0,
        },
        'month': {
          'revenue': monthRevenue,
          'count': monthCount,
          'successful': monthSuccessful,
          'successRate': monthCount > 0 ? (monthSuccessful / monthCount * 100).round() : 0,
        },
        'paymentMethods': paymentMethods,
        'paymentStatuses': paymentStatuses,
      };
    } catch (e) {
      _logger.severe('Error getting payment stats: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: const Text('Billing Administration'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _processPendingBilling,
            tooltip: 'Process Pending Billing',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 18)),
            Tab(text: 'Payments', icon: Icon(Icons.credit_card, size: 18)),
            Tab(text: 'Billing', icon: Icon(Icons.payment, size: 18)),
            Tab(text: 'Refunds', icon: Icon(Icons.money_off, size: 18)),
            Tab(text: 'Failed', icon: Icon(Icons.error, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildPaymentsTab(),
                _buildBillingTab(),
                _buildRefundsTab(),
                _buildFailedPaymentsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final currentMonth = _billingStats['currentMonth'] ?? {};
    final schedulerStatus = _billingStats['schedulerStatus'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics
          const Text(
            'Key Metrics',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard(
                'Monthly Revenue',
                '\$${(currentMonth['totalRevenue'] ?? 0.0).toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.green,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                'Success Rate',
                '${currentMonth['successRate'] ?? 0}%',
                Icons.check_circle,
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard(
                'Successful Billings',
                '${currentMonth['successfulBillings'] ?? 0}',
                Icons.payment,
                Colors.green,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                'Failed Billings',
                '${currentMonth['failedBillings'] ?? 0}',
                Icons.error,
                Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Payment Monitoring
          const Text(
            'Payment Monitoring',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard(
                'Today\'s Revenue',
                '\$${((_paymentStats['today'] ?? {})['revenue'] ?? 0.0).toStringAsFixed(2)}',
                Icons.today,
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                'Today\'s Payments',
                '${(_paymentStats['today'] ?? {})['count'] ?? 0}',
                Icons.credit_card,
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard(
                'Week Revenue',
                '\$${((_paymentStats['week'] ?? {})['revenue'] ?? 0.0).toStringAsFixed(2)}',
                Icons.date_range,
                Colors.purple,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                'Total Payments',
                '${_recentPayments.length}',
                Icons.receipt_long,
                Colors.teal,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Pending Operations
          const Text(
            'Pending Operations',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard(
                'Due Billings',
                '${_pendingCounts['dueBillings'] ?? 0}',
                Icons.schedule,
                Colors.orange,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                'Retry Billings',
                '${_pendingCounts['retryBillings'] ?? 0}',
                Icons.refresh,
                Colors.yellow,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard(
                'Expired Grace',
                '${_pendingCounts['expiredGracePeriods'] ?? 0}',
                Icons.warning,
                Colors.red,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                'Pending Refunds',
                '${_pendingRefunds.length}',
                Icons.money_off,
                Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Scheduler Status
          const Text(
            'Billing Scheduler',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.grey[800],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        schedulerStatus['isRunning'] == true ? Icons.play_circle : Icons.pause_circle,
                        color: schedulerStatus['isRunning'] == true ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        schedulerStatus['isRunning'] == true ? 'Running' : 'Stopped',
                        style: TextStyle(
                          color: schedulerStatus['isRunning'] == true ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Interval: ${schedulerStatus['intervalHours'] ?? 1} hour(s)',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (schedulerStatus['nextRun'] != null)
                    Text(
                      'Next Run: ${_formatDateTime(schedulerStatus['nextRun'])}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _processPendingBilling,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Process Pending'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _exportBillingData,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showBillingSettings,
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab() {
    final todayStats = _paymentStats['today'] ?? {};
    final weekStats = _paymentStats['week'] ?? {};
    final monthStats = _paymentStats['month'] ?? {};
    final paymentMethods = _paymentStats['paymentMethods'] as Map<String, int>? ?? {};
    final paymentStatuses = _paymentStats['paymentStatuses'] as Map<String, int>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Statistics
          const Text(
            'Payment Statistics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          
          // Time-based stats
          Row(
            children: [
              _buildMetricCard(
                'Today',
                '\$${(todayStats['revenue'] ?? 0.0).toStringAsFixed(2)}',
                Icons.today,
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                'This Week',
                '\$${(weekStats['revenue'] ?? 0.0).toStringAsFixed(2)}',
                Icons.date_range,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard(
                'Today Count',
                '${todayStats['count'] ?? 0}',
                Icons.payment,
                Colors.orange,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                'Success Rate',
                '${todayStats['successRate'] ?? 0}%',
                Icons.check_circle,
                Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Payment Methods Breakdown
          const Text(
            'Payment Methods',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.grey[800],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: paymentMethods.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatPaymentMethod(entry.key),
                          style: const TextStyle(color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entry.value}',
                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Payment Status Breakdown
          const Text(
            'Payment Status Distribution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.grey[800],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: paymentStatuses.entries.map((entry) {
                  final color = _getPaymentStatusColor(entry.key);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entry.value}',
                            style: TextStyle(color: color, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Recent Payment Transactions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Payment Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              TextButton.icon(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _recentPayments.isEmpty
              ? const Center(
                  child: Text(
                    'No recent payment transactions',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentPayments.length,
                  itemBuilder: (context, index) {
                    final payment = _recentPayments[index];
                    return _buildPaymentCard(payment);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildBillingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Billing Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              TextButton.icon(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _recentBillings.isEmpty
              ? const Center(
                  child: Text(
                    'No recent billing activity',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentBillings.length,
                  itemBuilder: (context, index) {
                    final billing = _recentBillings[index];
                    return _buildBillingCard(billing);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildRefundsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending Refund Requests',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          _pendingRefunds.isEmpty
              ? const Center(
                  child: Text(
                    'No pending refund requests',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pendingRefunds.length,
                  itemBuilder: (context, index) {
                    final refund = _pendingRefunds[index];
                    return _buildRefundCard(refund);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildFailedPaymentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Failed Payments Requiring Attention',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          _failedPayments.isEmpty
              ? const Center(
                  child: Text(
                    'No failed payments',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _failedPayments.length,
                  itemBuilder: (context, index) {
                    final payment = _failedPayments[index];
                    return _buildFailedPaymentCard(payment);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: Colors.grey[800],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillingCard(BillingHistory billing) {
    final statusColor = _getBillingStatusColor(billing.status);
    
    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'User: ${billing.userId.substring(0, 8)}...',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    billing.status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${billing.amount.toStringAsFixed(2)} ${billing.currency}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(billing.billingDate),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            if (billing.transactionId != null) ...[
              const SizedBox(height: 4),
              Text(
                'Transaction: ${billing.transactionId}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
            if (billing.failureReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[900]?.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Failure: ${billing.failureReason}',
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
              ),
            ],
            if (billing.retryCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Retries: ${billing.retryCount}',
                style: const TextStyle(color: Colors.orange, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRefundCard(RefundRequest refund) {
    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'User: ${refund.userId.substring(0, 8)}...',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${refund.amount.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Reason: ${refund.reason}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Original Transaction: ${refund.originalTransactionId}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Requested: ${DateFormat('MMM dd, yyyy').format(refund.requestDate)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => _approveRefund(refund),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(60, 30),
                      ),
                      child: const Text('Approve', style: TextStyle(fontSize: 10)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _rejectRefund(refund),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(60, 30),
                      ),
                      child: const Text('Reject', style: TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final userId = payment['userId'] as String? ?? 'Unknown';
    final amount = payment['amount'] as double? ?? 0.0;
    final currency = payment['currency'] as String? ?? 'USD';
    final status = payment['status'] as String? ?? 'unknown';
    final paymentMethod = payment['paymentMethod'] as String? ?? 'unknown';
    final transactionId = payment['transactionId'] as String? ?? payment['id'] as String;
    final createdAt = payment['createdAt'] as Timestamp?;
    final type = payment['type'] as String? ?? 'payment';
    
    final statusColor = _getPaymentStatusColor(status);
    
    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'User: ${userId.length > 8 ? userId.substring(0, 8) : userId}...',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${amount < 0 ? '-' : ''}\$${amount.abs().toStringAsFixed(2)} $currency',
                  style: TextStyle(
                    color: amount < 0 ? Colors.red : Colors.white, 
                    fontSize: 16, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                if (createdAt != null)
                  Text(
                    DateFormat('MMM dd, yyyy HH:mm').format(createdAt.toDate()),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatPaymentMethod(paymentMethod),
                    style: const TextStyle(color: Colors.blue, fontSize: 10),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    type.toUpperCase(),
                    style: const TextStyle(color: Colors.purple, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Transaction: $transactionId',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedPaymentCard(Map<String, dynamic> payment) {
    final userId = payment['userId'] as String;
    final failedAttempts = payment['failedAttempts'] as int? ?? 0;
    final gracePeriodEnd = payment['gracePeriodEnd'] as Timestamp?;
    
    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'User: ${userId.substring(0, 8)}...',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    'PAST DUE',
                    style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Failed Attempts: $failedAttempts/3',
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
            if (gracePeriodEnd != null) ...[
              const SizedBox(height: 4),
              Text(
                'Grace Period Ends: ${DateFormat('MMM dd, yyyy HH:mm').format(gracePeriodEnd.toDate())}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _retryBilling(userId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(80, 30),
                  ),
                  child: const Text('Retry Now', style: TextStyle(fontSize: 10)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _suspendUser(userId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(80, 30),
                  ),
                  child: const Text('Suspend', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getBillingStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'succeeded':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'succeeded':
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'pending':
      case 'processing':
        return Colors.orange;
      case 'cancelled':
        return Colors.grey;
      case 'requiresaction':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'creditcard':
        return 'Credit Card';
      case 'paypal':
        return 'PayPal';
      case 'googlepay':
        return 'Google Pay';
      case 'applepay':
        return 'Apple Pay';
      case 'unknown':
        return 'Unknown';
      default:
        return method;
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Future<void> _processPendingBilling() async {
    try {
      await BillingSchedulerService.processAllPendingBilling();
      _showSuccessSnackBar('Pending billing operations processed');
      _loadDashboardData();
    } catch (e) {
      _showErrorSnackBar('Error processing billing: $e');
    }
  }

  Future<void> _approveRefund(RefundRequest refund) async {
    try {
      await FirebaseFirestore.instance
          .collection('refund_requests')
          .doc(refund.id)
          .update({
        'status': RefundStatus.approved.name,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      
      _showSuccessSnackBar('Refund approved');
      _loadDashboardData();
    } catch (e) {
      _showErrorSnackBar('Error approving refund: $e');
    }
  }

  Future<void> _rejectRefund(RefundRequest refund) async {
    try {
      await FirebaseFirestore.instance
          .collection('refund_requests')
          .doc(refund.id)
          .update({
        'status': RefundStatus.rejected.name,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      
      _showSuccessSnackBar('Refund rejected');
      _loadDashboardData();
    } catch (e) {
      _showErrorSnackBar('Error rejecting refund: $e');
    }
  }

  Future<void> _retryBilling(String userId) async {
    try {
      final success = await BillingSchedulerService.triggerBillingForUser(userId);
      if (success) {
        _showSuccessSnackBar('Billing retry initiated for user');
      } else {
        _showErrorSnackBar('Billing retry failed');
      }
      _loadDashboardData();
    } catch (e) {
      _showErrorSnackBar('Error retrying billing: $e');
    }
  }

  Future<void> _suspendUser(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('billing_config')
          .doc(userId)
          .update({
        'status': BillingStatus.suspended.name,
        'suspensionReason': 'Admin action - payment failures',
        'suspendedAt': FieldValue.serverTimestamp(),
        'suspendedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      
      _showSuccessSnackBar('User billing suspended');
      _loadDashboardData();
    } catch (e) {
      _showErrorSnackBar('Error suspending user: $e');
    }
  }

  void _exportBillingData() {
    _showInfoSnackBar('Export functionality would be implemented here');
  }

  void _showBillingSettings() {
    _showInfoSnackBar('Billing settings would be implemented here');
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}