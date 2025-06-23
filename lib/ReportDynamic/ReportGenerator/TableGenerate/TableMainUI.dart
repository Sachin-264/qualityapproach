// lib/ReportDynamic/TableGenerator/TableMainUI.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart'; // For PdfColor constants

import '../../../ReportUtils/Appbar.dart';
import '../../../ReportUtils/CustomPlutogrid.dart';
import '../../../ReportUtils/Export_widget.dart';
import '../../../ReportUtils/subtleloader.dart';
import '../../ReportAPIService.dart';
import 'TableBLoc.dart'; // Direct import (no alias here)
import '../PrintTemp/printpreview.dart';
import '../PrintTemp/print_template_selection.dart';

// CONVERTED TO STATEFULWIDGET to handle temporary loaders
class TableMainUI extends StatefulWidget {
  final String recNo;
  final String apiName;
  final String reportLabel;
  final Map<String, String> userParameterValues;
  final List<Map<String, dynamic>> actionsConfig;
  final Map<String, String> displayParameterValues;
  final String companyName;
  final Map<String, String>? parentDisplayParameterValues;

  const TableMainUI({
    super.key,
    required this.recNo,
    required this.apiName,
    required this.reportLabel,
    required this.userParameterValues,
    this.actionsConfig = const [],
    required this.displayParameterValues,
    required this.companyName,
    this.parentDisplayParameterValues,
  });

  @override
  State<TableMainUI> createState() => _TableMainUIState();
}

class _TableMainUIState extends State<TableMainUI> {
  Timer? _noConfigTimer;
  bool _showNoConfigMessage = false;

  Timer? _noDataTimer;
  bool _showNoDataMessage = false;

  @override
  void dispose() {
    _noConfigTimer?.cancel();
    _noDataTimer?.cancel();
    super.dispose();
  }

  static String formatIndianNumber(double number, int decimalPoints) {
    String pattern = '##,##,##0';
    if (decimalPoints > 0) {
      pattern += '.${'0' * decimalPoints}';
    }
    final NumberFormat indianFormat = NumberFormat(
      pattern,
      'en_IN',
    );
    return indianFormat.format(number);
  }

