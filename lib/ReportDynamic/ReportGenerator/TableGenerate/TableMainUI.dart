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


class TableMainUI extends StatelessWidget {
  final String recNo;
  final String apiName;
  final String reportLabel;
  final Map<String, String> userParameterValues;
  final List<Map<String, dynamic>> actionsConfig;
  final Map<String, String> displayParameterValues; // Parameters specific to THIS TableMainUI's API call
  final String companyName;
  final Map<String, String>? parentDisplayParameterValues; // NEW: To hold parameters from the parent report

  const TableMainUI({
    super.key,
    required this.recNo,
    required this.apiName,
    required this.reportLabel,
    required this.userParameterValues,
    this.actionsConfig = const [],
    required this.displayParameterValues,
    required this.companyName,
    this.parentDisplayParameterValues, // NEW: Make it optional (nullable)
  });

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
    print('TableMainUI: BUILDING "${reportLabel}" (RecNo: $recNo, ApiName: $apiName)');
    print('TableMainUI: Company Name passed: $companyName');
    print('TableMainUI: Parent Display Parameters received: $parentDisplayParameterValues');

    return Scaffold(
      appBar: AppBarWidget(
        title: reportLabel,
        onBackPress: () => Navigator.pop(context),
      ),
      body: BlocListener<TableBlocGenerate, ReportState>(
        listener: (context, state) {
          if (state.error != null) {
            print('TableMainUI Listener error: ${state.error}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        child: BlocBuilder<TableBlocGenerate, ReportState>(
          builder: (context, state) {
            print('TableMainUI BlocBuilder rebuild for "$reportLabel": isLoading=${state.isLoading}, '
                'fieldConfigs.length=${state.fieldConfigs.length}, '
                'reportData.length=${state.reportData.length}, '
                'state.actionsConfig.length=${state.actionsConfig.length}, '
                'state.includePdfFooterDateTime=${state.includePdfFooterDateTime}');

            if (state.isLoading) {
              print('TableMainUI: Showing loader for "$reportLabel"');
              return const Center(child: SubtleLoader());
            }

            if (state.error != null) {
              print('TableMainUI: Showing error for "$reportLabel": ${state.error}');
              return Center(
                child: Text(
                  'Error: ${state.error}',
                  style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (state.fieldConfigs.isEmpty) {
              print('TableMainUI: No field configurations available for "$reportLabel"');
              return Center(
                child: Text(
                  'No field configurations available for this report. Please check the report design.',
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (state.reportData.isEmpty) {
              print('TableMainUI: No report data available for "$reportLabel" for selected parameters.');
              return Center(
                child: Text(
                  'No report data available for the selected parameters.',
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final sortedFieldConfigs = List<Map<String, dynamic>>.from(state.fieldConfigs)
              ..sort((a, b) => int.parse(a['Sequence_no']?.toString() ?? '0')
                  .compareTo(int.parse(b['Sequence_no']?.toString() ?? '0')));

            String? breakpointColumnName;
            final List<String> subtotalColumnNames = [];
            final Map<String, int> subtotalColumnDecimals = {};
            final Map<String, bool> numericColumnMap = {};
            final Map<String, bool> imageColumnMap = {};
            final Map<String, bool> indianFormatColumnMap = {};

            bool hasGrandTotals = false;

            print('--- TableMainUI: Field Configs for "$reportLabel" (RecNo: $recNo) ---');
            for (var config in sortedFieldConfigs) {
              final fieldName = config['Field_name']?.toString() ?? 'N/A';
              final fieldLabel = config['Field_label']?.toString() ?? 'N/A';
              final dataType = config['data_type']?.toString().toLowerCase();

              bool currentFieldIsNumeric = false;
              if (dataType == 'number' || dataType == 'decimal' || dataType == 'integer') {
                currentFieldIsNumeric = true;
              } else if (
              ['vq_grandtotal', 'qty', 'rate', 'netrate', 'grandtotal', 'value', 'amount',
                'excise', 'cess', 'hscess', 'freight', 'tcs', 'cgst', 'sgst', 'igst'].contains(fieldName.toLowerCase())
              ) {
                currentFieldIsNumeric = true;
              }
              if (config['Total']?.toString() == '1' || config['SubTotal']?.toString() == '1') {
                currentFieldIsNumeric = true;
              }

              numericColumnMap[fieldName] = currentFieldIsNumeric;

              final isImage = config['image']?.toString() == '1';
              imageColumnMap[fieldName] = isImage;

              final bool useIndianFormat = config['indian_format']?.toString() == '1';
              indianFormatColumnMap[fieldName] = useIndianFormat;

              if (config['Breakpoint']?.toString() == '1') {
                breakpointColumnName = fieldName;
              }
              if (config['SubTotal']?.toString() == '1' && currentFieldIsNumeric) {
                subtotalColumnNames.add(fieldName);
                subtotalColumnDecimals[fieldName] = int.tryParse(config['decimal_points']?.toString().trim() ?? '0') ?? 0;
              }
              if (config['Total']?.toString() == '1' && currentFieldIsNumeric) {
                hasGrandTotals = true;
              }
              print('  Field: $fieldName, Label: $fieldLabel, Type: $dataType, '
                  'Total: ${config['Total']}, SubTotal: ${config['SubTotal']}, Breakpoint: ${config['Breakpoint']}, '
                  'Decimal: ${config['decimal_points']}, Width: ${config['width']}, DetectedNumeric: ${numericColumnMap[fieldName]}, indian_format: $useIndianFormat');
            }
            print('  Calculated Properties: hasGrandTotals=$hasGrandTotals, breakpointColumnName=$breakpointColumnName, subtotalColumns=$subtotalColumnNames');
            print('----------------------------------------------------');

            final List<PlutoColumn> columns = [];

            final List<String> allVisibleFieldNames = sortedFieldConfigs
                .map((c) => c['Field_name'].toString())
                .where((fName) => fName != '__actions__')
                .toList();

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
              if (decimalPoints > 0) {
                plutoGridFormatString += '.' + '0' * decimalPoints;
              }

              return PlutoColumn(
                title: fieldLabel,
                field: fieldName,
                type: isNumericField ? PlutoColumnType.number(format: plutoGridFormatString) : PlutoColumnType.text(),
                width: width,
                textAlign: alignment == 'center'
                    ? PlutoColumnTextAlign.center
                    : alignment == 'right'
                    ? PlutoColumnTextAlign.right
                    : PlutoColumnTextAlign.left,
                enableFilterMenuItem: true,
                footerRenderer: (rendererContext) {
                  if (!hasGrandTotals) {
                    return const SizedBox.shrink();
                  }

                  if (i == 0) {
                    return PlutoAggregateColumnFooter(
                      rendererContext: rendererContext,
                      type: PlutoAggregateColumnType.count,
                      alignment: Alignment.centerLeft,
                      titleSpanBuilder: (text) {
                        return [
                          TextSpan(
                            text: 'Grand Total',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ];
                      },
                    );
                  } else if (total && isNumericField) {
                    double sum = 0.0;
                    for (var row in rendererContext.stateManager.rows) {
                      if (row.cells.containsKey('__isSubtotal__') && row.cells['__isSubtotal__']!.value == true) {
                        continue;
                      }
                      final cellValue = row.cells[fieldName]?.value;
                      final parsedValue = double.tryParse(cellValue.toString()) ?? 0.0;
                      sum += parsedValue;
                    }
                    final String formattedTotal = useIndianFormatForColumn
                        ? formatIndianNumber(sum, decimalPoints)
                        : sum.toStringAsFixed(decimalPoints);

                    return PlutoAggregateColumnFooter(
                      rendererContext: rendererContext,
                      type: PlutoAggregateColumnType.sum,
                      format: plutoGridFormatString,
                      alignment: Alignment.centerRight,
                      titleSpanBuilder: (text) {
                        return [
                          TextSpan(
                            text: formattedTotal,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ];
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
                renderer: (rendererContext) {
                  final rawCellValue = rendererContext.cell.value;
                  final String valueString = rawCellValue?.toString() ?? '';
                  final isSubtotalRow = rendererContext.row.cells.containsKey('__isSubtotal__') && rendererContext.row.cells['__isSubtotal__']!.value == true;

                  if (isImageColumn && valueString.isNotEmpty && (valueString.startsWith('http://') || valueString.startsWith('https://'))) {
                    return Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4.0),
                        child: Image.network(
                          valueString,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 20.0,
                                height: 20.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                            print('Image loading error for $fieldName: $exception, URL: $valueString');
                            return Center(
                              child: Icon(Icons.broken_image, color: Colors.red[300], size: 24),
                            );
                          },
                        ),
                      ),
                    );
                  }

                  Widget textWidget;

                  if (isNumericField && rawCellValue != null) {
                    final number = double.tryParse(rawCellValue.toString()) ?? 0.0;
                    final String formattedNumber = useIndianFormatForColumn
                        ? formatIndianNumber(number, decimalPoints)
                        : number.toStringAsFixed(decimalPoints);

                    textWidget = Text(
                      formattedNumber,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isSubtotalRow ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: alignment == 'center'
                          ? TextAlign.center
                          : alignment == 'right'
                          ? TextAlign.right
                          : TextAlign.left,
                    );
                  } else {
                    textWidget = Text(
                      valueString,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isSubtotalRow ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: isSubtotalRow && fieldName == breakpointColumnName
                          ? TextAlign.left
                          : alignment == 'center'
                          ? TextAlign.center
                          : alignment == 'right'
                          ? TextAlign.right
                          : TextAlign.left,
                    );
                  }
                  return textWidget;
                },
              );
            }));

            columns.add(
              PlutoColumn(
                title: 'Raw Data (Hidden)',
                field: '__raw_data__',
                type: PlutoColumnType.text(),
                hide: true,
                width: 1,
                enableFilterMenuItem: false,
                enableSorting: false,
                enableRowChecked: false,
                enableContextMenu: false,
              ),
            );

            final bool showActionsColumnFromState = state.actionsConfig.isNotEmpty;
            print('TableMainUI: Will render actions column: $showActionsColumnFromState (from BLoC state)');

            if (showActionsColumnFromState) {
              columns.add(
                PlutoColumn(
                  title: 'Actions',
                  field: '__actions__',
                  type: PlutoColumnType.text(),
                  width: state.actionsConfig.length * 100.0,
                  minWidth: 120,
                  enableFilterMenuItem: false,
                  enableSorting: false,
                  enableRowChecked: false,
                  enableContextMenu: false,
                  renderer: (rendererContext) {
                    final isSubtotalRow = rendererContext.row.cells.containsKey('__isSubtotal__') && rendererContext.row.cells['__isSubtotal__']!.value == true;
                    if (isSubtotalRow) {
                      return const SizedBox.shrink();
                    }

                    final Map<String, dynamic> originalRowData =
                        (rendererContext.row.cells['__raw_data__']?.value as Map<String, dynamic>?) ?? {};

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: state.actionsConfig.map((action) {
                          final String actionName = action['name']?.toString() ?? 'Action';
                          final String actionType = action['type']?.toString() ?? 'unknown';
                          final String actionApiUrlTemplate = action['api']?.toString() ?? '';
                          final List<dynamic> actionParamsConfig = List<dynamic>.from(action['params'] ?? []);
                          final String actionRecNoResolved = action['recNo_resolved']?.toString() ?? '';
                          final String actionReportLabel = action['reportLabel']?.toString() ?? 'Action Report';
                          final String actionApiNameResolved = action['apiName_resolved']?.toString() ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                            child: ElevatedButton(
                              onPressed: () async {
                                // #######################################################
                                // #                  START OF FINAL FIX                  #
                                // #######################################################
                                debugPrint('\n\n\n--- ACTION BUTTON CLICKED (in TableMainUI) ---');
                                debugPrint('[ACTION_UI] Action Name: "$actionName"');

                                final Map<String, String> dynamicApiParams = {};

                                debugPrint('[ACTION_UI] Building override params map...');
                                for (var paramConfig in actionParamsConfig) {
                                  final paramName = paramConfig['parameterName']?.toString() ?? '';
                                  final sourceFieldName = paramConfig['parameterValue']?.toString() ?? '';

                                  if (paramName.isNotEmpty && originalRowData.containsKey(sourceFieldName)) {
                                    String valueFromRow = originalRowData[sourceFieldName]?.toString() ?? '';

                                    // FINAL FIX: Convert numbers with .0 to integers.
                                    final double? numericValue = double.tryParse(valueFromRow);
                                    if (numericValue != null && numericValue == numericValue.truncate()) {
                                      valueFromRow = numericValue.toInt().toString();
                                      debugPrint('  -> Converted numeric value for "$sourceFieldName" to integer: "$valueFromRow"');
                                    }

                                    debugPrint('  -> Mapping row field "$sourceFieldName" (value: "$valueFromRow") to param "$paramName"');
                                    dynamicApiParams[paramName] = valueFromRow;
                                  }
                                }
                                debugPrint('[ACTION_UI] Final Override Params to be dispatched: ${jsonEncode(dynamicApiParams)}');
                                debugPrint('--- END OF UI LOGGING, DISPATCHING BLOC EVENT ---');
                                // #######################################################
                                // #                   END OF FINAL FIX                    #
                                // #######################################################

                                if (actionType == 'table') {
                                  final Map<String, String> nestedDisplayValuesForExport = {};
                                  for (var param in state.selectedApiParameters) {
                                    final pName = param['name'].toString();
                                    final String currentApiValue = state.userParameterValues[pName] ?? '';
                                    String displayValue = '';
                                    if (param['is_company_name_field'] == true) {
                                      if (param['show'] == true && currentApiValue.isNotEmpty) {
                                        final String configType = param['config_type']?.toString().toLowerCase() ?? '';
                                        if (configType == 'database' && state.pickerOptions.containsKey(pName)) {
                                          final List<Map<String, String>> pickerOptions = state.pickerOptions[pName] ?? [];
                                          displayValue = pickerOptions.firstWhere((opt) => opt['value'] == currentApiValue, orElse: () => {'label': currentApiValue, 'value': currentApiValue})['label']!;
                                        } else {
                                          displayValue = currentApiValue;
                                        }
                                      }
                                      else if (param['show'] == false && param['display_value_cache']?.toString().isNotEmpty == true) {
                                        displayValue = param['display_value_cache'].toString();
                                      }
                                    } else {
                                      final pConfigType = param['config_type']?.toString().toLowerCase() ?? '';
                                      if ((pConfigType == 'radio' || pConfigType == 'checkbox') && currentApiValue.isNotEmpty) {
                                        final opts = List<Map<String, String>>.from(param['options']?.map((e) => Map<String, String>.from(e ?? {})) ?? []);
                                        displayValue = opts.firstWhere((opt) => opt['value'] == currentApiValue, orElse: () => {'label': currentApiValue, 'value': currentApiValue})['label']!;
                                      } else if (pConfigType == 'database' && currentApiValue.isNotEmpty && state.pickerOptions.containsKey(pName)) {
                                        final pOpts = state.pickerOptions[pName] ?? [];
                                        displayValue = pOpts.firstWhere((opt) => opt['value'] == currentApiValue, orElse: () => {'label': currentApiValue, 'value': currentApiValue})['label']!;
                                      } else {
                                        displayValue = currentApiValue;
                                      }
                                    }
                                    if (displayValue.isNotEmpty) {
                                      final paramLabel = param['field_label']?.isNotEmpty == true ? param['field_label'] : pName;
                                      nestedDisplayValuesForExport[paramLabel] = displayValue;
                                    }
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider<TableBlocGenerate>(
                                        create: (context) => TableBlocGenerate(ReportAPIService())
                                          ..add(FetchApiDetails(actionApiNameResolved, const []))
                                          ..add(FetchFieldConfigs(actionRecNoResolved, actionApiNameResolved, actionReportLabel, actionApiUrlTemplate: actionApiUrlTemplate, dynamicApiParams: dynamicApiParams)),
                                        child: TableMainUI(recNo: actionRecNoResolved, apiName: actionApiNameResolved, reportLabel: actionReportLabel, userParameterValues: dynamicApiParams, actionsConfig: const [], displayParameterValues: nestedDisplayValuesForExport, companyName: companyName, parentDisplayParameterValues: displayParameterValues),
                                      ),
                                    ),
                                  );
                                } else if (actionType == 'print') {
                                  final TemplateSelectionResult? result = await showDialog<TemplateSelectionResult>(context: context, builder: (BuildContext dialogContext) => const ReportTemplateSelectionDialog());
                                  if (result != null) {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => PrintPreviewPage(actionApiUrlTemplate: actionApiUrlTemplate, dynamicApiParams: dynamicApiParams, reportLabel: actionReportLabel, selectedTemplate: result.template, selectedColor: result.color)));
                                  } else {
                                    print('No print template or color selected.');
                                  }
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
              processedReportData.sort((a, b) {
                final aValue = a[breakpointColumnName]?.toString() ?? '';
                final bValue = b[breakpointColumnName]?.toString() ?? '';
                return aValue.compareTo(bValue);
              });

              String? currentBreakpointValue;
              Map<String, double> currentGroupSubtotals = {
                for (var colName in subtotalColumnNames) colName: 0.0
              };
              List<Map<String, dynamic>> currentGroupDataRows = [];

              void addSubtotalRowForGroup(String groupName, List<Map<String, dynamic>> groupRows) {
                if (groupRows.isNotEmpty && subtotalColumnNames.isNotEmpty) {
                  finalRows.add(_createSubtotalRow(
                    groupName: groupName,
                    subtotals: currentGroupSubtotals,
                    sortedFieldConfigs: sortedFieldConfigs,
                    breakpointColumnName: breakpointColumnName,
                    hasActionsColumn: showActionsColumnFromState,
                    actionsConfigForSubtotalRow: state.actionsConfig,
                    numericColumnMap: numericColumnMap,
                    subtotalColumnDecimals: subtotalColumnDecimals,
                    indianFormatColumnMap: indianFormatColumnMap,
                  ));
                }
                currentGroupSubtotals = {
                  for (var colName in subtotalColumnNames) colName: 0.0
                };
                currentGroupDataRows.clear();
              }

              for (int i = 0; i < processedReportData.length; i++) {
                final data = processedReportData[i];
                final rowBreakpointValue = data[breakpointColumnName]?.toString() ?? '';

                if (currentBreakpointValue != null && rowBreakpointValue != currentBreakpointValue) {
                  addSubtotalRowForGroup(currentBreakpointValue, currentGroupDataRows);
                }

                final rowCells = <String, PlutoCell>{};
                for (var config in sortedFieldConfigs) {
                  final fieldName = config['Field_name']?.toString() ?? '';
                  final rawValue = data[fieldName];
                  final bool isNumeric = numericColumnMap[fieldName] ?? false;

                  dynamic cellValue;
                  if (isNumeric) {
                    cellValue = double.tryParse(rawValue?.toString().trim() ?? '') ?? 0.0;
                  } else {
                    cellValue = rawValue?.toString() ?? '';
                  }
                  rowCells[fieldName] = PlutoCell(value: cellValue);
                }

                if (showActionsColumnFromState) {
                  rowCells['__actions__'] = PlutoCell(value: '');
                }
                rowCells['__isSubtotal__'] = PlutoCell(value: false);
                rowCells['__raw_data__'] = PlutoCell(value: data);
                finalRows.add(PlutoRow(cells: rowCells));
                currentGroupDataRows.add(data);

                for (var colName in subtotalColumnNames) {
                  final value = data[colName];
                  if (value != null) {
                    final parsedValue = double.tryParse(value.toString()) ?? 0.0;
                    currentGroupSubtotals[colName] = (currentGroupSubtotals[colName] ?? 0.0) + parsedValue;
                  }
                }

                currentBreakpointValue = rowBreakpointValue;

                if (i == processedReportData.length - 1) {
                  addSubtotalRowForGroup(currentBreakpointValue, currentGroupDataRows);
                }
              }
            } else {
              finalRows.addAll(processedReportData.map((data) {
                final rowCells = <String, PlutoCell>{};
                for (var config in sortedFieldConfigs) {
                  final fieldName = config['Field_name']?.toString() ?? '';
                  final rawValue = data[fieldName];
                  final bool isNumeric = numericColumnMap[fieldName] ?? false;

                  dynamic cellValue;
                  if (isNumeric) {
                    cellValue = double.tryParse(rawValue?.toString().trim() ?? '') ?? 0.0;
                  } else {
                    cellValue = rawValue?.toString() ?? '';
                  }
                  rowCells[fieldName] = PlutoCell(value: cellValue);
                }

                if (showActionsColumnFromState) {
                  rowCells['__actions__'] = PlutoCell(value: '');
                }
                rowCells['__isSubtotal__'] = PlutoCell(value: false);
                rowCells['__raw_data__'] = PlutoCell(value: data);
                return PlutoRow(cells: rowCells);
              }));
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ExportWidget(
                    columns: columns,
                    plutoRows: finalRows,
                    fileName: reportLabel,
                    fieldConfigs: sortedFieldConfigs,
                    reportLabel: reportLabel,
                    parameterValues: userParameterValues,
                    displayParameterValues: parentDisplayParameterValues ?? displayParameterValues,
                    apiParameters: state.selectedApiParameters,
                    pickerOptions: state.pickerOptions,
                    companyName: companyName,
                    includePdfFooterDateTime: state.includePdfFooterDateTime,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: CustomPlutoGrid(
                      columns: columns,
                      rows: finalRows,
                      rowColorCallback: (rowContext) {
                        if (rowContext.row.cells.containsKey('__isSubtotal__') && rowContext.row.cells['__isSubtotal__']!.value == true) {
                          return Colors.grey[200]!;
                        }
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