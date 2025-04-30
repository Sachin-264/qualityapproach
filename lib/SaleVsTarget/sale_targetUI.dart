import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../ReportUtils/Appbar.dart';
import '../ReportUtils/ExportsButton.dart';
import '../ReportUtils/subtleloader.dart';
import 'SaleDetailUI.dart';
import 'sale_TargetBloc.dart';


class SaleTargetUI extends StatelessWidget {
  const SaleTargetUI({super.key});

  // Custom Indian number formatter
  String indianNumberFormat(double value) {
    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SaleTargetBloc()..add(FetchSaleTargets()),
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Sales Target Report',
          onBackPress: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.grey[100],
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BlocBuilder<SaleTargetBloc, SaleTargetState>(
            builder: (context, state) {
              if (state is SaleTargetLoading) {
                return const Center(child: SubtleLoader());
              } else if (state is SaleTargetLoaded) {
                final data = state.saleTargets
                    .where((item) =>
                item['TotalTargeValue'] != '.00' ||
                    item['TotalSaleValue'] != '.00' ||
                    item['TotalSaleOrderValue'] != '.00')
                    .toList();

                if (data.isEmpty) {
                  return const Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                final dateFormat = DateFormat('dd-MM-yyyy');
                final currentDate = DateTime.now();
                final daysInMonth =
                    DateTime(currentDate.year, currentDate.month + 1, 0).day;
                final monthName = DateFormat('MMMM').format(currentDate);

                // Header map for export
                final headerMap = {
                  'S.NO': 'serialNo',
                  'Salesman Name': 'SalesManName',
                  for (int i = 1; i <= daysInMonth; i++) ...{
                    'Order Punch ${dateFormat.format(DateTime(currentDate.year, currentDate.month, i))}':
                    'SaleValue$i',
                    'Sale ${dateFormat.format(DateTime(currentDate.year, currentDate.month, i))}':
                    'SaleOrderValue$i',
                  },
                  'Target': 'TotalTargeValue',
                  'Order Punch Total': 'TotalSaleValue',
                  'Sale Invoices Total': 'TotalSaleOrderValue',
                  'Achievement % Order Punch': 'OrderPunchPercent',
                  'Achievement % Sale Invoice': 'SaleInvoicePercent',
                };

                // Calculate totals
                final totals = {
                  for (int i = 1; i <= daysInMonth; i++) ...{
                    'SaleValue$i': 0.0,
                    'SaleOrderValue$i': 0.0,
                  },
                  'TotalTargeValue': 0.0,
                  'TotalSaleValue': 0.0,
                  'TotalSaleOrderValue': 0.0,
                };
                for (var item in data) {
                  for (int i = 1; i <= daysInMonth; i++) {
                    totals['SaleValue$i'] = (totals['SaleValue$i'] ?? 0.0) +
                        (double.tryParse(item['SaleValue$i'] ?? '0') ?? 0.0);
                    totals['SaleOrderValue$i'] =
                        (totals['SaleOrderValue$i'] ?? 0.0) +
                            (double.tryParse(item['SaleOrderValue$i'] ?? '0') ??
                                0.0);
                  }
                  totals['TotalTargeValue'] =
                      (totals['TotalTargeValue'] ?? 0.0) +
                          (double.tryParse(item['TotalTargeValue'] ?? '0') ??
                              0.0);
                  totals['TotalSaleValue'] = (totals['TotalSaleValue'] ?? 0.0) +
                      (double.tryParse(item['TotalSaleValue'] ?? '0') ?? 0.0);
                  totals['TotalSaleOrderValue'] =
                      (totals['TotalSaleOrderValue'] ?? 0.0) +
                          (double.tryParse(item['TotalSaleOrderValue'] ?? '0') ??
                              0.0);
                }

                // Define PlutoGrid columns
                final columns = [
                  PlutoColumn(
                    title: 'Action',
                    field: 'action',
                    type: PlutoColumnType.text(),
                    width: 100,
                    enableSorting: false,
                    enableFilterMenuItem: false,
                    renderer: (rendererContext) {
                      final salesManRecNo =
                          rendererContext.row.cells['SalesManRecNo']?.value ?? '';
                      return TextButton(
                        onPressed: () {
                          final now = DateTime.now();
                          final firstDay = DateFormat('dd-MMM-yyyy')
                              .format(DateTime(now.year, now.month, 1));
                          final lastDay = DateFormat('dd-MMM-yyyy').format(
                              DateTime(now.year, now.month + 1, 0));
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SaleDetailUI(
                                salesManRecNo: salesManRecNo,
                                fromDate: firstDay,
                                toDate: lastDay,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'View',
                          style: TextStyle(color: Colors.blue),
                        ),
                      );
                    },
                  ),
                  PlutoColumn(
                    title: 'S.NO',
                    field: 'serialNo',
                    type: PlutoColumnType.text(),
                    width: 80,
                    textAlign: PlutoColumnTextAlign.center,
                    enableSorting: false,
                    enableFilterMenuItem: true,
                  ),
                  PlutoColumn(
                    title: 'SalesmanName',
                    field: 'SalesManName',
                    type: PlutoColumnType.text(),
                    width: 200,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                  ...List.generate(daysInMonth, (index) {
                    final day = index + 1;
                    final date = dateFormat
                        .format(DateTime(currentDate.year, currentDate.month, day));
                    return [
                      PlutoColumn(
                        title: 'Order($date)',
                        field: 'SaleValue$day',
                        type: PlutoColumnType.number(),
                        width: 200,
                        textAlign: PlutoColumnTextAlign.right,
                        enableSorting: true,
                        enableFilterMenuItem: true,
                        formatter: (value) =>
                            indianNumberFormat(value as double),
                      ),
                      PlutoColumn(
                        title: 'Sale($date)',
                        field: 'SaleOrderValue$day',
                        type: PlutoColumnType.number(),
                        width: 200,
                        textAlign: PlutoColumnTextAlign.right,
                        enableSorting: true,
                        enableFilterMenuItem: true,
                        formatter: (value) =>
                            indianNumberFormat(value as double),
                      ),
                    ];
                  }).expand((pair) => pair).toList(),
                  PlutoColumn(
                    title: '$monthName(Target)',
                    field: 'TotalTargeValue',
                    type: PlutoColumnType.number(),
                    width: 180,
                    textAlign: PlutoColumnTextAlign.right,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                    formatter: (value) => indianNumberFormat(value as double),
                  ),
                  PlutoColumn(
                    title: 'Total(Order Punch)',
                    field: 'TotalSaleValue',
                    type: PlutoColumnType.number(),
                    width: 180,
                    textAlign: PlutoColumnTextAlign.right,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                    formatter: (value) => indianNumberFormat(value as double),
                  ),
                  PlutoColumn(
                    title: 'Total(Sale Invoices)',
                    field: 'TotalSaleOrderValue',
                    type: PlutoColumnType.number(),
                    width: 180,
                    textAlign: PlutoColumnTextAlign.right,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                    formatter: (value) => indianNumberFormat(value as double),
                  ),
                  PlutoColumn(
                    title: '% (Order Punch)',
                    field: 'OrderPunchPercent',
                    type: PlutoColumnType.text(),
                    width: 180,
                    textAlign: PlutoColumnTextAlign.center,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                  PlutoColumn(
                    title: ' % (Sale Invoice)',
                    field: 'SaleInvoicePercent',
                    type: PlutoColumnType.text(),
                    width: 180,
                    textAlign: PlutoColumnTextAlign.center,
                    enableSorting: true,
                    enableFilterMenuItem: true,
                  ),
                ];

                // Define PlutoGrid rows
                final rows = data.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final totalTarget =
                      double.tryParse(item['TotalTargeValue'] ?? '0') ?? 0;
                  final totalSale =
                      double.tryParse(item['TotalSaleValue'] ?? '0') ?? 0;
                  final totalSaleOrder =
                      double.tryParse(item['TotalSaleOrderValue'] ?? '0') ?? 0;
                  final orderPunchPercent = totalTarget != 0
                      ? ((totalSale / totalTarget) * 100).toStringAsFixed(2)
                      : '0';
                  final saleInvoicePercent = totalTarget != 0
                      ? ((totalSaleOrder / totalTarget) * 100).toStringAsFixed(2)
                      : '0';
                  final viewLevel = int.parse(item['ViewLevel'] ?? '0');
                  final displayName = (item['SalesManName'] ?? '').isEmpty
                      ? '  ' * (viewLevel * 2) + (item['SalesManDesignation'] ?? '')
                      : '  ' * (viewLevel * 2) + (item['SalesManName'] ?? '');

                  return PlutoRow(
                    cells: {
                      'action': PlutoCell(value: ''),
                      'serialNo': PlutoCell(value: (index + 1).toString()),
                      'SalesManName': PlutoCell(value: displayName),
                      'SalesManRecNo': PlutoCell(value: item['SalesManRecNo'] ?? ''),
                      'ViewLevel': PlutoCell(value: viewLevel.toString()),
                      for (int i = 1; i <= daysInMonth; i++) ...{
                        'SaleValue$i': PlutoCell(
                            value: double.tryParse(item['SaleValue$i'] ?? '0') ??
                                0.0),
                        'SaleOrderValue$i': PlutoCell(
                            value: double.tryParse(
                                item['SaleOrderValue$i'] ?? '0') ??
                                0.0),
                      },
                      'TotalTargeValue': PlutoCell(
                          value: double.tryParse(
                              item['TotalTargeValue'] ?? '0') ??
                              0.0),
                      'TotalSaleValue': PlutoCell(
                          value: double.tryParse(item['TotalSaleValue'] ?? '0') ??
                              0.0),
                      'TotalSaleOrderValue': PlutoCell(
                          value: double.tryParse(
                              item['TotalSaleOrderValue'] ?? '0') ??
                              0.0),
                      'OrderPunchPercent': PlutoCell(value: '$orderPunchPercent%'),
                      'SaleInvoicePercent': PlutoCell(value: '$saleInvoicePercent%'),
                    },
                  );
                }).toList();

                // Add totals row
                rows.add(PlutoRow(
                  cells: {
                    'action': PlutoCell(value: ''),
                    'serialNo': PlutoCell(value: ''),
                    'SalesManName': PlutoCell(value: 'Total'),
                    'SalesManRecNo': PlutoCell(value: ''),
                    'ViewLevel': PlutoCell(value: '-1'),
                    for (int i = 1; i <= daysInMonth; i++) ...{
                      'SaleValue$i': PlutoCell(
                          value: totals['SaleValue$i'] ?? 0.0),
                      'SaleOrderValue$i': PlutoCell(
                          value: totals['SaleOrderValue$i'] ?? 0.0),
                    },
                    'TotalTargeValue': PlutoCell(
                        value: totals['TotalTargeValue'] ?? 0.0),
                    'TotalSaleValue': PlutoCell(
                        value: totals['TotalSaleValue'] ?? 0.0),
                    'TotalSaleOrderValue': PlutoCell(
                        value: totals['TotalSaleOrderValue'] ?? 0.0),
                    'OrderPunchPercent': PlutoCell(value: ''),
                    'SaleInvoicePercent': PlutoCell(value: ''),
                  },
                ));

                return Column(
                  children: [
                    ExportButtons(
                      data: data,
                      fileName:
                      'sales_target_${DateFormat('MMM_yyyy').format(DateTime.now())}',
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
                            final viewLevel = int.tryParse(
                                context.row.cells['ViewLevel']?.value ??
                                    '0') ??
                                0;
                            if (viewLevel == -1) {
                              return Colors.blueGrey[200]!;
                            } else if ([0, 1, 2].contains(viewLevel)) {
                              return Colors.grey[300]!;
                            }
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