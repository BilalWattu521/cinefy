import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class StorageService {
  // Retrieve these from your .env file
  String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  String get _apiKey => dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  String get _apiSecret => dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

  bool get isConfigured =>
      _cloudName.isNotEmpty && _apiKey.isNotEmpty && _apiSecret.isNotEmpty;

  /// Uploads a video file to Cloudinary.
  /// Returns the standard download URL or secure URL on success.
  Future<String> uploadVideo({
    required String uid,
    required String movieUniqueId,
    required File videoFile,
    void Function(double progress)? onProgress,
  }) async {
    if (!isConfigured) {
      throw Exception('Cloudinary is not configured in .env');
    }

    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/video/upload');

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // We will organize files into folders using 'folder' param
    final folderPath = 'movie_tracker/users/$uid/videos/$movieUniqueId';

    // To sign the request, we sort params to sign alphabetically.
    // We are passing: folder, timestamp
    final String paramsToSign = 'folder=$folderPath&timestamp=$timestamp$_apiSecret';
    final String signature =
        sha1.convert(utf8.encode(paramsToSign)).toString();

    // Use http.MultipartRequest to upload file
    final request = http.MultipartRequest('POST', url)
      ..fields['api_key'] = _apiKey
      ..fields['timestamp'] = timestamp.toString()
      ..fields['signature'] = signature
      ..fields['folder'] = folderPath;

    final fileStream = videoFile.openRead();
    final totalBytes = videoFile.lengthSync();
    int sentBytes = 0;

    final stream = fileStream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          sentBytes += data.length;
          if (onProgress != null) {
            onProgress(sentBytes / totalBytes);
          }
          sink.add(data);
        },
      ),
    );

    request.files.add(http.MultipartFile(
      'file',
      stream.asBroadcastStream(), // Use broadcast if needed, or just regular
      totalBytes,
      filename: videoFile.path.split(Platform.pathSeparator).last,
    ));

    final response = await request.send();

    final responseBody = await response.stream.bytesToString();
    final jsonResponse = jsonDecode(responseBody);

    if (response.statusCode == 200) {
      if (onProgress != null) onProgress(1.0);
      return jsonResponse['secure_url'];
    } else {
      throw Exception('Upload failed: ${jsonResponse['error']?['message'] ?? 'Unknown error'}');
    }
  }

  /// Deletes a video file from Cloudinary using its secure URL.
  Future<void> deleteVideo(String videoUrl) async {
    if (!isConfigured) {
      throw Exception('Cloudinary is not configured in .env');
    }

    // Extract the public_id from the videoUrl
    final uri = Uri.parse(videoUrl);
    final segments = uri.pathSegments;
    final uploadIndex = segments.indexOf('upload');

    // Handle variation in URL structure
    if (uploadIndex == -1 || uploadIndex + 1 >= segments.length) {
      if (kDebugMode) print('Could not extract public_id from URL: $videoUrl');
      return;
    }

    // Check if the next segment is a version string (starts with 'v' and followed by digits)
    int startIdx = uploadIndex + 1;
    if (segments[startIdx].startsWith('v') &&
        segments[startIdx].substring(1).contains(RegExp(r'^\d+$'))) {
      startIdx++;
    }

    if (startIdx >= segments.length) {
      if (kDebugMode) print('Could not extract public_id (invalid segments) from URL: $videoUrl');
      return;
    }

    String publicIdWithExtension = segments.sublist(startIdx).join('/');
    String publicId = publicIdWithExtension;
    if (publicIdWithExtension.contains('.')) {
      publicId = publicIdWithExtension.substring(0, publicIdWithExtension.lastIndexOf('.'));
    }

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/video/destroy');
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Params to sign (must be alphabetical): public_id, timestamp
    final String paramsToSign = 'public_id=$publicId&timestamp=$timestamp$_apiSecret';
    final String signature = sha1.convert(utf8.encode(paramsToSign)).toString();

    final response = await http.post(
      url,
      body: {
        'public_id': publicId,
        'timestamp': timestamp.toString(),
        'api_key': _apiKey,
        'signature': signature,
      },
    );

    if (response.statusCode != 200) {
      final jsonResponse = jsonDecode(response.body);
      throw Exception('Delete failed: ${jsonResponse['error']?['message'] ?? 'Unknown error'}');
    }

    // Auto-cleanup: Try to delete the movie folder if it's now empty
    if (publicId.contains('/')) {
      final folderPath = publicId.substring(0, publicId.lastIndexOf('/'));
      // Only attempt if it's under the movie_tracker/users branch
      if (folderPath.startsWith('movie_tracker/users/')) {
        await deleteFolder(folderPath); // Non-recursive delete (only if empty)
      }
    }
  }

  /// Deletes an empty folder from Cloudinary.
  /// Note: Folders can only be deleted if they are truly empty.
  Future<void> deleteFolder(String folderPath) async {
    if (!isConfigured) return;

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/folders/$folderPath');
    final String auth = 'Basic ${base64Encode(utf8.encode('$_apiKey:$_apiSecret'))}';

    final response = await http.delete(url, headers: {'Authorization': auth});

    if (response.statusCode == 200) {
      if (kDebugMode) print('Cloudinary folder deleted successfully: $folderPath');
    }
    // We ignore failures (like 404 or 409 Conflict if not empty) for normal cleanup
  }

  /// Force-deletes a folder and all its contents (resources and subfolders).
  Future<void> deleteFolderRecursive(String folderPath) async {
    if (!isConfigured) return;

    try {
      // 1. Delete all resources in this folder (and subfolders)
      // We must specify the resource_type. For our app, 'video' is most common.
      await _deleteResourcesByPrefix(folderPath, 'video');
      await _deleteResourcesByPrefix(folderPath, 'image');
      await _deleteResourcesByPrefix(folderPath, 'raw');

      // 2. Recursively delete sub-folders
      await _deleteSubFolders(folderPath);

      // 3. Delete the folder itself
      await deleteFolder(folderPath);
    } catch (e) {
      if (kDebugMode) print('Error in deleteFolderRecursive for $folderPath: $e');
    }
  }

  /// Admin API helper to delete resources by prefix
  Future<void> _deleteResourcesByPrefix(String prefix, String resourceType) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/resources/$resourceType/upload?prefix=$prefix');
    final String auth = 'Basic ${base64Encode(utf8.encode('$_apiKey:$_apiSecret'))}';

    await http.delete(url, headers: {'Authorization': auth});
  }

  /// Admin API helper to list and delete subfolders
  Future<void> _deleteSubFolders(String folderPath) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/folders/$folderPath');
    final String auth = 'Basic ${base64Encode(utf8.encode('$_apiKey:$_apiSecret'))}';

    final response = await http.get(url, headers: {'Authorization': auth});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final folders = data['folders'] as List<dynamic>?;
      if (folders != null) {
        for (var f in folders) {
          final subPath = f['path'] as String;
          // Recursively delete subfolder
          await deleteFolderRecursive(subPath);
        }
      }
    }
  }
}
