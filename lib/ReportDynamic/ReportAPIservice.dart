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
      'post_demo_table': '$_baseUrl?mode=post_demo_table',
      'post_demo_table2': '$_baseUrl?mode=post_demo_table2',
      'post_database_server': '$_baseUrl?mode=post_database_server',
      'delete_database_server': '$_baseUrl?mode=delete_database_server',
      'edit_database_server': '$_baseUrl?mode=edit_database_server',
      'edit_demo_tables': '$_baseUrl?mode=edit_demo_tables',
      'delete_demo_tables': '$_baseUrl?mode=delete_demo_tables',
      'deploy_report': 'http://localhost/reportBuilder/deploy_report_to_client.php',
    };

    _getEndpoints = {
      'fetch_tables_and_fields': _databaseFieldUrl,
      'get_database_server': '$_baseUrl?mode=get_database_server',
      'get_demo_table': '$_baseUrl?mode=get_demo_table',
      'get_demo_table2': '$_baseUrl?mode=get_demo_table2',
      'fetch_databases': _databaseFetchUrl,
    };
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
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <String>[];
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          return List<String>.from(jsonData['databases'] ?? []);
        } else {
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        throw Exception('Failed to fetch databases: ${response.statusCode} - ${response.body}');
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
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <String>[];
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['tables'] is List) {
          return List<String>.from(jsonData['tables'].map((item) => item.toString()));
        } else {
          throw Exception('API returned error or unexpected data format: ${jsonData['message'] ?? response.body}');
        }
      } else {
        throw Exception('Failed to fetch tables: ${response.statusCode} - ${response.body}');
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
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <String>[];
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['fields'] is List) {
          return List<String>.from(jsonData['fields'].map((item) => item.toString()));
        } else {
          throw Exception('API returned error or unexpected data format for fields: ${jsonData['message'] ?? response.body}');
        }
      } else {
        throw Exception('Failed to fetch fields: ${response.statusCode} - ${response.body}');
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
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <Map<String, dynamic>>[];
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['data'] is List) {
          return (jsonData['data'] as List).whereType<Map<String, dynamic>>().toList();
        } else {
          throw Exception('API returned error or unexpected data format for picker data: ${jsonData['message'] ?? response.body}');
        }
      } else {
        throw Exception('Failed to fetch picker data: ${response.statusCode} - ${response.body}');
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
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <String>[];
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['data'] is List) {
          return List<String>.from(jsonData['data'].map((item) => item.toString()));
        } else {
          throw Exception('API returned error or unexpected data format: ${jsonData['message'] ?? response.body}');
        }
      } else {
        throw Exception('Failed to fetch field values: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> getAvailableApis() async {
    final url = _getEndpoints['get_database_server'];
    if (url == null) throw Exception('GET API not found');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <String>[];
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          _apiDetails = {};
          final uniqueApis = <String>{};
          for (var item in jsonData['data']) {
            if (item is Map<String, dynamic> && item['APIName'] != null) {
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
                  'actions_config': item['actions_config'] != null && item['actions_config'].toString().isNotEmpty ? jsonDecode(item['actions_config']) : <dynamic>[],
                };
              }
            }
          }
          return uniqueApis.toList();
        } else {
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        throw Exception('Failed to load APIs: ${response.statusCode} - ${response.body}');
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
      final response = await http.get(uri);
      return _parseApiResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchReportDataFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 120));
      return _parseApiResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> fetchRawJsonFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        if (response.body.isEmpty) return {};
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch raw JSON from $url: ${response.statusCode} - ${response.body}');
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
      throw Exception('Failed to parse response JSON: $e. Response was: "${response.body}".');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDemoTable() async {
    final url = _getEndpoints['get_demo_table'];
    if (url == null) throw Exception('GET API not found');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <Map<String, dynamic>>[];
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
      } else {
        throw Exception('Failed to load data: ${response.statusCode} - ${response.body}');
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
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        if (response.body.isEmpty) return <Map<String, dynamic>>[];
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
      } else {
        throw Exception('Failed to load data: ${response.statusCode} - ${response.body}');
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
    required List<Map<String, dynamic>> fields,
    List<Map<String, dynamic>> actions = const <Map<String, dynamic>>[],
    required bool includePdfFooterDateTime,
  }) async {
    final url = _postEndpoints['post_demo_table'];
    if (url == null) throw Exception('POST API not found');

    final recNo = ++_recNoCounter;
    final payload = {'RecNo': recNo, 'Report_name': reportName, 'Report_label': reportLabel, 'API_name': apiName, 'Parameter': parameter, 'actions_config': jsonEncode(actions), 'pdf_footer_datetime': includePdfFooterDateTime ? 1 : 0};
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) throw Exception('Failed to save report: ${response.statusCode} - ${response.body}');
      if (response.body.isEmpty) throw Exception('API returned empty response, cannot confirm save.');
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') throw Exception('API returned error: ${jsonData['message']}');
      final backendRecNo = int.tryParse(jsonData['RecNo'].toString());
      return backendRecNo ?? recNo;
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
    final payload = {'ServerIP': serverIP.trim(), 'UserName': userName.trim(), 'Password': password.trim(), 'DatabaseName': databaseName.trim(), 'APIServerURl': apiServerURL.trim(), 'APIName': apiName.trim(), 'Parameter': parameters.isNotEmpty ? jsonEncode(parameters) : ''};
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) throw Exception('Failed to save database server: ${response.statusCode} - ${response.body}');
      if (response.body.isEmpty) return;
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') throw Exception('API returned error: ${jsonData['message']}');
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
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (response.statusCode != 200) throw Exception('Failed to save field config for ${field['Field_name']}: ${response.statusCode} - ${response.body}');
        if (response.body.isEmpty) continue;
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] != 'success') throw Exception('API returned error: ${jsonData['message']}');
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
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) throw Exception('Failed to delete database server: ${response.statusCode} - ${response.body}');
      if (response.body.isEmpty) return;
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') throw Exception('API returned error: ${jsonData['message']}');
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
  }) async {
    final url = _postEndpoints['edit_database_server'];
    if (url == null) throw Exception('POST API not found');
    final payload = {'id': id, 'ServerIP': serverIP.trim(), 'UserName': userName.trim(), 'Password': password.trim(), 'DatabaseName': databaseName.trim(), 'APIServerURl': apiServerURL.trim(), 'APIName': apiName.trim(), 'Parameter': parameters.isNotEmpty ? jsonEncode(parameters) : ''};
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) throw Exception('Failed to edit database server: ${response.statusCode} - ${response.body}');
      if (response.body.isEmpty) return;
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') throw Exception('API returned error: ${jsonData['message']}');
    } catch (e) {
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
    if (url == null) throw Exception('POST API not found');
    final payload = {'RecNo': recNo.toString(), 'Demo_table': {'Report_name': reportName.trim(), 'Report_label': reportLabel.trim(), 'API_name': apiName.trim(), 'Parameter': parameter.trim(), 'actions_config': jsonEncode(actions), 'pdf_footer_datetime': includePdfFooterDateTime ? 1 : 0}, 'Demo_table_2': fieldConfigs};
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) throw Exception('Failed to edit demo tables: ${response.statusCode} - ${response.body}');
      if (response.body.isEmpty) return;
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') throw Exception('API returned error: ${jsonData['message']}');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteDemoTables({required int recNo}) async {
    final url = _postEndpoints['delete_demo_tables'];
    if (url == null) throw Exception('POST API not found');
    final payload = {'RecNo': recNo};
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) throw Exception('Failed to delete demo tables: ${response.statusCode} - ${response.body}');
      if (response.body.isEmpty) return {'status': 'success', 'message': 'Operation completed but no response body.'};
      final jsonData = jsonDecode(response.body);
      if (jsonData['status'] != 'success') throw Exception('API returned error: ${jsonData['message']}');
      return jsonData;
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
    final url = _postEndpoints['deploy_report'];
    if (url == null) throw Exception('POST API not found for deployment.');
    final payload = {'report_metadata': jsonEncode(reportMetadata), 'field_configs': jsonEncode(fieldConfigs), 'client_server': clientServerIP.trim(), 'client_user': clientUserName.trim(), 'client_password': clientPassword.trim(), 'client_database': clientDatabaseName.trim()};
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 180));
      if (response.statusCode == 200) {
        if (response.body.isEmpty) throw Exception('Empty response body from deployment script.');
        return jsonDecode(response.body);
      } else {
        throw Exception('Server error during deployment: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> postJson(String url, Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return {'status': 'success', 'message': 'Operation successful with no content.'};
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
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map<String, dynamic>) return errorBody;
        } catch (_) {
          throw Exception('Server error: ${response.statusCode} - ${response.body}');
        }
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Failed to process request: $e'};
    }
  }
}