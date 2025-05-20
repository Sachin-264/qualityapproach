import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../ReportUtils/Appbar.dart';
import '../ReportUtils/ExportsButton.dart';
import '../ReportUtils/subtleloader.dart';
import 'SaleDetailUIBloc.dart';

class SaleDetailUI extends StatelessWidget {
  final String salesManRecNo;
  final String fromDate;
  final String toDate;

  const SaleDetailUI({
    super.key,
    required this.salesManRecNo,
    required this.fromDate,
    required this.toDate,
  });

  // Custom Indian number formatter
  String indianNumberFormat(double value) {
    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SaleDetailBloc()
        ..add(FetchSaleDetails(
          salesManRecNo: salesManRecNo,
          fromDate: fromDate,
          toDate: toDate,
        )),
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Sales Detail Report',
          onBackPress: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.grey[100],
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BlocBuilder<SaleDetailBloc, SaleDetailState>(
            builder: (context, state) {
              if (state is SaleDetailLoading) {
                return const Center(child: SubtleLoader());
              } else if (state is SaleDetailLoaded) {
                final data = state.saleDetails;

                if (data.isEmpty) {
                  return const Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                // Header map for export
                final headerMap = {
                  'S.No': 'SNo',
                  'Account Name': 'AccountName',
                  'Account Group': 'AccountGroupName',
                  'Invoice No': 'InvoiceNo',
                  'Invoice Date': 'InvoiceDate',
                  'Salesman Name': 'SalesManName',
                  'State': 'StateName',
                  'Item Name': 'ItemName',
                  'Our Item No': 'OurItemNo',
                  'Unit': 'UnitName',
                  'Item Group': 'ItemGroupName',
                  'Qty': 'Qty',
                  'Net Rate': 'NetRate',
                  'Value': 'Value',
                  'Delivered Qty': 'DeliveredQty',
                  'Remarks': 'ItemRemarks',
                  'Added By': 'AddUserName',
                };

                // Define PlutoGrid columns
                final columns = [
                  PlutoColumn(
                    title: 'S.No',
                    field: 'SNo',
                    type: PlutoColumnType.text(),
                    width: 80,
                    textAlign: PlutoColumnTextAlign.center,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                  PlutoColumn(
                    title: 'Account Name',
                    field: 'AccountName',
                    type: PlutoColumnType.text(),
                    width: 250,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                  PlutoColumn(
                    title: 'Account Group',
                    field: 'AccountGroupName',
                    type: PlutoColumnType.text(),
                    width: 150,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                  PlutoColumn(
                    title: 'Invoice No',
                    field: 'InvoiceNo',
                    type: PlutoColumnType.text(),
                    width: 150,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                  PlutoColumn(
                    title: 'Invoice Date',
                    field: 'InvoiceDate',
                    type: PlutoColumnType.text(),
                    width: 120,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                  PlutoColumn(
                    title: 'Salesman Name',
                    field: 'SalesManName',
                    type: PlutoColumnType.text(),
                    width: 200,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                  PlutoColumn(
                    title: 'State',
                    field: 'StateName',
                    type: PlutoColumnType.text(),
                    width: 120,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                  PlutoColumn(
                    title: 'Item Name',
                    field: 'ItemName',
                    type: PlutoColumnType.text(),
                    width: 200,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                  PlutoColumn(
                    title: 'Our Item No',
                    field: 'OurItemNo',
                    type: PlutoColumnType.text(),
                    width: 120,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                  PlutoColumn(
                    title: 'Unit',
                    field: 'UnitName',
                    type: PlutoColumnType.text(),
                    width: 100,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                  PlutoColumn(
                    title: 'Item Group',
                    field: 'ItemGroupName',
                    type: PlutoColumnType.text(),
                    width: 150,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                  PlutoColumn(
                    title: 'Qty',
                    field: 'Qty',
                    type: PlutoColumnType.number(),
                    width: 100,
                    textAlign: PlutoColumnTextAlign.right,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                    formatter: (value) => indianNumberFormat(value as double),
                  ),
                  PlutoColumn(
                    title: 'Net Rate',
                    field: 'NetRate',
                    type: PlutoColumnType.number(),
                    width: 120,
                    textAlign: PlutoColumnTextAlign.right,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                    formatter: (value) => indianNumberFormat(value as double),
                  ),
                  PlutoColumn(
                    title: 'Value',
                    field: 'Value',
                    type: PlutoColumnType.number(),
                    width: 150,
                    textAlign: PlutoColumnTextAlign.right,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                    formatter: (value) => indianNumberFormat(value as double),
                  ),
                  PlutoColumn(
                    title: 'Delivered Qty',
                    field: 'DeliveredQty',
                    type: PlutoColumnType.number(),
                    width: 120,
                    textAlign: PlutoColumnTextAlign.right,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                    formatter: (value) => indianNumberFormat(value as double),
                  ),
                  PlutoColumn(
                    title: 'Remarks',
                    field: 'ItemRemarks',
                    type: PlutoColumnType.text(),
                    width: 150,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                  PlutoColumn(
                    title: 'Added By',
                    field: 'AddUserName',
                    type: PlutoColumnType.text(),
                    width: 120,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                ];

                // Define PlutoGrid rows
                final rows = data.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  return PlutoRow(
                    cells: {
                      'SNo': PlutoCell(value: (index + 1).toString()),
                      'AccountName': PlutoCell(value: item['AccountName'] ?? ''),
                      'AccountGroupName': PlutoCell(value: item['AccountGroupName'] ?? ''),
                      'InvoiceNo': PlutoCell(value: item['InvoiceNo'] ?? ''),
                      'InvoiceDate': PlutoCell(value: item['InvoiceDate'] ?? ''),
                      'SalesManName': PlutoCell(value: item['SalesManName'] ?? ''),
                      'StateName': PlutoCell(value: item['StateName'] ?? ''),
                      'ItemName': PlutoCell(value: item['ItemName'] ?? ''),
                      'OurItemNo': PlutoCell(value: item['OurItemNo'] ?? ''),
                      'UnitName': PlutoCell(value: item['UnitName'] ?? ''),
                      'ItemGroupName': PlutoCell(value: item['ItemGroupName'] ?? ''),
                      'Qty': PlutoCell(
                          value: double.tryParse(item['Qty']?.toString() ?? '0') ?? 0.0),
                      'NetRate': PlutoCell(
                          value: double.tryParse(item['NetRate']?.toString() ?? '0') ?? 0.0),
                      'Value': PlutoCell(
                          value: double.tryParse(item['Value']?.toString() ?? '0') ?? 0.0),
                      'DeliveredQty': PlutoCell(
                          value: double.tryParse(item['DeliveredQty']?.toString() ?? '0') ?? 0.0),
                      'ItemRemarks': PlutoCell(value: item['ItemRemarks'] ?? ''),
                      'AddUserName': PlutoCell(value: item['AddUserName'] ?? ''),
                    },
                  );
                }).toList();

                return Column(
                  children: [
                    ExportButtons(
                      data: data,
                      fileName: 'sales_detail_${DateFormat('MMM_yyyy').format(DateTime.now())}',
                      headerMap: headerMap,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: PlutoGrid(
                          columns: columns,
                          rows: rows,
                          configuration: PlutoGridConfiguration(
                            style: PlutoGridStyleConfig(
                              gridBackgroundColor: Colors.white,
                              cellTextStyle: GoogleFonts.poppins(fontSize: 12),
                              columnTextStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey[800],
                              ),
                              gridBorderColor: Colors.grey[400]!,
                              borderColor: Colors.grey[400]!,
                              activatedBorderColor: Colors.blueGrey[300]!,
                              inactivatedBorderColor: Colors.grey[400]!,
                            ),
                            columnSize: const PlutoGridColumnSizeConfig(
                              autoSizeMode: PlutoAutoSizeMode.none,
                            ),
                          ),
                          rowColorCallback: (PlutoRowColorContext context) {
                            return context.rowIdx % 2 == 0
                                ? Colors.white
                                : Colors.grey[50]!;
                          },
                          onLoaded: (PlutoGridOnLoadedEvent event) {
                            event.stateManager.setShowColumnFilter(true);
                          },
                        ),
                      ),
                    ),
                  ],
                );
              } else if (state is SaleDetailError) {
                return Center(
                );
              } else {
                return const Center(
                  child: Text(
                    'Error loading data',
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}