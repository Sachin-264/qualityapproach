import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:qualityapproach/QualtyChecks/MRNDetail.dart';
import 'package:qualityapproach/QualtyChecks/MRNbloc.dart';
import '../ReportUtils/ExportsButton.dart';

class MRNReportPage extends StatelessWidget {
  final String branchCode;
  final String fromDate;
  final String toDate;
  final String pending;
  final String str;
  final double UserCode;
  final int UserGroupCode;

  const MRNReportPage({
    required this.branchCode,
    required this.fromDate,
    required this.toDate,
    required this.pending,
    required this.str,
    required this.UserCode,
    required this.UserGroupCode,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MRNReportBloc()
        ..add(FetchMRNReport(
          branchCode: branchCode,
          fromDate: fromDate,
          toDate: toDate,
          pending: pending,
          str: str,
        )),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MRN Report Filter', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.blue,
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Row(
                children: [
                  Icon(Icons.arrow_back_ios, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Back', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            BlocBuilder<MRNReportBloc, MRNReportState>(
              builder: (context, state) {
                if (state is MRNReportLoaded) {
                  log('Exporting data: ${state.reports}');
                  final headerMap = {
                    'SNo': 'SNo', // Generated field
                    'MRN No': 'MRNNO',
                    'MRN Date': 'MRNDATE',
                    'Vendor Name': 'AccountName',
                    'Our Item Code': 'OurItemNo',
                    'Item Name': 'ItemName',
                    'Quantity': 'SNo', // Note: 'Quantity' uses 'SNo' from data
                    'Status': 'status',
                  };

                  // Preprocess data to include SNo as an incrementing number
                  final exportData = state.reports.asMap().entries.map((entry) {
                    final index = entry.key;
                    final report = Map<String, dynamic>.from(entry.value); // Create a mutable copy
                    report['SNo'] = (index + 1).toString(); // Add SNo as string
                    report['status'] = 'Select'; // Ensure status is included
                    return report;
                  }).toList();

                  return ExportButtons(
                    data: exportData,
                    fileName: 'MRN_report',
                    headerMap: headerMap,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child: MRNReportGrid(
                branchCode: branchCode,
                str: str,
                UserCode: UserCode,
                UserGroupCode: UserGroupCode,
                pending: pending,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MRNReportGrid extends StatelessWidget {
  final String branchCode;
  final String str;
  final double UserCode;
  final int UserGroupCode;
  final String pending;

  const MRNReportGrid({
    required this.branchCode,
    required this.pending,
    required this.str,
    required this.UserCode,
    required this.UserGroupCode,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MRNReportBloc, MRNReportState>(
      builder: (context, state) {
        log('Current state in MRNReportGrid: $state');
        if (state is MRNReportLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is MRNReportError) {
          return Center(child: Text(state.message));
        } else if (state is MRNReportLoaded) {
          log('Reports data in MRNReportGrid: ${state.reports}');

          return PlutoGrid(
            columns: _buildColumns(context),
            rows: _buildRows(state.reports),
            configuration: PlutoGridConfiguration(
              columnFilter: PlutoGridColumnFilterConfig(
                filters: const [
                  ...FilterHelper.defaultFilters,
                ],
              ),
            ),
            onLoaded: (PlutoGridOnLoadedEvent event) {
              event.stateManager.setShowColumnFilter(true);
            },
          );
        }
        return const Center(child: Text('No data available'));
      },
    );
  }

  List<PlutoColumn> _buildColumns(BuildContext context) {
    return [
      PlutoColumn(
        title: 'SNo',
        field: 'SNo',
        type: PlutoColumnType.number(),
      ),
      PlutoColumn(
        title: 'MRN No',
        field: 'MRN No',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'MRN Date',
        field: 'MRN Date',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Vendor Name',
        field: 'Vendor Name',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Our Item Code',
        field: 'Our Item Code',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Item Name',
        field: 'Item Name',
        type: PlutoColumnType.text(),
        width: 350,
      ),
      PlutoColumn(
        title: 'Quantity',
        field: 'Quantity',
        type: PlutoColumnType.text(),
        textAlign: PlutoColumnTextAlign.right,
      ),
      PlutoColumn(
        title: 'Status',
        field: 'status',
        type: PlutoColumnType.text(),
        renderer: (rendererContext) {
          return InkWell(
            onTap: () {
              _navigateToMRNDetails(
                context,
                str,
                branchCode,
                rendererContext.row.cells['MRN No']?.value.toString() ?? 'N/A',
                rendererContext.row.cells['MRN Date']?.value.toString() ?? 'N/A',
                rendererContext.row.cells['Vendor Name']?.value.toString() ?? 'N/A',
                rendererContext.row.cells['Item Name']?.value.toString() ?? 'N/A',
                rendererContext.row.cells['ItemNo']?.value.toString() ?? 'N/A',
                rendererContext.row.cells['Quantity']?.value.toString() ?? 'N/A',
                rendererContext.row.cells['RecNo']?.value.toString() ?? 'N/A',
                UserCode,
                UserGroupCode,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text(
                  'View Details',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ];
  }

  List<PlutoRow> _buildRows(List<Map<String, dynamic>> reports) {
    return reports.asMap().entries.map((entry) {
      final index = entry.key;
      final report = entry.value;
      return PlutoRow(
        cells: {
          'SNo': PlutoCell(value: index + 1), // Generate SNo here
          'MRN No': PlutoCell(value: report['MRNNO'] ?? 'N/A'),
          'MRN Date': PlutoCell(value: report['MRNDATE'] ?? 'N/A'),
          'Vendor Name': PlutoCell(value: report['AccountName'] ?? 'N/A'),
          'Our Item Code': PlutoCell(value: report['OurItemNo'] ?? 'N/A'),
          'Item Name': PlutoCell(value: report['ItemName'] ?? 'N/A'),
          'Quantity': PlutoCell(value: report['SNo'] ?? 'N/A'),
          'ItemNo': PlutoCell(value: report['ItemNo'] ?? 'N/A'),
          'RecNo': PlutoCell(value: report['RecNo'] ?? 'N/A'),
          'status': PlutoCell(value: 'Select'),
        },
      );
    }).toList();
  }

  void _navigateToMRNDetails(
      BuildContext context,
      String str,
      String branchCode,
      String mrnNo,
      String mrnDate,
      String vendorName,
      String itemName,
      String itemNo,
      String itemSno,
      String RecNo,
      double UserCode,
      int UserGroupCode,
      ) {
    print('Navigating with the following parameters:');
    print('str: $str');
    print('branchCode: $branchCode');
    print('mrnNo: $mrnNo');
    print('mrnDate: $mrnDate');
    print('vendorName: $vendorName');
    print('itemName: $itemName');
    print('itemNo: $itemNo');
    print('itemSNo: $itemSno');
    print('RecNo: $RecNo');
    print('UserCode: $UserCode');
    print('UserGroupCode: $UserGroupCode');
    print('Pending: $pending');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MRNDetailsPage(
          str: str,
          pending: pending,
          branchCode: branchCode,
          mrnNo: mrnNo,
          mrnDate: mrnDate,
          vendorName: vendorName,
          itemName: itemName,
          itemNo: itemNo,
          itemSno: itemSno,
          RecNo: RecNo,
          UserCode: UserCode,
          UserGroupCode: UserGroupCode,
        ),
      ),
    );
  }
}