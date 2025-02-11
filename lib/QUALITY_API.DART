import 'dart:convert';
import 'package:http/http.dart' as http;

class QualityAPI {
  static const String baseUrl = "http://10.0.2.2/AquavivaAPI";

  /// Fetches item quality parameters
  static Future<List<Map<String, dynamic>>> getItemQualityParameters({
    required String branchCode,
    required String itemNo,
    required String str,
  }) async {
    final url = Uri.parse(
        '$baseUrl/get_item_quality_parameter.php?BranchCode=$branchCode&itemNo=$itemNo&str=$str');

    try {
      final response = await http.get(url);
      print('API URL: $url');

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final List<dynamic> data = json.decode(response.body);
          return data.cast<Map<String, dynamic>>();
        } else {
          throw Exception('Received empty response');
        }
      } else {
        throw Exception(
            'Failed to load quality parameters: ${response.statusCode}');
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
      print('API URL: $url');

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
    final url =
        Uri.parse('$baseUrl/post_add_mrn_quality_parameters.php?str=$str');
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

      print('Request Body: $requestBody');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      _logResponse(url, response);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Response Data: $responseData');

        // Check for the 'message' field in the response
        if (responseData['message'] ==
            'MRN and Quality Parameters inserted successfully') {
          return true; // Submission successful
        } else {
          return false; // Submission failed
        }
      } else {
        throw Exception('Failed to submit: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in submitMRNQualityParameters: $e');
      throw Exception('Error submitting MRN quality parameters: $e');
    }
  }

  /// Logs the response for debugging purposes
  static void _logResponse(Uri url, http.Response response) {
    print('API URL: $url');
    print('Response Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');
  }
}
