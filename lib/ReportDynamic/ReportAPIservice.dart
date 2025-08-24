import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ReportAPIService {
  final String _baseUrl = 'http://localhost/reportBuilder/DemoTables.php';
  final String _databaseFetchUrl = 'https://aquare.co.in/mobileAPI/sachin/reportBuilder/DatabaseFetch.php';
  final String _databaseFieldUrl = 'https://aquare.co.in/mobileAPI/sachin/reportBuilder/DatabaseField.php';
  final String _setupApiUrl = 'http://localhost/reportBuilder/DatabaseSetup.php';

  late final Map<String, String> _postEndpoints;
  late final Map<String, String> _getEndpoints;

  Map<String, Map<String, dynamic>> _apiDetails = {};

  Completer<void>? _apiDetailsLoadingCompleter;

  // This local counter is not used for saving reports anymore, but might be used elsewhere.
  static int _recNoCounter = 0;

  ReportAPIService() {
    _postEndpoints = {
      'post_demo_table': '$_baseUrl?mode=post_demo_table',
      'post_demo_table2': '$_baseUrl?mode=post_demo_table2',
      'post_database_server': '$_baseUrl?mode=post_database_server',
      'delete_database_server': '$_baseUrl?mode=delete_database_server',
      'edit_database_server': '$_baseUrl?mode=edit_database_server',
      'edit_demo_tables': '$_baseUrl?mode=edit_demo_tables',
      'delete_demo_tables': '$_baseUrl?mode=delete_demo_tables',
      'deploy_report': 'http://localhost/reportBuilder/deploy_report_to_client.php',
      'transfer_report': 'http://localhost/reportBuilder/deploy_report_to_client.php',
      'post_dashboard': '$_baseUrl?mode=post_dashboard',
      'edit_dashboard': '$_baseUrl?mode=edit_dashboard',
      'delete_dashboard': '$_baseUrl?mode=delete_dashboard',
      // NEW ENDPOINT for the full dashboard transfer
      'transfer_full_dashboard': 'http://localhost/reportBuilder/transfer_full_dashboard.php',
    };

    _getEndpoints = {
      'fetch_tables_and_fields': _databaseFieldUrl,
      'get_database_server': '$_baseUrl?mode=get_database_server',
      'get_demo_table': '$_baseUrl?mode=get_demo_table',
      'get_demo_table2': '$_baseUrl?mode=get_demo_table2',
      'fetch_databases': _databaseFetchUrl,
      'get_dashboards': '$_baseUrl?mode=get_dashboards',
    };
  }

  void _logRequest({
    required String httpMethod,
    required String url,
    Object? payload,
    String? functionName,
  }) {
    debugPrint('--- ReportAPIService Request ---');
    if (functionName != null) {
      debugPrint('Function: $functionName');
    }
    debugPrint('HTTP Method: $httpMethod');
    debugPrint('URL: $url');
    if (payload != null) {
      try {
        const encoder = JsonEncoder.withIndent('  ');
        final prettyPayload = encoder.convert(payload);
        debugPrint('Payload:\n$prettyPayload');
      } catch (e) {
        debugPrint('Payload: ${payload.toString()}');
      }
    }
    debugPrint('---------------------------------');
  }

  void clearApiDetailsCache() {
    _apiDetails = {};
    _apiDetailsLoadingCompleter = null;
    debugPrint('ReportAPIService: API details cache cleared.');
  }

  Future<void> _ensureApiDetailsCacheLoaded() async {
    if (_apiDetailsLoadingCompleter != null && !_apiDetailsLoadingCompleter!.isCompleted) {
      debugPrint('ReportAPIService: API details cache load in progress. Waiting...');
      return _apiDetailsLoadingCompleter!.future;
    }

    if (_apiDetails.isEmpty) {
      _apiDetailsLoadingCompleter = Completer<void>();
      debugPrint('ReportAPIService: Initiating new API details cache load.');
      try {
        await getAvailableApis();
        _apiDetailsLoadingCompleter!.complete();
      } catch (e) {
        _apiDetailsLoadingCompleter!.completeError(e);
        debugPrint('ReportAPIService: Error during API details cache load: $e');
        rethrow;
      } finally {
        _apiDetailsLoadingCompleter = null;
      }
    }
  }

  Future<List<String>> fetchDatabases({
    required String serverIP,
    required String userName,
    required String password,
  }) async {
    final url = _getEndpoints['fetch_databases'];
    if (url == null) throw Exception('GET API not found');

    try {
      final payload = {'server': serverIP.trim(), 'user': userName.trim(), 'password': password.trim()};
      final uri = Uri.parse(url);

      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'fetchDatabases');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <String>[];
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData['status'] == 'success') {
            return List<String>.from(jsonData['databases'] ?? []);
          } else {
            throw Exception('API returned error: ${jsonData['message']}');
          }
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Failed to fetch databases: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> fetchTables({
    required String server,
    required String UID,
    required String PWD,
    required String database,
  }) async {
    final url = _getEndpoints['fetch_tables_and_fields'];
    if (url == null) throw Exception('API endpoint not found for fetching tables.');

    final payload = {'server': server.trim(), 'UID': UID.trim(), 'PWD': PWD.trim(), 'Database': database.trim(), 'action': 'table'};
    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'fetchTables');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <String>[];
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData['status'] == 'success' && jsonData['tables'] is List) {
            return List<String>.from(jsonData['tables'].map((item) => item.toString()));
          } else {
            throw Exception('API returned error or unexpected data format: ${jsonData['message'] ?? response.body}');
          }
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Failed to fetch tables: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> fetchFields({
    required String server,
    required String UID,
    required String PWD,
    required String database,
    required String table,
  }) async {
    final url = _getEndpoints['fetch_tables_and_fields'];
    if (url == null) throw Exception('API endpoint not found for fetching fields.');

    final payload = {'server': server.trim(), 'UID': UID.trim(), 'PWD': PWD.trim(), 'Database': database.trim(), 'action': 'fields', 'table': table.trim()};
    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'fetchFields');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <String>[];
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData['status'] == 'success' && jsonData['fields'] is List) {
            return List<String>.from(jsonData['fields'].map((item) => item.toString()));
          } else {
            throw Exception('API returned error or unexpected data format for fields: ${jsonData['message'] ?? response.body}');
          }
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Failed to fetch fields: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPickerData({
    required String server,
    required String UID,
    required String PWD,
    required String database,
    required String masterTable,
    required String displayField,
    required String masterField,
  }) async {
    final url = _getEndpoints['fetch_tables_and_fields'];
    if (url == null) throw Exception('API endpoint not found for fetching picker data.');

    final payload = {'server': server.trim(), 'UID': UID.trim(), 'PWD': PWD.trim(), 'Database': database.trim(), 'action': 'picker_data', 'table': masterTable.trim(), 'master_field': masterField.trim(), 'display_field': displayField.trim()};
    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'fetchPickerData');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <Map<String, dynamic>>[];
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData['status'] == 'success' && jsonData['data'] is List) {
            return (jsonData['data'] as List).whereType<Map<String, dynamic>>().toList();
          } else {
            throw Exception('API returned error or unexpected data format for picker data: ${jsonData['message'] ?? response.body}');
          }
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Failed to fetch picker data: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> fetchFieldValues({
    required String server,
    required String UID,
    required String PWD,
    required String database,
    required String table,
    required String field,
  }) async {
    final url = _getEndpoints['fetch_tables_and_fields'];
    if (url == null) throw Exception('API endpoint not found for fetching field values.');

    final payload = {'server': server.trim(), 'UID': UID.trim(), 'PWD': PWD.trim(), 'Database': database.trim(), 'action': 'field', 'table': table.trim(), 'field': field.trim()};
    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'fetchFieldValues');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <String>[];
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData['status'] == 'success' && jsonData['data'] is List) {
            return List<String>.from(jsonData['data'].map((item) => item.toString()));
          } else {
            throw Exception('API returned error or unexpected data format: ${jsonData['message'] ?? response.body}');
          }
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Failed to fetch field values: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> getAvailableApis() async {
    final url = _getEndpoints['get_database_server'];
    if (url == null) throw Exception('GET API not found');

    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'GET', url: uri.toString(), functionName: 'getAvailableApis');

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <String>[];
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData['status'] == 'success') {
            _apiDetails = {};
            final uniqueApis = <String>{};
            for (var item in jsonData['data']) {
              if (item is Map<String, dynamic> && item['APIName'] != null) {
                final bool isDashboard = (item['IsDashboard'] == 1 || item['IsDashboard'] == '1' || item['IsDashboard'] == true);

                if (!uniqueApis.contains(item['APIName'])) {
                  uniqueApis.add(item['APIName']);
                  _apiDetails[item['APIName']] = {
                    'url': item['APIServerURl'],
                    'parameters': item['Parameter'] != null && item['Parameter'].toString().isNotEmpty ? jsonDecode(item['Parameter']) : <dynamic>[],
                    'serverIP': item['ServerIP'],
                    'userName': item['UserName'],
                    'password': item['Password'],
                    'databaseName': item['DatabaseName'],
                    'id': item['id'],
                    'IsDashboard': isDashboard,
                    'actions_config': item['actions_config'] != null && item['actions_config'].toString().isNotEmpty ? jsonDecode(item['actions_config']) : <dynamic>[],
                  };
                }
              }
            }
            return uniqueApis.toList();
          } else {
            throw Exception('API returned error: ${jsonData['message']}');
          }
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Failed to load APIs: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getApiDetails(String apiName) async {
    await _ensureApiDetailsCacheLoaded();
    if (_apiDetails.containsKey(apiName)) {
      return _apiDetails[apiName]!;
    } else {
      throw Exception('API details not found for "$apiName".');
    }
  }

  Future<List<Map<String, dynamic>>> fetchApiData(String apiName) async {
    final apiDetail = await getApiDetails(apiName);
    String baseUrl = apiDetail['url'];
    List<dynamic> parameters = apiDetail['parameters'] ?? [];
    Map<String, String> queryParams = {};
    for (var param in parameters) {
      if (param is Map) {
        final String paramName = param['name']?.toString() ?? '';
        final String paramValue = param['value']?.toString() ?? '';
        if (paramName.isNotEmpty) queryParams[paramName] = paramValue;
      }
    }
    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
    try {
      _logRequest(httpMethod: 'GET', url: uri.toString(), functionName: 'fetchApiData');
      final response = await http.get(uri);
      return _parseApiResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchReportDataFromUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'GET', url: uri.toString(), functionName: 'fetchReportDataFromUrl');
      final response = await http.get(uri).timeout(const Duration(seconds: 120));
      return _parseApiResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> fetchRawJsonFromUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'GET', url: uri.toString(), functionName: 'fetchRawJsonFromUrl');
      final response = await http.get(uri).timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        if (response.body.isEmpty) return {};
        try {
          return jsonDecode(response.body);
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Failed to fetch raw JSON from $url: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic>) {
              errorMessage += ' - ${errorData['message'] ?? response.body}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchApiDataWithParams(String apiName, Map<String, String> userParams, {String? actionApiUrlTemplate}) async {
    String effectiveBaseUrl;
    Map<String, String> finalQueryParams = {};

    if (actionApiUrlTemplate != null && actionApiUrlTemplate.isNotEmpty) {
      effectiveBaseUrl = actionApiUrlTemplate;
      final Uri tempUri = Uri.parse(effectiveBaseUrl);
      finalQueryParams.addAll(tempUri.queryParameters);
    } else {
      await _ensureApiDetailsCacheLoaded();
      final apiDetail = await getApiDetails(apiName);
      effectiveBaseUrl = apiDetail['url'];
      final Uri tempUri = Uri.parse(effectiveBaseUrl);
      finalQueryParams.addAll(tempUri.queryParameters);
      (apiDetail['parameters'] as List<dynamic>?)?.forEach((param) {
        if (param is Map) {
          final paramName = param['name']?.toString();
          final paramValue = param['value']?.toString();
          if (paramName != null && paramName.isNotEmpty) finalQueryParams[paramName] = paramValue ?? '';
        }
      });
    }

    finalQueryParams.addAll(userParams);
    final Uri baseUriNoQuery = Uri.parse(effectiveBaseUrl).removeFragment().replace(query: '');
    final uri = baseUriNoQuery.replace(queryParameters: finalQueryParams);

    try {
      _logRequest(httpMethod: 'GET', url: uri.toString(), functionName: 'fetchApiDataWithParams');
      final response = await http.get(uri).timeout(const Duration(seconds: 180));
      final parsedData = _parseApiResponse(response);
      return {'status': response.statusCode, 'data': parsedData, 'error': response.statusCode != 200 ? 'Failed to load data: ${response.statusCode}' : null};
    } catch (e) {
      return {'status': null, 'data': <Map<String, dynamic>>[], 'error': 'Failed to fetch data: $e'};
    }
  }

  List<Map<String, dynamic>> _parseApiResponse(http.Response response) {
    try {
      if (response.body.trim().isEmpty) {
        return response.statusCode == 200 ? <Map<String, dynamic>>[] : throw Exception('Empty response body: ${response.statusCode}');
      }
      try {
        final dynamic jsonData = jsonDecode(response.body);
        if (jsonData is List) {
          if (jsonData.isNotEmpty) {
            if (jsonData[0] is List) return (jsonData[0] as List).whereType<Map<String, dynamic>>().toList();
            if (jsonData[0] is Map<String, dynamic>) return jsonData.whereType<Map<String, dynamic>>().toList();
            throw Exception('List contains unexpected element type: ${jsonData[0].runtimeType}');
          }
          return <Map<String, dynamic>>[];
        } else if (jsonData is Map<String, dynamic>) {
          final status = jsonData['status'];
          final isSuccess = status == 'success' || status == 200 || status == '200';
          if (isSuccess && jsonData.containsKey('data')) {
            final data = jsonData['data'];
            if (data is List) return data.whereType<Map<String, dynamic>>().toList();
            if (data is Map<String, dynamic>) return [Map<String, dynamic>.from(data)];
            throw Exception('Data field must be a list or a map');
          } else if (!isSuccess && jsonData.containsKey('message')) {
            throw Exception('API returned error: ${jsonData['message']}');
          } else {
            throw Exception('Unexpected response format: ${response.body}');
          }
        } else {
          throw Exception('Invalid outermost response format: ${response.body}');
        }
      } on FormatException catch (e) {
        throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDemoTable() async {
    final url = _getEndpoints['get_demo_table'];
    if (url == null) throw Exception('GET API not found');

    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'GET', url: uri.toString(), functionName: 'fetchDemoTable');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <Map<String, dynamic>>[];
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData['status'] == 'success') {
            List<Map<String, dynamic>> reports = [];
            for (var item in jsonData['data']) {
              if (item is Map<String, dynamic>) {
                Map<String, dynamic> reportItem = Map.from(item);
                if (reportItem['actions_config'] is String && reportItem['actions_config'].toString().isNotEmpty) {
                  try {
                    reportItem['actions_config'] = jsonDecode(reportItem['actions_config'].toString());
                  } catch (e) {
                    reportItem['actions_config'] = <Map<String, dynamic>>[];
                  }
                } else {
                  reportItem['actions_config'] ??= <Map<String, dynamic>>[];
                }
                reportItem['pdf_footer_datetime'] = item['pdf_footer_datetime'] == '1' || item['pdf_footer_datetime'] == true;
                reports.add(reportItem);
              }
            }
            return reports;
          } else {
            throw Exception('API returned error: ${jsonData['message']}');
          }
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Failed to load data: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDemoTable2(String recNo) async {
    final url = _getEndpoints['get_demo_table2'];
    if (url == null) throw Exception('GET API not found');

    final fullUrl = '$url&RecNo=$recNo';
    try {
      final uri = Uri.parse(fullUrl);
      _logRequest(httpMethod: 'GET', url: uri.toString(), functionName: 'fetchDemoTable2');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <Map<String, dynamic>>[];
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData['status'] == 'success') {
            List<Map<String, dynamic>> fields = [];
            for (var item in (jsonData['data'] as List)) {
              if (item is Map<String, dynamic>) {
                Map<String, dynamic> fieldItem = Map.from(item);
                fieldItem['is_api_driven'] = item['is_api_driven'] == '1' || item['is_api_driven'] == true;
                fieldItem['api_url'] = item['api_url']?.toString() ?? '';
                fieldItem['field_params'] = item['field_params'] is String && item['field_params'].isNotEmpty ? (jsonDecode(item['field_params']) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
                fieldItem['is_user_filling'] = item['is_user_filling'] == '1' || item['is_user_filling'] == true;
                fieldItem['updated_url'] = item['updated_url']?.toString() ?? '';
                fieldItem['payload_structure'] = item['payload_structure'] is String && item['payload_structure'].isNotEmpty ? (jsonDecode(item['payload_structure']) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
                fields.add(fieldItem);
              }
            }
            return fields;
          } else {
            throw Exception('API returned error: ${jsonData['message']}');
          }
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Failed to load data: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<int> saveReport({
    required String reportName,
    required String reportLabel,
    required String apiName,
    required String parameter,
    required String ucode,
    required List<Map<String, dynamic>> fields,
    List<Map<String, dynamic>> actions = const <Map<String, dynamic>>[],
    required bool includePdfFooterDateTime,
  }) async {
    final url = _postEndpoints['post_demo_table'];
    if (url == null) throw Exception('POST API not found');

    final payload = {'Report_name': reportName, 'Report_label': reportLabel, 'API_name': apiName, 'Parameter': parameter,
      'ucode': ucode, 'actions_config': jsonEncode(actions), 'pdf_footer_datetime': includePdfFooterDateTime ? 1 : 0};
    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'saveReport');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) throw Exception('Failed to save report: ${response.statusCode} - ${response.body}');
      if (response.body.isEmpty) throw Exception('API returned empty response, cannot confirm save.');
      try {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] != 'success') throw Exception('API returned error: ${jsonData['message']}');
        final backendRecNo = int.tryParse(jsonData['RecNo'].toString());
        if (backendRecNo == null) throw Exception('API did not return a valid RecNo.');
        return backendRecNo;
      } on FormatException catch (e) {
        throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveDatabaseServer({
    required String serverIP,
    required String userName,
    required String password,
    required String databaseName,
    required String apiServerURL,
    required String apiName,
    required List<Map<String, dynamic>> parameters,
  }) async {
    final url = _postEndpoints['post_database_server'];
    if (url == null) throw Exception('POST API not found');
    if (serverIP.isEmpty || userName.isEmpty || password.isEmpty || databaseName.isEmpty || apiServerURL.isEmpty || (parameters.isNotEmpty && apiName.isEmpty)) {
      throw Exception('Invalid input parameters: All required fields must be provided');
    }
    final payload = {
      'ServerIP': serverIP.trim(),
      'UserName': userName.trim(),
      'Password': password.trim(),
      'DatabaseName': databaseName.trim(),
      'APIServerURl': apiServerURL.trim(),
      'APIName': apiName.trim(),
      'Parameter': parameters.isNotEmpty ? jsonEncode(parameters) : '',
      'IsDashboard': 0,
    };
    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'saveDatabaseServer');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) throw Exception('Failed to save database server: ${response.statusCode} - ${response.body}');
      if (response.body.isEmpty) return;
      try {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] != 'success') throw Exception('API returned error: ${jsonData['message']}');
      } on FormatException catch (e) {
        throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveFieldConfigs(List<Map<String, dynamic>> fields, int recNo) async {
    final url = _postEndpoints['post_demo_table2'];
    if (url == null) throw Exception('POST API not found');
    if (fields.isEmpty) return;

    for (final field in fields) {
      final payload = {
        'RecNo': recNo,
        'Field_name': field['Field_name']?.toString() ?? '',
        'Field_label': field['Field_label']?.toString() ?? field['Field_name']?.toString() ?? '',
        'Sequence_no': field['Sequence_no'] is int ? field['Sequence_no'] : int.tryParse(field['Sequence_no'].toString()) ?? 0,
        'width': field['width'] is int ? field['width'] : int.tryParse(field['width'].toString()) ?? 100,
        'Total': field['Total'] == true ? 1 : 0,
        'num_alignment': field['num_alignment']?.toString() ?? 'left',
        'time': field['time'] == true ? 1 : 0,
        'indian_format': field['num_format'] == true ? 1 : 0,
        'decimal_points': field['decimal_points'] is int ? field['decimal_points'] : int.tryParse(field['decimal_points'].toString()) ?? 0,
        'Breakpoint': field['Breakpoint'] == true ? 1 : 0,
        'SubTotal': field['SubTotal'] == true ? 1 : 0,
        'image': field['image'] == true ? 1 : 0,
        'Group_by': field['Group_by'] == true ? 1 : 0,
        'Filter': field['Filter'] == true ? 1 : 0,
        'filterJson': field['filterJson']?.toString() ?? '',
        'orderby': field['orderby'] == true ? 1 : 0,
        'orderjson': field['orderjson']?.toString() ?? '',
        'groupjson': field['groupjson']?.toString() ?? '',
        'is_api_driven': field['is_api_driven'] == true ? 1 : 0,
        'api_url': field['api_url']?.toString() ?? '',
        'field_params': jsonEncode(field['field_params'] ?? <Map<String, dynamic>>[]),
        'is_user_filling': field['is_user_filling'] == true ? 1 : 0,
        'updated_url': field['updated_url']?.toString() ?? '',
        'payload_structure': jsonEncode(field['payload_structure'] ?? <Map<String, dynamic>>[]),
      };

      try {
        final uri = Uri.parse(url);
        _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'saveFieldConfigs (field: ${field['Field_name']})');

        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (response.statusCode != 200) throw Exception('Failed to save field config for ${field['Field_name']}: ${response.statusCode} - ${response.body}');
        if (response.body.isEmpty) continue;
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData['status'] != 'success') throw Exception('API returned error: ${jsonData['message']}');
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } catch (e) {
        throw Exception('Failed to save field config for ${field['Field_name']}: $e');
      }
    }
  }

  Future<void> deleteDatabaseServer(String id) async {
    final url = _postEndpoints['delete_database_server'];
    if (url == null) throw Exception('POST API not found');
    final payload = {'id': id};
    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'deleteDatabaseServer');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) throw Exception('Failed to delete database server: ${response.statusCode} - ${response.body}');
      if (response.body.isEmpty) return;
      try {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] != 'success') throw Exception('API returned error: ${jsonData['message']}');
      } on FormatException catch (e) {
        throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> editDatabaseServer({
    required String id,
    required String serverIP,
    required String userName,
    required String password,
    required String databaseName,
    required String apiServerURL,
    required String apiName,
    required List<Map<String, dynamic>> parameters,
    required bool isDashboard,
  }) async {
    final url = _postEndpoints['edit_database_server'];
    if (url == null) throw Exception('POST API not found');
    final payload = {
      'id': id,
      'ServerIP': serverIP.trim(),
      'UserName': userName.trim(),
      'Password': password.trim(),
      'DatabaseName': databaseName.trim(),
      'APIServerURl': apiServerURL.trim(),
      'APIName': apiName.trim(),
      'Parameter': parameters.isNotEmpty ? jsonEncode(parameters) : '',
      'IsDashboard': isDashboard ? 1 : 0,
    };
    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'editDatabaseServer');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) throw Exception('Failed to edit database server: ${response.statusCode} - ${response.body}');
      if (response.body.isEmpty) return;
      try {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] != 'success') throw Exception('API returned error: ${jsonData['message']}');

        clearApiDetailsCache();
        debugPrint('ReportAPIService: Successfully edited database server, cache cleared.');
      } on FormatException catch (e) {
        throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> editDemoTables({
    required int recNo,
    required String reportName,
    required String reportLabel,
    required String apiName,
    required String parameter,
    required String ucode,
    required List<Map<String, dynamic>> fieldConfigs,
    required List<Map<String, dynamic>> actions,
    required bool includePdfFooterDateTime,
  }) async {
    final urlString = _postEndpoints['edit_demo_tables'];
    if (urlString == null) {
      throw Exception('POST API endpoint "edit_demo_tables" not found');
    }
    final url = Uri.parse(urlString);

    final payload = {
      'RecNo': recNo.toString(),
      'Demo_table': {
        'Report_name': reportName.trim(),
        'Report_label': reportLabel.trim(),
        'API_name': apiName.trim(),
        'Parameter': parameter.trim(),
        'ucode': ucode,
        'actions_config': jsonEncode(actions),
        'pdf_footer_datetime': includePdfFooterDateTime ? 1 : 0,
      },
      'Demo_table_2': fieldConfigs
    };

    try {
      _logRequest(httpMethod: 'POST', url: url.toString(), payload: payload, functionName: 'editDemoTables');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success') {
            return data;
          } else {
            throw Exception('API returned an error: ${data['message'] ?? 'Unknown error'}');
          }
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Server Error ${response.statusCode}';
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson is Map<String, dynamic> && errorJson['error'] != null) {
            errorMessage += ': ${errorJson['error']}';
          } else {
            errorMessage += ': Raw body: ${response.body}';
          }
        } catch (_) {
          errorMessage += ': Raw body: ${response.body}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Error in editDemoTables API call: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteDemoTables({required int recNo}) async {
    final url = _postEndpoints['delete_demo_tables'];
    if (url == null) throw Exception('POST API not found');
    final payload = {'RecNo': recNo};
    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'deleteDemoTables');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) throw Exception('Failed to delete demo tables: ${response.statusCode} - ${response.body}');
      if (response.body.isEmpty) return {'status': 'success', 'message': 'Operation completed but no response body.'};
      try {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] != 'success') throw Exception('API returned error: ${jsonData['message']}');
        return jsonData;
      } on FormatException catch (e) {
        throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
      }
    } catch (e) {
      rethrow;
    }
  }


  Future<Map<String, dynamic>> deployReportToClient({
    required Map<String, dynamic> reportMetadata,
    required List<Map<String, dynamic>> fieldConfigs,
    required String clientServerIP,
    required String clientUserName,
    required String clientPassword,
    required String clientDatabaseName,
  }) async {
    const jsonEncoder = JsonEncoder.withIndent('  ');

    debugPrint('\n\n======================================================');
    debugPrint('====== START deployReportToClient INVOCATION ======');
    debugPrint('======================================================');

    final url = _postEndpoints['deploy_report'];
    if (url == null) {
      debugPrint('[FATAL ERROR] Deployment URL ("deploy_report") is not defined in _postEndpoints map.');
      debugPrint('====================== DEPLOYMENT END ======================');
      throw Exception('POST API not found for deployment.');
    }

    debugPrint('Step 1: Deployment URL confirmed: $url');

    try {
      // Log the raw data received from the BLoC
      debugPrint('\n--- Step 2: Logging Raw Input Data ---');
      debugPrint('Client Server IP: "$clientServerIP"');
      debugPrint('Client User Name: "$clientUserName"');
      debugPrint('Client Password: "${clientPassword.isNotEmpty ? "********" : "EMPTY"}"');
      debugPrint('Client Database Name: "$clientDatabaseName"');
      debugPrint('--- Raw Report Metadata (from BLoC) ---');
      debugPrint(jsonEncoder.convert(reportMetadata));
      debugPrint('--- Raw Field Configs (from BLoC) ---');
      debugPrint('Field Configs Count: ${fieldConfigs.length}');
      debugPrint(jsonEncoder.convert(fieldConfigs));
      debugPrint('----------------------------------------');

      // Prepare payload and log it
      debugPrint('\n--- Step 3: Preparing Payload for HTTP POST ---');
      final payload = {
        'report_metadata': jsonEncode(reportMetadata),
        'field_configs': jsonEncode(fieldConfigs),
        'client_server': clientServerIP.trim(),
        'client_user': clientUserName.trim(),
        'client_password': clientPassword.trim(),
        'client_database': clientDatabaseName.trim()
      };

      debugPrint('--- Final Payload being sent to the server ---');
      debugPrint('This is the exact JSON body of the POST request.');
      debugPrint(jsonEncoder.convert(payload));
      debugPrint('------------------------------------------------');

      // Make the HTTP request
      final uri = Uri.parse(url);
      debugPrint('\n--- Step 4: Making the HTTP POST Request ---');
      _logRequest(httpMethod: 'POST', url: uri.toString(), functionName: 'deployReportToClient (INTERNAL)');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 180));

      // Log the full response
      debugPrint('\n--- Step 5: Received HTTP Response ---');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Headers:');
      debugPrint(jsonEncoder.convert(response.headers));
      debugPrint('--- Full Raw Response Body ---');
      debugPrint(response.body);
      debugPrint('----------------------------------');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          debugPrint('[ERROR] Response body is empty, but status code is 200. This is ambiguous.');
          throw Exception('Empty response body from deployment script.');
        }
        try {
          final Map<String, dynamic> decodedResponse = jsonDecode(response.body);
          debugPrint('\n--- Step 6: Successfully Parsed JSON Response ---');
          debugPrint(jsonEncoder.convert(decodedResponse));
          debugPrint('====================== DEPLOYMENT END (SUCCESS) ======================');
          return decodedResponse;
        } on FormatException catch (e) {
          debugPrint('[FATAL ERROR] Failed to parse the server\'s JSON response.');
          debugPrint('Error details: $e');
          debugPrint('====================== DEPLOYMENT END (ERROR) ======================');
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        debugPrint('[ERROR] Server returned a non-200 status code: ${response.statusCode}.');
        String errorMessage = 'Server error during deployment: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        debugPrint('Final error message to be thrown: "$errorMessage"');
        debugPrint('====================== DEPLOYMENT END (ERROR) ======================');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[FATAL CATCH BLOCK] An unexpected error occurred during deployment process.');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('====================== DEPLOYMENT END (ERROR) ======================');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> transferReportToDatabase({
    required Map<String, dynamic> reportMetadata,
    required List<Map<String, dynamic>> fieldConfigs,
    required String targetServerIP,
    required String targetUserName,
    required String targetPassword,
    required String targetDatabaseName,
  }) async {
    const jsonEncoder = JsonEncoder.withIndent('  ');

    debugPrint('\n\n======================================================');
    debugPrint('====== START transferReportToDatabase INVOCATION ======');
    debugPrint('======================================================');

    final url = _postEndpoints['transfer_report'];
    if (url == null) {
      debugPrint('[FATAL ERROR] Transfer URL ("transfer_report") is not defined in _postEndpoints map.');
      debugPrint('====================== TRANSFER END ======================');
      throw Exception('POST API not found for report transfer.');
    }

    debugPrint('Step 1: Transfer URL confirmed: $url');

    try {
      // Log the raw data received
      debugPrint('\n--- Step 2: Logging Raw Input Data ---');
      debugPrint('Target Server IP: "$targetServerIP"');
      debugPrint('Target User Name: "$targetUserName"');
      debugPrint('Target Password: "${targetPassword.isNotEmpty ? "********" : "EMPTY"}"');
      debugPrint('Target Database Name: "$targetDatabaseName"');
      debugPrint('--- Raw Report Metadata ---');
      debugPrint(jsonEncoder.convert(reportMetadata));
      debugPrint('--- Raw Field Configs ---');
      debugPrint('Field Configs Count: ${fieldConfigs.length}');
      debugPrint(jsonEncoder.convert(fieldConfigs));
      debugPrint('----------------------------------------');

      // Prepare payload and log it
      debugPrint('\n--- Step 3: Preparing Payload for HTTP POST ---');
      final payload = {
        'report_metadata': jsonEncode(reportMetadata),
        'field_configs': jsonEncode(fieldConfigs),
        'client_server': targetServerIP.trim(),       // WAS: 'target_server'
        'client_user': targetUserName.trim(),       // WAS: 'target_user'
        'client_password': targetPassword.trim(),     // WAS: 'target_password'
        'client_database': targetDatabaseName.trim()
      };

      debugPrint('--- Final Payload being sent to the server ---');
      debugPrint('This is the exact JSON body of the POST request.');
      debugPrint(jsonEncoder.convert(payload));
      debugPrint('------------------------------------------------');

      // Make the HTTP request
      final uri = Uri.parse(url);
      debugPrint('\n--- Step 4: Making the HTTP POST Request ---');
      _logRequest(httpMethod: 'POST', url: uri.toString(), functionName: 'transferReportToDatabase (INTERNAL)');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 180));

      // Log the full response
      debugPrint('\n--- Step 5: Received HTTP Response ---');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Headers:');
      debugPrint(jsonEncoder.convert(response.headers));
      debugPrint('--- Full Raw Response Body ---');
      debugPrint(response.body);
      debugPrint('----------------------------------');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          debugPrint('[ERROR] Response body is empty, but status code is 200. This is ambiguous.');
          throw Exception('Empty response body from transfer script.');
        }
        try {
          final Map<String, dynamic> decodedResponse = jsonDecode(response.body);
          debugPrint('\n--- Step 6: Successfully Parsed JSON Response ---');
          debugPrint(jsonEncoder.convert(decodedResponse));
          debugPrint('====================== TRANSFER END (SUCCESS) ======================');
          return decodedResponse;
        } on FormatException catch (e) {
          debugPrint('[FATAL ERROR] Failed to parse the server\'s JSON response.');
          debugPrint('Error details: $e');
          debugPrint('====================== TRANSFER END (ERROR) ======================');
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        debugPrint('[ERROR] Server returned a non-200 status code: ${response.statusCode}.');
        String errorMessage = 'Server error during transfer: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        debugPrint('Final error message to be thrown: "$errorMessage"');
        debugPrint('====================== TRANSFER END (ERROR) ======================');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[FATAL CATCH BLOCK] An unexpected error occurred during the transfer process.');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('====================== DEPLOYMENT END (ERROR) ======================');
      // **** MODIFICATION HERE ****
      // Instead of rethrowing a raw ClientException, throw a clean, readable Exception.
      throw Exception('Network Error: Could not connect to the deployment server. Please check the server address and your network connection.');
    }
  }

  Future<Map<String, dynamic>> postJson(String url, Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'postJson');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return {'status': 'success', 'message': 'Operation successful with no content.'};
        try {
          final decodedBody = jsonDecode(response.body);
          if (decodedBody is List && decodedBody.isNotEmpty) {
            if (decodedBody[0] is Map<String, dynamic>) {
              final Map<String, dynamic> result = decodedBody[0];
              if (result.containsKey('ResultStatus') && !result.containsKey('status')) {
                result['status'] = result['ResultStatus']?.toString().toLowerCase();
              }
              return result;
            }
          } else if (decodedBody is Map<String, dynamic>) {
            return decodedBody;
          }
          throw Exception('Unexpected JSON format from server: ${response.body}');
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Server error: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorBody = jsonDecode(response.body);
            if (errorBody is Map<String, dynamic>) return errorBody;
          } catch (_) {
            errorMessage += ' - ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Failed to process request: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> getDashboards() async {
    final url = _getEndpoints['get_dashboards'];
    if (url == null) throw Exception('GET API not found for dashboards');

    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'GET', url: uri.toString(), functionName: 'getDashboards');

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <Map<String, dynamic>>[];
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData['status'] == 'success' && jsonData['data'] is List) {
            return List<Map<String, dynamic>>.from(jsonData['data']);
          } else {
            throw Exception('API returned error or unexpected data format: ${jsonData['message'] ?? response.body}');
          }
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Failed to load dashboards: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> saveDashboard({
    required String dashboardName,
    String? dashboardDescription,
    required String templateId,
    required Map<String, dynamic> layoutConfig,
    Map<String, dynamic>? globalFiltersConfig,
  }) async {
    final url = _postEndpoints['post_dashboard'];
    if (url == null) throw Exception('POST API not found for saving dashboard');

    final payload = {
      'DashboardName': dashboardName.trim(),
      'DashboardDescription': dashboardDescription?.trim(),
      'TemplateID': templateId.trim(),
      'LayoutConfig': jsonEncode(layoutConfig),
      'GlobalFiltersConfig': globalFiltersConfig != null ? jsonEncode(globalFiltersConfig) : null,
    };

    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'saveDashboard');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.isEmpty) throw Exception('API returned empty response for save dashboard.');
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData['status'] == 'success') {
            final dashboardId = jsonData['DashboardID']?.toString();
            if (dashboardId == null || dashboardId.isEmpty) {
              throw Exception('API did not return a valid DashboardID.');
            }
            return dashboardId;
          } else {
            throw Exception('API returned error: ${jsonData['message']}');
          }
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Failed to save dashboard: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Error in saveDashboard: $e');
      rethrow;
    }
  }

  Future<void> editDashboard({
    required String dashboardId,
    required String dashboardName,
    String? dashboardDescription,
    required String templateId,
    required Map<String, dynamic> layoutConfig,
    Map<String, dynamic>? globalFiltersConfig,
  }) async {
    final url = _postEndpoints['edit_dashboard'];
    if (url == null) throw Exception('POST API not found for editing dashboard');

    final payload = {
      'DashboardID': dashboardId,
      'DashboardName': dashboardName.trim(),
      'DashboardDescription': dashboardDescription?.trim(),
      'TemplateID': templateId.trim(),
      'LayoutConfig': jsonEncode(layoutConfig),
      'GlobalFiltersConfig': globalFiltersConfig != null ? jsonEncode(globalFiltersConfig) : null,
    };

    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'editDashboard');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to edit dashboard: ${response.statusCode} - ${response.body}');
      }
      if (response.body.isEmpty) return;
      try {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] != 'success') {
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } on FormatException catch (e) {
        throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
      }
    } catch (e) {
      debugPrint('Error in editDashboard: $e');
      rethrow;
    }
  }

  Future<void> deleteDashboard({required String dashboardId}) async {
    final url = _postEndpoints['delete_dashboard'];
    if (url == null) throw Exception('POST API not found for deleting dashboard');

    final payload = {'DashboardID': dashboardId};

    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'deleteDashboard');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete dashboard: ${response.statusCode} - ${response.body}');
      }
      if (response.body.isEmpty) return;
      try {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] != 'success') {
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } on FormatException catch (e) {
        throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
      }
    } catch (e) {
      debugPrint('Error in deleteDashboard: $e');
      rethrow;
    }
  }

  Future<dynamic> getReportData(String? url) async {
    if (url == null || url.isEmpty) {
      throw Exception('API URL for graph data is missing.');
    }

    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'GET', url: uri.toString(), functionName: 'getReportData');
      final response = await http.get(uri).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('API returned an empty response.');
        }
        try {
          return jsonDecode(response.body);
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Failed to load report data: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Error in getReportData: $e');
      rethrow;
    }
  }



  Future<void> saveSetupConfiguration({
    required String configName,
    required String serverIP,
    required String userName,
    required String password,
    // UPDATED: Added new required parameters
    required String databaseName,
    required String connectionString,
  }) async {
    final uri = Uri.parse(_setupApiUrl);

    final payload = {
      'configName': configName,
      'serverIP': serverIP,
      'userName': userName,
      'password': password,
      'databaseName': databaseName,
      'connectionString': connectionString,
    };

    _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'saveSetupConfiguration');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (response.body.isEmpty) {
          debugPrint('ReportAPIService: saveSetupConfiguration received empty body with success status.');
          return;
        }
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData is Map<String, dynamic> && jsonData.containsKey('message')) {
            debugPrint('Setup Configuration saved: ${jsonData['message']}');
          } else {
            throw Exception('Unexpected response format: ${response.body}');
          }
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Failed to save setup configuration: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      // Rethrows the exception to be handled by the BLoC
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSetupConfigurations() async {
    final uri = Uri.parse(_setupApiUrl);
    _logRequest(httpMethod: 'GET', url: uri.toString(), functionName: 'getSetupConfigurations');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          // If body is empty but status is 200, return a success map with empty data
          return {'status': 'success', 'data': []};
        }
        try {
          final dynamic jsonData = jsonDecode(response.body);
          // Directly return the parsed JSON data, as the Bloc expects a Map
          // and will handle extracting the 'data' key.
          if (jsonData is Map<String, dynamic>) {
            // Log the full received map for debugging, as per your original problem
            debugPrint('Received full response map for getSetupConfigurations: ${response.body}');
            return jsonData;
          } else {
            // If it's not a map (e.g., a direct list, or other unexpected format)
            // convert it to a map with a 'data' key for consistency with the bloc's expectation
            // (This fallback might be less common if backend is consistent)
            if (jsonData is List) {
              return {'status': 'success', 'data': jsonData};
            }
            throw Exception('Unexpected response format for GET setup configurations: ${response.body}');
          }
        } on FormatException catch (e) {
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Failed to fetch setup configurations: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> transferFullDashboard({
    required Map<String, dynamic> dashboardData,
    required String clientServerIP,
    required String clientUserName,
    required String clientPassword,
    required String clientDatabaseName,
  }) async {
    // For pretty printing JSON in logs
    const jsonEncoder = JsonEncoder.withIndent('  ');

    debugPrint('\n\n======================================================');
    debugPrint('====== START transferFullDashboard INVOCATION ======');
    debugPrint('======================================================');

    final url = _postEndpoints['transfer_full_dashboard'];
    if (url == null) {
      debugPrint('[FATAL ERROR] The URL for "transfer_full_dashboard" is not defined in the _postEndpoints map.');
      throw Exception('POST API not found for full dashboard transfer.');
    }
    debugPrint('--- Step 1: Endpoint URL confirmed: $url');


    // Step 2: Extract all unique report RecNo's from the dashboard layout
    final Set<String> reportRecNos = {};
    try {
      dynamic layoutConfig = dashboardData['LayoutConfig'];
      if (layoutConfig is String) {
        layoutConfig = jsonDecode(layoutConfig);
      }

      if (layoutConfig != null && layoutConfig['report_groups'] is List) {
        for (var group in (layoutConfig['report_groups'] as List)) {
          if (group['reports'] is List) {
            for (var report in (group['reports'] as List)) {
              if (report['reportRecNo'] != null) {
                reportRecNos.add(report['reportRecNo'].toString());
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[FATAL ERROR] Failed to parse dashboard LayoutConfig: $e');
      throw Exception('Failed to parse dashboard LayoutConfig to find report dependencies: $e');
    }

    debugPrint('--- Step 2: Extracted ${reportRecNos.length} unique report dependencies: ${reportRecNos.toList()}');

    // Step 3: Fetch the full data for each dependent report
    final List<Map<String, dynamic>> fullReportsData = [];
    debugPrint('--- Step 3a: Fetching all report metadata from the source (fetchDemoTable)...');
    final List<Map<String, dynamic>> allSourceReports = await fetchDemoTable();
    debugPrint('--- -> Found ${allSourceReports.length} total reports in the source system.');


    for (String recNoStr in reportRecNos) {
      debugPrint('--- Step 3b: Processing dependency for RecNo: $recNoStr');
      final int recNo = int.parse(recNoStr);

      final reportMetadata = allSourceReports.firstWhere(
            (r) => r['RecNo'].toString() == recNoStr,
        orElse: () {
          debugPrint('[FATAL ERROR] Could not find report metadata for RecNo $recNo in the fetched list.');
          throw Exception('Could not find report metadata for RecNo $recNo');
        },
      );
      debugPrint('--- -> Found metadata for RecNo: $recNoStr');

      final fieldConfigs = await fetchDemoTable2(recNoStr);
      debugPrint('--- -> Found ${fieldConfigs.length} field configurations for RecNo: $recNoStr');

      fullReportsData.add({
        'report_metadata': reportMetadata,
        'field_configs': fieldConfigs,
      });
    }
    debugPrint('--- Step 3c: Successfully bundled all ${fullReportsData.length} reports with their field configs.');


    // Step 4: Assemble the final payload for the API
    final payload = {
      'dashboard_data':dashboardData,
      'reports':  fullReportsData,
      'client_server': clientServerIP.trim(),
      'client_user': clientUserName.trim(),
      'client_password': clientPassword.trim(),
      'client_database': clientDatabaseName.trim(),
    };

    debugPrint('--- Step 4: Final payload assembled. Preparing to send...');
    // The _logRequest function will pretty-print the full payload.

    // Step 5: Make the API call
    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'POST', url: uri.toString(), payload: payload, functionName: 'transferFullDashboard (INTERNAL)');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 300));

      debugPrint('\n--- Step 5: Received HTTP Response ---');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Headers:\n${jsonEncoder.convert(response.headers)}');
      debugPrint('--- Full Raw Response Body ---\n${response.body}');
      debugPrint('----------------------------------');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          debugPrint('[ERROR] Transfer script returned an empty body with a 200 OK status. This is ambiguous.');
          throw Exception('Empty response body from the transfer script.');
        }
        try {
          final decodedResponse = jsonDecode(response.body);
          debugPrint('--- Step 6: Successfully parsed JSON response.');
          debugPrint('====================== TRANSFER END (SUCCESS) ======================');
          return decodedResponse;
        } on FormatException catch (e) {
          debugPrint('[FATAL ERROR] The server response was not valid JSON.');
          throw Exception('Failed to parse response JSON: $e. Raw response: "${response.body}".');
        }
      } else {
        String errorMessage = 'Server error during transfer: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
              errorMessage += ' - ${errorData['message']}';
            } else {
              errorMessage += ' - Raw body: ${response.body}';
            }
          } catch (_) {
            errorMessage += ' - Raw body: ${response.body}';
          }
        }
        debugPrint('[ERROR] Server returned a non-200 status code. Final error message to be thrown: "$errorMessage"');
        debugPrint('====================== TRANSFER END (SERVER ERROR) ======================');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[FATAL CATCH BLOCK] An unexpected error occurred during the HTTP request.');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('====================== TRANSFER END (CRITICAL ERROR) ======================');
      // This is where the CORS ClientException is caught. We rethrow it so the UI can display the message.
      rethrow;
    }
  }

  /// Fetches all reports that are associated with a specific database.
  ///
  /// It works by:
  /// 1. Fetching all reports from `demo_table`.
  /// 2. For each report, it looks up the details of its associated API.
  /// 3. It then checks if the database name for that API matches the provided [databaseName].
  /// 4. Returns a list of all matching reports.
  Future<List<Map<String, dynamic>>> fetchReportsForApi(String databaseName) async {
    _logRequest(httpMethod: 'INTERNAL', url: 'N/A', functionName: 'fetchReportsForApi(databaseName: $databaseName)');
    try {
      // Step 1: Fetch all reports from demo_table.
      final List<Map<String, dynamic>> allReports = await fetchDemoTable();
      final List<Map<String, dynamic>> matchedReports = [];

      // Step 2: Iterate through each report to check its database connection.
      for (final report in allReports) {
        final String? apiName = report['API_name']?.toString();

        if (apiName != null && apiName.isNotEmpty) {
          try {
            // Step 3: Get the details for the API linked to the report.
            final apiDetails = await getApiDetails(apiName);
            final String? apiDatabaseName = apiDetails['databaseName']?.toString();

            // Step 4: Compare the database name and add to collection if it matches.
            if (apiDatabaseName == databaseName) {
              matchedReports.add(report);
            }
          } catch (e) {
            // This catch block handles cases where a report in demo_table
            // references an API_name that no longer exists in demotable1.
            debugPrint('Could not retrieve details for API \'$apiName\'. It might be misconfigured or deleted. Skipping report \'${report['Report_name']}\'. Error: $e');
          }
        }
      }
      return matchedReports;
    } catch (e) {
      debugPrint('An error occurred in fetchReportsForApi: $e');
      rethrow; // Rethrow the error to be handled by the caller.
    }
  }
}