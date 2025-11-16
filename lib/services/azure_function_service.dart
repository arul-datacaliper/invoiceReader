import 'dart:convert';
import 'package:http/http.dart' as http;

class AzureFunctionService {
  // Your deployed Azure Function App URL
  static const String _defaultBaseUrl = 'https://invoice-processor-func-bybfd4dmfcggfbfy.centralindia-01.azurewebsites.net/api';
  
  final String baseUrl;
  final String? functionKey;

  AzureFunctionService({
    String? baseUrl,
    this.functionKey,
  }) : baseUrl = baseUrl ?? _defaultBaseUrl;

  // Call Azure Function to process invoice
  Future<bool> processInvoice({
    required String tenantId,
    required String invoiceId,
    required String imageUrl,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/ProcessInvoice');
      
      final headers = {
        'Content-Type': 'application/json',
        if (functionKey != null) 'x-functions-key': functionKey!,
      };

      final body = jsonEncode({
        'tenantId': tenantId,
        'invoiceId': invoiceId,
        'imageUrl': imageUrl,
      });

      print('Calling Azure Function: $url');
      print('Request body: $body');

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      print('Azure Function response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] ?? false;
      } else {
        throw Exception('Azure Function call failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Azure Function error: $e');
      throw Exception('Failed to call Azure Function: $e');
    }
  }

  // Health check for Azure Function
  Future<bool> healthCheck() async {
    try {
      final url = Uri.parse('$baseUrl/health');
      
      final response = await http.get(url);
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Mock processing for development (when Azure Function is not available)
  Future<bool> mockProcessInvoice({
    required String tenantId,
    required String invoiceId,
    required String imageUrl,
  }) async {
    print('Mock processing invoice: $invoiceId');
    
    // Simulate processing delay
    await Future.delayed(const Duration(seconds: 3));
    
    // Return success for demonstration
    return true;
  }
}
