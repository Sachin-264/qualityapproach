import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

class WarrantyService {
  static const String baseUrl = 'http://localhost/allWarrantyGetAPI.php';

  static Future<List<Map<String, String>>> _processResponse(
      http.Response response) async {
    if (response.statusCode == 200) {
      final List<dynamic> rawData = json.decode(response.body);
      developer.log('Raw API Response: $rawData', name: 'WarrantyService');

      return rawData.map<Map<String, String>>((item) {
        return {
          'id': item['FieldID']?.toString() ?? '',
          'name': item['FieldName']?.toString() ?? '',
        };
      }).toList();
    } else {
      developer.log('API Error: ${response.statusCode}',
          name: 'WarrantyService');
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  static Future<String> getSlipNo() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl?type=SlipNo'));
      final rawData = json.decode(response.body);
      print(rawData);
      return rawData[0]['NextCode']?.toString() ?? '';
    } catch (e) {
      developer.log('SlipNo fetch error: $e', name: 'WarrantyService');
      rethrow;
    }
  }

  static Future<List<Map<String, String>>> getHeadquarters() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl?type=HeadQuarter'));
      return _processResponse(response);
    } catch (e) {
      developer.log('Headquarters fetch error: $e', name: 'WarrantyService');
      rethrow;
    }
  }

  static Future<List<Map<String, String>>> getCustomers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl?type=CustomerName'));
      return _processResponse(response);
    } catch (e) {
      developer.log('Customers fetch error: $e', name: 'WarrantyService');
      rethrow;
    }
  }

  static Future<List<Map<String, String>>> getBillNumbers(
      String customerId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl?type=BillNo&customerID=$customerId'));
      return _processResponse(response);
    } catch (e) {
      developer.log('Bill Numbers fetch error: $e', name: 'WarrantyService');
      rethrow;
    }
  }

  static Future<Map<String, String>> getItemDetails(String invoiceId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl?type=ItemName&InvoiceId=$invoiceId'));
      final rawData = json.decode(response.body);
      return {
        'id': rawData[0]['FieldID']?.toString() ?? '',
        'name': rawData[0]['FieldName']?.toString() ?? '',
        'hsnCode': rawData[0]['HSNCode']?.toString() ?? '',
        'mcNo': rawData[0]['MCNo']?.toString() ?? '',
        'itemRemarks': rawData[0]['itemRemarks']?.toString() ?? '',
        'withSpareParts': rawData[0]['WithSpareParts']?.toString() ?? '',
        'amcStartDate': rawData[0]['AMCStartDate']?.toString() ?? '',
        'amcEndDate': rawData[0]['AMCEndDate']?.toString() ?? '',
        'installationAddress':
            rawData[0]['installationAddress']?.toString() ?? '',
      };
    } catch (e) {
      developer.log('Item Details fetch error: $e', name: 'WarrantyService');
      rethrow;
    }
  }

  static Future<Map<String, String>> getCustomerDetails(
      String customerId) async {
    try {
      final response = await http.get(
          Uri.parse('$baseUrl?type=CustomerDetails&customerID=$customerId'));
      final rawData = json.decode(response.body);
      return {
        'id': rawData[0]['FieldID']?.toString() ?? '',
        'name': rawData[0]['FieldName']?.toString() ?? '',
      };
    } catch (e) {
      developer.log('Customer Details fetch error: $e',
          name: 'WarrantyService');
      rethrow;
    }
  }
}
