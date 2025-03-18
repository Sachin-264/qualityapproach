import 'dart:convert';
import 'dart:developer' as developer; // Import for logging
import 'package:http/http.dart' as http;

class QualityAPI {
  static const String baseUrl = "http://localhost/AquavivaAPI";

  /// Fetches item quality parameters
  static Future<List<Map<String, dynamic>>> getItemQualityParameters({
    required String branchCode,
    required String itemNo,
    required String str,
  }) async {
    final url = Uri.parse(
        '$baseUrl/get_item_quality_parameter.php?BranchCode=$branchCode&itemNo=$itemNo&str=$str');

    try {
      developer.log('Fetching item quality parameters from: $url', name: 'QualityAPI');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final List<dynamic> data = json.decode(response.body);
          return data.cast<Map<String, dynamic>>();
        } else {
          throw Exception('Received empty response');
        }
      } else {
        throw Exception('Failed to load quality parameters: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching quality parameters: $e');
    }
  }

  /// Fetches MRN Report details
  static Future<List<Map<String, dynamic>>> getMRNReport({
    required String branchCode,
    required String fromDate,
    required String toDate,
    required String pending,
    required String str,
  }) async {
    final url = Uri.parse(
        '$baseUrl/get_mrn_qc_details.php?BranchCode=$branchCode&FromDate=$fromDate&ToDate=$toDate&Level1=&UserCode=0&Company_QC_SingleLevel=&Branch_QC_Level=0&Pending=$pending&str=$str');

    try {
      final response = await http.get(url);
      // print('API URL: $url');

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final List<dynamic> jsonList = json.decode(response.body);
          return jsonList.cast<Map<String, dynamic>>();
        } else {
          throw Exception('Received empty response');
        }
      } else {
        throw Exception('Failed to load reports: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching MRN report: $e');
    }
  }

  /// Submits MRN quality parameters
  static Future<bool> submitMRNQualityParameters({
    required String str,
    required double UserCode,
    required int UserGroupCode,
    required int RecNo,
    required int ItemSno,
    required String ItemNo,
    required String signature,
    required List<Map<String, dynamic>> FileDetail,
  }) async {
    final url = Uri.parse('http://localhost/post_add_mrn_quality_parameters.php?str=$str');
    print('API URL: $url');

    try {
      final Map<String, dynamic> requestBody = {
        'UserCode': UserCode,
        'UserGroupCode': UserGroupCode,
        'RecNo': RecNo,
        'ItemSno': ItemSno,
        'ItemNo': ItemNo,
        'IMGSign': signature,
        'FileDetail': FileDetail,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Response Data: $responseData');

        // Extract the 'message' field
        dynamic message = responseData['message'];

        if (message is String) {
          try {
            message = json.decode(message);
          } catch (e) {
            print('Failed to parse message string: $e');
            return false;
          }
        }

        if (message is Map<String, dynamic>) {
          print('ResultStatus: ${message['ResultStatus']}');
          print('ResultMsg: ${message['ResultMsg']}');

          final resultStatus = message['ResultStatus']?.toString().trim();
          final resultMsg = message['ResultMsg']?.toString().trim();

          if (resultStatus == 'Success') {
            print('Submission successful');
            return true; // Submission successful
          } else {
            print('Submission failed: ResultStatus = $resultStatus, ResultMsg = $resultMsg');
            return false; // Submission failed
          }
        } else {
          print('Message is still not a Map after parsing: $message');
          return false; // Unexpected format
        }
      } else {
        throw Exception('Failed to submit: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in submitMRNQualityParameters: $e');
      throw Exception('Error submitting MRN quality parameters: $e');
    }
  }

  /// Loads MRN item quality details
  static Future<List<Map<String, dynamic>>> loadMRNItemQualityDetails({
    required int RecNo,
    required String ItemNo,
    required int ItemSNo,
    required String str,
  }) async {
    final url = Uri.parse(
        '$baseUrl/sp_LoadMRNItemQualityDetails.php?RecNo=$RecNo&ItemNo=$ItemNo&ItemSNo=$ItemSNo&str=*$str');

    try {
      developer.log('Fetching MRN item quality details from: $url', name: 'QualityAPI');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final List<dynamic> jsonList = json.decode(response.body);
          return jsonList.cast<Map<String, dynamic>>();
        } else {
          throw Exception('Received empty response');
        }
      } else {
        throw Exception('Failed to load MRN item quality details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching MRN item quality details: $e');
    }
  }
}