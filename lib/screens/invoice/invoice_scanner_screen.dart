import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../services/camera_service.dart';

class InvoiceScannerScreen extends StatefulWidget {
  const InvoiceScannerScreen({super.key});

  @override
  State<InvoiceScannerScreen> createState() => _InvoiceScannerScreenState();
}

class _InvoiceScannerScreenState extends State<InvoiceScannerScreen> {
  final CameraService _cameraService = CameraService();
  File? _selectedImage;
  bool _isProcessing = false;

  Future<void> _takePhoto() async {
    try {
      print('🔵 [ScannerScreen] Taking photo...');
      final image = await _cameraService.takePhoto();
      print('🔵 [ScannerScreen] Photo taken: ${image?.path}');
      
      if (image != null) {
        print('🔵 [ScannerScreen] Starting image cropping...');
        final croppedImage = await _cameraService.cropImage(image);
        print('🔵 [ScannerScreen] Image cropped: ${croppedImage?.path}');
        
        if (croppedImage != null) {
          setState(() {
            _selectedImage = croppedImage;
          });
          print('🟢 [ScannerScreen] Image selected successfully');
        } else {
          print('🟡 [ScannerScreen] Image cropping was cancelled');
        }
      } else {
        print('🟡 [ScannerScreen] Photo capture was cancelled');
      }
    } catch (e, stackTrace) {
      print('🔴 [ScannerScreen] Take photo failed: $e');
      print('🔴 [ScannerScreen] Stack trace: $stackTrace');
      _showErrorSnackBar('Failed to take photo: ${e.toString()}');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      print('🔵 [ScannerScreen] Picking from gallery...');
      final image = await _cameraService.pickFromGallery();
      print('🔵 [ScannerScreen] Image picked: ${image?.path}');
      
      if (image != null) {
        print('🔵 [ScannerScreen] Starting image cropping...');
        final croppedImage = await _cameraService.cropImage(image);
        print('🔵 [ScannerScreen] Image cropped: ${croppedImage?.path}');
        
        if (croppedImage != null) {
          setState(() {
            _selectedImage = croppedImage;
          });
          print('🟢 [ScannerScreen] Image selected successfully');
        } else {
          print('🟡 [ScannerScreen] Image cropping was cancelled');
        }
      } else {
        print('🟡 [ScannerScreen] Gallery picker was cancelled');
      }
    } catch (e, stackTrace) {
      print('🔴 [ScannerScreen] Pick from gallery failed: $e');
      print('🔴 [ScannerScreen] Stack trace: $stackTrace');
      _showErrorSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _processInvoice() async {
    print('🔵 [ScannerScreen] Process invoice called');
    
    if (_selectedImage == null) {
      print('🔴 [ScannerScreen] No image selected, aborting');
      return;
    }

    print('🔵 [ScannerScreen] Image selected: ${_selectedImage!.path}');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final tenantId = authProvider.userDocument?.tenantId;

    print('🔵 [ScannerScreen] TenantId from auth: $tenantId');

    if (tenantId == null) {
      print('🔴 [ScannerScreen] User not authenticated');
      _showErrorSnackBar('User not authenticated');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    print('🔵 [ScannerScreen] Processing state set to true, calling provider...');

    try {
      final success = await invoiceProvider.processInvoice(
        imageFile: _selectedImage!,
        tenantId: tenantId,
      );

      print('🔵 [ScannerScreen] Provider returned success: $success');

      if (success && mounted) {
        print('🟢 [ScannerScreen] Processing successful, showing success message');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice uploaded successfully! Processing...'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedImage = null;
        });
      } else if (mounted) {
        print('🔴 [ScannerScreen] Processing failed: ${invoiceProvider.errorMessage}');
        _showErrorSnackBar(
          invoiceProvider.errorMessage ?? 'Failed to process invoice',
        );
      }
    } catch (e, stackTrace) {
      print('🔴 [ScannerScreen] Exception in _processInvoice: $e');
      print('🔴 [ScannerScreen] Stack trace: $stackTrace');
      _showErrorSnackBar('Error processing invoice: ${e.toString()}');
    } finally {
      if (mounted) {
        print('🔵 [ScannerScreen] Resetting processing state');
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instructions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        size: 48,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Scan Invoice',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Take a photo or select an image of your invoice to extract data automatically.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Image Preview
              if (_selectedImage != null) ...[
                Card(
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        child: Image.file(
                          _selectedImage!,
                          height: 300,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _clearImage,
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing ? null : _processInvoice,
                                icon: _isProcessing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.upload),
                                label: Text(_isProcessing ? 'Processing...' : 'Process'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('From Gallery'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
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
