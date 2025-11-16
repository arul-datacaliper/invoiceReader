import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'dart:developer' as developer;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload invoice image
  Future<String> uploadInvoiceImage({
    required File imageFile,
    required String tenantId,
    required String invoiceId,
  }) async {
    try {
      print('🔵 [StorageService] Starting image upload...');
      print('🔵 [StorageService] TenantId: $tenantId');
      print('🔵 [StorageService] InvoiceId: $invoiceId');
      print('🔵 [StorageService] Image path: ${imageFile.path}');
      print('🔵 [StorageService] Image exists: ${await imageFile.exists()}');
      print('🔵 [StorageService] Image size: ${await imageFile.length()} bytes');

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      print('🔵 [StorageService] Generated filename: $fileName');
      
      final ref = _storage
          .ref()
          .child('invoices')
          .child(tenantId)
          .child(invoiceId)
          .child(fileName);
      
      print('🔵 [StorageService] Firebase Storage path: ${ref.fullPath}');

      print('🔵 [StorageService] Starting upload task...');
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'tenantId': tenantId,
            'invoiceId': invoiceId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Listen to upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          print('🔵 [StorageService] Upload progress: ${progress.toStringAsFixed(1)}%');
        },
        onError: (error) {
          print('🔴 [StorageService] Upload stream error: $error');
        },
      );

      print('🔵 [StorageService] Waiting for upload completion...');
      final snapshot = await uploadTask;
      print('🔵 [StorageService] Upload completed, getting download URL...');
      
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('🟢 [StorageService] Upload successful! Download URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e, stackTrace) {
      print('🔴 [StorageService] Upload failed with error: $e');
      print('🔴 [StorageService] Stack trace: $stackTrace');
      throw Exception('Failed to upload image: $e');
    }
  }

  // Delete invoice image
  Future<void> deleteInvoiceImage(String downloadUrl) async {
    try {
      print('🔵 [StorageService] Deleting image: $downloadUrl');
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      print('🟢 [StorageService] Image deleted successfully');
    } catch (e, stackTrace) {
      print('🔴 [StorageService] Delete failed: $e');
      print('🔴 [StorageService] Stack trace: $stackTrace');
      throw Exception('Failed to delete image: $e');
    }
  }

  // Get image metadata
  Future<FullMetadata> getImageMetadata(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      return await ref.getMetadata();
    } catch (e) {
      throw Exception('Failed to get image metadata: $e');
    }
  }

  // List images for a tenant
  Future<List<String>> listInvoiceImages(String tenantId) async {
    try {
      final ref = _storage.ref().child('invoices').child(tenantId);
      final result = await ref.listAll();
      
      final List<String> downloadUrls = [];
      for (final item in result.items) {
        final url = await item.getDownloadURL();
        downloadUrls.add(url);
      }
      
      return downloadUrls;
    } catch (e) {
      throw Exception('Failed to list images: $e');
    }
  }
}
