import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';

import '../../ReportUtils/subtleloader.dart';
import 'Mainreportbloc.dart';


// MainReport Widget
class MainReport extends StatelessWidget {
  final String fromDate;
  final String toDate;
  final String fieldId;

  const MainReport({
    super.key,
    required this.fromDate,
    required this.toDate,
    required this.fieldId,
  });

  @override
  Widget build(BuildContext context) {
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
            'Complaint Report',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevation: 2,
        ),
        body: BlocBuilder<MainReportBloc, MainReportState>(
          builder: (context, state) {
            if (state is MainReportLoading) {
              return const SubtleLoader();
            } else if (state is MainReportLoaded) {
              // Add SNo column as the first column
              final columns = [
                PlutoColumn(
                  title: 'SNo',
                  field: 'sno',
                  type: PlutoColumnType.number(),
                  width: 60,
                  enableSorting: false,
                  enableFilterMenuItem: false,
                  enableContextMenu: false,
                ),
                ...state.visibleColumns.map((column) => PlutoColumn(
                  title: column['titleName'] as String,
                  field: column['headerName'] as String,
                  type: PlutoColumnType.text(),
                )).toList(),
              ];

              // Add serial number to rows
              final rows = state.reportData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final rowCells = <String, PlutoCell>{
                  'sno': PlutoCell(value: index + 1), // Serial number starting from 1
                };

                for (var column in state.visibleColumns) {
                  final headerName = column['headerName'] as String;
                  rowCells[headerName] = PlutoCell(value: data[headerName] ?? '');
                }
                return PlutoRow(cells: rowCells);
              }).toList();

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: PlutoGrid(
                  columns: columns,
                  rows: rows,
                  onLoaded: (PlutoGridOnLoadedEvent event) {
                    event.stateManager.setShowColumnFilter(true);
                  },
                  configuration: PlutoGridConfiguration(
                    style: PlutoGridStyleConfig(
                      gridBorderColor: Colors.grey[300]!,
                      columnTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      cellTextStyle: GoogleFonts.poppins(),
                    ),
                  ),
                ),
              );
            } else if (state is MainReportError) {
              return Center(
                child: Text(
                  state.message,
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}