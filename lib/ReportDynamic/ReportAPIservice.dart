// lib/ReportDynamic/ReportAPIService.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // Import for debugPrint

class ReportAPIService {
  final String _baseUrl = 'https://aquare.co.in/mobileAPI/sachin/reportBuilder/DemoTables.php';
  final String _databaseFetchUrl = 'https://aquare.co.in/mobileAPI/sachin/reportBuilder/DatabaseFetch.php';
  final String _databaseFieldUrl = 'https://aquare.co.in/mobileAPI/sachin/reportBuilder/DatabaseField.php';
  late final Map<String, String> _postEndpoints;
  late final Map<String, String> _getEndpoints;

  // Cache for API details fetched from get_database_server
  Map<String, Map<String, dynamic>> _apiDetails = {};

  // Completer to manage concurrent fetches of _apiDetails
  Completer<void>? _apiDetailsLoadingCompleter;

  static int _recNoCounter = 0; // Consider if this is truly needed or if backend manages RecNo

  ReportAPIService() {
    _postEndpoints = {
      // Corrected problematic characters in URLs
      'post_demo_table': '$_baseUrl?mode=post_demo_table',
      'post_demo_table2': '$_baseUrl?mode=post_demo_table2',
      'post_database_server': '$_baseUrl?mode=post_database_server',
      'delete_database_server': '$_baseUrl?mode=delete_database_server',
      'edit_database_server': '$_baseUrl?mode=edit_database_server',
      'edit_demo_tables': '$_baseUrl?mode=edit_demo_tables',
      'delete_demo_tables': '$_baseUrl?mode=delete_demo_tables',
      // NEW ENDPOINT: Added for the deployment functionality
      'deploy_report': 'http://localhost/reportBuilder/deploy_report_to_client.php', // *** IMPORTANT: CHANGE THIS URL FOR PRODUCTION DEPLOYMENT! ***
    };

    _getEndpoints = {
      'fetch_tables_and_fields': _databaseFieldUrl,
      'get_database_server': '$_baseUrl?mode=get_database_server',
      'get_demo_table': '$_baseUrl?mode=get_demo_table',
      'get_demo_table2': '$_baseUrl?mode=get_demo_table2',
      'fetch_databases': _databaseFetchUrl,
    };
  }

  /// Ensures that the [_apiDetails] cache is populated.
  /// If a fetch is already in progress, it waits for it.
  /// If the cache is empty and no fetch is in progress, it initiates a new fetch.
  Future<void> _ensureApiDetailsCacheLoaded() async {
    // 1. Check if a fetch is already in progress
    if (_apiDetailsLoadingCompleter != null && !_apiDetailsLoadingCompleter!.isCompleted) {
      debugPrint('ReportAPIService: API details cache load in progress. Waiting...');
      return _apiDetailsLoadingCompleter!.future; // If yes, return the existing Future and wait for it
    }

    // 2. If cache is empty AND no fetch is in progress, start a new one
    if (_apiDetails.isEmpty) {
      _apiDetailsLoadingCompleter = Completer<void>(); // Create a new Completer
      debugPrint('ReportAPIService: Initiating new API details cache load.');
      try {
        await getAvailableApis(); // This method performs the actual API call to get_database_server and populates _apiDetails
        _apiDetailsLoadingCompleter!.complete(); // Mark the Completer as complete (success)
      } catch (e) {
        _apiDetailsLoadingCompleter!.completeError(e); // Mark as complete with an error
        debugPrint('ReportAPIService: Error during API details cache load: $e');
        rethrow; // Re-throw the error to propagate it
      } finally {
        // Reset the completer regardless of success or failure, but only after it's completed.
        // This ensures the next request will start a new fetch if needed.
        _apiDetailsLoadingCompleter = null;
      }
    }
    // If cache is already populated, or if we just completed populating it, this method finishes successfully.
  }

  Future<List<String>> fetchDatabases({
    required String serverIP,
    required String userName,
    required String password,
  }) async {
    final url = _getEndpoints['fetch_databases'];
    if (url == null) {
      debugPrint('Error: GET API not found for fetch_databases'); // Log
      throw Exception('GET API not found');
    }

    try {
      final payload = {
        'server': serverIP.trim(),
        'user': userName.trim(),
        'password': password.trim(),
      };
      debugPrint('DatabaseFetch URL: $url, Payload: $payload'); // ADDED LOG
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Request to $url timed out');
      });

