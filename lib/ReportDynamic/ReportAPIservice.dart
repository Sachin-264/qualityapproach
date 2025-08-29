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

  // Cache for API connection details
  Map<String, Map<String, dynamic>> _apiDetails = {};
  Completer<void>? _apiDetailsLoadingCompleter;

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

  // A standardized logging utility
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

  /// Ensures that the API details from the `DatabaseServerMaster` table are loaded and cached.
  /// This prevents multiple unnecessary fetches.
  Future<void> _ensureApiDetailsCacheLoaded() async {
    // If a load is already in progress, wait for it to complete.
    if (_apiDetailsLoadingCompleter != null && !_apiDetailsLoadingCompleter!.isCompleted) {
      debugPrint('ReportAPIService: API details cache load in progress. Waiting...');
      return _apiDetailsLoadingCompleter!.future;
    }

    // If the cache is empty, start a new load operation.
    if (_apiDetails.isEmpty) {
      _apiDetailsLoadingCompleter = Completer<void>();
      debugPrint('ReportAPIService: Initiating new API details cache load.');
      try {
        // The getAvailableApis method populates the cache.
        await getAvailableApis();
        _apiDetailsLoadingCompleter!.complete();
      } catch (e) {
        _apiDetailsLoadingCompleter!.completeError(e);
        debugPrint('ReportAPIService: [CRITICAL] Error during API details cache load: $e');
        rethrow; // Rethrow so the caller knows it failed.
      } finally {
        _apiDetailsLoadingCompleter = null;
      }
    }
  }


  Future<List<String>> getAvailableApis() async {
    final url = _getEndpoints['get_database_server'];
    if (url == null) throw Exception('GET API not found for get_database_server');

    debugPrint('\n\n✅ =======================================================');
    debugPrint('✅ STARTING DIAGNOSTIC FETCH: getAvailableApis');
    debugPrint('✅ This function fetches data from your DatabaseServerMaster table.');
    debugPrint('✅ =======================================================\n');

    try {
      final uri = Uri.parse(url);
      _logRequest(httpMethod: 'GET', url: uri.toString(), functionName: 'getAvailableApis');

      debugPrint('STEP 1: Making HTTP GET request to the server...');
      final response = await http.get(uri);
      debugPrint('STEP 2: Received response from server with Status Code: ${response.statusCode}');

      debugPrint('\n--- 🔍 START: RAW RESPONSE BODY FROM SERVER 🔍 ---');
      debugPrint(response.body);
      debugPrint('--- 🔍 END: RAW RESPONSE BODY FROM SERVER 🔍 ---\n');

      if (response.statusCode != 200) {
        throw Exception('Request failed with non-200 status code. See RAW RESPONSE above for server error message.');
      }

      if (response.body.isEmpty) {
        debugPrint('⚠️ WARNING: Response body is empty. The server returned no data.');
        return <String>[];
      }

      dynamic jsonData;
      try {
        debugPrint('STEP 3: Attempting to parse the raw response body as JSON...');
        jsonData = jsonDecode(response.body);
        debugPrint('STEP 4: Successfully parsed JSON. Checking "status" key...');
      } on FormatException catch (e, stackTrace) {
        debugPrint('[FATAL] Failed to parse response JSON. The RAW RESPONSE above is not valid JSON.');
        debugPrint('Error: $e');
        debugPrint('Stack Trace: $stackTrace');
        throw Exception('Failed to parse response JSON: $e.');
      }

      if (jsonData is! Map<String, dynamic> || jsonData['status'] != 'success') {
        throw Exception('API returned status="${jsonData['status']}", message: ${jsonData['message']}');
      }

      debugPrint('STEP 5: JSON status is "success". Clearing old cache and processing new data...');
      _apiDetails = {}; // Clear previous cache
      final uniqueApis = <String>{};

      final List<dynamic> dataList = jsonData['data'] ?? [];
      debugPrint(' -> Found ${dataList.length} items in the "data" array.');

      for (var item in dataList) {
        if (item is! Map<String, dynamic>) {
          debugPrint('   -> ⚠️ SKIPPED item because it was not a valid map.');
          continue;
        }

        final String? apiName = item['APIName']?.toString();
        if (apiName == null || apiName.isEmpty) {
          debugPrint('   -> ⚠️ SKIPPED item because its APIName is null or empty. Item data: $item');
          continue;
        }

        debugPrint('   -> Processing item with APIName: "$apiName"');
        if (uniqueApis.contains(apiName)) {
          debugPrint('      ⚠️ SKIPPED duplicate APIName: "$apiName"');
          continue;
        }

        List<dynamic> parsedParameters = [];
        try {
          // ========== FIX #2 HERE ==========
          final rawParams = item['parameters']; // Changed from 'Parameter' to match JSON
          if (rawParams is String && rawParams.isNotEmpty) {
            parsedParameters = jsonDecode(rawParams);
          } else if (rawParams is List) { // Also handle if it's already a list
            parsedParameters = rawParams;
          }
        } catch (e) {
          debugPrint('      [WARNING] Could not parse "parameters" JSON for $apiName: $e. Defaulting to empty list.');
        }

        List<dynamic> parsedActions = [];
        try {
          final rawActions = item['actions_config'];
          if (rawActions is String && rawActions.isNotEmpty) {
            parsedActions = jsonDecode(rawActions);
          } else if (rawActions is List) {
            parsedActions = rawActions;
          }
        } catch(e) {
          debugPrint('      [WARNING] Could not parse "actions_config" JSON for $apiName: $e. Defaulting to empty list.');
        }

        uniqueApis.add(apiName);
        _apiDetails[apiName] = {
          // ========== FIX #1 HERE ==========
          'url': item['url']?.toString() ?? '', // Changed 'APIServerURl' to 'url'
          // ===================================
          'parameters': parsedParameters,
          'serverIP': item['ServerIP']?.toString() ?? '',
          'userName': item['UserName']?.toString() ?? '',
          'password': item['Password']?.toString() ?? '',
          'databaseName': item['DatabaseName']?.toString() ?? '',
          'id': item['id']?.toString() ?? '',
          'IsDashboard': item['IsDashboard'] == 1 || item['IsDashboard'] == '1' || item['IsDashboard'] == true,
          'actions_config': parsedActions,
          'connectionString': item['connectionString']?.toString(),
        };

        debugPrint('      ✅ CACHED details for "$apiName"');
      }
      debugPrint('\nSTEP 6: Finished processing. Total unique APIs cached: ${uniqueApis.length}');
      return uniqueApis.toList();

    } catch (e, stackTrace) {
      debugPrint('\n❌ =======================================================');
      debugPrint('❌ CRITICAL ERROR in getAvailableApis');
      debugPrint('❌ Error Type: ${e.runtimeType}');
      debugPrint('❌ Error: $e');
      debugPrint('❌ StackTrace: $stackTrace');
      debugPrint('❌ =======================================================\n');
      rethrow;
    } finally {
      debugPrint('\n🏁 =======================================================');
      debugPrint('🏁 FINISHED DIAGNOSTIC FETCH: getAvailableApis');
      debugPrint('🏁 =======================================================\n');
    }
  }


  Future<Map<String, dynamic>> getApiDetails(String apiName) async {
    await _ensureApiDetailsCacheLoaded();
    final details = _apiDetails[apiName];
    if (details != null) {
      return details;
    } else {
      // This provides a more helpful error message if an API name is requested but not found.
      debugPrint('[FATAL] API details not found for "$apiName". Available APIs are: ${_apiDetails.keys.toList()}');
      throw Exception('API details not found for "$apiName".');
    }
  }

  // --- START: FULLY REVAMPED fetchApiDataWithParams with ROBUST LOGGING AND ERROR HANDLING ---
  Future<Map<String, dynamic>> fetchApiDataWithParams(String apiName, Map<String, String> userParams, {String? actionApiUrlTemplate}) async {
    String effectiveBaseUrl;
    Map<String, String> finalQueryParams = {};

    debugPrint('--- [fetchApiDataWithParams] Preparing API call for "$apiName" ---');

    try {
      if (actionApiUrlTemplate != null && actionApiUrlTemplate.isNotEmpty) {
        effectiveBaseUrl = actionApiUrlTemplate;
        debugPrint(' -> Using provided actionApiUrlTemplate: $effectiveBaseUrl');
        final Uri tempUri = Uri.parse(effectiveBaseUrl);
        finalQueryParams.addAll(tempUri.queryParameters);
      } else {
        await _ensureApiDetailsCacheLoaded();
        final apiDetail = await getApiDetails(apiName);
        effectiveBaseUrl = apiDetail['url'] ?? '';
        if (effectiveBaseUrl.isEmpty) {
          throw Exception('API URL is missing for "$apiName" in cached details.');
        }
        debugPrint(' -> Using cached API URL: $effectiveBaseUrl');
        final Uri tempUri = Uri.parse(effectiveBaseUrl);
        finalQueryParams.addAll(tempUri.queryParameters);

        // Safely add default parameters from cache
        (apiDetail['parameters'] as List<dynamic>?)?.forEach((param) {
          if (param is Map) {
            final paramName = param['name']?.toString();
            // IMPORTANT: Safely get the value, defaulting to empty string if null
            final paramValue = param['value']?.toString() ?? '';
            if (paramName != null && paramName.isNotEmpty) {
              finalQueryParams[paramName] = paramValue;
            }
          }
        });
      }

      // Override with user-provided parameters
      finalQueryParams.addAll(userParams);
      debugPrint(' -> Final combined query parameters: $finalQueryParams');

      final Uri baseUriNoQuery = Uri.parse(effectiveBaseUrl).removeFragment().replace(query: '');
      final uri = baseUriNoQuery.replace(queryParameters: finalQueryParams);

      _logRequest(httpMethod: 'GET', url: uri.toString(), functionName: 'fetchApiDataWithParams');
      final response = await http.get(uri).timeout(const Duration(seconds: 180));

      debugPrint(' -> Received response with status code: ${response.statusCode}');
      debugPrint(' -> Raw response body:\n${response.body}');

      final parsedData = _parseApiResponse(response);
      return {'status': response.statusCode, 'data': parsedData, 'error': null};
    } catch (e, stackTrace) {
      // THIS IS THE CRITICAL LOGGING YOU NEEDED
      debugPrint('--- [fetchApiDataWithParams] CRITICAL ERROR CAUGHT ---');
      debugPrint(' -> Error Type: ${e.runtimeType}');
      debugPrint(' -> Error Message: $e');
      debugPrint(' -> Stack Trace:\n$stackTrace');
      debugPrint('----------------------------------------------------');
      // Return a structured error so the BLoC can display it
      return {'status': 500, 'data': <Map<String, dynamic>>[], 'error': 'Failed to fetch data: $e'};
    }
  }
  // --- END: FULLY REVAMPED fetchApiDataWithParams ---

  // --- START: FULLY REVAMPED _parseApiResponse with ROBUST LOGGING AND NULL SAFETY ---
  List<Map<String, dynamic>> _parseApiResponse(http.Response response) {
    debugPrint("--- [_parseApiResponse] Starting to parse response (Status: ${response.statusCode}) ---");
    if (response.body.trim().isEmpty) {
      if (response.statusCode == 200) {
        debugPrint(" -> Response body is empty but status is 200. Returning empty list.");
        return <Map<String, dynamic>>[];
      } else {
        throw Exception('API Error: Empty response body with status code ${response.statusCode}');
      }
    }

    try {
      final dynamic jsonData = jsonDecode(response.body);
      debugPrint(" -> Successfully decoded JSON. Detected type: ${jsonData.runtimeType}");

      // Case 1: The entire response is a JSON array
      if (jsonData is List) {
        debugPrint(" -> JSON is a List. Processing as a direct data array.");
        // Ensure all elements are of the correct type before returning
        return jsonData.whereType<Map<String, dynamic>>().toList();
      }
      // Case 2: The response is a JSON object (most common)
      else if (jsonData is Map<String, dynamic>) {
        debugPrint(" -> JSON is a Map. Looking for 'status' and 'data' keys.");
        final status = jsonData['status'];
        final isSuccess = status == 'success' || status == 200 || status == '200';

        if (isSuccess && jsonData.containsKey('data')) {
          final data = jsonData['data'];
          debugPrint(" -> Status is 'success' and 'data' key exists. Data type is: ${data.runtimeType}");
          if (data is List) {
            return data.whereType<Map<String, dynamic>>().toList();
          }
          if (data is Map<String, dynamic>) {
            return [Map<String, dynamic>.from(data)];
          }
          // Handle case where 'data' is null or not a List/Map
          if (data == null) {
            debugPrint(" -> 'data' key was found, but its value is null. Returning empty list.");
            return [];
          }
          throw Exception("'data' field was found but is not a List or Map. It is: ${data.runtimeType}");

        } else if (!isSuccess && jsonData.containsKey('message')) {
          final errorMessage = jsonData['message']?.toString() ?? 'Unknown API Error';
          throw Exception('API returned an error: $errorMessage');
        } else {
          // This can happen for APIs that return a single JSON object without a status wrapper
          debugPrint(" -> No 'status'/'data' wrapper found. Treating the whole map as a single data item.");
          return [jsonData];
        }
      }
      // Case 3: Unexpected JSON format
      else {
        throw Exception('Invalid response format: Expected a JSON List or Map, but got ${jsonData.runtimeType}');
      }
    } on FormatException catch (e, stackTrace) {
      debugPrint('[FATAL] Failed to parse response JSON. See raw body in previous log.');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      throw Exception('Failed to parse response JSON: $e.');
    } catch (e, stackTrace) {
      debugPrint('[FATAL] An unexpected error occurred during API response parsing.');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
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
    if (url == null) throw Exception('GET API not found for get_demo_table2');

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
            if (jsonData['data'] is! List) {
              throw Exception('API response for demo_table_2 did not contain a list in the "data" key.');
            }
            for (var item in (jsonData['data'] as List)) {
              if (item is Map<String, dynamic>) {
                Map<String, dynamic> fieldItem = Map.from(item);

                fieldItem['is_api_driven'] = item['is_api_driven'] == '1' || item['is_api_driven'] == true;
                fieldItem['api_url'] = item['api_url']?.toString() ?? '';

                try {
                  final fieldParamsValue = item['field_params'];
                  if (fieldParamsValue is String && fieldParamsValue.isNotEmpty) {
                    fieldItem['field_params'] = (jsonDecode(fieldParamsValue) as List).cast<Map<String, dynamic>>();
                  } else if (fieldParamsValue is List) {
                    fieldItem['field_params'] = fieldParamsValue.cast<Map<String, dynamic>>();
                  } else {
                    fieldItem['field_params'] = <Map<String, dynamic>>[];
                  }
                } catch (e) {
                  debugPrint('Could not parse field_params for RecNo $recNo: $e. Defaulting to empty list.');
                  fieldItem['field_params'] = <Map<String, dynamic>>[];
                }

                fieldItem['is_user_filling'] = item['is_user_filling'] == '1' || item['is_user_filling'] == true;
                fieldItem['updated_url'] = item['updated_url']?.toString() ?? '';

                try {
                  final payloadStructureValue = item['payload_structure'];
                  if (payloadStructureValue is String && payloadStructureValue.isNotEmpty) {
                    fieldItem['payload_structure'] = (jsonDecode(payloadStructureValue) as List).cast<Map<String, dynamic>>();
                  } else if (payloadStructureValue is List) {
                    fieldItem['payload_structure'] = payloadStructureValue.cast<Map<String, dynamic>>();
                  } else {
                    fieldItem['payload_structure'] = <Map<String, dynamic>>[];
                  }
                } catch (e) {
                  debugPrint('Could not parse payload_structure for RecNo $recNo: $e. Defaulting to empty list.');
                  fieldItem['payload_structure'] = <Map<String, dynamic>>[];
                }

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
        String errorMessage = 'Failed to load data from demo_table_2: ${response.statusCode}';
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
      debugPrint('Critical error in fetchDemoTable2 for RecNo $recNo: $e');
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

      final uri = Uri.parse(url);
      debugPrint('\n--- Step 4: Making the HTTP POST Request ---');
      _logRequest(httpMethod: 'POST', url: uri.toString(), functionName: 'deployReportToClient (INTERNAL)');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 180));

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
    required String targetConnectionString,
  }) async {
    const jsonEncoder = JsonEncoder.withIndent('  ');

    debugPrint('\n\n======================================================');
    debugPrint('====== START transferReportToDatabase INVOCATION ======');
    debugPrint('======================================================');

    final url = _postEndpoints['transfer_report'];
    if (url == null) {
      debugPrint('[FATAL ERROR] Transfer URL ("transfer_report") is not defined in _postEndpoints map.');
      debugPrint('====================== TRANSFER END ======================');
      throw Exception('POST API not found for transfer.');
    }

    debugPrint('Step 1: Transfer URL confirmed: $url');

    try {
      debugPrint('\n--- Step 2: Logging Raw Input Data ---');
      debugPrint('Target Server IP: "$targetServerIP"');
      debugPrint('Target User Name: "$targetUserName"');
      debugPrint('Target Password: "${targetPassword.isNotEmpty ? "********" : "EMPTY"}"');
      debugPrint('Target Database Name: "$targetDatabaseName"');
      debugPrint('Target Connection String: "$targetConnectionString"');
      debugPrint('--- Raw Report Metadata (from BLoC) ---');
      debugPrint(jsonEncoder.convert(reportMetadata));
      debugPrint('--- Raw Field Configs (from BLoC) ---');
      debugPrint('Field Configs Count: ${fieldConfigs.length}');
      debugPrint(jsonEncoder.convert(fieldConfigs));
      debugPrint('----------------------------------------');

      debugPrint('\n--- Step 3: Preparing Payload for HTTP POST ---');
      final payload = {
        'report_metadata': jsonEncode(reportMetadata),
        'field_configs': jsonEncode(fieldConfigs),
        'client_server': targetServerIP.trim(),
        'client_user': targetUserName.trim(),
        'client_password': targetPassword.trim(),
        'client_database': targetDatabaseName.trim(),
        'targetconnectionstring': targetConnectionString.trim(),
      };

      debugPrint('--- Final Payload being sent to the server ---');
      debugPrint('This is the exact JSON body of the POST request.');
      debugPrint(jsonEncoder.convert(payload));
      debugPrint('------------------------------------------------');

      final uri = Uri.parse(url);
      debugPrint('\n--- Step 4: Making the HTTP POST Request ---');
      _logRequest(httpMethod: 'POST', url: uri.toString(), functionName: 'transferReportToDatabase (INTERNAL)');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 180));

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
      debugPrint('[FATAL CATCH BLOCK] An unexpected error occurred during transfer process.');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('====================== TRANSFER END (ERROR) ======================');
      rethrow;
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
          return {'status': 'success', 'data': []};
        }
        try {
          final dynamic jsonData = jsonDecode(response.body);
          if (jsonData is Map<String, dynamic>) {
            debugPrint('Received full response map for getSetupConfigurations: ${response.body}');
            return jsonData;
          } else {
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


    final payload = {
      'dashboard_data':dashboardData,
      'reports':  fullReportsData,
      'client_server': clientServerIP.trim(),
      'client_user': clientUserName.trim(),
      'client_password': clientPassword.trim(),
      'client_database': clientDatabaseName.trim(),
    };

    debugPrint('--- Step 4: Final payload assembled. Preparing to send...');

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
      rethrow;
    }
  }


  Future<List<Map<String, dynamic>>> fetchReportsForApi(String databaseName) async {
    _logRequest(httpMethod: 'INTERNAL', url: 'N/A', functionName: 'fetchReportsForApi(databaseName: $databaseName)');
    try {
      final List<Map<String, dynamic>> allReports = await fetchDemoTable();
      final List<Map<String, dynamic>> matchedReports = [];

      for (final report in allReports) {
        final String? apiName = report['API_name']?.toString();

        if (apiName != null && apiName.isNotEmpty) {
          try {
            final apiDetails = await getApiDetails(apiName);
            final String? apiDatabaseName = apiDetails['databaseName']?.toString();

            if (apiDatabaseName == databaseName) {
              matchedReports.add(report);
            }
          } catch (e) {

            debugPrint('Could not retrieve details for API \'$apiName\'. It might be misconfigured or deleted. Skipping report \'${report['Report_name']}\'. Error: $e');
          }
        }
      }
      return matchedReports;
    } catch (e) {
      debugPrint('An error occurred in fetchReportsForApi: $e');
      rethrow;
    }
  }
}