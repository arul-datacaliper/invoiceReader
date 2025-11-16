import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceHistoryItem {
  final String invoiceId;
  final double quantity;
  final double unitPrice;
  final DateTime addedAt;

  InvoiceHistoryItem({
    required this.invoiceId,
    required this.quantity,
    required this.unitPrice,
    required this.addedAt,
  });

  factory InvoiceHistoryItem.fromJson(Map<String, dynamic> json) {
    return InvoiceHistoryItem(
      invoiceId: json['invoiceId'] ?? '',
      quantity: json['quantity']?.toDouble() ?? 0.0,
      unitPrice: json['unitPrice']?.toDouble() ?? 0.0,
      addedAt: (json['addedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoiceId': invoiceId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }
}

class InventoryItem {
  final String id;
  final String tenantId;
  final String invoiceId; // Original invoice that created this item
  final String? lastInvoiceId; // Last invoice that updated this item
  final String itemName;
  final String? itemCode;
  final int piecesCount;
  final double? mrp;
  final double? rate;
  final double? discountAmount;
  final double? totalAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final String? unit; // e.g., "ML", "KG", "PCS"
  final double? quantity; // Total quantity across all invoices
  final List<InvoiceHistoryItem>? invoiceHistory; // Track all invoices that added to this item

  InventoryItem({
    required this.id,
    required this.tenantId,
    required this.invoiceId,
    this.lastInvoiceId,
    required this.itemName,
    this.itemCode,
    required this.piecesCount,
    this.mrp,
    this.rate,
    this.discountAmount,
    this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.unit,
    this.quantity,
    this.invoiceHistory,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    List<InvoiceHistoryItem>? historyItems;
    if (json['invoiceHistory'] != null) {
      historyItems = (json['invoiceHistory'] as List)
          .map((item) => InvoiceHistoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return InventoryItem(
      id: json['id'] ?? '',
      tenantId: json['tenantId'] ?? '',
      invoiceId: json['invoiceId'] ?? '',
      lastInvoiceId: json['lastInvoiceId'],
      itemName: json['itemName'] ?? '',
      itemCode: json['itemCode'],
      piecesCount: json['piecesCount']?.toInt() ?? 0,
      mrp: json['mrp']?.toDouble(),
      rate: json['rate']?.toDouble(),
      discountAmount: json['discountAmount']?.toDouble(),
      totalAmount: json['totalAmount']?.toDouble(),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      description: json['description'],
      unit: json['unit'],
      quantity: json['quantity']?.toDouble(),
      invoiceHistory: historyItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'invoiceId': invoiceId,
      'lastInvoiceId': lastInvoiceId,
      'itemName': itemName,
      'itemCode': itemCode,
      'piecesCount': piecesCount,
      'mrp': mrp,
      'rate': rate,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'description': description,
      'unit': unit,
      'quantity': quantity,
      'invoiceHistory': invoiceHistory?.map((item) => item.toJson()).toList(),
    };
  }

  InventoryItem copyWith({
    String? id,
    String? tenantId,
    String? invoiceId,
    String? lastInvoiceId,
    String? itemName,
    String? itemCode,
    int? piecesCount,
    double? mrp,
    double? rate,
    double? discountAmount,
    double? totalAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    String? unit,
    double? quantity,
    List<InvoiceHistoryItem>? invoiceHistory,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      invoiceId: invoiceId ?? this.invoiceId,
      lastInvoiceId: lastInvoiceId ?? this.lastInvoiceId,
      itemName: itemName ?? this.itemName,
      itemCode: itemCode ?? this.itemCode,
      piecesCount: piecesCount ?? this.piecesCount,
      mrp: mrp ?? this.mrp,
      rate: rate ?? this.rate,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      invoiceHistory: invoiceHistory ?? this.invoiceHistory,
    );
  }
}

class InventoryService {
  static const String collectionName = 'inventory';

  // Add inventory items from an invoice
  static Future<bool> addInventoryItems(
    String tenantId,
    String invoiceId,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final now = DateTime.now();

      for (final item in items) {
        final inventoryItem = InventoryItem(
          id: firestore.collection('temp').doc().id, // Generate unique ID
          tenantId: tenantId,
          invoiceId: invoiceId,
          itemName: item['description'] ?? 'Unknown Item',
          itemCode: _extractItemCode(item['description']),
          piecesCount: _extractPiecesCount(item),
          mrp: item['mrp']?.toDouble(),
          rate: item['unitPrice']?.toDouble(),
          discountAmount: item['discountAmount']?.toDouble(),
          totalAmount: item['totalPrice']?.toDouble(),
          createdAt: now,
          updatedAt: now,
          description: item['description'],
          unit: _extractUnit(item['description']),
          quantity: item['quantity']?.toDouble(),
        );

        final docRef = firestore
            .collection('tenants')
            .doc(tenantId)
            .collection(collectionName)
            .doc(inventoryItem.id);

        batch.set(docRef, inventoryItem.toJson());
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error adding inventory items: $e');
      return false;
    }
  }

  // Get inventory items for a tenant
  static Stream<List<InventoryItem>> getInventoryStream(String tenantId) {
    return FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection(collectionName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InventoryItem.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  // Get inventory items for a specific invoice
  static Stream<List<InventoryItem>> getInventoryByInvoiceStream(
    String tenantId,
    String invoiceId,
  ) {
    return FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection(collectionName)
        .where('invoiceId', isEqualTo: invoiceId)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InventoryItem.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  // Extract item code from description (e.g., "AMUL001" from "AMUL ICE CREAM 100ML")
  static String? _extractItemCode(String? description) {
    if (description == null) return null;
    
    // Look for patterns like alphanumeric codes
    final regex = RegExp(r'\b[A-Z]{2,}[0-9]{1,}\b');
    final match = regex.firstMatch(description.toUpperCase());
    return match?.group(0);
  }

  // Extract pieces count from item data
  static int _extractPiecesCount(Map<String, dynamic> item) {
    // Try to get from quantity first
    if (item['quantity'] != null) {
      return item['quantity'].toInt();
    }
    
    // Look for pieces in description
    final description = item['description']?.toString().toLowerCase() ?? '';
    final regex = RegExp(r'\((\d+)\s*(?:nos?|pieces?|pcs?)\)');
    final match = regex.firstMatch(description);
    
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 1;
    }
    
    return 1; // Default to 1 piece
  }

  // Extract unit from description (e.g., "ML", "KG", "PCS")
  static String? _extractUnit(String? description) {
    if (description == null) return null;
    
    final upperDesc = description.toUpperCase();
    
    // Common units
    if (upperDesc.contains('ML')) return 'ML';
    if (upperDesc.contains('KG')) return 'KG';
    if (upperDesc.contains('GM') || upperDesc.contains('GRAM')) return 'GM';
    if (upperDesc.contains('LTR') || upperDesc.contains('LITER')) return 'LTR';
    if (upperDesc.contains('PCS') || upperDesc.contains('PIECE')) return 'PCS';
    
    return 'PCS'; // Default unit
  }
}
