import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ReportAPIService {
  final String _baseUrl = 'http://localhost/reportBuilder/DemoTables.php';
  final String _databaseFetchUrl = 'http://localhost/reportBuilder/DatabaseFetch.php';
  late final Map<String, String> _postEndpoints;
  late final Map<String, String> _getEndpoints;

  Map<String, Map<String, dynamic>> _apiDetails = {};

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
    };

    _getEndpoints = {
      'get_database_server': '$_baseUrl?mode=get_database_server',
      'get_demo_table': '$_baseUrl?mode=get_demo_table',
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
      print('Error: GET API not found for fetch_databases');
      throw Exception('GET API not found');
    }

    print('Fetching databases from: $url');
    try {
      final payload = {
        'server': serverIP.trim(),
        'user': userName.trim(),
        'password': password.trim(),
      };
      print('Sending payload: $payload');
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

      print('Response status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          final databases = List<String>.from(jsonData['databases'] ?? []);
          print('Databases fetched successfully: $databases');
          return databases;
        } else {
          print('DatabaseFetch error: ${jsonData['message']}');
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        print('DatabaseFetch failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to fetch databases: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      print('DatabaseFetch exception: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<String>> getAvailableApis() async {
    final url = _getEndpoints['get_database_server'];
    if (url == null) {
      print('Error: GET API not found for get_database_server');
      throw Exception('GET API not found');
    }

    print('Fetching available APIs from: $url');
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          _apiDetails = {};
          final uniqueApis = <String>{};
          for (var item in jsonData['data']) {
            if (!uniqueApis.contains(item['APIName'])) {
              uniqueApis.add(item['APIName']);
              _apiDetails[item['APIName']] = {
                'url': item['APIServerURl'],
                'parameters': item['Parameter'] != null ? jsonDecode(item['Parameter']) : [],
                'serverIP': item['ServerIP'],
                'userName': item['UserName'],
                'password': item['Password'],
                'databaseName': item['DatabaseName'],
                'id': item['id'],
              };
            }
          }
          print('Available APIs: ${uniqueApis.toList()}');
          return uniqueApis.toList();
        } else {
          print('get_database_server error: ${jsonData['message']}');
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        print('get_database_server failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to load APIs: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('get_database_server exception: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getApiDetails(String apiName) async {
    if (_apiDetails.isEmpty) {
      await getAvailableApis();
    }
    final apiDetail = _apiDetails[apiName];
    if (apiDetail == null) {
      print('Error: API not found for apiName=$apiName');
      throw Exception('API not found');
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
    print('Fetching ApiData with URL: $uri');

    try {
      final response = await http.get(uri);
      print('ApiData response: status=${response.statusCode}, body=${response.body}');
      return _parseApiResponse(response);
    } catch (e) {
      print('ApiData exception: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchApiDataWithParams(String apiName, Map<String, String> userParams) async {
    final apiDetail = await getApiDetails(apiName);
    String baseUrl = apiDetail['url'];
    List<dynamic> parameters = apiDetail['parameters'] ?? [];

    Map<String, String> queryParams = {};
    for (var param in parameters) {
      final paramName = param['name'];
      queryParams[paramName] = userParams[paramName] ?? param['value'].toString();
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
    print('Fetching ApiData with URL: $uri');

    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Request to $uri timed out'),
      );
      print('ApiData response: status=${response.statusCode}, body=${response.body}');

      final parsedData = _parseApiResponse(response);
      return {
        'status': response.statusCode,
        'data': parsedData,
        'error': response.statusCode != 200 ? 'Failed to load data: ${response.statusCode}' : null,
      };
    } catch (e) {
      print('ApiData exception: $e');
      return {
        'status': null,
        'data': [],
        'error': e.toString(),
      };
    }
  }

  List<Map<String, dynamic>> _parseApiResponse(http.Response response) {
    try {
      final jsonData = jsonDecode(response.body);

      // Handle different response formats
      if (jsonData is List) {
        // Direct list of records: [{SNo: 1, ...}, ...]
        return List<Map<String, dynamic>>.from(jsonData);
      } else if (jsonData is Map<String, dynamic>) {
        // Structured response: {status: "success"/200, data: [...], message: ""}
        final status = jsonData['status'];
        final isSuccess = status == 'success' || status == 200 || status == '200';

        if (isSuccess && jsonData['data'] != null) {
          return List<Map<String, dynamic>>.from(jsonData['data']);
        } else if (!isSuccess && jsonData['message'] != null) {
          throw Exception('API returned error: ${jsonData['message']}');
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception('Invalid response format: ${response.body}');
      }
    } catch (e) {
      print('ParseApiResponse error: $e');
      if (response.statusCode != 200) {
        throw Exception('Failed to load data: ${response.statusCode} - ${response.body}');
      }
      throw Exception('Failed to parse response: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchDemoTable() async {
    final url = _getEndpoints['get_demo_table'];
    if (url == null) {
      print('Error: GET API not found for get_demo_table');
      throw Exception('GET API not found');
    }

    print('Fetching DemoTable with URL: $url');
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          print('DemoTable fetch successful: data.length=${jsonData['data'].length}');
          return List<Map<String, dynamic>>.from(jsonData['data']);
        } else {
          print('DemoTable error: ${jsonData['message']}');
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        print('DemoTable failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to load data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('DemoTable exception: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDemoTable2(String recNo) async {
    final url = _getEndpoints['get_demo_table2'];
    if (url == null) {
      print('Error: GET API not found for get_demo_table2');
      throw Exception('GET API not found');
    }

    final fullUrl = '$url&RecNo=$recNo';
    print('Fetching DemoTable2 with URL: $fullUrl');
    try {
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          print('DemoTable2 fetch successful: data.length=${jsonData['data'].length}');
          return List<Map<String, dynamic>>.from(jsonData['data']);
        } else {
          print('DemoTable2 error: ${jsonData['message']}');
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        print('DemoTable2 failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to load data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('DemoTable2 exception: $e');
      rethrow;
    }
  }

  Future<int> saveReport({
    required String reportName,
    required String reportLabel,
    required String apiName,
    required String parameter,
    required List<Map<String, dynamic>> fields,
  }) async {
    final url = _postEndpoints['post_demo_table'];
    if (url == null) {
      print('Error: POST API not found for post_demo_table');
      throw Exception('POST API not found');
    }

    final recNo = ++_recNoCounter;
    final payload = {
      'RecNo': recNo,
      'Report_name': reportName,
      'Report_label': reportLabel,
      'API_name': apiName,
      'Parameter': parameter,
    };

    print('Saving report with payload: $payload');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('post_demo_table response: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode != 200) {
        print('post_demo_table failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to save report: ${response.statusCode} - ${response.body}');
      }

      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        print('post_demo_table error: ${jsonData['message']}');
        throw Exception('API returned error: ${jsonData['message']}');
      }

      final backendRecNo = int.tryParse(jsonData['RecNo'].toString());
      print('Report saved successfully: RecNo=${backendRecNo ?? recNo}');
      return backendRecNo ?? recNo;
    } catch (e) {
      print('post_demo_table exception: $e');
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
      print('Error: POST API not found for post_database_server');
      throw Exception('POST API not found');
    }

    print('saveDatabaseServer Inputs: serverIP=$serverIP, userName=$userName, '
        'password=$password, databaseName=$databaseName, apiServerURL=$apiServerURL, '
        'apiName=$apiName, parameters=$parameters');

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
          'parameters=${parameters.isEmpty ? "empty" : "non-empty"}');
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

    print('Saving database server with payload: $payload');
    print('Payload JSON: ${jsonEncode(payload)}');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print('post_database_server response: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode != 200) {
        print('post_database_server failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to save database server: ${response.statusCode} - ${response.body}');
      }

      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        print('post_database_server error: ${jsonData['message']}');
        throw Exception('API returned error: ${jsonData['message']}');
      }
      print('Database server saved successfully');
    } catch (e) {
      print('post_database_server exception: $e');
      rethrow;
    }
  }

  Future<void> saveFieldConfigs(List<Map<String, dynamic>> fields, int recNo) async {
    final url = _postEndpoints['post_demo_table2'];
    if (url == null) {
      print('Error: POST API not found for post_demo_table2');
      throw Exception('POST API not found');
    }

    if (fields.isEmpty) {
      print('No fields to save for post_demo_table2 with RecNo $recNo');
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
      };

      print('Saving field config for ${field['Field_name']} with payload: $payload');
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        print('post_demo_table2 response for ${field['Field_name']}: status=${response.statusCode}, body=${response.body}');
        if (response.statusCode != 200) {
          print('post_demo_table2 failed for ${field['Field_name']}: status=${response.statusCode}, body=${response.body}');
          throw Exception('Failed to save field config for ${field['Field_name']}: ${response.statusCode} - ${response.body}');
        }

        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] != 'success') {
          print('post_demo_table2 error for ${field['Field_name']}: ${jsonData['message']}');
          throw Exception('API returned error for ${field['Field_name']}: ${jsonData['message']}');
        }
      } catch (e) {
        print('post_demo_table2 exception for ${field['Field_name']}: $e');
        throw Exception('Failed to save field config for ${field['Field_name']}: $e');
      }
    }
  }

  Future<void> deleteDatabaseServer(String id) async {
    final url = _postEndpoints['delete_database_server'];
    if (url == null) {
      print('Error: POST API not found for delete_database_server');
      throw Exception('POST API not found');
    }

    final payload = {'id': id};
    print('Deleting database server with payload: $payload');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print('delete_database_server response: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode != 200) {
        print('delete_database_server failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to delete database server: ${response.statusCode} - ${response.body}');
      }

      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        print('delete_database_server error: ${jsonData['message']}');
        throw Exception('API returned error: ${jsonData['message']}');
      }
      print('Database server deleted successfully: id=$id');
    } catch (e) {
      print('delete_database_server exception: $e');
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
      print('Error: POST API not found for edit_database_server');
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

    print('Editing database server with payload: $payload');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print('edit_database_server response: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode != 200) {
        print('edit_database_server failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to edit database server: ${response.statusCode} - ${response.body}');
      }

      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        print('edit_database_server error: ${jsonData['message']}');
        throw Exception('API returned error: ${jsonData['message']}');
      }
      print('Database server edited successfully: id=$id');
    } catch (e) {
      print('edit_database_server exception: $e');
      rethrow;
    }
  }

  Future<void> editDemoTables({
    required int recNo,
    required String reportName,
    required String reportLabel,
    required String apiName,
    required String parameter,
    required List<Map<String, dynamic>> fieldConfigs, // Changed to List for multiple fields
  }) async {
    final url = _postEndpoints['edit_demo_tables'];
    if (url == null) {
      print('Error: POST API not found for edit_demo_tables');
      throw Exception('POST API not found');
    }

    final payload = {
      'RecNo': recNo.toString(),
      'Demo_table': {
        'Report_name': reportName.trim(),
        'Report_label': reportLabel.trim(),
        'API_name': apiName.trim(),
        'Parameter': parameter.trim(),
      },
      'Demo_table_2': fieldConfigs.map((field) => {
        'Field_name': field['Field_name']?.toString() ?? '',
        'Field_label': field['Field_label']?.toString() ?? field['Field_name']?.toString() ?? '',
        'Sequence_no': field['Sequence_no'] is int ? field['Sequence_no'] : int.tryParse(field['Sequence_no'].toString()) ?? 0,
        'width': field['width'] is int ? field['width'] : int.tryParse(field['width'].toString()) ?? 100,
        'Total': field['Total'] == true ? 1 : 0,
        'num_alignment': field['num_alignment']?.toString() ?? 'Left',
        'time': field['time'] == true ? 1 : 0,
        'indian_format': field['num_format'] == true ? 1 : 0,
        'decimal_points': field['decimal_points'] is int ? field['decimal_points'] : int.tryParse(field['decimal_points'].toString()) ?? 0,
      }).toList(),
    };

    print('Editing demo tables with payload: $payload');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print('edit_demo_tables response: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode != 200) {
        print('edit_demo_tables failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to edit demo tables: ${response.statusCode} - ${response.body}');
      }

      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        print('edit_demo_tables error: ${jsonData['message']}');
        throw Exception('API returned error: ${jsonData['message']}');
      }
      print('Demo tables edited successfully: RecNo=$recNo');
    } catch (e) {
      print('edit_demo_tables exception: $e');
      rethrow;
    }
  }

  Future<void> deleteDemoTables({
    required int recNo,
  }) async {
    final url = _postEndpoints['delete_demo_tables'];
    if (url == null) {
      print('Error: POST API not found for delete_demo_tables');
      throw Exception('POST API not found');
    }

    final payload = {'RecNo': recNo};
    print('Deleting demo tables with payload: $payload');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print('delete_demo_tables response: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode != 200) {
        print('delete_demo_tables failed: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to delete demo tables: ${response.statusCode} - ${response.body}');
      }

      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') {
        print('delete_demo_tables error: ${jsonData['message']}');
        throw Exception('API returned error: ${jsonData['message']}');
      }
      print('Demo tables deleted successfully: RecNo=$recNo');
    } catch (e) {
      print('delete_demo_tables exception: $e');
      rethrow;
    }
  }
}