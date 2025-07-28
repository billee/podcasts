import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/billing_service.dart';
import '../../services/payment_service.dart';

class BillingManagementScreen extends StatefulWidget {
  const BillingManagementScreen({Key? key}) : super(key: key);

  @override
  State<BillingManagementScreen> createState() => _BillingManagementScreenState();
}

class _BillingManagementScreenState extends State<BillingManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _user = FirebaseAuth.instance.currentUser;
  
  List<BillingHistory> _billingHistory = [];
  List<Receipt> _receipts = [];
  List<RefundRequest> _refundRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBillingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBillingData() async {
    if (_user == null) return;

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        BillingService.getBillingHistory(_user!.uid),
        BillingService.getReceipts(_user!.uid),
        BillingService.getRefundRequests(_user!.uid),
      ]);

      setState(() {
        _billingHistory = results[0] as List<BillingHistory>;
        _receipts = results[1] as List<Receipt>;
        _refundRequests = results[2] as List<RefundRequest>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load billing data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing Management'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBillingHistoryTab(),
                _buildReceiptsTab(),
                _buildRefundsTab(),
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
            Text('No billing history found', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBillingData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _billingHistory.length,
        itemBuilder: (context, index) {
          final billing = _billingHistory[index];
          return _buildBillingHistoryCard(billing);
        },
      ),
    );
  }

  Widget _buildBillingHistoryCard(BillingHistory billing) {
    final statusColor = _getBillingStatusColor(billing.status);
    final statusIcon = _getBillingStatusIcon(billing.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _formatBillingStatus(billing.status),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${billing.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('MMM dd, yyyy - hh:mm a').format(billing.billingDate),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (billing.transactionId != null) ...[
              const SizedBox(height: 4),
              Text(
                'Transaction: ${billing.transactionId}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
            if (billing.failureReason != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        billing.failureReason!,
                        style: const TextStyle(fontSize: 11, color: Colors.red),
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
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ],
            if (billing.nextRetryDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Next retry: ${DateFormat('MMM dd, yyyy - hh:mm a').format(billing.nextRetryDate!)}',
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
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
            Text('No receipts found', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBillingData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _receipts.length,
        itemBuilder: (context, index) {
          final receipt = _receipts[index];
          return _buildReceiptCard(receipt);
        },
      ),
    );
  }

  Widget _buildReceiptCard(Receipt receipt) {
    final isRefund = receipt.amount < 0;
    final amountColor = isRefund ? Colors.green : Colors.black;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${isRefund ? '+' : ''}\$${receipt.amount.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(receipt.date),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatPaymentMethod(receipt.paymentMethod),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Receipt ID: ${receipt.id}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _downloadReceipt(receipt),
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text('Download', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _shareReceipt(receipt),
                  icon: const Icon(Icons.share, size: 14),
                  label: const Text('Share', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showRefundRequestDialog,
              icon: const Icon(Icons.money_off, size: 16),
              label: const Text('Request Refund', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        Expanded(
          child: _refundRequests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.money_off, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No refund requests found', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBillingData,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _refundRequests.length,
                    itemBuilder: (context, index) {
                      final refund = _refundRequests[index];
                      return _buildRefundCard(refund);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRefundCard(RefundRequest refund) {
    final statusColor = _getRefundStatusColor(refund.status);
    final statusIcon = _getRefundStatusIcon(refund.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _formatRefundStatus(refund.status),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${refund.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Requested: ${DateFormat('MMM dd, yyyy').format(refund.requestDate)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (refund.processedDate != null) ...[
              const SizedBox(height: 2),
              Text(
                'Processed: ${DateFormat('MMM dd, yyyy').format(refund.processedDate!)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Reason: ${refund.reason}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Original Transaction: ${refund.originalTransactionId}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (refund.refundTransactionId != null) ...[
              const SizedBox(height: 2),
              Text(
                'Refund Transaction: ${refund.refundTransactionId}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRefundRequestDialog() {
    showDialog(
      context: context,
      builder: (context) => RefundRequestDialog(
        onRefundRequested: () {
          _loadBillingData();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _downloadReceipt(Receipt receipt) {
    // In a real implementation, this would generate and download a PDF receipt
    _showInfoSnackBar('Receipt download functionality would be implemented here');
  }

  void _shareReceipt(Receipt receipt) {
    // In a real implementation, this would share the receipt via system share
    _showInfoSnackBar('Receipt sharing functionality would be implemented here');
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
      ),
    );
  }
}

class RefundRequestDialog extends StatefulWidget {
  final VoidCallback onRefundRequested;

  const RefundRequestDialog({
    Key? key,
    required this.onRefundRequested,
  }) : super(key: key);

  @override
  State<RefundRequestDialog> createState() => _RefundRequestDialogState();
}

class _RefundRequestDialogState extends State<RefundRequestDialog> {
  final _reasonController = TextEditingController();
  String? _selectedTransactionId;
  double? _selectedAmount;
  List<Receipt> _availableReceipts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableReceipts();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableReceipts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final receipts = await BillingService.getReceipts(user.uid);
      // Filter to only show positive amounts (not refunds) from last 30 days
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      
      setState(() {
        _availableReceipts = receipts
            .where((receipt) => 
                receipt.amount > 0 && 
                receipt.date.isAfter(cutoffDate))
            .toList();
      });
    } catch (e) {
      // Handle error silently or show error message
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request Refund', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Transaction:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTransactionId,
                  hint: const Text('Choose a transaction', style: TextStyle(fontSize: 12)),
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  items: _availableReceipts.map((receipt) {
                    return DropdownMenuItem<String>(
                      value: receipt.transactionId,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            receipt.description,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${DateFormat('MMM dd, yyyy').format(receipt.date)} - \$${receipt.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTransactionId = value;
                      _selectedAmount = _availableReceipts
                          .firstWhere((r) => r.transactionId == value)
                          .amount;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Reason for Refund:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Please explain why you are requesting a refund...',
                hintStyle: TextStyle(fontSize: 12),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8),
              ),
            ),
            if (_selectedAmount != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Refund Amount:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    Text(
                      '\$${_selectedAmount!.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(fontSize: 12)),
        ),
        ElevatedButton(
          onPressed: _canSubmitRefund() ? _submitRefundRequest : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  bool _canSubmitRefund() {
    return _selectedTransactionId != null &&
           _selectedAmount != null &&
           _reasonController.text.trim().isNotEmpty &&
           !_isLoading;
  }

  Future<void> _submitRefundRequest() async {
    if (!_canSubmitRefund()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final refundRequest = await BillingService.processRefundRequest(
        userId: user.uid,
        transactionId: _selectedTransactionId!,
        amount: _selectedAmount!,
        reason: _reasonController.text.trim(),
      );

      if (refundRequest != null) {
        widget.onRefundRequested();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Refund request submitted successfully', style: TextStyle(fontSize: 12)),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to process refund request');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: const TextStyle(fontSize: 12)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}