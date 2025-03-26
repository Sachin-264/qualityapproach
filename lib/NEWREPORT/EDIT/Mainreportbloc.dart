import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

abstract class MainReportEvent {}

class FetchReportData extends MainReportEvent {
  final String userCode;
  final String companyCode;
  final String fromDate;
  final String toDate;
  final String recNo;

  FetchReportData({
    required this.userCode,
    required this.companyCode,
    required this.fromDate,
    required this.toDate,
    required this.recNo,
  });
}

abstract class MainReportState {}

class MainReportInitial extends MainReportState {}

class MainReportLoading extends MainReportState {}

class MainReportLoaded extends MainReportState {
  final List<Map<String, String>> visibleColumns;
  final List<Map<String, dynamic>> reportData;
  final bool showAlloted;
  final bool showWorkDone;
  final bool showFileAttached;
  final List<String> allotedColumns;
  final List<String> workDoneColumns;
  final List<String> fileAttachedColumns;

  MainReportLoaded({
    required this.visibleColumns,
    required this.reportData,
    required this.showAlloted,
    required this.showWorkDone,
    required this.showFileAttached,
    required this.allotedColumns,
    required this.workDoneColumns,
    required this.fileAttachedColumns,
  });
}

class MainReportError extends MainReportState {
  final String message;

  MainReportError(this.message);
}

class MainReportBloc extends Bloc<MainReportEvent, MainReportState> {
  MainReportBloc() : super(MainReportInitial()) {
    on<FetchReportData>(_onFetchReportData);
  }

  final DateFormat _dateFormatter = DateFormat('dd-MMM-yyyy');

  bool _showAlloted = false;
  bool _showWorkDone = false;
  bool _showFileAttached = false;

  static const Set<String> _allotedColumns = {
    'Urgent/Routine', 'Tentative Service Date', 'From Time', 'To Time',
    'Alloted To', 'Mobile No', 'Allotment Remarks', 'Other Name',
    'Other Mobile No', 'Tentative Parts Cost', 'Tentative Service Charge'
  };

  static const Set<String> _workDoneColumns = {
    'Service Cost', 'Rejection Type', 'Rejection Others', 'Service Date',
    'Worked By', 'Is Parts Required', 'Work Done', 'Next Service Date',
    'Next Service Remaks', 'Visit Date', 'Visit time', 'Parts Cost Amount',
    'Parts Remaks', 'Service Charge Amount', 'Service Charge Remarks',
    'Total Charges'
  };

  static const Set<String> _fileAttachmentColumns = {'File Attachment'};

