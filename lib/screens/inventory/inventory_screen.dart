import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/inventory.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = '';
  bool _showGrouped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInventory();
    });
  }

  void _loadInventory() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tenantId = authProvider.userDocument?.tenantId;
    
    if (tenantId != null) {
      Provider.of<InventoryProvider>(context, listen: false)
          .getInventoryItems(tenantId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final userDocument = authProvider.userDocument;

    if (user == null || userDocument == null) {
      return const Center(
        child: Text('Please login to view inventory'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: Icon(_showGrouped ? Icons.list : Icons.group),
            onPressed: () {
              setState(() {
                _showGrouped = !_showGrouped;
              });
            },
            tooltip: _showGrouped ? 'Show All Items' : 'Group by Item',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInventory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Summary cards
          _buildSummaryCards(),

          // Inventory list
          Expanded(
            child: Consumer<InventoryProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null) {
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
                          'Error loading inventory',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadInventory,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final filteredItems = provider.filterItems(_searchQuery);

                if (filteredItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No items found for "$_searchQuery"'
                              : 'No inventory items yet',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try adjusting your search query'
                              : 'Items will appear here after processing invoices',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return _showGrouped
                    ? _buildGroupedList(provider, filteredItems)
                    : _buildInventoryList(filteredItems);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final totalValue = provider.getTotalInventoryValue();
        final totalPieces = provider.getTotalPiecesCount();
        final totalItems = provider.inventoryItems.length;

        return Container(
          height: 100,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Value',
                  '₹${totalValue.toStringAsFixed(2)}',
                  Icons.currency_rupee,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Total Pieces',
                  totalPieces.toString(),
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Total Items',
                  totalItems.toString(),
                  Icons.list_alt,
                  Colors.orange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryList(List<InventoryItem> items) {
    return RefreshIndicator(
      onRefresh: () async => _loadInventory(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return InventoryItemCard(item: item);
        },
      ),
    );
  }

  Widget _buildGroupedList(InventoryProvider provider, List<InventoryItem> filteredItems) {
    // Group filtered items
    final grouped = <String, List<InventoryItem>>{};
    for (final item in filteredItems) {
      final key = item.itemName;
      if (grouped.containsKey(key)) {
        grouped[key]!.add(item);
      } else {
        grouped[key] = [item];
      }
    }

    return RefreshIndicator(
      onRefresh: () async => _loadInventory(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final itemName = grouped.keys.elementAt(index);
          final items = grouped[itemName]!;
          return GroupedInventoryCard(itemName: itemName, items: items);
        },
      ),
    );
  }
}

class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;

  const InventoryItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showItemDetails(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.itemName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (item.itemCode != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        item.itemCode!,
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow('Pieces', '${item.piecesCount}'),
                  ),
                  if (item.unit != null)
                    Expanded(
                      child: _buildInfoRow('Unit', item.unit!),
                    ),
                ],
              ),
              
              Row(
                children: [
                  if (item.mrp != null)
                    Expanded(
                      child: _buildInfoRow('MRP', '₹${item.mrp!.toStringAsFixed(2)}'),
                    ),
                  if (item.rate != null)
                    Expanded(
                      child: _buildInfoRow('Rate', '₹${item.rate!.toStringAsFixed(2)}'),
                    ),
                ],
              ),
              
              Row(
                children: [
                  if (item.discountAmount != null)
                    Expanded(
                      child: _buildInfoRow('Discount', '₹${item.discountAmount!.toStringAsFixed(2)}'),
                    ),
                  if (item.totalAmount != null)
                    Expanded(
                      child: _buildInfoRow('Total', '₹${item.totalAmount!.toStringAsFixed(2)}', isTotal: true),
                    ),
                ],
              ),
              
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Added: ${dateFormat.format(item.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                  if (item.invoiceHistory != null && item.invoiceHistory!.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${item.invoiceHistory!.length} invoices',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ItemDetailsSheet(item: item),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green[700] : null,
            ),
          ),
        ],
      ),
    );
  }
}

class GroupedInventoryCard extends StatelessWidget {
  final String itemName;
  final List<InventoryItem> items;

  const GroupedInventoryCard({
    super.key,
    required this.itemName,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final totalPieces = items.fold(0, (sum, item) => sum + item.piecesCount);
    final totalValue = items.fold(0.0, (sum, item) => sum + (item.totalAmount ?? 0.0));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          itemName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Text('${items.length} entries • $totalPieces pieces • ₹${totalValue.toStringAsFixed(2)}'),
        children: items.map((item) => InventoryItemCard(item: item)).toList(),
      ),
    );
  }
}

class ItemDetailsSheet extends StatelessWidget {
  final InventoryItem item;

  const ItemDetailsSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (item.itemCode != null)
                            Text(
                              'Code: ${item.itemCode}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
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
                    // Current Summary
                    _buildSummarySection(context),
                    
                    const SizedBox(height: 24),
                    
                    // Invoice History
                    if (item.invoiceHistory != null && item.invoiceHistory!.isNotEmpty) ...[
                      Text(
                        'Invoice History',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      
                      ...item.invoiceHistory!.map((history) => _buildHistoryCard(
                        context, 
                        history, 
                        dateFormat,
                      )).toList(),
                    ] else ...[
                      Text(
                        'No Invoice History Available',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem('Total Pieces', item.piecesCount.toString()),
                ),
                if (item.quantity != null)
                  Expanded(
                    child: _buildSummaryItem('Total Quantity', item.quantity!.toStringAsFixed(1)),
                  ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                if (item.mrp != null)
                  Expanded(
                    child: _buildSummaryItem('Current MRP', '₹${item.mrp!.toStringAsFixed(2)}'),
                  ),
                if (item.rate != null)
                  Expanded(
                    child: _buildSummaryItem('Current Rate', '₹${item.rate!.toStringAsFixed(2)}'),
                  ),
              ],
            ),
            
            if (item.totalAmount != null) ...[
              const SizedBox(height: 8),
              _buildSummaryItem(
                'Total Value',
                '₹${item.totalAmount!.toStringAsFixed(2)}',
                isHighlighted: true,
              ),
            ],
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'First added: ${DateFormat('MMM dd, yyyy').format(item.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ),
              ],
            ),
            
            if (item.lastInvoiceId != null && item.lastInvoiceId != item.invoiceId) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.update, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last updated: ${DateFormat('MMM dd, yyyy').format(item.updatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isHighlighted = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlighted ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: isHighlighted ? Colors.green[700] : null,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(BuildContext context, InvoiceHistoryItem history, DateFormat dateFormat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Invoice icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.receipt_long,
                color: Colors.blue[700],
                size: 20,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice: ${history.invoiceId.substring(0, 8)}...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(history.addedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            
            // Quantity and price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Qty: ${history.quantity.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${history.unitPrice.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
