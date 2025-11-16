import 'package:flutter/material.dart';
import '../models/inventory.dart';

class InventoryProvider extends ChangeNotifier {
  List<InventoryItem> _inventoryItems = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<InventoryItem> get inventoryItems => _inventoryItems;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get inventory items for a tenant
  void getInventoryItems(String tenantId) {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    InventoryService.getInventoryStream(tenantId).listen(
      (items) {
        _inventoryItems = items;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  // Get inventory items for a specific invoice
  void getInventoryByInvoice(String tenantId, String invoiceId) {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    InventoryService.getInventoryByInvoiceStream(tenantId, invoiceId).listen(
      (items) {
        _inventoryItems = items;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  // Add inventory items from an invoice
  Future<bool> addInventoryItemsFromInvoice(
    String tenantId,
    String invoiceId,
    List<Map<String, dynamic>> items,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final success = await InventoryService.addInventoryItems(
      tenantId,
      invoiceId,
      items,
    );

    _isLoading = false;
    if (!success) {
      _errorMessage = 'Failed to add inventory items';
    }
    notifyListeners();

    return success;
  }

  // Clear inventory items
  void clearInventory() {
    _inventoryItems = [];
    _errorMessage = null;
    notifyListeners();
  }

  // Filter inventory items by item name or code
  List<InventoryItem> filterItems(String query) {
    if (query.isEmpty) return _inventoryItems;
    
    final lowercaseQuery = query.toLowerCase();
    return _inventoryItems.where((item) {
      return item.itemName.toLowerCase().contains(lowercaseQuery) ||
             (item.itemCode?.toLowerCase().contains(lowercaseQuery) ?? false) ||
             (item.description?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  // Group items by item name for summary
  Map<String, List<InventoryItem>> groupItemsByName() {
    final Map<String, List<InventoryItem>> grouped = {};
    
    for (final item in _inventoryItems) {
      final key = item.itemName;
      if (grouped.containsKey(key)) {
        grouped[key]!.add(item);
      } else {
        grouped[key] = [item];
      }
    }
    
    return grouped;
  }

  // Get total inventory value
  double getTotalInventoryValue() {
    return _inventoryItems.fold(
      0.0,
      (total, item) => total + (item.totalAmount ?? 0.0),
    );
  }

  // Get total pieces count
  int getTotalPiecesCount() {
    return _inventoryItems.fold(
      0,
      (total, item) => total + item.piecesCount,
    );
  }
}
