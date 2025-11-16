import 'package:cloud_firestore/cloud_firestore.dart';

class Invoice {
  final String id;
  final String tenantId;
  final String imageUrl;
  final DateTime dateTime;
  final InvoiceStatus status;
  final InvoiceData? extractedData;
  final DateTime createdAt;
  final DateTime updatedAt;

  Invoice({
    required this.id,
    required this.tenantId,
    required this.imageUrl,
    required this.dateTime,
    required this.status,
    this.extractedData,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] ?? '',
      tenantId: json['tenantId'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      dateTime: (json['dateTime'] as Timestamp).toDate(),
      status: InvoiceStatus.values.firstWhere(
        (e) => e.toString() == 'InvoiceStatus.${json['status']}',
        orElse: () => InvoiceStatus.pending,
      ),
      extractedData: json['extractedData'] != null
          ? InvoiceData.fromJson(json['extractedData'])
          : null,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'imageUrl': imageUrl,
      'dateTime': Timestamp.fromDate(dateTime),
      'status': status.toString().split('.').last,
      'extractedData': extractedData?.toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Invoice copyWith({
    String? id,
    String? tenantId,
    String? imageUrl,
    DateTime? dateTime,
    InvoiceStatus? status,
    InvoiceData? extractedData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      imageUrl: imageUrl ?? this.imageUrl,
      dateTime: dateTime ?? this.dateTime,
      status: status ?? this.status,
      extractedData: extractedData ?? this.extractedData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum InvoiceStatus {
  pending,
  processing,
  completed,
  failed,
}

class InvoiceData {
  // Legacy fields for backward compatibility
  final String? vendorName;
  final String? customerName;
  final String? invoiceId;
  final String? invoiceDate;
  final String? dueDate;
  final double? totalAmount;
  final double? subTotal;
  final double? taxAmount;
  
  // New specific fields for ice cream parlour business
  final String? supplierName;    // From whom (e.g., Aravindhan Agency)
  final String? billDate;        // Invoice Date
  final String? invoiceNumber;   // Invoice Number
  final int? totalCases;         // Total Cases
  final int? totalPieces;        // Total Pieces  
  final double? grossAmount;     // Gross Amount
  final double? gstAmount;       // GST Amount
  final double? netAmount;       // Net Amount
  
  final List<InvoiceItem>? items;
  final Map<String, dynamic>? extractedFields;

  InvoiceData({
    // Legacy fields
    this.vendorName,
    this.customerName,
    this.invoiceId,
    this.invoiceDate,
    this.dueDate,
    this.totalAmount,
    this.subTotal,
    this.taxAmount,
    // New fields
    this.supplierName,
    this.billDate,
    this.invoiceNumber,
    this.totalCases,
    this.totalPieces,
    this.grossAmount,
    this.gstAmount,
    this.netAmount,
    this.items,
    this.extractedFields,
  });

  factory InvoiceData.fromJson(Map<String, dynamic> json) {
    return InvoiceData(
      // Legacy fields
      vendorName: json['vendorName'],
      customerName: json['customerName'],
      invoiceId: json['invoiceId'],
      invoiceDate: json['invoiceDate'],
      dueDate: json['dueDate'],
      totalAmount: json['totalAmount']?.toDouble(),
      subTotal: json['subTotal']?.toDouble(),
      taxAmount: json['taxAmount']?.toDouble(),
      // New fields
      supplierName: json['supplierName'],
      billDate: json['billDate'],
      invoiceNumber: json['invoiceNumber'],
      totalCases: json['totalCases']?.toInt(),
      totalPieces: json['totalPieces']?.toInt(),
      grossAmount: json['grossAmount']?.toDouble(),
      gstAmount: json['gstAmount']?.toDouble(),
      netAmount: json['netAmount']?.toDouble(),
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => InvoiceItem.fromJson(item))
              .toList()
          : null,
      extractedFields: json['extractedFields'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Legacy fields
      'vendorName': vendorName,
      'customerName': customerName,
      'invoiceId': invoiceId,
      'invoiceDate': invoiceDate,
      'dueDate': dueDate,
      'totalAmount': totalAmount,
      'subTotal': subTotal,
      'taxAmount': taxAmount,
      // New fields
      'supplierName': supplierName,
      'billDate': billDate,
      'invoiceNumber': invoiceNumber,
      'totalCases': totalCases,
      'totalPieces': totalPieces,
      'grossAmount': grossAmount,
      'gstAmount': gstAmount,
      'netAmount': netAmount,
      'items': items?.map((item) => item.toJson()).toList(),
      'extractedFields': extractedFields,
    };
  }
}

class InvoiceItem {
  final String? description;
  final double? quantity;
  final double? unitPrice;
  final double? totalPrice;

  InvoiceItem({
    this.description,
    this.quantity,
    this.unitPrice,
    this.totalPrice,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      description: json['description'],
      quantity: json['quantity']?.toDouble(),
      unitPrice: json['unitPrice']?.toDouble(),
      totalPrice: json['totalPrice']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }
}
