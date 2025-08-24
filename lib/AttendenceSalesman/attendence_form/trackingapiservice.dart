import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TrackingApiService {
  static const String _phpBaseUrl = "http://10.93.183.119/AquareCRM"; // For Android Emulator

  // NEW: Helper method to log HTTP requests and responses
  void _logRequest({
    required String endpoint,
    required String method,
    Map<String, String>? body,
    Map<String, String>? headers,
    http.Response? response,
    Object? error,
  }) {
    final log = StringBuffer('[$method] $endpoint\n');
    if (body != null) {
      log.write('Request Body: ${jsonEncode(body)}\n');
    }
    if (headers != null) {
      log.write('Request Headers: ${jsonEncode(headers)}\n');
    }
    if (response != null) {
      log.write('Response Status: ${response.statusCode}\n');
      log.write('Response Body: ${response.body}\n');
      log.write('Response Headers: ${jsonEncode(response.headers)}\n');
    }
    if (error != null) {
      log.write('Error: $error\n');
    }
    debugPrint(log.toString());
  }

  // Handles all POST requests and error handling
  Future<Map<String, dynamic>> _postRequest(String endpoint, Map<String, String> body) async {
    try {
      final headers = {'Content-Type': 'application/x-www-form-urlencoded'};
      _logRequest(
        endpoint: '$_phpBaseUrl/$endpoint',
        method: 'POST',
        body: body,
        headers: headers,
      );

      final response = await http.post(
        Uri.parse('$_phpBaseUrl/$endpoint'),
        headers: headers,
        body: body,
      );

      _logRequest(
        endpoint: '$_phpBaseUrl/$endpoint',
        method: 'POST',
        response: response,
      );

      if (response.statusCode == 200) {
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          } else {
            throw FormatException('Response is not a valid JSON object: ${response.body}');
          }
        } catch (e) {
          _logRequest(
            endpoint: '$_phpBaseUrl/$endpoint',
            method: 'POST',
            error: 'JSON decode error: $e',
          );
          throw Exception('Failed to parse server response: $e');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _logRequest(
        endpoint: '$_phpBaseUrl/$endpoint',
        method: 'POST',
        body: body,
        error: 'Exception: $e\nStackTrace: $stackTrace',
      );
      throw Exception('Failed to connect to the server: $e');
    }
  }

  /// Step 1: Uploads the image and returns the unique filename from the server.
  Future<String> uploadImage({
    required String imagePath,
    required String userId,
    required String groupCode,
  }) async {
    debugPrint('Starting uploadImage: imagePath=$imagePath, userId=$userId, groupCode=$groupCode');

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('Error: Image file does not exist at $imagePath');
        throw Exception('Image file does not exist: $imagePath');
      }

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      debugPrint('Image encoded to base64, length: ${base64Image.length}');

      final payload = {
        'userID': userId,
        'groupCode': groupCode,
        'stationImages': [base64Image],
      };
      final headers = {'Content-Type': 'application/json'};

      _logRequest(
        endpoint: '$_phpBaseUrl/photogcp.php',
        method: 'POST',
        body: {'userID': userId, 'groupCode': groupCode, 'stationImages': '[base64 truncated]'},
        headers: headers,
      );

      final response = await http.post(
        Uri.parse('$_phpBaseUrl/photogcp.php'),
        headers: headers,
        body: json.encode(payload),
      );

      _logRequest(
        endpoint: '$_phpBaseUrl/photogcp.php',
        method: 'POST',
        response: response,
      );

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          debugPrint('uploadImage response data: ${jsonEncode(data)}');

          if (data['error']['code'] == 200 && data['stationUploads'] is List && data['stationUploads'].isNotEmpty) {
            final uniqueFileName = data['stationUploads'][0]['UniqueFileName'];
            if (uniqueFileName is String && uniqueFileName.isNotEmpty) {
              debugPrint('uploadImage success: UniqueFileName=$uniqueFileName');
              return uniqueFileName;
            } else {
              throw Exception('Invalid or missing UniqueFileName in response');
            }
          } else {
            throw Exception(data['error']['message'] ?? 'Unknown error uploading image');
          }
        } catch (e) {
          _logRequest(
            endpoint: '$_phpBaseUrl/photogcp.php',
            method: 'POST',
            error: 'JSON decode error: $e',
          );
          throw Exception('Failed to parse uploadImage response: $e');
        }
      } else {
        throw Exception('Failed to upload image. Status code: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _logRequest(
        endpoint: '$_phpBaseUrl/photogcp.php',
        method: 'POST',
        error: 'Exception: $e\nStackTrace: $stackTrace',
      );
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Step 2: Marks attendance and returns the database record number (RecNo).
  Future<int> markAttendance({
    required String userCode,
    required String branchCode,
    required String selfiePath,
  }) async {
    debugPrint('Starting markAttendance: userCode=$userCode, branchCode=$branchCode, selfiePath=$selfiePath');

    try {
      final body = {
        'action': 'markAttendance',
        'UserCode': userCode,
        'BranchCode': branchCode,
        'SelfieImagePath': selfiePath,
      };

      final response = await _postRequest('attendence_api.php', body);

      debugPrint('markAttendance response: ${jsonEncode(response)}');

      if (response['status'] == 'success' && response['RecNo'] != null) {
        final recNo = int.tryParse(response['RecNo'].toString());
        if (recNo != null) {
          debugPrint('markAttendance success: RecNo=$recNo');
          return recNo;
        } else {
          throw Exception('Invalid RecNo format: ${response['RecNo']}');
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to mark attendance');
      }
    } catch (e, stackTrace) {
      debugPrint('markAttendance error: $e\nStackTrace: $stackTrace');
      throw Exception('Failed to mark attendance: $e');
    }
  }

  /// Step 3: Sends a single tracking point to the server.
  Future<void> trackUser({
    required int recNo,
    required String userCode,
    required LatLng location,
  }) async {
    debugPrint('Starting trackUser: recNo=$recNo, userCode=$userCode, latitude=${location.latitude}, longitude=${location.longitude}');

    try {
      final body = {
        'action': 'trackUser',
        'RecNo': recNo.toString(),
        'UserCode': userCode,
        'Latitude': location.latitude.toString(),
        'Longitude': location.longitude.toString(),
      };

      final response = await _postRequest('attendence_api.php', body);

      debugPrint('trackUser response: ${jsonEncode(response)}');

      if (response['status'] != 'success') {
        debugPrint('Failed to save tracking point: ${response['message']}');
      } else {
        debugPrint('trackUser success');
      }
    } catch (e, stackTrace) {
      debugPrint('trackUser error: $e\nStackTrace: $stackTrace');
    }
  }
}