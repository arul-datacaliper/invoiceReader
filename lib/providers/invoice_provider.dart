import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/invoice.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/azure_function_service.dart';

class InvoiceProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final AzureFunctionService _azureFunctionService = AzureFunctionService();

  List<Invoice> _invoices = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Invoice> get invoices => _invoices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get invoices stream
  Stream<List<Invoice>> getInvoicesStream(String tenantId) {
    return _firestoreService.getInvoicesStream(tenantId);
  }

  // Process new invoice
  Future<bool> processInvoice({
    required File imageFile,
    required String tenantId,
  }) async {
    try {
      print('🔵 [InvoiceProvider] Starting invoice processing...');
      print('🔵 [InvoiceProvider] TenantId: $tenantId');
      print('🔵 [InvoiceProvider] Image file: ${imageFile.path}');
      
      _setLoading(true);
      _clearError();

      // Generate invoice ID
      final invoiceId = DateTime.now().millisecondsSinceEpoch.toString();
      print('🔵 [InvoiceProvider] Generated invoiceId: $invoiceId');

      // Upload image to Firebase Storage
      print('🔵 [InvoiceProvider] Starting image upload...');
      final downloadUrl = await _storageService.uploadInvoiceImage(
        imageFile: imageFile,
        tenantId: tenantId,
        invoiceId: invoiceId,
      );
      print('🟢 [InvoiceProvider] Image uploaded successfully: $downloadUrl');

      // Create invoice document in Firestore
      print('🔵 [InvoiceProvider] Creating invoice document...');
      final invoice = Invoice(
        id: invoiceId,
        tenantId: tenantId,
        imageUrl: downloadUrl,
        dateTime: DateTime.now(),
        status: InvoiceStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestoreService.createInvoice(invoice);
      print('🟢 [InvoiceProvider] Invoice document created in Firestore');

      // Call Azure Function for processing (or use mock for development)
      try {
        print('🔵 [InvoiceProvider] Calling Azure Function...');
        await _azureFunctionService.processInvoice(
          tenantId: tenantId,
          invoiceId: invoiceId,
          imageUrl: downloadUrl,
        );
        print('🟢 [InvoiceProvider] Azure Function called successfully');
      } catch (e) {
        // If Azure Function is not available, use mock processing
        print('🟡 [InvoiceProvider] Azure Function not available, using mock processing: $e');
        await _azureFunctionService.mockProcessInvoice(
          tenantId: tenantId,
          invoiceId: invoiceId,
          imageUrl: downloadUrl,
        );
        print('🟢 [InvoiceProvider] Mock processing completed');
      }

      print('🎉 [InvoiceProvider] Invoice processing completed successfully!');
      return true;
    } catch (e, stackTrace) {
      print('🔴 [InvoiceProvider] Invoice processing failed: $e');
      print('🔴 [InvoiceProvider] Stack trace: $stackTrace');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
      print('🔵 [InvoiceProvider] Processing finished, loading state reset');
    }
  }

  // Update invoice status
  Future<void> updateInvoiceStatus({
    required String tenantId,
    required String invoiceId,
    required InvoiceStatus status,
    InvoiceData? extractedData,
  }) async {
    try {
      final invoice = await _firestoreService.getInvoice(tenantId, invoiceId);
      if (invoice != null) {
        final updatedInvoice = invoice.copyWith(
          status: status,
          extractedData: extractedData ?? invoice.extractedData,
          updatedAt: DateTime.now(),
        );
        await _firestoreService.updateInvoice(updatedInvoice);
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Delete invoice
  Future<bool> deleteInvoice(Invoice invoice) async {
    try {
      _setLoading(true);
      _clearError();

      // Delete from Storage
      await _storageService.deleteInvoiceImage(invoice.imageUrl);

      // Delete from Firestore
      await _firestoreService.deleteInvoice(invoice.tenantId, invoice.id);

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Watch invoice status changes
  Stream<Invoice> watchInvoiceStatus(String tenantId, String invoiceId) {
    return _firestoreService.watchInvoiceStatus(tenantId, invoiceId);
  }

  // Get daily report
  Future<Map<String, double>> getDailyReport({
    required String tenantId,
    required DateTime date,
  }) async {
    try {
      return await _firestoreService.getDailyReport(
        tenantId: tenantId,
        date: date,
      );
    } catch (e) {
      _setError(e.toString());
      return {};
    }
  }

  // Get monthly report
  Future<Map<String, double>> getMonthlyReport({
    required String tenantId,
    required int year,
    required int month,
  }) async {
    try {
      return await _firestoreService.getMonthlyReport(
        tenantId: tenantId,
        year: year,
        month: month,
      );
    } catch (e) {
      _setError(e.toString());
      return {};
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }
}
