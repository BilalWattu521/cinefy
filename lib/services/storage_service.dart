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
    // Typical URL: https://res.cloudinary.com/{cloud_name}/video/upload/v{version}/{public_id}.mp4
    final uri = Uri.parse(videoUrl);
    final segments = uri.pathSegments;
    
    // Find the 'upload' segment, skip the version segment, then get everything after it
    int uploadIndex = segments.indexOf('upload');
    if (uploadIndex == -1 || uploadIndex + 2 >= segments.length) {
      if (kDebugMode) print('Could not extract public_id from URL: $videoUrl');
      return; 
    }

    // Combine remaining segments to form public_id and remove the file extension
    String publicIdWithExtension = segments.sublist(uploadIndex + 2).join('/');
    String publicId = publicIdWithExtension.substring(
        0, publicIdWithExtension.lastIndexOf('.'));

    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/video/destroy');

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // params to sign: public_id, timestamp
    final String paramsToSign = 'public_id=$publicId&timestamp=$timestamp$_apiSecret';
    final String signature =
        sha1.convert(utf8.encode(paramsToSign)).toString();

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
      throw Exception(
          'Delete failed: ${jsonResponse['error']?['message'] ?? 'Unknown error'}');
    }
  }
}
