import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // Import for debugPrint

class ReportAPIService {
  final String _baseUrl = 'http://localhost/reportBuilder/DemoTables.php';
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
          return (jsonData['data'] as List)
              .map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            } else {
              debugPrint('Warning: Expected Map<String, dynamic> in picker data, but found ${item.runtimeType}. Item: $item');
              return <String, dynamic>{};
            }
          })
              .where((item) => item.isNotEmpty)
              .toList();
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
    await _ensureApiDetailsCacheLoaded();

    if (_apiDetails.containsKey(apiName)) {
      debugPrint('ReportAPIService: Retrieved API details for $apiName from cache: ${_apiDetails[apiName]}'); // ADDED LOG
      return _apiDetails[apiName]!;
    } else {
      debugPrint('Error: API details not found for "$apiName" after cache load attempt.'); // Log
      throw Exception('API details not found for "$apiName".');
    }
  }


  Future<List<Map<String, dynamic>>> fetchApiData(String apiName) async {
    final apiDetail = await getApiDetails(apiName);
    String baseUrl = apiDetail['url'];
    List<dynamic> parameters = apiDetail['parameters'] ?? [];

    Map<String, String> queryParams = {};
    for (var param in parameters) {
      final String paramName = param['name']?.toString() ?? '';
      final String paramValue = param['value']?.toString() ?? '';
      if (paramName.isNotEmpty) {
        queryParams[paramName] = paramValue;
      }
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
    debugPrint('ReportAPIService: Fetching API data from URL: $uri'); // ADDED LOG

    try {
      final response = await http.get(uri);
      debugPrint('ApiData response: status=${response.statusCode}, body=${response.body.length}');
      return _parseApiResponse(response);
    } catch (e) {
      debugPrint('ApiData exception: $e');
      rethrow;
    }
  }

  // This method is for structured report data (List of Maps)
  Future<List<Map<String, dynamic>>> fetchReportDataFromUrl(String url) async {
    debugPrint('ReportAPIService: Fetching structured report data from URL: $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('ReportAPIService: Structured URL fetch timed out for $url');
          throw TimeoutException('Request to $url timed out');
        },
      );
      debugPrint('ReportAPIService: Structured URL response: status=${response.statusCode}, body length=${response.body.length}');
      return _parseApiResponse(response);
    } catch (e) {
      debugPrint('ReportAPIService: Exception fetching structured report data from URL: $e');
      rethrow;
    }
  }

  // This method is for any raw JSON data (e.g., for PrintPreview)
  Future<dynamic> fetchRawJsonFromUrl(String url) async {
    debugPrint('ReportAPIService: Fetching raw JSON from URL: $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('ReportAPIService: Raw JSON URL fetch timed out for $url');
          throw TimeoutException('Request to $url timed out');
        },
      );
      debugPrint('ReportAPIService: Raw JSON URL response: status=${response.statusCode}, body length=${response.body.length}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          debugPrint('ReportAPIService: Empty response body for raw JSON fetch. Returning empty map.');
          return {};
        }
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch raw JSON from $url: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('ReportAPIService: Exception fetching raw JSON from URL: $e');
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
      debugPrint('ReportAPIService: Initializing params from actionApiUrlTemplate: $effectiveBaseUrl');
    } else {
      await _ensureApiDetailsCacheLoaded();
      final apiDetail = await getApiDetails(apiName);
      effectiveBaseUrl = apiDetail['url'];
      final Uri tempUri = Uri.parse(effectiveBaseUrl);
      finalQueryParams.addAll(tempUri.queryParameters);
      debugPrint('ReportAPIService: Initializing params from API config base URL: $effectiveBaseUrl');

      (apiDetail['parameters'] as List<dynamic>?)?.forEach((param) {
        final paramName = param['name']?.toString();
        final paramValue = param['value']?.toString();
        if (paramName != null && paramName.isNotEmpty) {
          finalQueryParams[paramName] = paramValue ?? '';
        }
      });
    }

    finalQueryParams.addAll(userParams);
    debugPrint('ReportAPIService: Merged query parameters (final): $finalQueryParams');

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
          if (jsonData[0] is List) {
            debugPrint('ParseApiResponse: Detected List of Lists. Taking the first inner list and ensuring types.');
            if (jsonData[0].isNotEmpty) {
              return (jsonData[0] as List).whereType<Map<String, dynamic>>().toList();
            } else {
              debugPrint('ParseApiResponse: First inner list is empty. Returning empty list.');
              return [];
            }
          } else if (jsonData[0] is Map<String, dynamic>) {
            debugPrint('ParseApiResponse: Detected List of Maps directly. Ensuring types.');
            return jsonData.whereType<Map<String, dynamic>>().toList();
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
            debugPrint('ParseApiResponse: Detected Map with "data" field as List. Ensuring types.');
            return data.whereType<Map<String, dynamic>>().toList();
          } else if (data is Map<String, dynamic>) {
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
      rethrow;
    }
  }

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
        debugPrint('Raw JSON from get_demo_table: ${jsonEncode(jsonData)}');
        if (jsonData['status'] == 'success') {
          List<Map<String, dynamic>> reports = [];
          for (var item in jsonData['data']) {
            if (item is Map<String, dynamic>) {
              Map<String, dynamic> reportItem = Map.from(item);
              if (reportItem['actions_config'] is String && reportItem['actions_config'].toString().isNotEmpty) {
                try {
                  reportItem['actions_config'] = jsonDecode(reportItem['actions_config'].toString());
                } catch (e) {
                  debugPrint('Warning: Failed to decode actions_config for RecNo ${reportItem['RecNo']}: ${reportItem['actions_config']} - Error: $e'); // Log
                  reportItem['actions_config'] = [];
                }
              } else if (reportItem['actions_config'] == null) {
                reportItem['actions_config'] = [];
              }

              reportItem['pdf_footer_datetime'] = item['pdf_footer_datetime'] == '1' || item['pdf_footer_datetime'] == true;
              debugPrint('Report ${reportItem['RecNo']} has pdf_footer_datetime: ${reportItem['pdf_footer_datetime']}');

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
      debugPrint('Error: GET API not found for get_demo_table2');
      throw Exception('GET API not found');
    }

    final fullUrl = '$url&RecNo=$recNo';
    debugPrint('Fetching DemoTable2 with URL: $fullUrl');
    try {
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          debugPrint('Fetch demo table 2: Empty response body for 200 status. Returning empty list.');
          return [];
        }
        final jsonData = jsonDecode(response.body);
        debugPrint('Raw JSON from get_demo_table2 for RecNo $recNo: ${jsonEncode(jsonData)}');
        if (jsonData['status'] == 'success') {
          List<Map<String, dynamic>> fields = [];
          for (var item in (jsonData['data'] as List)) {
            if (item is Map<String, dynamic>) {
              Map<String, dynamic> fieldItem = Map.from(item);
              fieldItem['is_api_driven'] = item['is_api_driven'] == '1' || item['is_api_driven'] == true;
              fieldItem['api_url'] = item['api_url']?.toString() ?? '';
              fieldItem['field_params'] = item['field_params'] is String && item['field_params'].isNotEmpty
                  ? (jsonDecode(item['field_params']) as List).cast<Map<String, dynamic>>()
                  : [];
              fieldItem['is_user_filling'] = item['is_user_filling'] == '1' || item['is_user_filling'] == true;
              fieldItem['updated_url'] = item['updated_url']?.toString() ?? '';
              fieldItem['payload_structure'] = item['payload_structure'] is String && item['payload_structure'].isNotEmpty
                  ? (jsonDecode(item['payload_structure']) as List).cast<Map<String, dynamic>>()
                  : [];
              fields.add(fieldItem);
            }
          }
          return fields;
        } else {
          debugPrint('DemoTable2 error: ${jsonData['message']}');
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        debugPrint('DemoTable2 failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to load data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('DemoTable2 exception: $e');
      rethrow;
    }
  }

  Future<int> saveReport({
    required String reportName,
    required String reportLabel,
    required String apiName,
    required String parameter,
    required List<Map<String, dynamic>> fields,
    List<Map<String, dynamic>> actions = const [],
    required bool includePdfFooterDateTime,
  }) async {
    final url = _postEndpoints['post_demo_table'];
    if (url == null) {
      debugPrint('Error: POST API not found for post_demo_table');
      throw Exception('POST API not found');
    }

    final recNo = ++_recNoCounter;
    final payload = {
      'RecNo': recNo,
      'Report_name': reportName,
      'Report_label': reportLabel,
      'API_name': apiName,
      'Parameter': parameter,
      'actions_config': jsonEncode(actions),
      'pdf_footer_datetime': includePdfFooterDateTime ? 1 : 0,
    };
    debugPrint('SaveReport URL: $url, Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint('post_demo_table failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to save report: ${response.statusCode} - ${response.body}');
      }

      if (response.body.isEmpty) {
        debugPrint('post_demo_table: Empty response body for 200 status. Cannot get RecNo.');
        throw Exception('API returned empty response, cannot confirm save.');
      }
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        debugPrint('post_demo_table error: ${jsonData['message']}');
        throw Exception('API returned error: ${jsonData['message']}');
      }

      final backendRecNo = int.tryParse(jsonData['RecNo'].toString());
      return backendRecNo ?? recNo;
    } catch (e) {
      debugPrint('post_demo_table exception: $e');
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
      debugPrint('Error: POST API not found for post_database_server');
      throw Exception('POST API not found');
    }

    if (serverIP.isEmpty ||
        userName.isEmpty ||
        password.isEmpty ||
        databaseName.isEmpty ||
        apiServerURL.isEmpty ||
        (parameters.isNotEmpty && apiName.isEmpty)) {
      debugPrint('Validation Failed...');
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
    debugPrint('SaveDatabaseServer URL: $url, Payload: $payload');

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
        debugPrint('post_database_server failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to save database server: ${response.statusCode} - ${response.body}');
      }
      if (response.body.isEmpty) {
        debugPrint('post_database_server: Empty response body for 200 status. Cannot verify save.');
        return;
      }
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        debugPrint('post_database_server error: ${jsonData['message']}');
        throw Exception('API returned error: ${jsonData['message']}');
      }
    } catch (e) {
      debugPrint('post_database_server exception: $e');
      rethrow;
    }
  }

  Future<void> saveFieldConfigs(List<Map<String, dynamic>> fields, int recNo) async {
    final url = _postEndpoints['post_demo_table2'];
    if (url == null) {
      debugPrint('Error: POST API not found for post_demo_table2');
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
        'field_params': jsonEncode(field['field_params'] ?? []),
        'is_user_filling': field['is_user_filling'] == true ? 1 : 0,
        'updated_url': field['updated_url']?.toString() ?? '',
        'payload_structure': jsonEncode(field['payload_structure'] ?? []),
      };

      debugPrint('SaveFieldConfigs URL: $url, Payload for ${field['Field_name']}: $payload');

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (response.statusCode != 200) {
          debugPrint('post_demo_table2 failed for ${field['Field_name']}: status=${response.statusCode}, body=${response.body}');
          throw Exception('Failed to save field config for ${field['Field_name']}: ${response.statusCode} - ${response.body}');
        }
        if (response.body.isEmpty) {
          debugPrint('post_demo_table2: Empty response body for 200 status. Cannot verify save for ${field['Field_name']}.');
          continue;
        }
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] != 'success') {
          debugPrint('post_demo_table2 error: ${jsonData['message']}');
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } catch (e) {
        debugPrint('post_demo_table2 exception for ${field['Field_name']}: $e');
        throw Exception('Failed to save field config for ${field['Field_name']}: $e');
      }
    }
  }

  Future<void> deleteDatabaseServer(String id) async {
    final url = _postEndpoints['delete_database_server'];
    if (url == null) {
      debugPrint('Error: POST API not found for delete_database_server');
      throw Exception('POST API not found');
    }

    final payload = {'id': id};
    debugPrint('DeleteDatabaseServer URL: $url, Payload: $payload');
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
        debugPrint('delete_database_server failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to delete database server: ${response.statusCode} - ${response.body}');
      }
      if (response.body.isEmpty) {
        debugPrint('delete_database_server: Empty response body for 200 status. Cannot verify delete.');
        return;
      }
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        debugPrint('delete_database_server error: ${jsonData['message']}');
        throw Exception('API returned error: ${jsonData['message']}');
      }
    } catch (e) {
      debugPrint('delete_database_server exception: $e');
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
      debugPrint('Error: POST API not found for edit_database_server');
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
    debugPrint('EditDatabaseServer URL: $url, Payload: $payload');

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
        debugPrint('edit_database_server failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to edit database server: ${response.statusCode} - ${response.body}');
      }
      if (response.body.isEmpty) {
        debugPrint('edit_database_server: Empty response body for 200 status. Cannot verify edit.');
        return;
      }
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        debugPrint('edit_database_server error: ${jsonData['message']}');
        throw Exception('API returned error: ${jsonData['message']}');
      }
    } catch (e) {
      debugPrint('edit_database_server exception: $e');
      rethrow;
    }
  }

  Future<void> editDemoTables({
    required int recNo,
    required String reportName,
    required String reportLabel,
    required String apiName,
    required String parameter,
    required List<Map<String, dynamic>> fieldConfigs,
    required List<Map<String, dynamic>> actions,
    required bool includePdfFooterDateTime,
  }) async {
    final url = _postEndpoints['edit_demo_tables'];
    if (url == null) {
      debugPrint('Error: POST API not found for edit_demo_tables');
      throw Exception('POST API not found');
    }

    final payload = {
      'RecNo': recNo.toString(),
      'Demo_table': {
        'Report_name': reportName.trim(),
        'Report_label': reportLabel.trim(),
        'API_name': apiName.trim(),
        'Parameter': parameter.trim(),
        'actions_config': jsonEncode(actions),
        'pdf_footer_datetime': includePdfFooterDateTime ? 1 : 0,
      },
      'Demo_table_2': fieldConfigs,
    };

    debugPrint('EditDemoTables URL: $url, Final Payload for RecNo $recNo: ${jsonEncode(payload)}');

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
        debugPrint('edit_demo_tables failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to edit demo tables: ${response.statusCode} - ${response.body}');
      }
      if (response.body.isEmpty) {
        debugPrint('edit_demo_tables: Empty response body for 200 status. Cannot verify edit.');
        return;
      }
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        debugPrint('edit_demo_tables error: ${jsonData['message']}');
        throw Exception('API returned error: ${jsonData['message']}');
      }
    } catch (e) {
      debugPrint('edit_demo_tables exception: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteDemoTables({
    required int recNo,
  }) async {
    final url = _postEndpoints['delete_demo_tables'];
    if (url == null) {
      debugPrint('Error: POST API not found for delete_demo_tables');
      throw Exception('POST API not found');
    }

    final payload = {'RecNo': recNo};
    debugPrint('DeleteDemoTables URL: $url, Payload: $payload');
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
        debugPrint('delete_demo_tables failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to delete demo tables: ${response.statusCode} - ${response.body}');
      }
      if (response.body.isEmpty) {
        debugPrint('delete_demo_tables: Empty response body for 200 status. Cannot verify delete.');
        return {'status': 'success', 'message': 'Operation completed but no response body.'};
      }
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        debugPrint('delete_demo_tables error: ${jsonData['message']}');
        throw Exception('API returned error: ${jsonData['message']}');
      }
      return jsonData;
    } catch (e) {
      debugPrint('delete_demo_tables exception: $e');
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
    debugPrint('DeployReportToClient URL: $url, Payload keys: ${payload.keys.join(', ')}');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 180));

      debugPrint('DeployReportToClient response status: ${response.statusCode}');
      debugPrint('DeployReportToClient response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response body from deployment script.');
        }
        return jsonDecode(response.body);
      } else {
        throw Exception('Server error during deployment: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('DeployReportToClient exception: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  // ******************* FIX IS HERE *******************
  // This function now correctly handles a response that is a List or a Map.
  Future<Map<String, dynamic>> postJson(String url, Map<String, dynamic> payload) async {
    debugPrint('ReportAPIService: postJson to URL: $url, Payload keys: ${payload.keys.join(', ')}');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      debugPrint('postJson response status: ${response.statusCode}');
      debugPrint('postJson response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          // If the body is empty on success, return a standard success map.
          return {'status': 'success', 'message': 'Operation successful with no content.'};
        }

        final decodedBody = jsonDecode(response.body);

        // If the server returns a List (like [{"ResultMsg":"Success"}]),
        // we extract the first object from it.
        if (decodedBody is List && decodedBody.isNotEmpty) {
          // Check if the first element is actually a map before casting
          if (decodedBody[0] is Map<String, dynamic>) {
            final Map<String, dynamic> result = decodedBody[0];
            // Standardize the status key. Your API returns "ResultStatus", so we check for it.
            if (result.containsKey('ResultStatus') && !result.containsKey('status')) {
              result['status'] = result['ResultStatus']?.toString().toLowerCase();
            }
            return result;
          }
        }

        // If the server returns a Map (like {"status":"success"}), we return it directly.
        else if (decodedBody is Map<String, dynamic>) {
          return decodedBody;
        }

        // If the format is unexpected, throw an error.
        throw Exception('Unexpected JSON format from server: ${response.body}');

      } else {
        // For non-200 responses, try to parse the error message if possible.
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map<String, dynamic>) {
            return errorBody;
          }
        } catch (_) {
          // If the error response is not valid JSON, throw a generic error.
          throw Exception('Server error: ${response.statusCode} - ${response.body}');
        }
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('postJson exception: $e\nStack trace: $stackTrace');
      // Return a structured error map so the UI can handle it gracefully.
      return {
        'status': 'error',
        'message': 'Failed to process request: $e',
      };
    }
  }
// ******************* END OF FIX *******************
}