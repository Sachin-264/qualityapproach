import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'dart:developer' as developer;

import '../../ReportUtils/ExportsButton.dart';
import 'DetailPageBloc.dart';

class DetailPage extends StatelessWidget {
  final List<Map<String, String>> selectedColumns;
  final String type;
  final String userCode;
  final String companyCode;
  final String recNo;
  final String reportName;

  const DetailPage({
    super.key,
    required this.selectedColumns,
    required this.type,
    required this.userCode,
    required this.companyCode,
    required this.recNo,
    required this.reportName,
  });

  @override
  Widget build(BuildContext context) {
    // Log initial inputs
    developer.log('DetailPage initialized with: type=$type, userCode=$userCode, companyCode=$companyCode, recNo=$recNo');
    developer.log('Selected Columns: $selectedColumns');

    return BlocProvider(
      create: (context) => DetailPageBloc()
        ..add(FetchDetailData(
          type: type,
          userCode: userCode,
          companyCode: companyCode,
          recNo: recNo,
        )),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue[800],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Custom Report - $reportName',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevation: 2,
        ),
        body: Column(
          children: [
            BlocBuilder<DetailPageBloc, DetailPageState>(
              builder: (context, state) {
                developer.log('ExportButtons BlocBuilder state: ${state.runtimeType}');
                if (state is DetailPageLoaded) {
                  if (state.detailData.isEmpty) {
                    developer.log('Detail data is empty');
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No data available for export'),
                    );
                  }
                  final headerMap = Map.fromEntries(
                    selectedColumns.map((col) {
                      final titleName = col['titleName'] ?? 'UnknownTitle';
                      final headerName = col['headerName'] ?? 'UnknownHeader';
                      developer.log('Mapping column: $titleName -> $headerName');
                      return MapEntry(titleName, headerName);
                    }),
                  );
                  developer.log('Exporting data: ${state.detailData}');
                  developer.log('Header Map: $headerMap');
                  return ExportButtons(
                    data: state.detailData,
                    fileName: 'Custom Report - $reportName',
                    headerMap: headerMap,
                  );
                } else if (state is DetailPageLoading) {
                  developer.log('ExportButtons: Loading state');
                  return const SizedBox.shrink();
                } else if (state is DetailPageError) {
                  developer.log('ExportButtons: Error state - ${state.message}');
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Error: ${state.message}',
                      style: GoogleFonts.poppins(color: Colors.red),
                    ),
                  );
                }
                developer.log('ExportButtons: Default state (Initial)');
                return const SizedBox.shrink(); // For DetailPageInitial
              },
            ),
            Expanded(
              child: BlocBuilder<DetailPageBloc, DetailPageState>(
                builder: (context, state) {
                  developer.log('PlutoGrid BlocBuilder state: ${state.runtimeType}');
                  if (state is DetailPageLoading) {
                    developer.log('PlutoGrid: Loading state');
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is DetailPageLoaded) {
                    if (state.detailData.isEmpty || selectedColumns.isEmpty) {
                      developer.log('PlutoGrid: No data or columns available - detailData: ${state.detailData.length}, selectedColumns: ${selectedColumns.length}');
                      return const Center(child: Text('No data or columns to display'));
                    }

                    final columns = selectedColumns.map((column) {
                      final title = column['titleName'] ?? 'Untitled';
                      final field = column['headerName'] ?? 'UnknownField';
                      developer.log('Creating column: title=$title, field=$field');
                      return PlutoColumn(
                        title: title,
                        field: field,
                        type: PlutoColumnType.text(),
                      );
                    }).toList();

                    final rows = state.detailData.map((data) {
                      final rowCells = <String, PlutoCell>{};
                      for (var column in selectedColumns) {
                        final headerName = column['headerName'] ?? 'UnknownField';
                        final value = data[headerName] ?? '';
                        rowCells[headerName] = PlutoCell(value: value.toString());
                        developer.log('Row cell: $headerName = $value');
                      }
                      return PlutoRow(cells: rowCells);
                    }).toList();

                    developer.log('PlutoGrid rendering with ${columns.length} columns and ${rows.length} rows');
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: PlutoGrid(
                        columns: columns,
                        rows: rows,
                        onLoaded: (PlutoGridOnLoadedEvent event) {
                          developer.log('PlutoGrid loaded');
                          event.stateManager.setShowColumnFilter(true);
                          event.stateManager.setShowColumnTitle(true);
                        },
                        configuration: PlutoGridConfiguration(
                          style: PlutoGridStyleConfig(
                            gridBorderColor: Colors.grey[300]!,
                            columnTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                            cellTextStyle: GoogleFonts.poppins(),
                          ),
                          columnSize: const PlutoGridColumnSizeConfig(
                            autoSizeMode: PlutoAutoSizeMode.scale,
                          ),
                        ),
                      ),
                    );
                  } else if (state is DetailPageError) {
                    developer.log('PlutoGrid: Error state - ${state.message}');
                    return Center(
                      child: Text(
                        state.message,
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                    );
                  }
                  developer.log('PlutoGrid: Default state (Initial)');
                  return const Center(child: Text('No data available'));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}