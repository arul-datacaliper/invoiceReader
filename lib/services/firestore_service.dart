import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create invoice document
  Future<void> createInvoice(Invoice invoice) async {
    try {
      await _firestore
          .collection('tenants')
          .doc(invoice.tenantId)
          .collection('invoices')
          .doc(invoice.id)
          .set(invoice.toJson());
    } catch (e) {
      throw Exception('Failed to create invoice: $e');
    }
  }

  // Update invoice
  Future<void> updateInvoice(Invoice invoice) async {
    try {
      await _firestore
          .collection('tenants')
          .doc(invoice.tenantId)
          .collection('invoices')
          .doc(invoice.id)
          .update(invoice.toJson());
    } catch (e) {
      throw Exception('Failed to update invoice: $e');
    }
  }

  // Get invoice by ID
  Future<Invoice?> getInvoice(String tenantId, String invoiceId) async {
    try {
      final doc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('invoices')
          .doc(invoiceId)
          .get();
      
      if (doc.exists) {
        return Invoice.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get invoice: $e');
    }
  }

  // Get invoices stream for a tenant
  Stream<List<Invoice>> getInvoicesStream(String tenantId) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('invoices')
        // Temporarily removed orderBy to avoid index requirement
        // .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final invoices = snapshot.docs
              .map((doc) => Invoice.fromJson(doc.data()))
              .toList();
          
          // Sort in memory as temporary solution
          invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return invoices;
        });
  }

  // Get invoices for a specific date range
  Stream<List<Invoice>> getInvoicesByDateRange({
    required String tenantId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('invoices')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Invoice.fromJson(doc.data()))
            .toList());
  }

  // Get daily report data
  Future<Map<String, double>> getDailyReport({
    required String tenantId,
    required DateTime date,
  }) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('invoices')
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('status', isEqualTo: 'completed')
          .get();

      double totalAmount = 0.0;
      double totalTax = 0.0;
      int invoiceCount = snapshot.docs.length;

      for (final doc in snapshot.docs) {
        final invoice = Invoice.fromJson(doc.data());
        if (invoice.extractedData?.totalAmount != null) {
          totalAmount += invoice.extractedData!.totalAmount!;
        }
        if (invoice.extractedData?.taxAmount != null) {
          totalTax += invoice.extractedData!.taxAmount!;
        }
      }

      return {
        'totalAmount': totalAmount,
        'totalTax': totalTax,
        'invoiceCount': invoiceCount.toDouble(),
      };
    } catch (e) {
      throw Exception('Failed to get daily report: $e');
    }
  }

  // Get monthly report data
  Future<Map<String, double>> getMonthlyReport({
    required String tenantId,
    required int year,
    required int month,
  }) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('invoices')
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .where('status', isEqualTo: 'completed')
          .get();

      double totalAmount = 0.0;
      double totalTax = 0.0;
      int invoiceCount = snapshot.docs.length;

      for (final doc in snapshot.docs) {
        final invoice = Invoice.fromJson(doc.data());
        if (invoice.extractedData?.totalAmount != null) {
          totalAmount += invoice.extractedData!.totalAmount!;
        }
        if (invoice.extractedData?.taxAmount != null) {
          totalTax += invoice.extractedData!.taxAmount!;
        }
      }

      return {
        'totalAmount': totalAmount,
        'totalTax': totalTax,
        'invoiceCount': invoiceCount.toDouble(),
      };
    } catch (e) {
      throw Exception('Failed to get monthly report: $e');
    }
  }

  // Watch invoice status changes
  Stream<Invoice> watchInvoiceStatus(String tenantId, String invoiceId) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('invoices')
        .doc(invoiceId)
        .snapshots()
        .map((doc) => Invoice.fromJson(doc.data()!));
  }

  // Delete invoice
  Future<void> deleteInvoice(String tenantId, String invoiceId) async {
    try {
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('invoices')
          .doc(invoiceId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete invoice: $e');
    }
  }
}