      if (response.statusCode == 200) {
        if (response.body.isEmpty) { // Handle empty body for 200 OK
          debugPrint('DatabaseFetch: Empty response body for 200 status. Returning empty list.');
          return [];
        }
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          final databases = List<String>.from(jsonData['databases'] ?? []);
          return databases;
        } else {
          debugPrint('DatabaseFetch error: ${jsonData['message']}'); // Log
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        debugPrint('DatabaseFetch failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to fetch databases: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('DatabaseFetch exception: $e\nStack trace: $stackTrace'); // Log
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
    if (url == null) {
      debugPrint('Error: API endpoint not found for fetching tables.'); // Log
      throw Exception('API endpoint not found for fetching tables.');
    }

    final payload = {
      'server': server.trim(),
      'UID': UID.trim(),
      'PWD': PWD.trim(),
      'Database': database.trim(),
      'action': 'table',
    };
    debugPrint('FetchTables URL: $url, Payload: $payload'); // ADDED LOG

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) { // Handle empty body for 200 OK
          debugPrint('Fetch tables: Empty response body for 200 status. Returning empty list.');
          return [];
        }
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['tables'] is List) {
          return List<String>.from(jsonData['tables'].map((item) => item.toString()));
        } else {
          debugPrint('Fetch tables error: API returned error or unexpected data format: ${jsonData['message'] ?? response.body}'); // Log
          throw Exception('API returned error or unexpected data format: ${jsonData['message'] ?? response.body}');
        }
      } else {
        debugPrint('Fetch tables failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to fetch tables: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching tables: $e'); // Log
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
    if (url == null) {
      debugPrint('Error: API endpoint not found for fetching fields.'); // Log
      throw Exception('API endpoint not found for fetching fields.');
    }

    final payload = {
      'server': server.trim(),
      'UID': UID.trim(),
      'PWD': PWD.trim(),
      'Database': database.trim(),
      'action': 'fields',
      'table': table.trim(),
    };
    debugPrint('FetchFields URL: $url, Payload: $payload'); // ADDED LOG

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) { // Handle empty body for 200 OK
          debugPrint('Fetch fields: Empty response body for 200 status. Returning empty list.');
          return [];
        }
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['fields'] is List) {
          return List<String>.from(jsonData['fields'].map((item) => item.toString()));
        } else {
          debugPrint('Fetch fields error: API returned error or unexpected data format for fields: ${jsonData['message'] ?? response.body}'); // Log
          throw Exception('API returned error or unexpected data format for fields: ${jsonData['message'] ?? response.body}');
        }
      } else {
        debugPrint('Fetch fields failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to fetch fields: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching fields: $e'); // Log
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
    if (url == null) {
      debugPrint('Error: API endpoint not found for fetching picker data.'); // Log
      throw Exception('API endpoint not found for fetching picker data.');
    }

    final payload = {
      'server': server.trim(),
      'UID': UID.trim(),
      'PWD': PWD.trim(),
      'Database': database.trim(),
      'action': 'picker_data',
      'table': masterTable.trim(),
      'master_field': masterField.trim(),
      'display_field': displayField.trim(),
    };
    debugPrint('FetchPickerData URL: $url, Payload: $payload'); // ADDED LOG

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) { // Handle empty body for 200 OK
          debugPrint('Fetch picker data: Empty response body for 200 status. Returning empty list.');
          return [];
        }
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['data'] is List) {
          return List<Map<String, dynamic>>.from(jsonData['data']);
        } else {
          debugPrint('Fetch picker data error: API returned error or unexpected data format for picker data: ${jsonData['message'] ?? response.body}'); // Log
          throw Exception('API returned error or unexpected data format for picker data: ${jsonData['message'] ?? response.body}');
        }
      } else {
        debugPrint('Fetch picker data failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to fetch picker data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching picker data: $e'); // Log
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
    if (url == null) {
      debugPrint('Error: API endpoint not found for fetching field values.'); // Log
      throw Exception('API endpoint not found for fetching field values.');
    }

    final payload = {
      'server': server.trim(),
      'UID': UID.trim(),
      'PWD': PWD.trim(),
      'Database': database.trim(),
      'action': 'field',
      'table': table.trim(),
      'field': field.trim(),
    };
    debugPrint('FetchFieldValues URL: $url, Payload: $payload'); // ADDED LOG

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) { // Handle empty body for 200 OK
          debugPrint('Fetch field values: Empty response body for 200 status. Returning empty list.');
          return [];
        }
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['data'] is List) {
          return List<String>.from(jsonData['data'].map((item) => item.toString()));
        } else {
          debugPrint('Fetch field values error: API returned error or unexpected data format: ${jsonData['message'] ?? response.body}'); // Log
          throw Exception('API returned error or unexpected data format: ${jsonData['message'] ?? response.body}');
        }
      } else {
        debugPrint('Fetch field values failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to fetch field values: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching field values: $e'); // Log
      rethrow;
    }
  }

  /// Fetches all available APIs from the database server and populates the [_apiDetails] cache.
  Future<List<String>> getAvailableApis() async {
    final url = _getEndpoints['get_database_server'];
    if (url == null) {
      debugPrint('Error: GET API not found for get_database_server'); // Log
      throw Exception('GET API not found');
    }

    debugPrint('ReportAPIService: Fetching available APIs from URL: $url'); // ADDED LOG
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (response.body.isEmpty) { // Handle empty body for 200 OK
          debugPrint('getAvailableApis: Empty response body for 200 status. Returning empty list.');
          return [];
        }
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          _apiDetails = {}; // Clear previous cache
          final uniqueApis = <String>{};
          for (var item in jsonData['data']) {
            if (!uniqueApis.contains(item['APIName'])) {
              uniqueApis.add(item['APIName']);
              // Store all details for later lookup by getApiDetails
              _apiDetails[item['APIName']] = {
                'url': item['APIServerURl'],
                'parameters': item['Parameter'] != null && item['Parameter'].toString().isNotEmpty
                    ? jsonDecode(item['Parameter'])
                    : [],
                'serverIP': item['ServerIP'],
                'userName': item['UserName'],
                'password': item['Password'],
                'databaseName': item['DatabaseName'],
                'id': item['id'],
                // actions_config is typically part of demo_table, not database_server,
                // but included here for consistency if backend ever provides it.
                'actions_config': item['actions_config'] != null && item['actions_config'].toString().isNotEmpty
                    ? jsonDecode(item['actions_config'])
                    : [],
              };
              debugPrint('ReportAPIService: Cached API details for ${item['APIName']}: URL=${item['APIServerURl']}, Parameter=${item['Parameter']}'); // ADDED LOG
            }
          }
          return uniqueApis.toList();
        } else {
          debugPrint('get_database_server error: ${jsonData['message']}'); // Log
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        debugPrint('get_database_server failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to load APIs: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('get_database_server exception: $e'); // Log
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getApiDetails(String apiName) async {
    // --- THIS IS THE KEY MODIFICATION: Ensure cache is loaded before attempting lookup ---
    await _ensureApiDetailsCacheLoaded();
    // -------------------------------------------------------------------------------------

    // Now, we are GUARANTEED that _apiDetails is populated (or an error was thrown and caught higher up)
    if (_apiDetails.containsKey(apiName)) {
      debugPrint('ReportAPIService: Retrieved API details for $apiName from cache: ${_apiDetails[apiName]}'); // ADDED LOG
      return _apiDetails[apiName]!;
    } else {
      debugPrint('Error: API details not found for "$apiName" after cache load attempt.'); // Log
      throw Exception('API details not found for "$apiName".');
    }
  }

  // MODIFIED: This method now explicitly constructs the URI using queryParameters map.
  // It relies on getApiDetails to provide the base URL and default parameters.
  Future<List<Map<String, dynamic>>> fetchApiData(String apiName) async {
    // getApiDetails internally calls _ensureApiDetailsCacheLoaded(), so no need to call it directly here.
    final apiDetail = await getApiDetails(apiName);
    String baseUrl = apiDetail['url'];
    List<dynamic> parameters = apiDetail['parameters'] ?? [];

    Map<String, String> queryParams = {};
    for (var param in parameters) {
      // Ensure param['name'] and param['value'] are handled safely
      final String paramName = param['name']?.toString() ?? '';
      final String paramValue = param['value']?.toString() ?? '';
      if (paramName.isNotEmpty) {
        queryParams[paramName] = paramValue;
      }
    }

    // Construct the URI properly from base URL and query parameters
    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
    debugPrint('ReportAPIService: Fetching API data from URL: $uri'); // ADDED LOG

    try {
      final response = await http.get(uri);
      debugPrint('ApiData response: status=${response.statusCode}, body=${response.body.length}'); // Log body length instead of full body
      return _parseApiResponse(response);
    } catch (e) {
      debugPrint('ApiData exception: $e'); // Log
      rethrow;
    }
  }

  // NEW METHOD: For fetching data when you already have a full URL (like for print actions)
  Future<dynamic> fetchDataFromFullUrl(String fullUrl) async {
    debugPrint('ReportAPIService: Fetching data from full URL: $fullUrl');
    try {
      final response = await http.get(Uri.parse(fullUrl)).timeout(
        const Duration(seconds: 30), // Increased timeout for potentially larger print data
        onTimeout: () {
          debugPrint('ReportAPIService: Full URL fetch timed out for $fullUrl');
          throw TimeoutException('Request to $fullUrl timed out');
        },
      );
      debugPrint('ReportAPIService: Full URL response: status=${response.statusCode}, body length=${response.body.length}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body); // Directly decode the body
      } else {
        throw Exception('Failed to fetch data from $fullUrl: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('ReportAPIService: Exception fetching data from full URL: $e');
      rethrow;
    }
  }


  Future<Map<String, dynamic>> fetchApiDataWithParams(String apiName, Map<String, String> userParams, {String? actionApiUrlTemplate}) async {
    String effectiveBaseUrl; // The URL string that contains base path and its inherent query parameters
    Map<String, String> finalQueryParams = {}; // Accumulator for all merged parameters

    // Step 1: Determine the base URL and populate initial query params from it.
    // Also, if from apiDetails, add its 'parameters' list.
    if (actionApiUrlTemplate != null && actionApiUrlTemplate.isNotEmpty) {
      effectiveBaseUrl = actionApiUrlTemplate;
      final Uri tempUri = Uri.parse(effectiveBaseUrl);
      tempUri.queryParameters.forEach((key, value) {
        finalQueryParams[key] = value; // Add existing query params from the template URL
      });
      debugPrint('ReportAPIService: Initializing params from actionApiUrlTemplate: $effectiveBaseUrl');
    } else {
      // --- THIS IS THE KEY MODIFICATION: Ensure cache is loaded before calling getApiDetails ---
      await _ensureApiDetailsCacheLoaded();
      // -----------------------------------------------------------------------------------------
      final apiDetail = await getApiDetails(apiName); // This is where getApiDetails is properly used with an apiName
      effectiveBaseUrl = apiDetail['url'];
      final Uri tempUri = Uri.parse(effectiveBaseUrl);
      tempUri.queryParameters.forEach((key, value) {
        finalQueryParams[key] = value; // Add existing query params from API config URL
      });
      debugPrint('ReportAPIService: Initializing params from API config base URL: $effectiveBaseUrl');

      // Add parameters from the apiDetails['parameters'] list. These might override some from the URL.
      (apiDetail['parameters'] as List<dynamic>?)?.forEach((param) {
        final paramName = param['name']?.toString();
        final paramValue = param['value']?.toString();
        if (paramName != null && paramName.isNotEmpty) {
          finalQueryParams[paramName] = paramValue ?? '';
        }
      });
    }

    // Step 2: Override with `userParams` (dynamic data extracted from the row or main UI inputs).
    // This step ensures that values from the current row or main UI always take precedence.
    userParams.forEach((key, value) {
      finalQueryParams[key] = value;
    });

    debugPrint('ReportAPIService: Merged query parameters (final): $finalQueryParams');

    // Step 3: Reconstruct the URI using the base path and the final merged query parameters.
    // We get only the path part (scheme, host, path) from effectiveBaseUrl
    final Uri baseUriNoQuery = Uri.parse(effectiveBaseUrl).removeFragment().replace(query: '');
    final uri = baseUriNoQuery.replace(queryParameters: finalQueryParams);
    debugPrint('ReportAPIService: Final API URL constructed: $uri');

    const int maxRetries = 3;
    int attempt = 1;

    while (attempt <= maxRetries) {
      try {
        final response = await http.get(uri).timeout(
          const Duration(seconds: 180),
          onTimeout: () {
            debugPrint('ReportAPIService: ApiData timeout on attempt $attempt/$maxRetries for $uri');
            throw TimeoutException('Request to $uri timed out');
          },
        );
        debugPrint('ReportAPIService: ApiData response: status=${response.statusCode}, body=${response.body.length}');

        final parsedData = _parseApiResponse(response);
        return {
          'status': response.statusCode,
          'data': parsedData,
          'error': response.statusCode != 200 ? 'Failed to load data: ${response.statusCode}' : null,
        };
      } catch (e) {
        debugPrint('ReportAPIService: ApiData exception on attempt $attempt/$maxRetries: $e');
        if (e is TimeoutException && attempt < maxRetries) {
          attempt++;
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        return {
          'status': null,
          'data': [],
          'error': e is TimeoutException
              ? 'API request timed out after $maxRetries attempts. Please check your network or try again later.'
              : 'Failed to fetch data: $e',
        };
      }
    }
    return {
      'status': null,
      'data': [],
      'error': 'API request failed after $maxRetries attempts.',
    };
  }

  // MODIFIED: This method is updated to handle nested lists and maps within the 'data' field.
  List<Map<String, dynamic>> _parseApiResponse(http.Response response) {
    try {
      if (response.body.trim().isEmpty) {
        if (response.statusCode == 200) {
          debugPrint('ParseApiResponse: Empty response body for 200 status. Returning empty list.');
          return [];
        } else {
          debugPrint('ParseApiResponse: Empty response body for non-200 status (${response.statusCode}).');
          throw Exception('Empty response body: ${response.statusCode}');
        }
      }

      final dynamic jsonData = jsonDecode(response.body);

      if (jsonData is List) {
        if (jsonData.isNotEmpty) {
          // Check if the first element of the list is also a list (e.g., [[{...}],[{...}]])
          if (jsonData[0] is List) {
            // This suggests multiple result sets, like from a stored procedure.
            // For document views or primary data, we typically care about the first inner list.
            debugPrint('ParseApiResponse: Detected List of Lists. Taking the first inner list.');
            if (jsonData[0].isNotEmpty && jsonData[0][0] is Map<String, dynamic>) {
              // Ensure the inner list actually contains maps.
              return List<Map<String, dynamic>>.from(jsonData[0]);
            } else {
              debugPrint('ParseApiResponse: First inner list is empty or does not contain maps. Returning empty list.');
              return [];
            }
          } else if (jsonData[0] is Map<String, dynamic>) {
            // This is a direct list of maps, e.g., [{"id":1}, {"id":2}]
            debugPrint('ParseApiResponse: Detected List of Maps directly. Returning as is.');
            return List<Map<String, dynamic>>.from(jsonData);
          } else {
            debugPrint('ParseApiResponse: List contains unexpected element type: ${jsonData[0].runtimeType}. Throwing error.');
            throw Exception('List contains unexpected element type: ${jsonData[0].runtimeType}');
          }
        } else {
          debugPrint('ParseApiResponse: Empty list returned from API.');
          return [];
        }
      } else if (jsonData is Map<String, dynamic>) {
        final status = jsonData['status'];
        final isSuccess = status == 'success' || status == 200 || status == '200';

        if (isSuccess && jsonData['data'] != null) {
          final data = jsonData['data'];
          if (data is List) {
            debugPrint('ParseApiResponse: Detected Map with "data" field as List. Returning data list.');
            return List<Map<String, dynamic>>.from(data);
          } else if (data is Map<String, dynamic>) {
            // Handle case where 'data' is a single map (e.g., for some document APIs returning single object)
            debugPrint('ParseApiResponse: Detected Map with "data" field as single Map. Wrapping in List.');
            return [Map<String, dynamic>.from(data)];
          } else {
            debugPrint('ParseApiResponse: Data field is not a list or map: $data. Throwing error.');
            throw Exception('Data field must be a list or a map');
          }
        } else if (!isSuccess && jsonData['message'] != null) {
          debugPrint('ParseApiResponse: API error: ${jsonData['message']}. Throwing error.');
          throw Exception('API returned error: ${jsonData['message']}');
        } else {
          debugPrint('ParseApiResponse: Unexpected response format (Map, but no success or data). Throwing error. Response: ${response.body}');
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        debugPrint('ParseApiResponse: Invalid outermost response format. Throwing error. Response: ${response.body}');
        throw Exception('Invalid outermost response format: ${response.body}');
      }
    } on FormatException catch (e) {
      debugPrint('ParseApiResponse FormatException: $e, response body: "${response.body}"');
      if (response.statusCode != 200) {
        throw Exception('Failed to load data: ${response.statusCode} - Invalid JSON from server.');
      }
      throw Exception('Failed to parse response JSON: $e. Response was: "${response.body}".');
    } catch (e) {
      debugPrint('ParseApiResponse generic error: $e, response: ${response.body}');
      if (response.statusCode != 200) {
        throw Exception('Failed to load data: ${response.statusCode} - ${response.body}');
      }
      rethrow; // Re-throw to allow higher-level catch to handle specific errors like TimeoutException.
    }
  }

// MODIFIED: Fetch all reports from demo_table - now decodes actions_config
  Future<List<Map<String, dynamic>>> fetchDemoTable() async {
    final url = _getEndpoints['get_demo_table'];
    if (url == null) {
      debugPrint('Error: GET API not found for get_demo_table'); // Log
      throw Exception('GET API not found');
    }

    debugPrint('Fetching all DemoTable reports with URL: $url'); // Log
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (response.body.isEmpty) { // Handle empty body for 200 OK
          debugPrint('Fetch demo table: Empty response body for 200 status. Returning empty list.');
          return [];
        }
        final jsonData = jsonDecode(response.body);
        // ADDED LOG: Print the raw JSON data for demo_table (report metadata)
        debugPrint('Raw JSON from get_demo_table: ${jsonEncode(jsonData)}');
        if (jsonData['status'] == 'success') {
          List<Map<String, dynamic>> reports = [];
          for (var item in jsonData['data']) {
            if (item is Map<String, dynamic>) {
              Map<String, dynamic> reportItem = Map.from(item);
              // Decode 'actions_config' if it's a string and not empty
              if (reportItem['actions_config'] is String && reportItem['actions_config'].toString().isNotEmpty) {
                try {
                  reportItem['actions_config'] = jsonDecode(reportItem['actions_config'].toString());
                } catch (e) {
                  debugPrint('Warning: Failed to decode actions_config for RecNo ${reportItem['RecNo']}: ${reportItem['actions_config']} - Error: $e'); // Log
                  reportItem['actions_config'] = []; // Default to empty list on error
                }
              } else if (reportItem['actions_config'] == null) {
                reportItem['actions_config'] = []; // Ensure it's an empty list if null
              }
              reports.add(reportItem);
            }
          }
          return reports;
        } else {
          debugPrint('DemoTable error: ${jsonData['message']}'); // Log
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        debugPrint('DemoTable failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to load data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('DemoTable exception: $e'); // Log
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDemoTable2(String recNo) async {
    final url = _getEndpoints['get_demo_table2'];
    if (url == null) {
      debugPrint('Error: GET API not found for get_demo_table2'); // Log
      throw Exception('GET API not found');
    }

    final fullUrl = '$url&RecNo=$recNo';
    debugPrint('Fetching DemoTable2 with URL: $fullUrl'); // Log
    try {
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        if (response.body.isEmpty) { // Handle empty body for 200 OK
          debugPrint('Fetch demo table 2: Empty response body for 200 status. Returning empty list.');
          return [];
        }
        final jsonData = jsonDecode(response.body);
        // NEW LOG: Print the raw JSON data for field configurations
        debugPrint('Raw JSON from get_demo_table2 for RecNo $recNo: ${jsonEncode(jsonData)}');
        if (jsonData['status'] == 'success') {
          return List<Map<String, dynamic>>.from(jsonData['data']);
        } else {
          debugPrint('DemoTable2 error: ${jsonData['message']}'); // Log
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        debugPrint('DemoTable2 failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to load data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('DemoTable2 exception: $e'); // Log
      rethrow;
    }
  }

  Future<int> saveReport({
    required String reportName,
    required String reportLabel,
    required String apiName,
    required String parameter,
    required List<Map<String, dynamic>> fields, // Fields are saved via demo_table_2 (not directly in saveReport)
    List<Map<String, dynamic>> actions = const [], // NEW: Add actions parameter
  }) async {
    final url = _postEndpoints['post_demo_table'];
    if (url == null) {
      debugPrint('Error: POST API not found for post_demo_table'); // Log
      throw Exception('POST API not found');
    }

    final recNo = ++_recNoCounter; // This logic might need review if backend assigns RecNo
    final payload = {
      'RecNo': recNo,
      'Report_name': reportName,
      'Report_label': reportLabel,
      'API_name': apiName,
      'Parameter': parameter,
      'actions_config': jsonEncode(actions), // NEW: Encode actions to JSON string
    };
    debugPrint('SaveReport URL: $url, Payload: $payload'); // ADDED LOG

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint('post_demo_table failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to save report: ${response.statusCode} - ${response.body}');
      }

      if (response.body.isEmpty) {
        debugPrint('post_demo_table: Empty response body for 200 status. Cannot get RecNo.');
        throw Exception('API returned empty response, cannot confirm save.');
      }
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        debugPrint('post_demo_table error: ${jsonData['message']}'); // Log
        throw Exception('API returned error: ${jsonData['message']}');
      }

      final backendRecNo = int.tryParse(jsonData['RecNo'].toString());
      return backendRecNo ?? recNo;
    } catch (e) {
      debugPrint('post_demo_table exception: $e'); // Log
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
    if (url == null) {
      debugPrint('Error: POST API not found for post_database_server'); // Log
      throw Exception('POST API not found');
    }

    if (serverIP.isEmpty ||
        userName.isEmpty ||
        password.isEmpty ||
        databaseName.isEmpty ||
        apiServerURL.isEmpty ||
        (parameters.isNotEmpty && apiName.isEmpty)) {
      debugPrint('Validation Failed: serverIP=${serverIP.isEmpty ? "empty" : "non-empty"}, '
          'userName=${userName.isEmpty ? "empty" : "non-empty"}, '
          'password=${password.isEmpty ? "empty" : "non-empty"}, '
          'databaseName=${databaseName.isEmpty ? "empty" : "non-empty"}, '
          'apiServerURL=${apiServerURL.isEmpty ? "empty" : "non-empty"}, '
          'apiName=${apiName.isEmpty ? "empty" : "non-empty"}, '
          'parameters=${parameters.isEmpty ? "empty" : "non-empty"}'); // Log
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
    };
    debugPrint('SaveDatabaseServer URL: $url, Payload: $payload'); // ADDED LOG

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint('post_database_server failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to save database server: ${response.statusCode} - ${response.body}');
      }
      if (response.body.isEmpty) { // Handle empty body for 200 OK
        debugPrint('post_database_server: Empty response body for 200 status. Cannot verify save.');
        return; // Treat as success if backend provides no confirmation.
      }
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        debugPrint('post_database_server error: ${jsonData['message']}'); // Log
        throw Exception('API returned error: ${jsonData['message']}');
      }
    } catch (e) {
      debugPrint('post_database_server exception: $e'); // Log
      rethrow;
    }
  }

  Future<void> saveFieldConfigs(List<Map<String, dynamic>> fields, int recNo) async {
    final url = _postEndpoints['post_demo_table2'];
    if (url == null) {
      debugPrint('Error: POST API not found for post_demo_table2'); // Log
      throw Exception('POST API not found');
    }

    if (fields.isEmpty) {
      return;
    }

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
        'indian_format': field['num_format'] == true ? 1 : 0, // This is the field in question
        'decimal_points': field['decimal_points'] is int ? field['decimal_points'] : int.tryParse(field['decimal_points'].toString()) ?? 0,
        'Breakpoint': field['Breakpoint'] == true ? 1 : 0,
        'SubTotal': field['SubTotal'] == true ? 1 : 0,
        'image': field['image'] == true ? 1 : 0,
      };

      // ADDED LOG for indian_format
      debugPrint('Saving field config for ${field['Field_name']}: indian_format=${payload['indian_format']}');
      debugPrint('SaveFieldConfigs URL: $url, Payload for ${field['Field_name']}: $payload'); // ADDED LOG

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (response.statusCode != 200) {
          debugPrint('post_demo_table2 failed for ${field['Field_name']}: status=${response.statusCode}, body=${response.body}'); // Log
          throw Exception('Failed to save field config for ${field['Field_name']}: ${response.statusCode} - ${response.body}');
        }
        if (response.body.isEmpty) { // Handle empty body for 200 OK
          debugPrint('post_demo_table2: Empty response body for 200 status. Cannot verify save for ${field['Field_name']}.');
          continue; // Treat as success and continue to next field
        }
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] != 'success') {
          debugPrint('post_demo_table2 error: ${jsonData['message']}'); // Log
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } catch (e) {
        debugPrint('post_demo_table2 exception for ${field['Field_name']}: $e'); // Log
        throw Exception('Failed to save field config for ${field['Field_name']}: $e');
      }
    }
  }

  Future<void> deleteDatabaseServer(String id) async {
    final url = _postEndpoints['delete_database_server'];
    if (url == null) {
      debugPrint('Error: POST API not found for delete_database_server'); // Log
      throw Exception('POST API not found');
    }

    final payload = {'id': id};
    debugPrint('DeleteDatabaseServer URL: $url, Payload: $payload'); // ADDED LOG
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint('delete_database_server failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to delete database server: ${response.statusCode} - ${response.body}');
      }
      if (response.body.isEmpty) { // Handle empty body for 200 OK
        debugPrint('delete_database_server: Empty response body for 200 status. Cannot verify delete.');
        return; // Treat as success.
      }
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        debugPrint('delete_database_server error: ${jsonData['message']}'); // Log
        throw Exception('API returned error: ${jsonData['message']}');
      }
    } catch (e) {
      debugPrint('delete_database_server exception: $e'); // Log
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
  }) async {
    final url = _postEndpoints['edit_database_server'];
    if (url == null) {
      debugPrint('Error: POST API not found for edit_database_server'); // Log
      throw Exception('POST API not found');
    }

    final payload = {
      'id': id,
      'ServerIP': serverIP.trim(),
      'UserName': userName.trim(),
      'Password': password.trim(),
      'DatabaseName': databaseName.trim(),
      'APIServerURl': apiServerURL.trim(),
      'APIName': apiName.trim(),
      'Parameter': parameters.isNotEmpty ? jsonEncode(parameters) : '',
    };
    debugPrint('EditDatabaseServer URL: $url, Payload: $payload'); // ADDED LOG

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint('edit_database_server failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to edit database server: ${response.statusCode} - ${response.body}');
      }
      if (response.body.isEmpty) { // Handle empty body for 200 OK
        debugPrint('edit_database_server: Empty response body for 200 status. Cannot verify edit.');
        return; // Treat as success.
      }
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        debugPrint('edit_database_server error: ${jsonData['message']}'); // Log
        throw Exception('API returned error: ${jsonData['message']}');
      }
    } catch (e) {
      debugPrint('edit_database_server exception: $e'); // Log
      rethrow;
    }
  }

