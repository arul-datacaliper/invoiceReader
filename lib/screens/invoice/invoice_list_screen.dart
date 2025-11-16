import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../models/invoice.dart';

class InvoiceListScreen extends StatelessWidget {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final userDocument = authProvider.userDocument;

    // Check if user is authenticated but doesn't have a user document
    if (user != null && userDocument == null) {
      return const Center(
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
      );
    }

    final tenantId = userDocument?.tenantId;

    if (tenantId == null) {
      return const Center(
        child: Text('Please login to view invoices'),
      );
    }

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

            final invoices = snapshot.data ?? [];

            if (invoices.isEmpty) {
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
                      'Tap the + button to scan your first invoice',
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
                itemCount: invoices.length,
                itemBuilder: (context, index) {
                  final invoice = invoices[index];
                  return InvoiceCard(
                    invoice: invoice,
                    onTap: () => _showInvoiceDetails(context, invoice),
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

  void _showInvoiceDetails(BuildContext context, Invoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => InvoiceDetailsSheet(invoice: invoice),
    );
  }

  void _deleteInvoice(BuildContext context, Invoice invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure you want to delete this invoice?'),
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

class InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const InvoiceCard({
    super.key,
    required this.invoice,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.extractedData?.supplierName ?? invoice.extractedData?.vendorName ?? 'Processing...',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dateFormat.format(invoice.dateTime)} • ${timeFormat.format(invoice.dateTime)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(status: invoice.status),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Show net amount or fallback to total amount
              if (invoice.extractedData?.netAmount != null || invoice.extractedData?.totalAmount != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Net Amount: ₹${(invoice.extractedData?.netAmount ?? invoice.extractedData?.totalAmount)!.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
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
