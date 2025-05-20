import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // For debugPrint

class DynamicFieldApi {
  static const String _formBaseUrl = 'http://localhost/Dash/dynamic.php';
  static const String _autocompleteBaseUrl = 'http://localhost/Dash/getDynamicField.php';

  Future<List<Map<String, dynamic>>> fetchFormFields(String recNo) async {
    const action = 'GET_FORM_2';
    final uri = Uri.parse('$_formBaseUrl?action=$action&RECNO=$recNo');
    debugPrint('Fetching form fields from dynamic.php: $uri');
    debugPrint('Query Parameters: action=$action, RECNO=$recNo');

    try {
      final response = await http.get(uri);
      debugPrint('dynamic.php HTTP Status: ${response.statusCode}');
      debugPrint('dynamic.php Raw Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body);
          debugPrint('dynamic.php Parsed JSON: $jsonData (Type: ${jsonData.runtimeType})');

          if (jsonData is Map<String, dynamic>) {
            if (jsonData['status'] == 'success' && jsonData['data'] is List<dynamic>) {
              return jsonData['data'].cast<Map<String, dynamic>>();
            }
            if (jsonData.containsKey('error')) {
              debugPrint('dynamic.php API returned error: ${jsonData['error']}');
              return [];
            }
          }
          debugPrint('dynamic.php Unexpected JSON type: ${jsonData.runtimeType}');
          throw Exception('dynamic.php Invalid response format');
        } catch (e) {
          debugPrint('dynamic.php JSON decode error: $e');
          throw Exception('dynamic.php Failed to parse response: $e');
        }
      } else {
        debugPrint('dynamic.php HTTP error: ${response.statusCode}');
        throw Exception('dynamic.php Failed to load form fields: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('dynamic.php Network error: $e');
      throw Exception('dynamic.php Error fetching form fields: $e');
    }
  }

  Future<List<String>> fetchAutocompleteOptions(String masterField) async {
    String action;
    String displayField;
    bool useFallback = false;
    switch (masterField.toUpperCase()) {
      case 'BRACHNAME':
        action = 'BRANCH';
        displayField = 'BranchName';
        break;
      case 'ITEMNAME':
        action = 'ITEMNAME';
        displayField = 'ItemName';
        break;
      case 'OURITEMNO':
        action = 'OUR ITEM NO';
        displayField = 'OurItemNo';
        useFallback = true;
        break;
      case 'BRANDNAME':
        action = 'BRANDNAME';
        displayField = 'BrandName';
        break;
      case 'POTYPE':
        action = 'POTYPE';
        displayField = 'PoType';
        break;
      case 'DEPTNAME':
        action = 'DEPTNAME';
        displayField = 'DeptName';
        break;
      case 'PRNAME':
        action = 'PRNAME';
        displayField = 'PrName';
        break;
      case 'COSTCENTERNAME':
        action = 'COSTCENTERNAME';
        displayField = 'CostCenterName';
        break;
      case 'SUBCOSTCENTER':
        action = 'SUBCOSTCENTER';
        displayField = 'SubCostCenter';
        break;
      default:
        debugPrint('No autocomplete action for MasterField: $masterField');
        return [];
    }

    final uri = Uri.parse('$_autocompleteBaseUrl?action=$action');
    debugPrint('Fetching autocomplete options for $masterField: $uri');

    try {
      final response = await http.get(uri);
      debugPrint('getDynamicField.php HTTP Status for $action: ${response.statusCode}');
      debugPrint('getDynamicField.php Raw Response Body for $action: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData is Map<String, dynamic> && jsonData['data'] is List<dynamic>) {
            final data = jsonData['data'] as List<dynamic>;
            final options = data
                .where((item) => item is Map<String, dynamic> && item[displayField] != null && item[displayField].toString().isNotEmpty)
                .map((item) => (item as Map<String, dynamic>)[displayField].toString())
                .toList();
            if (useFallback && options.isEmpty) {
              debugPrint('Falling back to ItemName for $masterField');
              return data
                  .where((item) => item is Map<String, dynamic> && item['ItemName'] != null && item['ItemName'].toString().isNotEmpty)
                  .map((item) => (item as Map<String, dynamic>)['ItemName'].toString())
                  .toList();
            }
            debugPrint('Fetched ${options.length} options for $masterField');
            return options;
          }
          debugPrint('getDynamicField.php Invalid response format for $action');
          return [];
        } catch (e) {
          debugPrint('getDynamicField.php JSON decode error for $action: $e');
          throw Exception('getDynamicField.php Failed to parse response: $e');
        }
      } else {
        debugPrint('getDynamicField.php HTTP error for $action: ${response.statusCode}');
        throw Exception('getDynamicField.php Failed to load options: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('getDynamicField.php Network error for $action: $e');
      throw Exception('getDynamicField.php Error fetching options: $e');
    }
  }
}