// MODIFIED: Added actions parameter
  Future<void> editDemoTables({
    required int recNo,
    required String reportName,
    required String reportLabel,
    required String apiName,
    required String parameter,
    required List<Map<String, dynamic>> fieldConfigs, // This list is already correctly formatted
    required List<Map<String, dynamic>> actions, // NEW: actions parameter
  }) async {
    final url = _postEndpoints['edit_demo_tables'];
    if (url == null) {
      debugPrint('Error: POST API not found for edit_demo_tables'); // Log
      throw Exception('POST API not found');
    }

    // This is the CRITICAL change: Pass fieldConfigs directly as it's already correctly formatted.
    // The previous code was re-mapping it, causing the `indian_format` to revert.
    final payload = {
      'RecNo': recNo.toString(),
      'Demo_table': {
        'Report_name': reportName.trim(),
        'Report_label': reportLabel.trim(),
        'API_name': apiName.trim(),
        'Parameter': parameter.trim(),
        'actions_config': jsonEncode(actions), // NEW: Encode actions to JSON string
      },
      'Demo_table_2': fieldConfigs, // <-- Use the already processed fieldConfigs directly
    };

    debugPrint('EditDemoTables URL: $url, Final Payload to send: ${jsonEncode(payload)}'); // ADDED LOG for final payload

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint('edit_demo_tables failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to edit demo tables: ${response.statusCode} - ${response.body}');
      }
      if (response.body.isEmpty) { // Handle empty body for 200 OK
        debugPrint('edit_demo_tables: Empty response body for 200 status. Cannot verify edit.');
        return; // Treat as success.
      }
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        debugPrint('edit_demo_tables error: ${jsonData['message']}'); // Log
        throw Exception('API returned error: ${jsonData['message']}');
      }
    } catch (e) {
      debugPrint('edit_demo_tables exception: $e'); // Log
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteDemoTables({
    required int recNo,
  }) async {
    final url = _postEndpoints['delete_demo_tables'];
    if (url == null) {
      debugPrint('Error: POST API not found for delete_demo_tables'); // Log
      throw Exception('POST API not found');
    }

    final payload = {'RecNo': recNo};
    debugPrint('DeleteDemoTables URL: $url, Payload: $payload'); // ADDED LOG
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint('delete_demo_tables failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to delete demo tables: ${response.statusCode} - ${response.body}');
      }
      if (response.body.isEmpty) { // Handle empty body for 200 OK
        debugPrint('delete_demo_tables: Empty response body for 200 status. Cannot verify delete.');
        return {'status': 'success', 'message': 'Operation completed but no response body.'}; // Provide a dummy success for empty body
      }
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        debugPrint('delete_demo_tables error: ${jsonData['message']}'); // Log
        throw Exception('API returned error: ${jsonData['message']}');
      }
      return jsonData;
    } catch (e) {
      debugPrint('delete_demo_tables exception: $e'); // Log
      rethrow;
    }
  }

  // NEW METHOD: deployReportToClient - This was the one missing from the previous snippet!
  Future<Map<String, dynamic>> deployReportToClient({
    required Map<String, dynamic> reportMetadata,
    required List<Map<String, dynamic>> fieldConfigs,
    required String clientServerIP,
    required String clientUserName,
    required String clientPassword,
    required String clientDatabaseName,
  }) async {
    final url = _postEndpoints['deploy_report'];
    if (url == null) {
      debugPrint('Error: POST API not found for deploy_report');
      throw Exception('POST API not found for deployment.');
    }

    final payload = {
      'report_metadata': jsonEncode(reportMetadata),
      'field_configs': jsonEncode(fieldConfigs),
      'client_server': clientServerIP.trim(),
      'client_user': clientUserName.trim(),
      'client_password': clientPassword.trim(),
      'client_database': clientDatabaseName.trim(),
    };
    debugPrint('DeployReportToClient URL: $url, Payload keys: ${payload.keys.join(', ')}'); // Log keys, not full sensitive payload

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 180)); // Give it more time for DB operations

      debugPrint('DeployReportToClient response status: ${response.statusCode}');
      debugPrint('DeployReportToClient response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response body from deployment script.');
        }
        return jsonDecode(response.body); // Should contain status and message
      } else {
        throw Exception('Server error during deployment: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('DeployReportToClient exception: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }
}