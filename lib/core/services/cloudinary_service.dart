import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cloudinary Media Upload & Multi-Tier CDN Service
class CloudinaryService {
  CloudinaryService._();
  static final CloudinaryService instance = CloudinaryService._();

  static String cloudName = 'yaw5d7xi';
  static String uploadPreset = 'notifly_preset';

  /// Uploads image bytes to Cloudinary for CDN delivery & auto-optimization.
  /// Falls back to Supabase Storage or ImgBB CDN to return a short URL string.
  Future<String> uploadImageBytes(Uint8List imageBytes, {String filename = 'photo.jpg'}) async {
    // 1. Try Cloudinary Unsigned Upload
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: filename,
        ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 8));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final secureUrl = json['secure_url'] as String?;
        if (secureUrl != null && secureUrl.isNotEmpty) {
          return secureUrl;
        }
      }
    } catch (_) {}

    // 2. Try Supabase Storage 'chat-attachments' bucket
    try {
      final client = Supabase.instance.client;
      final cleanName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = 'uploads/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
      await client.storage.from('chat-attachments').uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      final publicUrl = client.storage.from('chat-attachments').getPublicUrl(path);
      if (publicUrl.isNotEmpty) return publicUrl;
    } catch (_) {}

    // 3. Try ImgBB CDN fallback
    try {
      final uri = Uri.parse('https://api.imgbb.com/1/upload?key=8e6bf7656ad93a11634b9cf80b43f915');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: filename));
      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final url = json['data']['url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
    } catch (_) {}

    throw Exception(
      'Image upload failed. Please configure Cloudinary Unsigned Upload Preset or create a public Supabase Storage bucket named "chat-attachments".',
    );
  }
}
