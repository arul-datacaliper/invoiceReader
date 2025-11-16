import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../models/invoice.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String _filterStatus = 'all'; // all, paid, unpaid, pending, processing, completed, failed
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final userDocument = authProvider.userDocument;

    // Check if user is authenticated but doesn't have a user document
    if (user != null && userDocument == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading user profile...'),
              SizedBox(height: 8),
              Text(
                'If this continues, please complete your profile setup.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final tenantId = userDocument?.tenantId;

    if (tenantId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login to view invoices'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              // The StreamBuilder will automatically refresh
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          _buildSearchAndFilterSection(),
          
          // Invoice List
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildInvoiceStream(tenantId),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search invoices by supplier name or invoice number...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          
          const SizedBox(height: 12),
          
          // Filter Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Date Range Filter
                _buildDateRangeFilter(),
                const SizedBox(width: 12),
                
                // Status Filter
                _buildStatusFilter(),
                
                const SizedBox(width: 12),
                
                // Clear Filters
                if (_startDate != null || _endDate != null || _filterStatus != 'all')
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _filterStatus = 'all';
                      });
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeFilter() {
    return OutlinedButton.icon(
      onPressed: () async {
        final result = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: _startDate != null && _endDate != null 
            ? DateTimeRange(start: _startDate!, end: _endDate!)
            : null,
        );
        
        if (result != null) {
          setState(() {
            _startDate = result.start;
            _endDate = result.end;
          });
        }
      },
      icon: const Icon(Icons.date_range),
      label: Text(
        _startDate != null && _endDate != null
          ? '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}'
          : 'Date Range',
      ),
    );
  }

  Widget _buildStatusFilter() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        setState(() {
          _filterStatus = value;
        });
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'all', child: Text('All Invoices')),
        const PopupMenuItem(value: 'paid', child: Text('Paid')),
        const PopupMenuItem(value: 'unpaid', child: Text('Unpaid')),
        const PopupMenuItem(value: 'pending', child: Text('Pending')),
        const PopupMenuItem(value: 'processing', child: Text('Processing')),
        const PopupMenuItem(value: 'completed', child: Text('Completed')),
        const PopupMenuItem(value: 'failed', child: Text('Failed')),
      ],
      child: OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.filter_list),
        label: Text(_filterStatus == 'all' ? 'Status' : _filterStatus.toUpperCase()),
      ),
    );
  }

  Widget _buildInvoiceStream(String tenantId) {
    return Consumer<InvoiceProvider>(
      builder: (context, invoiceProvider, _) {
        return StreamBuilder<List<Invoice>>(
          stream: invoiceProvider.getInvoicesStream(tenantId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading invoices',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final allInvoices = snapshot.data ?? [];
            final filteredInvoices = _filterInvoices(allInvoices);

            if (allInvoices.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No invoices yet',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the scan tab to scan your first invoice',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (filteredInvoices.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No invoices found',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your search or filters',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                // Refresh logic would go here
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredInvoices.length,
                itemBuilder: (context, index) {
                  final invoice = filteredInvoices[index];
                  return EnhancedInvoiceCard(
                    invoice: invoice,
                    onTap: () => _showInvoiceDetails(context, invoice),
                    onEdit: () => _editInvoice(context, invoice),
                    onTogglePayment: () => _togglePaymentStatus(context, invoice),
                    onDelete: () => _deleteInvoice(context, invoice),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  List<Invoice> _filterInvoices(List<Invoice> invoices) {
    return invoices.where((invoice) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final supplierName = (invoice.extractedData?.supplierName ?? 
                             invoice.extractedData?.vendorName ?? '').toLowerCase();
        final invoiceNumber = (invoice.extractedData?.invoiceNumber ?? 
                              invoice.extractedData?.invoiceId ?? '').toLowerCase();
        
        if (!supplierName.contains(query) && !invoiceNumber.contains(query)) {
          return false;
        }
      }

      // Date range filter
      if (_startDate != null && _endDate != null) {
        final invoiceDate = invoice.createdAt;
        if (invoiceDate.isBefore(_startDate!) || invoiceDate.isAfter(_endDate!.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // Status filter
      if (_filterStatus != 'all') {
        if (_filterStatus == 'paid' && !(invoice.isPaid ?? false)) {
          return false;
        }
        if (_filterStatus == 'unpaid' && (invoice.isPaid ?? false)) {
          return false;
        }
        if (_filterStatus != 'paid' && _filterStatus != 'unpaid') {
          if (invoice.status.toString().split('.').last != _filterStatus) {
            return false;
          }
        }
      }

      return true;
    }).toList();
  }

  void _showInvoiceDetails(BuildContext context, Invoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => InvoiceDetailsSheet(invoice: invoice),
    );
  }

  void _editInvoice(BuildContext context, Invoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditInvoiceSheet(invoice: invoice),
    );
  }

  void _togglePaymentStatus(BuildContext context, Invoice invoice) async {
    final newStatus = !(invoice.isPaid ?? false);
    
    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(invoice.tenantId)
          .collection('invoices')
          .doc(invoice.id)
          .update({
        'isPaid': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus ? 'Invoice marked as paid' : 'Invoice marked as unpaid',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating payment status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteInvoice(BuildContext context, Invoice invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure you want to delete this invoice? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final invoiceProvider = Provider.of<InvoiceProvider>(
                context,
                listen: false,
              );
              final success = await invoiceProvider.deleteInvoice(invoice);
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      invoiceProvider.errorMessage ?? 'Failed to delete invoice',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invoice deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class EnhancedInvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onTogglePayment;
  final VoidCallback onDelete;

  const EnhancedInvoiceCard({
    super.key,
    required this.invoice,
    required this.onTap,
    required this.onEdit,
    required this.onTogglePayment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final isPaid = invoice.isPaid ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.extractedData?.supplierName ?? 
                          invoice.extractedData?.vendorName ?? 
                          'Processing...',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dateFormat.format(invoice.createdAt)} • ${timeFormat.format(invoice.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(status: invoice.status),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Amount and Payment Status Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (invoice.extractedData?.netAmount != null || 
                            invoice.extractedData?.totalAmount != null)
                          Text(
                            '₹${(invoice.extractedData?.netAmount ?? invoice.extractedData?.totalAmount)!.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        if (invoice.extractedData?.invoiceNumber != null ||
                            invoice.extractedData?.invoiceId != null)
                          Text(
                            'Invoice: ${invoice.extractedData?.invoiceNumber ?? invoice.extractedData?.invoiceId}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Payment Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPaid ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPaid ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPaid ? Icons.check_circle : Icons.pending,
                          size: 16,
                          color: isPaid ? Colors.green[700] : Colors.red[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPaid ? 'Paid' : 'Unpaid',
                          style: TextStyle(
                            color: isPaid ? Colors.green[700] : Colors.red[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onTogglePayment,
                      icon: Icon(
                        isPaid ? Icons.close : Icons.check,
                        size: 16,
                      ),
                      label: Text(isPaid ? 'Mark Unpaid' : 'Mark Paid'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPaid ? Colors.orange : Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final InvoiceStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case InvoiceStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        icon = Icons.schedule;
        break;
      case InvoiceStatus.processing:
        color = Colors.blue;
        label = 'Processing';
        icon = Icons.sync;
        break;
      case InvoiceStatus.completed:
        color = Colors.green;
        label = 'Completed';
        icon = Icons.check_circle;
        break;
      case InvoiceStatus.failed:
        color = Colors.red;
        label = 'Failed';
        icon = Icons.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class InvoiceDetailsSheet extends StatelessWidget {
  final Invoice invoice;

  const InvoiceDetailsSheet({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Invoice Details',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        StatusChip(status: invoice.status),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    if (invoice.extractedData != null) ...[
                      _buildDetailCard(
                        'Invoice Parties',
                        [
                          _buildDetailRow('From (Supplier)', invoice.extractedData?.supplierName ?? invoice.extractedData?.vendorName),
                          _buildDetailRow('To (Customer)', invoice.extractedData?.customerName ?? 'Snowy Milk Parlour'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDetailCard(
                        'Invoice Details',
                        [
                          _buildDetailRow('Invoice No', invoice.extractedData?.invoiceNumber ?? invoice.extractedData?.invoiceId),
                          _buildDetailRow('Bill Date', invoice.extractedData?.billDate ?? invoice.extractedData?.invoiceDate),
                          _buildDetailRow('Due Date', invoice.extractedData?.dueDate),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDetailCard(
                        'Quantity Summary',
                        [
                          _buildDetailRow(
                            'Total Cases',
                            invoice.extractedData?.totalCases != null
                                ? '${invoice.extractedData!.totalCases}'
                                : null,
                          ),
                          _buildDetailRow(
                            'Total Pieces',
                            invoice.extractedData?.totalPieces != null
                                ? '${invoice.extractedData!.totalPieces}'
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDetailCard(
                        'Amount Details',
                        [
                          _buildDetailRow(
                            'Gross Amount',
                            invoice.extractedData?.grossAmount != null
                                ? '₹${invoice.extractedData!.grossAmount!.toStringAsFixed(2)}'
                                : (invoice.extractedData?.subTotal != null
                                    ? '₹${invoice.extractedData!.subTotal!.toStringAsFixed(2)}'
                                    : null),
                          ),
                          _buildDetailRow(
                            'GST Amount',
                            invoice.extractedData?.gstAmount != null
                                ? '₹${invoice.extractedData!.gstAmount!.toStringAsFixed(2)}'
                                : (invoice.extractedData?.taxAmount != null
                                    ? '₹${invoice.extractedData!.taxAmount!.toStringAsFixed(2)}'
                                    : null),
                          ),
                          _buildDetailRow(
                            'Net Amount',
                            invoice.extractedData?.netAmount != null
                                ? '₹${invoice.extractedData!.netAmount!.toStringAsFixed(2)}'
                                : (invoice.extractedData?.totalAmount != null
                                    ? '₹${invoice.extractedData!.totalAmount!.toStringAsFixed(2)}'
                                    : null),
                            isTotal: true,
                          ),
                        ],
                      ),
                    ] else ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                'Processing invoice data...',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    _buildDetailCard(
                      'Metadata',
                      [
                        _buildDetailRow(
                          'Scanned',
                          '${dateFormat.format(invoice.createdAt)} at ${timeFormat.format(invoice.createdAt)}',
                        ),
                        _buildDetailRow(
                          'Last Updated',
                          '${dateFormat.format(invoice.updatedAt)} at ${timeFormat.format(invoice.updatedAt)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: isTotal ? Colors.green[700] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EditInvoiceSheet extends StatefulWidget {
  final Invoice invoice;

  const EditInvoiceSheet({super.key, required this.invoice});

  @override
  State<EditInvoiceSheet> createState() => _EditInvoiceSheetState();
}

class _EditInvoiceSheetState extends State<EditInvoiceSheet> {
  late TextEditingController _supplierController;
  late TextEditingController _customerController;
  late TextEditingController _invoiceNumberController;
  late TextEditingController _grossAmountController;
  late TextEditingController _gstAmountController;
  late TextEditingController _netAmountController;
  late bool _isPaid;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _supplierController = TextEditingController(
      text: widget.invoice.extractedData?.supplierName ?? 
            widget.invoice.extractedData?.vendorName ?? '',
    );
    _customerController = TextEditingController(
      text: widget.invoice.extractedData?.customerName ?? '',
    );
    _invoiceNumberController = TextEditingController(
      text: widget.invoice.extractedData?.invoiceNumber ?? 
            widget.invoice.extractedData?.invoiceId ?? '',
    );
    _grossAmountController = TextEditingController(
      text: (widget.invoice.extractedData?.grossAmount ?? 
             widget.invoice.extractedData?.subTotal ?? 0.0).toString(),
    );
    _gstAmountController = TextEditingController(
      text: (widget.invoice.extractedData?.gstAmount ?? 
             widget.invoice.extractedData?.taxAmount ?? 0.0).toString(),
    );
    _netAmountController = TextEditingController(
      text: (widget.invoice.extractedData?.netAmount ?? 
             widget.invoice.extractedData?.totalAmount ?? 0.0).toString(),
    );
    _isPaid = widget.invoice.isPaid ?? false;
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _customerController.dispose();
    _invoiceNumberController.dispose();
    _grossAmountController.dispose();
    _gstAmountController.dispose();
    _netAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Edit Invoice',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveChanges,
                      child: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                    ),
                  ],
                ),
              ),
              
              const Divider(),
              
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Payment Status
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              _isPaid ? Icons.check_circle : Icons.pending,
                              color: _isPaid ? Colors.green[700] : Colors.red[700],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Payment Status',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            Switch(
                              value: _isPaid,
                              onChanged: (value) {
                                setState(() {
                                  _isPaid = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Invoice Parties
                    _buildSectionCard(
                      'Invoice Parties',
                      [
                        _buildTextField(
                          controller: _supplierController,
                          label: 'Supplier/Vendor Name',
                          icon: Icons.business,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _customerController,
                          label: 'Customer Name',
                          icon: Icons.person,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Invoice Details
                    _buildSectionCard(
                      'Invoice Details',
                      [
                        _buildTextField(
                          controller: _invoiceNumberController,
                          label: 'Invoice Number',
                          icon: Icons.receipt_long,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Amount Details
                    _buildSectionCard(
                      'Amount Details',
                      [
                        _buildTextField(
                          controller: _grossAmountController,
                          label: 'Gross Amount (₹)',
                          icon: Icons.currency_rupee,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _gstAmountController,
                          label: 'GST Amount (₹)',
                          icon: Icons.percent,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _netAmountController,
                          label: 'Net Amount (₹)',
                          icon: Icons.account_balance_wallet,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _saveChanges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Update the invoice data
      final updatedData = {
        'isPaid': _isPaid,
        'extractedData': {
          ...widget.invoice.extractedData?.toJson() ?? {},
          'supplierName': _supplierController.text.trim(),
          'customerName': _customerController.text.trim(),
          'invoiceNumber': _invoiceNumberController.text.trim(),
          'grossAmount': double.tryParse(_grossAmountController.text) ?? 0.0,
          'gstAmount': double.tryParse(_gstAmountController.text) ?? 0.0,
          'netAmount': double.tryParse(_netAmountController.text) ?? 0.0,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(widget.invoice.tenantId)
          .collection('invoices')
          .doc(widget.invoice.id)
          .update(updatedData);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
