// ReportAPIService.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ReportAPIService {
  final String _baseUrl = 'http://localhost/reportBuilder/DemoTables.php';
  final String _databaseFetchUrl = 'http://localhost/reportBuilder/DatabaseFetch.php';
  final String _databaseFieldUrl = 'http://localhost/reportBuilder/DatabaseField.php';
  late final Map<String, String> _postEndpoints;
  late final Map<String, String> _getEndpoints;

  Map<String, Map<String, dynamic>> _apiDetails = {};

  static int _recNoCounter = 0; // Consider if this is truly needed or if backend manages RecNo

  ReportAPIService() {
    _postEndpoints = {
      'post_demo_table': '$_baseUrl?mode=post_demo_table',
      'post_demo_table2': '$_baseUrl?mode=post_demo_table2',
      'post_database_server': '$_baseUrl?mode=post_database_server',
      'delete_database_server': '$_baseUrl?mode=delete_database_server',
      'edit_database_server': '$_baseUrl?mode=edit_database_server',
      'edit_demo_tables': '$_baseUrl?mode=edit_demo_tables',
      'delete_demo_tables': '$_baseUrl?mode=delete_demo_tables',
    };

    _getEndpoints = {
      'fetch_tables_and_fields': _databaseFieldUrl,
      'get_database_server': '$_baseUrl?mode=get_database_server',
      'get_demo_table': '$_baseUrl?mode=get_demo_table', // NEW: Add get_demo_table
      'get_demo_table2': '$_baseUrl?mode=get_demo_table2',
      'fetch_databases': _databaseFetchUrl,
    };
  }

  Future<List<String>> fetchDatabases({
    required String serverIP,
    required String userName,
    required String password,
  }) async {
    final url = _getEndpoints['fetch_databases'];
    if (url == null) {
      print('Error: GET API not found for fetch_databases'); // Log
      throw Exception('GET API not found');
    }

    try {
      final payload = {
        'server': serverIP.trim(),
        'user': userName.trim(),
        'password': password.trim(),
      };
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
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          final databases = List<String>.from(jsonData['databases'] ?? []);
          return databases;
        } else {
          print('DatabaseFetch error: ${jsonData['message']}'); // Log
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        print('DatabaseFetch failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to fetch databases: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      print('DatabaseFetch exception: $e\nStack trace: $stackTrace'); // Log
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
      print('Error: API endpoint not found for fetching tables.'); // Log
      throw Exception('API endpoint not found for fetching tables.');
    }

    final payload = {
      'server': server.trim(),
      'UID': UID.trim(),
      'PWD': PWD.trim(),
      'Database': database.trim(),
      'action': 'table',
    };

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
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['tables'] is List) {
          return List<String>.from(jsonData['tables'].map((item) => item.toString()));
        } else {
          print('Fetch tables error: API returned error or unexpected data format: ${jsonData['message'] ?? response.body}'); // Log
          throw Exception('API returned error or unexpected data format: ${jsonData['message'] ?? response.body}');
        }
      } else {
        print('Fetch tables failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to fetch tables: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching tables: $e'); // Log
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
      print('Error: API endpoint not found for fetching fields.'); // Log
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
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['fields'] is List) {
          return List<String>.from(jsonData['fields'].map((item) => item.toString()));
        } else {
          print('Fetch fields error: API returned error or unexpected data format for fields: ${jsonData['message'] ?? response.body}'); // Log
          throw Exception('API returned error or unexpected data format for fields: ${jsonData['message'] ?? response.body}');
        }
      } else {
        print('Fetch fields failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to fetch fields: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching fields: $e'); // Log
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
      print('Error: API endpoint not found for fetching picker data.'); // Log
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
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['data'] is List) {
          return List<Map<String, dynamic>>.from(jsonData['data']);
        } else {
          print('Fetch picker data error: API returned error or unexpected data format for picker data: ${jsonData['message'] ?? response.body}'); // Log
          throw Exception('API returned error or unexpected data format for picker data: ${jsonData['message'] ?? response.body}');
        }
      } else {
        print('Fetch picker data failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to fetch picker data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching picker data: $e'); // Log
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
      print('Error: API endpoint not found for fetching field values.'); // Log
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
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['data'] is List) {
          return List<String>.from(jsonData['data'].map((item) => item.toString()));
        } else {
          print('Fetch field values error: API returned error or unexpected data format: ${jsonData['message'] ?? response.body}'); // Log
          throw Exception('API returned error or unexpected data format: ${jsonData['message'] ?? response.body}');
        }
      } else {
        print('Fetch field values failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to fetch field values: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching field values: $e'); // Log
      rethrow;
    }
  }

  Future<List<String>> getAvailableApis() async {
    final url = _getEndpoints['get_database_server'];
    if (url == null) {
      print('Error: GET API not found for get_database_server'); // Log
      throw Exception('GET API not found');
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
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
            }
          }
          return uniqueApis.toList();
        } else {
          print('get_database_server error: ${jsonData['message']}'); // Log
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        print('get_database_server failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to load APIs: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('get_database_server exception: $e'); // Log
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getApiDetails(String apiName) async {
    // Attempt to retrieve from cache first
    if (_apiDetails.isNotEmpty && _apiDetails.containsKey(apiName)) {
      return _apiDetails[apiName]!;
    }

    // If not cached, fetch all and then retrieve (this might happen if getAvailableApis wasn't called first)
    print('getApiDetails: Details for $apiName not cached, fetching all APIs.'); // Log
    await getAvailableApis(); // This will populate _apiDetails cache
    final apiDetail = _apiDetails[apiName];

    if (apiDetail == null) {
      print('Error: API details not found for apiName=$apiName after fetch.'); // Log
      throw Exception('API details not found for "$apiName".');
    }
    return apiDetail;
  }

  Future<List<Map<String, dynamic>>> fetchApiData(String apiName) async {
    final apiDetail = await getApiDetails(apiName);
    String baseUrl = apiDetail['url'];
    List<dynamic> parameters = apiDetail['parameters'] ?? [];

    Map<String, String> queryParams = {};
    for (var param in parameters) {
      queryParams[param['name']] = param['value'].toString();
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri);
      print('ApiData response: status=${response.statusCode}, body=${response.body}'); // Log
      return _parseApiResponse(response);
    } catch (e) {
      print('ApiData exception: $e'); // Log
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchApiDataWithParams(String apiName, Map<String, String> userParams, {String? actionApiUrlTemplate}) async {
    String baseUrl;
    // Start with a map that will hold all final query parameters
    Map<String, String> finalQueryParams = {};

    if (actionApiUrlTemplate != null && actionApiUrlTemplate.isNotEmpty) {
      // If a specific action API URL template is provided, use it as the base URL
      baseUrl = actionApiUrlTemplate;
      // Parse parameters from this template URL first
      final Uri tempUri = Uri.parse(baseUrl);
      tempUri.queryParameters.forEach((key, value) {
        finalQueryParams[key] = value; // Add all template parameters
      });
      print('Using actionApiUrlTemplate as base: $baseUrl'); // Log
    } else {
      // Otherwise, fall back to getting API details from the database server config
      final apiDetail = await getApiDetails(apiName);
      baseUrl = apiDetail['url'];
      // Use parameters from apiDetail's config as defaults
      (apiDetail['parameters'] as List<dynamic>?)?.forEach((param) {
        final paramName = param['name']?.toString();
        final paramValue = param['value']?.toString();
        if (paramName != null && paramName.isNotEmpty) {
          finalQueryParams[paramName] = paramValue ?? '';
        }
      });
      print('Using API details from config for base: $baseUrl'); // Log
    }

    // Now, override with `userParams` (dynamic data from the row).
    // This is the crucial step: userParams values MUST override any defaults.
    userParams.forEach((key, value) {
      finalQueryParams[key] = value; // This will replace existing keys or add new ones
    });

    print('Parameters after merging (template defaults + userParams override): $finalQueryParams'); // Log the merged params

    final uri = Uri.parse(baseUrl).replace(queryParameters: finalQueryParams);
    print('Final API URL for action report: $uri'); // Log the final URL

    const int maxRetries = 3;
    int attempt = 1;

    while (attempt <= maxRetries) {
      try {
        final response = await http.get(uri).timeout(
          const Duration(seconds: 180),
          onTimeout: () {
            print('ApiData timeout on attempt $attempt/$maxRetries for $uri'); // Log
            throw TimeoutException('Request to $uri timed out');
          },
        );
        print('ApiData response: status=${response.statusCode}, body=${response.body}'); // Log

        final parsedData = _parseApiResponse(response);
        return {
          'status': response.statusCode,
          'data': parsedData,
          'error': response.statusCode != 200 ? 'Failed to load data: ${response.statusCode}' : null,
        };
      } catch (e) {
        print('ApiData exception on attempt $attempt/$maxRetries: $e'); // Log
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
      final jsonData = jsonDecode(response.body);

      if (jsonData is List) {
        return List<Map<String, dynamic>>.from(jsonData);
      } else if (jsonData is Map<String, dynamic>) {
        final status = jsonData['status'];
        final isSuccess = status == 'success' || status == 200 || status == '200';

        if (isSuccess && jsonData['data'] != null) {
          final data = jsonData['data'];
          if (data is List) {
            return List<Map<String, dynamic>>.from(data);
          } else {
            print('ParseApiResponse: Data field is not a list: $data'); // Log
            throw Exception('Data field must be a list');
          }
        } else if (!isSuccess && jsonData['message'] != null) {
          print('ParseApiResponse: API error: ${jsonData['message']}'); // Log
          throw Exception('API returned error: ${jsonData['message']}');
        } else {
          print('ParseApiResponse: Unexpected response format: ${response.body}'); // Log
          // If the body is empty but status is 200, return an empty list
          if (response.body.trim().isEmpty && response.statusCode == 200) {
            return [];
          }
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        print('ParseApiResponse: Invalid response format: ${response.body}'); // Log
        throw Exception('Invalid response format: ${response.body}');
      }
    } catch (e) {
      print('ParseApiResponse error: $e, response: ${response.body}'); // Log
      if (response.statusCode != 200) {
        throw Exception('Failed to load data: ${response.statusCode} - ${response.body}');
      }
      throw Exception('Failed to parse response: $e');
    }
  }

// MODIFIED: Fetch all reports from demo_table - now decodes actions_config
  Future<List<Map<String, dynamic>>> fetchDemoTable() async {
    final url = _getEndpoints['get_demo_table'];
    if (url == null) {
      print('Error: GET API not found for get_demo_table'); // Log
      throw Exception('GET API not found');
    }

    print('Fetching all DemoTable reports with URL: $url'); // Log
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
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
                  print('Warning: Failed to decode actions_config for RecNo ${reportItem['RecNo']}: ${reportItem['actions_config']} - Error: $e'); // Log
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
          print('DemoTable error: ${jsonData['message']}'); // Log
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        print('DemoTable failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to load data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('DemoTable exception: $e'); // Log
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDemoTable2(String recNo) async {
    final url = _getEndpoints['get_demo_table2'];
    if (url == null) {
      print('Error: GET API not found for get_demo_table2'); // Log
      throw Exception('GET API not found');
    }

    final fullUrl = '$url&RecNo=$recNo';
    print('Fetching DemoTable2 with URL: $fullUrl'); // Log
    try {
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          return List<Map<String, dynamic>>.from(jsonData['data']);
        } else {
          print('DemoTable2 error: ${jsonData['message']}'); // Log
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        print('DemoTable2 failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to load data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('DemoTable2 exception: $e'); // Log
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
      print('Error: POST API not found for post_demo_table'); // Log
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

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        print('post_demo_table failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to save report: ${response.statusCode} - ${response.body}');
      }

      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        print('post_demo_table error: ${jsonData['message']}'); // Log
        throw Exception('API returned error: ${jsonData['message']}');
      }

      final backendRecNo = int.tryParse(jsonData['RecNo'].toString());
      return backendRecNo ?? recNo;
    } catch (e) {
      print('post_demo_table exception: $e'); // Log
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
      print('Error: POST API not found for post_database_server'); // Log
      throw Exception('POST API not found');
    }

    if (serverIP.isEmpty ||
        userName.isEmpty ||
        password.isEmpty ||
        databaseName.isEmpty ||
        apiServerURL.isEmpty ||
        (parameters.isNotEmpty && apiName.isEmpty)) {
      print('Validation Failed: serverIP=${serverIP.isEmpty ? "empty" : "non-empty"}, '
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
        print('post_database_server failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to save database server: ${response.statusCode} - ${response.body}');
      }

      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        print('post_database_server error: ${jsonData['message']}'); // Log
        throw Exception('API returned error: ${jsonData['message']}');
      }
    } catch (e) {
      print('post_database_server exception: $e'); // Log
      rethrow;
    }
  }

  Future<void> saveFieldConfigs(List<Map<String, dynamic>> fields, int recNo) async {
    final url = _postEndpoints['post_demo_table2'];
    if (url == null) {
      print('Error: POST API not found for post_demo_table2'); // Log
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
      };

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (response.statusCode != 200) {
          print('post_demo_table2 failed for ${field['Field_name']}: status=${response.statusCode}, body=${response.body}'); // Log
          throw Exception('Failed to save field config for ${field['Field_name']}: ${response.statusCode} - ${response.body}');
        }

        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] != 'success') {
          print('post_demo_table2 error: ${jsonData['message']}'); // Log
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } catch (e) {
        print('post_demo_table2 exception for ${field['Field_name']}: $e'); // Log
        throw Exception('Failed to save field config for ${field['Field_name']}: $e');
      }
    }
  }

  Future<void> deleteDatabaseServer(String id) async {
    final url = _postEndpoints['delete_database_server'];
    if (url == null) {
      print('Error: POST API not found for delete_database_server'); // Log
      throw Exception('POST API not found');
    }

    final payload = {'id': id};
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
        print('delete_database_server failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to delete database server: ${response.statusCode} - ${response.body}');
      }

      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        print('delete_database_server error: ${jsonData['message']}'); // Log
        throw Exception('API returned error: ${jsonData['message']}');
      }
    } catch (e) {
      print('delete_database_server exception: $e'); // Log
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
      print('Error: POST API not found for edit_database_server'); // Log
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
        print('edit_database_server failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to edit database server: ${response.statusCode} - ${response.body}');
      }

      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        print('edit_database_server error: ${jsonData['message']}'); // Log
        throw Exception('API returned error: ${jsonData['message']}');
      }
    } catch (e) {
      print('edit_database_server exception: $e'); // Log
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
    required List<Map<String, dynamic>> fieldConfigs,
    required List<Map<String, dynamic>> actions, // NEW: actions parameter
  }) async {
    final url = _postEndpoints['edit_demo_tables'];
    if (url == null) {
      print('Error: POST API not found for edit_demo_tables'); // Log
      throw Exception('POST API not found');
    }

    final payload = {
      'RecNo': recNo.toString(),
      'Demo_table': {
        'Report_name': reportName.trim(),
        'Report_label': reportLabel.trim(),
        'API_name': apiName.trim(),
        'Parameter': parameter.trim(),
        'actions_config': jsonEncode(actions), // NEW: Encode actions to JSON string
      },
      'Demo_table_2': fieldConfigs.map((field) {
        return {
          'Field_name': field['Field_name']?.toString() ?? '',
          'Field_label': field['Field_label']?.toString() ?? field['Field_name']?.toString() ?? '',
          'Sequence_no': field['Sequence_no'] is int
              ? field['Sequence_no']
              : int.tryParse(field['Sequence_no'].toString()) ?? 0,
          'width': field['width'] is int ? field['width'] : int.tryParse(field['width'].toString()) ?? 100,
          'Total': field['Total'] is int
              ? field['Total']
              : (field['Total'] == true ? 1 : 0),
          'num_alignment': field['num_alignment']?.toString() ?? 'Left',
          'time': field['time'] is int
              ? field['time']
              : (field['time'] == true ? 1 : 0),
          'indian_format': field['num_format'] is int
              ? field['num_format']
              : (field['num_format'] == true ? 1 : 0),
          'Breakpoint': field['Breakpoint'] is int
              ? field['Breakpoint']
              : (field['Breakpoint'] == true ? 1 : 0),
          'SubTotal': field['SubTotal'] is int
              ? field['SubTotal']
              : (field['SubTotal'] == true ? 1 : 0),
          'decimal_points': field['decimal_points'] is int
              ? field['decimal_points']
              : int.tryParse(field['decimal_points'].toString()) ?? 0,
          'image': field['image'] is int
              ? field['image']
              : (field['image'] == true ? 1 : 0),
        };
      }).toList(),
    };

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
        print('edit_demo_tables failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to edit demo tables: ${response.statusCode} - ${response.body}');
      }

      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        print('edit_demo_tables error: ${jsonData['message']}'); // Log
        throw Exception('API returned error: ${jsonData['message']}');
      }
    } catch (e) {
      print('edit_demo_tables exception: $e'); // Log
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteDemoTables({
    required int recNo,
  }) async {
    final url = _postEndpoints['delete_demo_tables'];
    if (url == null) {
      print('Error: POST API not found for delete_demo_tables'); // Log
      throw Exception('POST API not found');
    }

    final payload = {'RecNo': recNo};
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
        print('delete_demo_tables failed: status=${response.statusCode}, body=${response.body}'); // Log
        throw Exception('Failed to delete demo tables: ${response.statusCode} - ${response.body}');
      }

      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        print('delete_demo_tables error: ${jsonData['message']}'); // Log
        throw Exception('API returned error: ${jsonData['message']}');
      }
      return jsonData;
    } catch (e) {
      print('delete_demo_tables exception: $e'); // Log
      rethrow;
    }
  }
}