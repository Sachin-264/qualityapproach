import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../ReportUtils/Appbar.dart';
import '../ReportUtils/Export_widget.dart';
import '../ReportUtils/subtleloader.dart';
import 'comparison.dart';
import 'detailDashBloc.dart';


class DetailDashPage extends StatefulWidget {
  final Map<String, String> boxData;

  const DetailDashPage({super.key, required this.boxData});

  @override
  _DetailDashPageState createState() => _DetailDashPageState();
}

class _DetailDashPageState extends State<DetailDashPage> {
  late final DetailDashBloc _detailDashBloc;
  PlutoGridStateManager? _stateManager;

  @override
  void initState() {
    super.initState();
    _detailDashBloc = DetailDashBloc()..add(FetchDetailDashData(widget.boxData));
    print('DetailDashPage initState: boxData=${widget.boxData}');
  }

  @override
  void dispose() {
    _detailDashBloc.close();
    super.dispose();
  }

  void _navigateToComparisonPage(BuildContext context, Map<String, dynamic> item) {
    final bidRecNo = (item['BidRecNo'] ?? '').toString().split('.')[0];
    final indentRecNo = (item['IndentRecNo'] ?? '').toString().split('.')[0];
    print('Navigating to ComparisonPage with bidRecNo=$bidRecNo, indentRecNo=$indentRecNo');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComparisonPage(
          bidRecNo: bidRecNo,
          indentRecNo: indentRecNo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Building DetailDashPage: boxData=${widget.boxData}');
    return BlocProvider(
      create: (context) => _detailDashBloc,
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Field Details',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocBuilder<DetailDashBloc, DetailDashState>(
          builder: (context, state) {
            print('BlocBuilder for body - Current state: $state');
            if (state is DetailDashLoading) {
              return const Center(child: SubtleLoader());
            } else if (state is DetailDashError) {
              return Center(
                child: Text(
                  state.message,
                  style: GoogleFonts.poppins(color: Colors.red, fontSize: 16),
                ),
              );
            } else if (state is DetailDashLoaded) {
              final rows = state.data.map((item) {
                final indentNo = (item['IndentNo'] ?? '').toString().split('.')[0];
                return PlutoRow(
                  cells: {
                    'action': PlutoCell(value: 'View'),
                    'indent_no': PlutoCell(value: indentNo),
                    'dept': PlutoCell(value: item['DepartmentName'] ?? ''),
                    'item': PlutoCell(value: item['ItemName'] ?? ''),
                    'qty': PlutoCell(value: item['Qty'] ?? ''),
                    'vendor_name': PlutoCell(value: item['VendorName'] ?? ''),
                    'last_date': PlutoCell(value: item['IndentDate'] ?? ''),
                    'Lowest Vendor': PlutoCell(value: ''),
                    'Lowest Rate': PlutoCell(value: ''),
                    'approval_action': PlutoCell(value: 'Approve'),
                    'remark': PlutoCell(
                      value: state.mergedData['Level1'] == 'Y'
                          ? item['Action_L1_Remark'] ?? ''
                          : item['Action_L2_Remark'] ?? '',
                    ),
                    'select_vendor': PlutoCell(value: item['VendorName'] ?? ''),
                  },
                );
              }).toList();

              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.blueAccent, width: 1.0),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blueAccent),
                        SizedBox(width: 8.0),
                        Text(
                          'Click "View" to compare vendors for an item',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Use ExportWidget instead of ExportButtons
                  ExportWidget(
                    data: state.data,
                    fileName: 'Field_Details',
                    headerMap: {
                      'Indent No': 'IndentNo',
                      'Dept': 'DepartmentName',
                      'Item': 'ItemName',
                      'Qty': 'Qty',
                      'Vendor Name': 'VendorName',
                      'Last Date': 'IndentDate',
                      'Remark': state.mergedData['Level1'] == 'Y' ? 'Action_L1_Remark' : 'Action_L2_Remark',
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: PlutoGrid(
                        columns: [
                          PlutoColumn(
                            title: 'Action',
                            field: 'action',
                            width: 120,
                            type: PlutoColumnType.text(),
                            enableEditingMode: false,
                            enableFilterMenuItem: false,
                            textAlign: PlutoColumnTextAlign.center,
                            titleTextAlign: PlutoColumnTextAlign.center,
                            renderer: (rendererContext) {
                              return TextButton(
                                onPressed: () {
                                  final rowData = state.data.firstWhere(
                                        (item) => (item['IndentNo'] ?? '').toString().split('.')[0] ==
                                        rendererContext.row.cells['indent_no']!.value.toString(),
                                  );
                                  _navigateToComparisonPage(context, rowData);
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'View',
                                  style: GoogleFonts.poppins(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                          PlutoColumn(
                            title: 'Indent No',
                            field: 'indent_no',
                            width: 150,
                            type: PlutoColumnType.text(),
                            enableEditingMode: false,
                            enableFilterMenuItem: true,
                            textAlign: PlutoColumnTextAlign.center,
                            titleTextAlign: PlutoColumnTextAlign.center,
                          ),
                          PlutoColumn(
                            title: 'Dept',
                            field: 'dept',
                            width: 150,
                            type: PlutoColumnType.text(),
                            enableEditingMode: false,
                            enableFilterMenuItem: true,
                            textAlign: PlutoColumnTextAlign.center,
                            titleTextAlign: PlutoColumnTextAlign.center,
                          ),
                          PlutoColumn(
                            title: 'Item',
                            field: 'item',
                            type: PlutoColumnType.text(),
                            enableEditingMode: false,
                            enableFilterMenuItem: true,
                            textAlign: PlutoColumnTextAlign.center,
                            titleTextAlign: PlutoColumnTextAlign.center,
                          ),
                          PlutoColumn(
                            title: 'Qty',
                            field: 'qty',
                            width: 100,
                            type: PlutoColumnType.text(),
                            enableEditingMode: false,
                            enableFilterMenuItem: true,
                            textAlign: PlutoColumnTextAlign.center,
                            titleTextAlign: PlutoColumnTextAlign.center,
                          ),
                          PlutoColumn(
                            title: 'Vendor Name',
                            field: 'vendor_name',
                            type: PlutoColumnType.text(),
                            enableEditingMode: false,
                            enableFilterMenuItem: true,
                            textAlign: PlutoColumnTextAlign.center,
                            titleTextAlign: PlutoColumnTextAlign.center,
                          ),
                          PlutoColumn(
                            title: 'Last Date',
                            field: 'last_date',
                            type: PlutoColumnType.text(),
                            enableEditingMode: false,
                            enableFilterMenuItem: true,
                            textAlign: PlutoColumnTextAlign.center,
                            titleTextAlign: PlutoColumnTextAlign.center,
                          ),
                          PlutoColumn(
                            title: 'Lowest Vendor',
                            field: 'Lowest Vendor',
                            type: PlutoColumnType.text(),
                            enableEditingMode: false,
                            enableFilterMenuItem: true,
                            textAlign: PlutoColumnTextAlign.center,
                            titleTextAlign: PlutoColumnTextAlign.center,
                          ),
                          PlutoColumn(
                            title: 'Lowest Rate',
                            field: 'Lowest Rate',
                            type: PlutoColumnType.text(),
                            enableEditingMode: false,
                            enableFilterMenuItem: true,
                            textAlign: PlutoColumnTextAlign.center,
                            titleTextAlign: PlutoColumnTextAlign.center,
                          ),
                          PlutoColumn(
                            title: 'Action',
                            field: 'approval_action',
                            type: PlutoColumnType.select(['Approve', 'Cancel', 'Discuss', 'Hold']),
                            enableFilterMenuItem: true,
                            textAlign: PlutoColumnTextAlign.center,
                            titleTextAlign: PlutoColumnTextAlign.center,
                            renderer: (rendererContext) {
                              return DropdownButton<String>(
                                value: rendererContext.cell.value,
                                onChanged: (newValue) {
                                  rendererContext.stateManager
                                      .changeCellValue(rendererContext.cell, newValue);
                                },
                                items: ['Approve', 'Cancel', 'Discuss', 'Hold']
                                    .map((value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                ))
                                    .toList(),
                              );
                            },
                          ),
                          PlutoColumn(
                            title: 'Remark',
                            field: 'remark',
                            type: PlutoColumnType.text(),
                            enableFilterMenuItem: true,
                            textAlign: PlutoColumnTextAlign.center,
                            titleTextAlign: PlutoColumnTextAlign.center,
                          ),
                          PlutoColumn(
                            title: 'Select Vendor',
                            field: 'select_vendor',
                            width: 400,
                            type: PlutoColumnType.select(
                                rows.map((row) => row.cells['vendor_name']!.value).toSet().toList()),
                            enableFilterMenuItem: true,
                            textAlign: PlutoColumnTextAlign.center,
                            titleTextAlign: PlutoColumnTextAlign.center,
                            renderer: (rendererContext) {
                              return DropdownButton<String>(
                                value: rendererContext.cell.value,
                                onChanged: (newValue) {
                                  rendererContext.stateManager
                                      .changeCellValue(rendererContext.cell, newValue);
                                },
                                items: rows
                                    .map((row) => row.cells['vendor_name']!.value)
                                    .toSet()
                                    .map((value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                ))
                                    .toList(),
                              );
                            },
                          ),
                        ],
                        rows: rows,
                        configuration: PlutoGridConfiguration(
                          style: PlutoGridStyleConfig(
                            gridBackgroundColor: Colors.white,
                            rowColor: Colors.white,
                            oddRowColor: Colors.grey[100]!,
                            evenRowColor: Colors.white,
                            columnTextStyle: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            cellTextStyle: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            gridBorderRadius: BorderRadius.circular(8),
                            borderColor: Colors.grey[300]!,
                          ),
                        ),
                        onChanged: (PlutoGridOnChangedEvent event) {
                          print('Cell changed: ${event.column.field} = ${event.value}');
                        },
                        onLoaded: (PlutoGridOnLoadedEvent event) {
                          _stateManager = event.stateManager;
                          _stateManager!.setShowColumnFilter(true);
                          print('PlutoGrid loaded, stateManager initialized');
                        },
                      ),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}