  PlutoRow _createSubtotalRow({
    required String groupName,
    required Map<String, double> subtotals,
    required List<Map<String, dynamic>> sortedFieldConfigs,
    required String? breakpointColumnName,
    required bool hasActionsColumn,
    required List<Map<String, dynamic>> actionsConfigForSubtotalRow,
    required Map<String, bool> numericColumnMap,
    required Map<String, int> subtotalColumnDecimals,
    required Map<String, bool> indianFormatColumnMap,
  }) {
    final Map<String, PlutoCell> subtotalCells = {};
    final allFieldNames = sortedFieldConfigs.map((c) => c['Field_name'].toString()).toSet();
    for (var action in actionsConfigForSubtotalRow) {
      final params = List<dynamic>.from(action['params'] ?? []);
      for (var param in params) {
        allFieldNames.add(param['parameterValue'].toString());
      }
    }

    for (var fieldName in allFieldNames) {
      final config = sortedFieldConfigs.firstWhere(
            (cfg) => cfg['Field_name']?.toString() == fieldName,
        orElse: () => {'Field_name': fieldName, 'data_type': 'text', 'decimal_points': '0', 'indian_format': '0'},
      );
      final isSubtotalColumn = config['SubTotal']?.toString() == '1';
      final isNumeric = numericColumnMap[fieldName] ?? false;

      if (fieldName == breakpointColumnName) {
        subtotalCells[fieldName] = PlutoCell(value: 'Subtotal ($groupName)');
      } else if (isSubtotalColumn && isNumeric) {
        final sum = subtotals[fieldName] ?? 0.0;
        subtotalCells[fieldName] = PlutoCell(value: sum);
      } else {
        subtotalCells[fieldName] = PlutoCell(value: '');
      }
    }
    subtotalCells['__actions__'] = PlutoCell(value: '');
    subtotalCells['__isSubtotal__'] = PlutoCell(value: true);
    subtotalCells['__raw_data__'] = PlutoCell(value: {});
    return PlutoRow(cells: subtotalCells);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: widget.reportLabel,
        onBackPress: () => Navigator.pop(context),
      ),
      body: BlocListener<TableBlocGenerate, ReportState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!), backgroundColor: Colors.redAccent));
          }
        },
        child: BlocBuilder<TableBlocGenerate, ReportState>(
          builder: (context, state) {
            // Priority 1: Main loading state from BLoC
            if (state.isLoading) {
              _noConfigTimer?.cancel();
              _noDataTimer?.cancel();
              _showNoConfigMessage = false;
              _showNoDataMessage = false;
              return const Center(child: SubtleLoader());
            }

            if (state.error != null) {
              return Center(child: Text('Error: ${state.error}', style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 16), textAlign: TextAlign.center));
            }

            // #######################################################
            // #             START OF NEW UI-LEVEL FIX                 #
            // #######################################################
            // Priority 2: Check for field configurations with a delay
            if (state.fieldConfigs.isEmpty) {
              if (_showNoConfigMessage) {
                return Center(child: Text('No field configurations available for this report.', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16), textAlign: TextAlign.center));
              }

              if (_noConfigTimer == null || !_noConfigTimer!.isActive) {
                _noConfigTimer = Timer(const Duration(seconds: 10), () {
                  if (context.read<TableBlocGenerate>().state.fieldConfigs.isEmpty) {
                    if (mounted) setState(() => _showNoConfigMessage = true);
                  }
                });
              }

              return Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SubtleLoader(),
                  const SizedBox(height: 16),
                  Text('Loading configuration...', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16)),
                ],
                ),
              );
            }
            // If we've passed the check, configs exist. Cancel the timer.
            _noConfigTimer?.cancel();
            _showNoConfigMessage = false;

            // Priority 3: Check for report data with a delay
            if (state.reportData.isEmpty) {
              if (_showNoDataMessage) {
                return Center(child: Text('No report data available for the selected parameters.', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16), textAlign: TextAlign.center));
              }

              if (_noDataTimer == null || !_noDataTimer!.isActive) {
                _noDataTimer = Timer(const Duration(seconds: 10), () {
                  if (context.read<TableBlocGenerate>().state.reportData.isEmpty) {
                    if (mounted) setState(() => _showNoDataMessage = true);
                  }
                });
              }

              return Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SubtleLoader(),
                  const SizedBox(height: 16),
                  Text('Fetching data...', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16)),
                ],
                ),
              );
            }
            // If we've passed this check, data exists. Cancel the timer.
            _noDataTimer?.cancel();
            _showNoDataMessage = false;
            // #######################################################
            // #              END OF NEW UI-LEVEL FIX                  #
            // #######################################################

            // --- If all checks pass, build the grid ---
            final sortedFieldConfigs = List<Map<String, dynamic>>.from(state.fieldConfigs)
              ..sort((a, b) => int.parse(a['Sequence_no']?.toString() ?? '0').compareTo(int.parse(b['Sequence_no']?.toString() ?? '0')));

            String? breakpointColumnName;
            final List<String> subtotalColumnNames = [];
            final Map<String, int> subtotalColumnDecimals = {};
            final Map<String, bool> numericColumnMap = {};
            final Map<String, bool> imageColumnMap = {};
            final Map<String, bool> indianFormatColumnMap = {};
            bool hasGrandTotals = false;

            for (var config in sortedFieldConfigs) {
              final fieldName = config['Field_name']?.toString() ?? 'N/A';
              final dataType = config['data_type']?.toString().toLowerCase();
              final bool isMarkedForAggregation = config['Total']?.toString() == '1' || config['SubTotal']?.toString() == '1';
              final bool hasNumericDataType = ['number', 'decimal', 'integer'].contains(dataType);
              final bool isKnownNumericName = ['vq_grandtotal', 'qty', 'rate', 'netrate', 'grandtotal', 'value', 'amount', 'excise', 'cess', 'hscess', 'freight', 'tcs', 'cgst', 'sgst', 'igst'].contains(fieldName.toLowerCase());
              final bool currentFieldIsNumeric = isMarkedForAggregation || hasNumericDataType || isKnownNumericName;

              numericColumnMap[fieldName] = currentFieldIsNumeric;
              imageColumnMap[fieldName] = config['image']?.toString() == '1';
              indianFormatColumnMap[fieldName] = config['indian_format']?.toString() == '1';

              if (config['Breakpoint']?.toString() == '1') breakpointColumnName = fieldName;
              if (config['SubTotal']?.toString() == '1' && currentFieldIsNumeric) {
                subtotalColumnNames.add(fieldName);
                subtotalColumnDecimals[fieldName] = int.tryParse(config['decimal_points']?.toString().trim() ?? '0') ?? 0;
              }
              if (config['Total']?.toString() == '1' && currentFieldIsNumeric) hasGrandTotals = true;
            }

            final List<PlutoColumn> columns = [];
            columns.addAll(sortedFieldConfigs.asMap().entries.map((entry) {
              final i = entry.key;
              final config = entry.value;
              final fieldName = config['Field_name']?.toString() ?? '';
              final fieldLabel = config['Field_label']?.toString() ?? '';
              final width = double.tryParse(config['width']?.toString() ?? '120') ?? 120.0;
              final total = config['Total']?.toString() == '1';
              final alignment = config['num_alignment']?.toString().toLowerCase() ?? 'left';
              final int decimalPoints = int.tryParse(config['decimal_points']?.toString().trim() ?? '0') ?? 0;
              final bool isNumericField = numericColumnMap[fieldName] ?? false;
              final bool isImageColumn = imageColumnMap[fieldName] ?? false;
              final bool useIndianFormatForColumn = indianFormatColumnMap[fieldName] ?? false;
              String plutoGridFormatString = '#,##0';
              if (decimalPoints > 0) plutoGridFormatString += '.${'0' * decimalPoints}';

              return PlutoColumn(
                title: fieldLabel,
                field: fieldName,
                type: isNumericField ? PlutoColumnType.number(format: plutoGridFormatString) : PlutoColumnType.text(),
                width: width,
                textAlign: alignment == 'center' ? PlutoColumnTextAlign.center : (alignment == 'right' ? PlutoColumnTextAlign.right : PlutoColumnTextAlign.left),
                enableFilterMenuItem: true,
                footerRenderer: (rendererContext) {
                  if (!hasGrandTotals) return const SizedBox.shrink();
                  if (i == 0) return PlutoAggregateColumnFooter(rendererContext: rendererContext, type: PlutoAggregateColumnType.count, alignment: Alignment.centerLeft, titleSpanBuilder: (text) => [TextSpan(text: 'Grand Total', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))]);
                  if (total && isNumericField) {
                    double sum = rendererContext.stateManager.rows.where((row) => row.cells['__isSubtotal__']?.value != true).fold(0.0, (prev, row) => prev + (double.tryParse(row.cells[fieldName]?.value.toString() ?? '0') ?? 0.0));
                    final String formattedTotal = useIndianFormatForColumn ? formatIndianNumber(sum, decimalPoints) : sum.toStringAsFixed(decimalPoints);
                    return PlutoAggregateColumnFooter(rendererContext: rendererContext, type: PlutoAggregateColumnType.sum, format: plutoGridFormatString, alignment: Alignment.centerRight, titleSpanBuilder: (text) => [TextSpan(text: formattedTotal, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))]);
                  }
                  return const SizedBox.shrink();
                },
                renderer: (rendererContext) {
                  final rawCellValue = rendererContext.cell.value;
                  final String valueString = rawCellValue?.toString() ?? '';
                  final isSubtotalRow = rendererContext.row.cells['__isSubtotal__']?.value == true;

                  if (isImageColumn && valueString.isNotEmpty && (valueString.startsWith('http://') || valueString.startsWith('https://'))) {
                    return Padding(padding: const EdgeInsets.all(2.0), child: ClipRRect(borderRadius: BorderRadius.circular(4.0),
                      child: Image.network(valueString, fit: BoxFit.contain, alignment: Alignment.center,
                        loadingBuilder: (ctx, child, progress) => progress == null ? child : Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0, value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null))),
                        errorBuilder: (ctx, err, st) => Center(child: Icon(Icons.broken_image, color: Colors.red[300], size: 24)),
                      ),
                    ),
                    );
                  }
                  Widget textWidget;
                  if (isNumericField && rawCellValue != null) {
                    final number = double.tryParse(rawCellValue.toString()) ?? 0.0;
                    final String formattedNumber = useIndianFormatForColumn ? formatIndianNumber(number, decimalPoints) : number.toStringAsFixed(decimalPoints);
                    textWidget = Text(isSubtotalRow && rawCellValue == 0.0 ? '' : formattedNumber, style: GoogleFonts.poppins(fontSize: 12, fontWeight: isSubtotalRow ? FontWeight.bold : FontWeight.normal), textAlign: alignment == 'center' ? TextAlign.center : (alignment == 'right' ? TextAlign.right : TextAlign.left));
                  } else {
                    textWidget = Text(valueString, style: GoogleFonts.poppins(fontSize: 12, fontWeight: isSubtotalRow ? FontWeight.bold : FontWeight.normal), textAlign: isSubtotalRow && fieldName == breakpointColumnName ? TextAlign.left : (alignment == 'center' ? TextAlign.center : (alignment == 'right' ? TextAlign.right : TextAlign.left)));
                  }
                  return textWidget;
                },
              );
            }));

            columns.add(PlutoColumn(title: 'Raw Data (Hidden)', field: '__raw_data__', type: PlutoColumnType.text(), hide: true, width: 1, enableFilterMenuItem: false, enableSorting: false, enableRowChecked: false, enableContextMenu: false));
            final bool showActionsColumnFromState = state.actionsConfig.isNotEmpty;
            if (showActionsColumnFromState) {
              columns.add(PlutoColumn(title: 'Actions', field: '__actions__', type: PlutoColumnType.text(), width: state.actionsConfig.length * 100.0, minWidth: 120, enableFilterMenuItem: false, enableSorting: false, enableRowChecked: false, enableContextMenu: false,
                renderer: (rendererContext) {
                  if (rendererContext.row.cells['__isSubtotal__']?.value == true) return const SizedBox.shrink();
                  final Map<String, dynamic> originalRowData = (rendererContext.row.cells['__raw_data__']?.value as Map<String, dynamic>?) ?? {};
                  return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(mainAxisSize: MainAxisSize.min,
                    children: state.actionsConfig.map((action) {
                      final String actionName = action['name']?.toString() ?? 'Action';
                      final String actionType = action['type']?.toString() ?? 'unknown';
                      final String actionApiUrlTemplate = action['api']?.toString() ?? '';
                      final List<dynamic> actionParamsConfig = List<dynamic>.from(action['params'] ?? []);
                      final String actionRecNoResolved = action['recNo_resolved']?.toString() ?? '';
                      final String actionReportLabel = action['reportLabel']?.toString() ?? 'Action Report';
                      final String actionApiNameResolved = action['apiName_resolved']?.toString() ?? '';
                      return Padding(padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                        child: ElevatedButton(
                          onPressed: () async {
                            final Map<String, String> dynamicApiParams = {};
                            for (var paramConfig in actionParamsConfig) {
                              final paramName = paramConfig['parameterName']?.toString() ?? '';
                              final sourceFieldName = paramConfig['parameterValue']?.toString() ?? '';
                              if (paramName.isNotEmpty && originalRowData.containsKey(sourceFieldName)) {
                                String valueFromRow = originalRowData[sourceFieldName]?.toString() ?? '';
                                final double? numericValue = double.tryParse(valueFromRow);
                                if (numericValue != null && numericValue == numericValue.truncate()) valueFromRow = numericValue.toInt().toString();
                                dynamicApiParams[paramName] = valueFromRow;
                              }
                            }
                            if (actionType == 'table') {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => BlocProvider<TableBlocGenerate>(
                                create: (context) => TableBlocGenerate(ReportAPIService())..add(FetchFieldConfigs(actionRecNoResolved, actionApiNameResolved, actionReportLabel, actionApiUrlTemplate: actionApiUrlTemplate, dynamicApiParams: dynamicApiParams)),
                                child: TableMainUI(recNo: actionRecNoResolved, apiName: actionApiNameResolved, reportLabel: actionReportLabel, userParameterValues: dynamicApiParams, actionsConfig: const [], displayParameterValues: widget.displayParameterValues, companyName: widget.companyName, parentDisplayParameterValues: widget.parentDisplayParameterValues ?? widget.displayParameterValues),
                              ),
                              ),
                              );
                            } else if (actionType == 'print') {
                              final TemplateSelectionResult? result = await showDialog<TemplateSelectionResult>(context: context, builder: (BuildContext dialogContext) => const ReportTemplateSelectionDialog());
                              if (result != null) Navigator.push(context, MaterialPageRoute(builder: (context) => PrintPreviewPage(actionApiUrlTemplate: actionApiUrlTemplate, dynamicApiParams: dynamicApiParams, reportLabel: actionReportLabel, selectedTemplate: result.template, selectedColor: result.color)));
                            } else if (actionType == 'form') {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Form action triggered for $actionName. (Not yet implemented)'), backgroundColor: Colors.orange));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: const Size(60, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 2, shadowColor: Colors.blueAccent.withOpacity(0.4)),
                          child: Text(actionName, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        ),
                      );
                    }).toList(),
                  ),
                  );
                },
              ),
              );
            }
            final List<PlutoRow> finalRows = [];
            List<Map<String, dynamic>> processedReportData = List.from(state.reportData);
            if (breakpointColumnName != null) {
              processedReportData.sort((a, b) => (a[breakpointColumnName]?.toString() ?? '').compareTo(b[breakpointColumnName]?.toString() ?? ''));
              String? currentBreakpointValue;
              Map<String, double> currentGroupSubtotals = { for (var colName in subtotalColumnNames) colName: 0.0 };
              for (int i = 0; i < processedReportData.length; i++) {
                final data = processedReportData[i];
                final rowBreakpointValue = data[breakpointColumnName]?.toString() ?? '';
                if (currentBreakpointValue != null && rowBreakpointValue != currentBreakpointValue) {
                  finalRows.add(_createSubtotalRow(groupName: currentBreakpointValue, subtotals: currentGroupSubtotals, sortedFieldConfigs: sortedFieldConfigs, breakpointColumnName: breakpointColumnName, hasActionsColumn: showActionsColumnFromState, actionsConfigForSubtotalRow: state.actionsConfig, numericColumnMap: numericColumnMap, subtotalColumnDecimals: subtotalColumnDecimals, indianFormatColumnMap: indianFormatColumnMap));
                  currentGroupSubtotals = { for (var colName in subtotalColumnNames) colName: 0.0 };
                }
                final rowCells = <String, PlutoCell>{};
                for (var config in sortedFieldConfigs) {
                  final fieldName = config['Field_name']?.toString() ?? '';
                  final rawValue = data[fieldName];
                  rowCells[fieldName] = PlutoCell(value: numericColumnMap[fieldName] == true ? (double.tryParse(rawValue?.toString().trim() ?? '') ?? 0.0) : (rawValue?.toString() ?? ''));
                }
                if (showActionsColumnFromState) rowCells['__actions__'] = PlutoCell(value: '');
                rowCells['__isSubtotal__'] = PlutoCell(value: false);
                rowCells['__raw_data__'] = PlutoCell(value: data);
                finalRows.add(PlutoRow(cells: rowCells));
                for (var colName in subtotalColumnNames) {
                  final value = data[colName];
                  if (value != null) currentGroupSubtotals[colName] = (currentGroupSubtotals[colName] ?? 0.0) + (double.tryParse(value.toString()) ?? 0.0);
                }
                currentBreakpointValue = rowBreakpointValue;
                if (i == processedReportData.length - 1) {
                  finalRows.add(_createSubtotalRow(groupName: currentBreakpointValue, subtotals: currentGroupSubtotals, sortedFieldConfigs: sortedFieldConfigs, breakpointColumnName: breakpointColumnName, hasActionsColumn: showActionsColumnFromState, actionsConfigForSubtotalRow: state.actionsConfig, numericColumnMap: numericColumnMap, subtotalColumnDecimals: subtotalColumnDecimals, indianFormatColumnMap: indianFormatColumnMap));
                }
              }
            } else {
              finalRows.addAll(processedReportData.map((data) {
                final rowCells = <String, PlutoCell>{};
                for (var config in sortedFieldConfigs) {
                  final fieldName = config['Field_name']?.toString() ?? '';
                  final rawValue = data[fieldName];
                  rowCells[fieldName] = PlutoCell(value: numericColumnMap[fieldName] == true ? (double.tryParse(rawValue?.toString().trim() ?? '') ?? 0.0) : (rawValue?.toString() ?? ''));
                }
                if (showActionsColumnFromState) rowCells['__actions__'] = PlutoCell(value: '');
                rowCells['__isSubtotal__'] = PlutoCell(value: false);
                rowCells['__raw_data__'] = PlutoCell(value: data);
                return PlutoRow(cells: rowCells);
              }));
            }
            return Padding(padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ExportWidget(columns: columns, plutoRows: finalRows, fileName: widget.reportLabel, fieldConfigs: sortedFieldConfigs, reportLabel: widget.reportLabel, parameterValues: widget.userParameterValues, displayParameterValues: widget.parentDisplayParameterValues ?? widget.displayParameterValues, apiParameters: state.selectedApiParameters, pickerOptions: state.pickerOptions, companyName: widget.companyName, includePdfFooterDateTime: state.includePdfFooterDateTime),
                  const SizedBox(height: 16),
                  Expanded(
                    child: CustomPlutoGrid(columns: columns, rows: finalRows,
                      rowColorCallback: (rowContext) {
                        if (rowContext.row.cells['__isSubtotal__']?.value == true) return Colors.grey[200]!;
                        return rowContext.rowIdx % 2 == 0 ? Colors.white : Colors.grey[50]!;
                      },
                      onChanged: (PlutoGridOnChangedEvent event) {},
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}