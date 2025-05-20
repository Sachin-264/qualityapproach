import 'dart:convert';
import 'package:http/http.dart' as http;

class ReportAPIService {
  // Map of API names to their endpoints
  final Map<String, String> _apiEndpoints = {
    'DetailDashboard': 'http://localhost/Dash/detail.php?UserGroupCode=1&UserCode=1&BranchCode=E&FromDate=01-Apr-2025&ToDate=31-Mar-2026&AccountCode&PassedUserID&VendorQuotationRecNo=0&CalledWith=VendorQuotationAuthorisation&Check1=N&Check2=N&Branch_VendorQuotation_Authorisation_SingleLevel=N&VendorQuotation_Auth_Level=2&Level1=Y&Opt1=N&Opt2=Y&ActionTaken&DepartmentRecNo=0&IndentNo=0&New+at+L1',
    // Add more APIs here in the future
  };

  Future<List<String>> getAvailableApis() async {
    return _apiEndpoints.keys.toList();
  }

  Future<List<Map<String, dynamic>>> fetchApiData(String apiName) async {
    final url = _apiEndpoints[apiName];
    if (url == null) throw Exception('API not found');

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] == 'success') {
        return List<Map<String, dynamic>>.from(jsonData['data']);
      } else {
        throw Exception('API returned error: ${jsonData['message']}');
      }
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }
}