  Future<void> _onFetchReportData(FetchReportData event, Emitter<MainReportState> emit) async {
    developer.log('FetchReportData event triggered with: userCode=${event.userCode}, recNo=${event.recNo}, fromDate=${event.fromDate}, toDate=${event.toDate}');
    emit(MainReportLoading());
    developer.log('State changed to MainReportLoading');

    try {
      String formattedFromDate;
      String formattedToDate;

      try {
        final fromDateTime = DateTime.parse(event.fromDate);
        final toDateTime = DateTime.parse(event.toDate);
        formattedFromDate = _dateFormatter.format(fromDateTime);
        formattedToDate = _dateFormatter.format(toDateTime);
        developer.log('Dates formatted successfully: $formattedFromDate to $formattedToDate');
      } catch (e) {
        formattedFromDate = event.fromDate;
        formattedToDate = event.toDate;
        developer.log('Date parsing failed, using raw input: $formattedFromDate to $formattedToDate, error: $e');
      }

      final designUrl =
          'http://localhost/Bestapi/sp_LoadComplaintReportDesignMaster.php?UserCode=1&CompanyCode=101&RecNo=${event.recNo}';
      developer.log('Fetching design data from: $designUrl');

      final designResponse = await http.get(Uri.parse(designUrl));
      developer.log('Design API response status: ${designResponse.statusCode}');

      if (designResponse.statusCode == 200) {
        final designData = jsonDecode(designResponse.body);
        developer.log('Design API response: ${designData.toString().substring(0, 100)}...'); // Log first 100 chars

        if (designData['status'] == 'success') {
          final visibleColumnsMap = <String, Map<String, String>>{};
          final columnList = (designData['data'] as List)
              .where((column) => column['IsVisible'] == 'Y')
              .toList();
          developer.log('Visible columns count: ${columnList.length}');

          final visibleTitles = columnList.map((column) => column['EnterColumnHeading'] as String).toSet();

          _showAlloted = visibleTitles.intersection(_allotedColumns).isNotEmpty;
          _showWorkDone = visibleTitles.intersection(_workDoneColumns).isNotEmpty;
          _showFileAttached = visibleTitles.intersection(_fileAttachmentColumns).isNotEmpty;

          developer.log('Button Visibility - Alloted: $_showAlloted, Matching Columns: ${visibleTitles.intersection(_allotedColumns)}');
          developer.log('Button Visibility - WorkDone: $_showWorkDone, Matching Columns: ${visibleTitles.intersection(_workDoneColumns)}');
          developer.log('Button Visibility - FileAttached: $_showFileAttached, Matching Columns: ${visibleTitles.intersection(_fileAttachmentColumns)}');

          for (var i = 0; i < columnList.length; i++) {
            final column = columnList[i];
            final columnName = column['ColumnName'] as String;
            final headerNameBase = columnName.split('.').last;
            final titleName = column['EnterColumnHeading'] as String;
            var headerName = headerNameBase;

            if (visibleColumnsMap.containsKey(headerName)) {
              headerName = '${headerNameBase}_$i';
              developer.log('Duplicate headerName detected: $headerNameBase, renamed to $headerName');
            }

            visibleColumnsMap[headerName] = {
              'headerName': headerName,
              'titleName': titleName,
            };
          }

          final visibleColumns = visibleColumnsMap.values.toList();
          developer.log('Processed visible columns: ${visibleColumns.length} columns');

          final reportUrl =
              'http://localhost/Bestapi/sp_GetComplaintReportDesignMasterDetails.php?UserCode=1&CompanyCode=101&FromDate=$formattedFromDate&ToDate=$formattedToDate&CustomerName=&ItemNo=';
          developer.log('Fetching report data from: $reportUrl');

          final reportResponse = await http.get(Uri.parse(reportUrl));
          developer.log('Report API response status: ${reportResponse.statusCode}');

          if (reportResponse.statusCode == 200) {
            final reportData = jsonDecode(reportResponse.body);
            developer.log('Report API response: ${reportData.toString().substring(0, 100)}...');

            if (reportData['status'] == 'success') {
              final List<Map<String, dynamic>> typedReportData = (reportData['data'] as List)
                  .map((item) => item as Map<String, dynamic>)
                  .toList();
              developer.log('Report data loaded: ${typedReportData.length} rows');

              emit(MainReportLoaded(
                visibleColumns: visibleColumns,
                reportData: typedReportData,
                showAlloted: _showAlloted,
                showWorkDone: _showWorkDone,
                showFileAttached: _showFileAttached,
                allotedColumns: _allotedColumns.toList(),
                workDoneColumns: _workDoneColumns.toList(),
                fileAttachedColumns: _fileAttachmentColumns.toList(),
              ));
              developer.log('State changed to MainReportLoaded');
            } else {
              emit(MainReportError('Failed to load report data: ${reportData['message']}'));
              developer.log('State changed to MainReportError: ${reportData['message']}');
            }
          } else {
            emit(MainReportError('Error fetching report data: HTTP ${reportResponse.statusCode}'));
            developer.log('State changed to MainReportError: HTTP ${reportResponse.statusCode}');
          }
        } else {
          emit(MainReportError('Failed to load column design: ${designData['message']}'));
          developer.log('State changed to MainReportError: ${designData['message']}');
        }
      } else {
        emit(MainReportError('Error fetching column design: HTTP ${designResponse.statusCode}'));
        developer.log('State changed to MainReportError: HTTP ${designResponse.statusCode}');
      }
    } catch (e) {
      emit(MainReportError('An error occurred: $e'));
      developer.log('State changed to MainReportError: $e');
    }
  }
}