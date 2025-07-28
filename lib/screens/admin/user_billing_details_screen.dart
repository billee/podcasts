import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
import '../../services/billing_service.dart';

class UserBillingDetailsScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;

  const UserBillingDetailsScreen({
    Key? key,
    required this.userId,
    required this.userName,
    required this.userEmail,
  }) : super(key: key);

  @override
  State<UserBillingDetailsScreen> createState() => _UserBillingDetailsScreenState();
}

class _UserBillingDetailsScreenState extends State<UserBillingDetailsScreen>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger('UserBillingDetails');
  late TabController _tabController;

  List<BillingHistory> _billingHistory = [];
  List<Receipt> _receipts = [];
  List<RefundRequest> _refundRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserBillingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserBillingData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        BillingService.getBillingHistory(widget.userId),
        BillingService.getReceipts(widget.userId),
        BillingService.getRefundRequests(widget.userId),
      ]);

      setState(() {
        _billingHistory = results[0] as List<BillingHistory>;
        _receipts = results[1] as List<Receipt>;
        _refundRequests = results[2] as List<RefundRequest>;
        _isLoading = false;
      });
    } catch (e) {
      _logger.severe('Error loading user billing data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: Text('Billing: ${widget.userName}'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserBillingData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'History', icon: Icon(Icons.history, size: 18)),
            Tab(text: 'Receipts', icon: Icon(Icons.receipt, size: 18)),
            Tab(text: 'Refunds', icon: Icon(Icons.money_off, size: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          // User Info Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[800],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.userEmail,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  'User ID: ${widget.userId}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBillingHistoryTab(),
                      _buildReceiptsTab(),
                      _buildRefundsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingHistoryTab() {
    if (_billingHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No billing history found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _billingHistory.length,
      itemBuilder: (context, index) {
        final billing = _billingHistory[index];
        return _buildBillingCard(billing);
      },
    );
  }

  Widget _buildReceiptsTab() {
    if (_receipts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No receipts found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _receipts.length,
      itemBuilder: (context, index) {
        final receipt = _receipts[index];
        return _buildReceiptCard(receipt);
      },
    );
  }

  Widget _buildRefundsTab() {
    if (_refundRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.money_off, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No refund requests found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _refundRequests.length,
      itemBuilder: (context, index) {
        final refund = _refundRequests[index];
        return _buildRefundCard(refund);
      },
    );
  }

  Widget _buildBillingCard(BillingHistory billing) {
    final statusColor = _getBillingStatusColor(billing.status);
    final statusIcon = _getBillingStatusIcon(billing.status);

    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _formatBillingStatus(billing.status),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${billing.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM dd, yyyy - hh:mm a').format(billing.billingDate),
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            if (billing.transactionId != null) ...[
              const SizedBox(height: 4),
              Text(
                'Transaction: ${billing.transactionId}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
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
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        billing.failureReason!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (billing.retryCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Retry attempts: ${billing.retryCount}',
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptCard(Receipt receipt) {
    final isRefund = receipt.amount < 0;
    final amountColor = isRefund ? Colors.green : Colors.white;

    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    receipt.description,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  '${isRefund ? '+' : ''}\$${receipt.amount.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(receipt.date),
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50]?.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatPaymentMethod(receipt.paymentMethod),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Receipt ID: ${receipt.id}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            Text(
              'Transaction: ${receipt.transactionId}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundCard(RefundRequest refund) {
    final statusColor = _getRefundStatusColor(refund.status);
    final statusIcon = _getRefundStatusIcon(refund.status);

    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _formatRefundStatus(refund.status),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${refund.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Requested: ${DateFormat('MMM dd, yyyy').format(refund.requestDate)}',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            if (refund.processedDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Processed: ${DateFormat('MMM dd, yyyy').format(refund.processedDate!)}',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Reason: ${refund.reason}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Original Transaction: ${refund.originalTransactionId}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            if (refund.refundTransactionId != null) ...[
              const SizedBox(height: 4),
              Text(
                'Refund Transaction: ${refund.refundTransactionId}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
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

  IconData _getBillingStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'succeeded':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'pending':
        return Icons.schedule;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getRefundStatusColor(RefundStatus status) {
    switch (status) {
      case RefundStatus.processed:
        return Colors.green;
      case RefundStatus.failed:
      case RefundStatus.rejected:
        return Colors.red;
      case RefundStatus.pending:
      case RefundStatus.approved:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getRefundStatusIcon(RefundStatus status) {
    switch (status) {
      case RefundStatus.processed:
        return Icons.check_circle;
      case RefundStatus.failed:
      case RefundStatus.rejected:
        return Icons.error;
      case RefundStatus.pending:
        return Icons.schedule;
      case RefundStatus.approved:
        return Icons.thumb_up;
      default:
        return Icons.help;
    }
  }

  String _formatBillingStatus(String status) {
    return status.split('_').map((word) => 
        word[0].toUpperCase() + word.substring(1).toLowerCase()).join(' ');
  }

  String _formatRefundStatus(RefundStatus status) {
    return status.name.split('_').map((word) => 
        word[0].toUpperCase() + word.substring(1).toLowerCase()).join(' ');
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
      case 'refund':
        return 'Refund';
      default:
        return method;
    }
  }
}