import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'dart:developer' as developer;

import '../../ReportUtils/ExportsButton.dart';
import 'Mainreportbloc.dart';
import 'DetailPage.dart';

class MainReport extends StatelessWidget {
  final String fromDate;
  final String toDate;
  final String fieldId;
  final String reportName;

  const MainReport({
    super.key,
    required this.fromDate,
    required this.toDate,
    required this.fieldId,
    required this.reportName,
  });

  @override
  Widget build(BuildContext context) {
    developer.log('Building MainReport widget with reportName: $reportName');
    return BlocProvider(
      create: (context) => MainReportBloc()
        ..add(FetchReportData(
          userCode: '1',
          companyCode: '101',
          fromDate: fromDate,
          toDate: toDate,
          recNo: fieldId,
        )),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue[800],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Custom Report ($reportName)',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevation: 2,
        ),
        body: Column(
          children: [
            BlocBuilder<MainReportBloc, MainReportState>(
              builder: (context, state) {
                developer.log('ExportButtons BlocBuilder state: ${state.runtimeType}');
                if (state is MainReportLoaded) {
                  final headerMap = {
                    'SNo': 'sno',
                    ...Map.fromEntries(
                      state.visibleColumns.map((col) => MapEntry(col['titleName'] as String, col['headerName'] as String)),
                    ),
                    if (state.showAlloted) 'Alloted': 'alloted_column',
                    if (state.showWorkDone) 'Work Done': 'workdone_column',
                    if (state.showFileAttached) 'File Attached': 'fileattached_column',
                  };

                  final exportData = state.reportData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final report = Map<String, dynamic>.from(entry.value);
                    report['sno'] = (index + 1).toString();
                    if (state.showAlloted) report['alloted_column'] = '';
                    if (state.showWorkDone) report['workdone_column'] = '';
                    if (state.showFileAttached) report['fileattached_column'] = '';
                    return report;
                  }).toList();

                  developer.log('ExportButtons prepared with ${exportData.length} rows');
                  return ExportButtons(
                    data: exportData,
                    fileName: 'Custom Report - $reportName',
                    headerMap: headerMap,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child: BlocBuilder<MainReportBloc, MainReportState>(
                builder: (context, state) {
                  developer.log('PlutoGrid BlocBuilder state: ${state.runtimeType}');
                  if (state is MainReportLoading) {
                    developer.log('Showing loading indicator');
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is MainReportLoaded) {
                    developer.log('MainReportLoaded: ${state.reportData.length} rows, ${state.visibleColumns.length} columns');
                    final columns = <PlutoColumn>[
                      PlutoColumn(
                        title: 'SNo',
                        field: 'sno',
                        type: PlutoColumnType.number(),
                        width: 60,
                        enableSorting: false,
                        enableFilterMenuItem: false,
                        enableContextMenu: false,
                      ),
                      ...state.visibleColumns.map((column) {
                        final headerName = column['headerName'] as String;
                        final titleName = column['titleName'] as String;
                        return PlutoColumn(
                          title: titleName,
                          field: headerName,
                          type: PlutoColumnType.text(),
                        );
                      }),
                      if (state.showAlloted)
                        PlutoColumn(
                          title: 'Alloted',
                          field: 'alloted_column',
                          type: PlutoColumnType.text(),
                          width: 150,
                          enableSorting: false,
                          enableFilterMenuItem: false,
                          enableContextMenu: false,
                          renderer: (rendererContext) {
                            return ElevatedButton(
                              onPressed: () {
                                final rowData = rendererContext.row.cells;
                                final allotedColumnsFull = state.visibleColumns
                                    .where((col) => state.allotedColumns.contains(col['titleName']))
                                    .map((col) => {
                                  'titleName': col['titleName'] as String,
                                  'headerName': col['headerName'] as String,
                                })
                                    .toList();
                                developer.log('Navigating to DetailPage (Alloted) with columns: $allotedColumnsFull');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailPage(
                                      selectedColumns: allotedColumnsFull,
                                      type: 'allotmentdetail',
                                      userCode: '1',
                                      companyCode: '101',
                                      recNo: fieldId,
                                      reportName: reportName,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: Text(
                                'Alloted',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      if (state.showWorkDone)
                        PlutoColumn(
                          title: 'Work Done',
                          field: 'workdone_column',
                          type: PlutoColumnType.text(),
                          width: 150,
                          enableSorting: false,
                          enableFilterMenuItem: false,
                          enableContextMenu: false,
                          renderer: (rendererContext) {
                            return ElevatedButton(
                              onPressed: () {
                                final rowData = rendererContext.row.cells;
                                final workDoneColumnsFull = state.visibleColumns
                                    .where((col) => state.workDoneColumns.contains(col['titleName']))
                                    .map((col) => {
                                  'titleName': col['titleName'] as String,
                                  'headerName': col['headerName'] as String,
                                })
                                    .toList();
                                developer.log('Navigating to DetailPage (WorkDone) with columns: $workDoneColumnsFull');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailPage(
                                      selectedColumns: workDoneColumnsFull,
                                      type: 'workdetail',
                                      userCode: '1',
                                      companyCode: '101',
                                      recNo: fieldId,
                                      reportName: reportName,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: Text(
                                'WorkDone',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      if (state.showFileAttached)
                        PlutoColumn(
                          title: 'File Attached',
                          field: 'fileattached_column',
                          type: PlutoColumnType.text(),
                          width: 150,
                          enableSorting: false,
                          enableFilterMenuItem: false,
                          enableContextMenu: false,
                          renderer: (rendererContext) {
                            return ElevatedButton(
                              onPressed: () {
                                final rowData = rendererContext.row.cells;
                                final fileAttachedColumnsFull = state.visibleColumns
                                    .where((col) => state.fileAttachedColumns.contains(col['titleName']))
                                    .map((col) => {
                                  'titleName': col['titleName'] as String,
                                  'headerName': col['headerName'] as String,
                                })
                                    .toList();
                                developer.log('Navigating to DetailPage (FileAttached) with columns: $fileAttachedColumnsFull');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailPage(
                                      selectedColumns: fileAttachedColumnsFull,
                                      type: 'filedetail',
                                      userCode: '1',
                                      companyCode: '101',
                                      recNo: fieldId,
                                      reportName: reportName,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: Text(
                                'FileAttached',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                    ];

                    final uniqueColumns = <String, PlutoColumn>{};
                    for (var column in columns) {
                      if (!uniqueColumns.containsKey(column.field)) {
                        uniqueColumns[column.field] = column;
                      } else {
                        developer.log('Duplicate field detected: ${column.field}');
                        final newField = '${column.field}_${uniqueColumns.length}';
                        uniqueColumns[newField] = PlutoColumn(
                          title: column.title,
                          field: newField,
                          type: column.type,
                          width: column.width,
                          enableSorting: column.enableSorting,
                          enableFilterMenuItem: column.enableFilterMenuItem,
                          enableContextMenu: column.enableContextMenu,
                          renderer: column.renderer,
                        );
                      }
                    }
                    final finalColumns = uniqueColumns.values.toList();
                    developer.log('Final columns prepared: ${finalColumns.length} columns');

                    final rows = state.reportData.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      final rowCells = <String, PlutoCell>{
                        'sno': PlutoCell(value: index + 1),
                      };

                      for (var column in state.visibleColumns) {
                        final headerName = column['headerName'] as String;
                        rowCells[headerName] = PlutoCell(value: data[headerName] ?? '');
                      }

                      if (state.showAlloted) {
                        rowCells['alloted_column'] = PlutoCell(value: '');
                      }
                      if (state.showWorkDone) {
                        rowCells['workdone_column'] = PlutoCell(value: '');
                      }
                      if (state.showFileAttached) {
                        rowCells['fileattached_column'] = PlutoCell(value: '');
                      }

                      return PlutoRow(cells: rowCells);
                    }).toList();
                    developer.log('Rows prepared: ${rows.length} rows');

                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: PlutoGrid(
                        columns: finalColumns,
                        rows: rows,
                        onLoaded: (PlutoGridOnLoadedEvent event) {
                          developer.log('PlutoGrid loaded with ${event.stateManager.rows.length} rows');
                          event.stateManager.setShowColumnFilter(true);
                          event.stateManager.setShowColumnTitle(true);
                        },
                        configuration: PlutoGridConfiguration(
                          style: PlutoGridStyleConfig(
                            gridBorderColor: Colors.grey[300]!,
                            columnTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                            cellTextStyle: GoogleFonts.poppins(),
                          ),
                          columnSize: PlutoGridColumnSizeConfig(
                            autoSizeMode: PlutoAutoSizeMode.scale,
                          ),
                        ),
                      ),
                    );
                  } else if (state is MainReportError) {
                    developer.log('MainReportError: ${state.message}');
                    return Center(
                      child: Text(
                        state.message,
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                    );
                  }
                  developer.log('Returning SizedBox.shrink() for state: ${state.runtimeType}');
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}