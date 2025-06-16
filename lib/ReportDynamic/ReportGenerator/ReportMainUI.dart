import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart'; // For PdfColor constants


import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/CustomPlutogrid.dart';
import '../../ReportUtils/Export_widget.dart'; // This is the file we're modifying
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart';

import '../ReportMakeEdit/EditDetailMaker.dart';
import 'PrintTemp/printpreview.dart';
import 'PrintTemp/printservice.dart';
import 'Reportbloc.dart';
import 'TableGenerate/TableBLoc.dart' as TableBlocEvents; // Alias for TableBloc
import 'TableGenerate/TableMainUI.dart'; // Import TableMainUI

// NEW EXTENSION: To convert PrintTemplateForMaker (from EditDetailMaker)
// to PrintTemplate (from printservice.dart)
extension PrintTemplateForMakerToPrintTemplate on PrintTemplateForMaker {
  PrintTemplate toPrintTemplate() {
    switch (this) {
      case PrintTemplateForMaker.premium:
        return PrintTemplate.premium;
      case PrintTemplateForMaker.minimalist:
        return PrintTemplate.minimalist;
      case PrintTemplateForMaker.corporate:
        return PrintTemplate.corporate;
      case PrintTemplateForMaker.modern:
        return PrintTemplate.modern;
    }
  }
}

class ReportMainUI extends StatelessWidget {
  final String recNo;
  final String apiName;
  final String reportLabel;
  final Map<String, String> userParameterValues;
  final List<Map<String, dynamic>> actionsConfig;
  final Map<String, String> displayParameterValues; // This is the map you want to pass down
  final String companyName;
  final bool includePdfFooterDateTime;

  const ReportMainUI({
    super.key,
    required this.recNo,
    required this.apiName,
    required this.reportLabel,
    required this.userParameterValues,
    this.actionsConfig = const [],
    required this.displayParameterValues,
    required this.companyName,
    required this.includePdfFooterDateTime,
  });

  // Helper function to format numbers using Indian locale
  static String formatIndianNumber(double number, int decimalPoints) {
    debugPrint('formatIndianNumber called for number: $number, decimalPoints: $decimalPoints'); // DEBUG PRINT
    String pattern = '##,##,##0';
    if (decimalPoints > 0) {
      pattern += '.${'0' * decimalPoints}';
    }

    final NumberFormat indianFormat = NumberFormat(
      pattern,
      'en_IN', // Use 'en_IN' locale for Indian number formatting
    );

    return indianFormat.format(number);
  }

  // Helper function to create a subtotal row
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
    final bool showActionsColumn = actionsConfig.isNotEmpty;

    return Scaffold(
      appBar: AppBarWidget(
        title: reportLabel,
        onBackPress: () => Navigator.pop(context),
      ),
      body: BlocListener<ReportBlocGenerate, ReportState>(
        listener: (context, state) {
          if (state.error != null) {
            debugPrint('ReportMainUI error: ${state.error}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        child: BlocBuilder<ReportBlocGenerate, ReportState>(
          builder: (context, state) {
            debugPrint('ReportMainUI rebuild: isLoading=${state.isLoading}, '
                'fieldConfigs.length=${state.fieldConfigs.length}, '
                'reportData.length=${state.reportData.length}');
            debugPrint('ReportMainUI: actionsConfig in constructor for "$reportLabel": ${actionsConfig.length} items.');
            debugPrint('ReportMainUI: Company Name passed: $companyName');
            debugPrint('ReportMainUI: Include PDF Footer Date/Time passed (from ReportUI/Bloc state): $includePdfFooterDateTime'); // NEW: Log footer flag

            // --- Reorder rendering conditions to prevent flicker ---
            if (state.isLoading) {
              debugPrint('ReportMainUI: Showing loader');
              return const Center(child: SubtleLoader());
            }

            if (state.error != null) {
              debugPrint('ReportMainUI: Showing error: ${state.error}');
              return Center(
                child: Text(
                  'Error: ${state.error}',
                  style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (state.fieldConfigs.isEmpty) {
              debugPrint('ReportMainUI: No field configurations available');
              return Center(
                child: Text(
                  'No field configurations available for this report. Please check the report design.',
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (state.reportData.isEmpty) {
              debugPrint('ReportMainUI: No report data available for selected parameters.');
              return Center(
                child: Text(
                  'No report data available for the selected parameters.',
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }
            // --- End reorder rendering conditions ---


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

            debugPrint('--- ReportMainUI: Field Configs for "$reportLabel" (RecNo: $recNo) ---');
            for (var config in sortedFieldConfigs) {
              final fieldName = config['Field_name']?.toString() ?? 'N/A';

              final bool isNumeric = [
                'VQ_GrandTotal', 'Qty', 'Rate', 'NetRate', 'GrandTotal', 'Value', 'Amount',
                'Excise', 'Cess', 'HSCess', 'Freight', 'TCS'
              ].contains(fieldName) || (config['data_type']?.toString().toLowerCase() == 'number');
              numericColumnMap[fieldName] = isNumeric;

              final bool isImage = config['image']?.toString() == '1';
              imageColumnMap[fieldName] = isImage;

              final bool useIndianFormat = config['indian_format']?.toString() == '1';
              indianFormatColumnMap[fieldName] = useIndianFormat;

              if (config['Breakpoint']?.toString() == '1') {
                breakpointColumnName = fieldName;
              }
              if (config['SubTotal']?.toString() == '1' && isNumeric) {
                subtotalColumnNames.add(fieldName);
                subtotalColumnDecimals[fieldName] = int.tryParse(config['decimal_points']?.toString().trim() ?? '0') ?? 0;
              }
              if (config['Total']?.toString() == '1' && isNumeric) {
                hasGrandTotals = true;
              }
              debugPrint('  Field: $fieldName, Label: ${config['Field_label']}, Type: ${config['data_type']}, '
                  'Total: ${config['Total']}, SubTotal: ${config['SubTotal']}, Breakpoint: ${config['Breakpoint']}, '
                  'Decimal: ${config['decimal_points']}, Width: ${config['width']}, isNumeric: $isNumeric, indian_format: $useIndianFormat');
            }
            debugPrint('  Calculated Properties: hasGrandTotals=$hasGrandTotals, breakpointColumnName=$breakpointColumnName, subtotalColumns=$subtotalColumnNames');
            debugPrint('----------------------------------------------------');

            final headerMap = {
              for (var config in sortedFieldConfigs)
                config['Field_label']?.toString() ?? '': config['Field_name']?.toString() ?? ''
            };

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

                  if (fieldName == 'Qty') {
                    debugPrint('--- Qty Renderer Debug ---');
                    debugPrint('  Column: $fieldName');
                    debugPrint('  isNumericField (from column def): $isNumericField');
                    debugPrint('  useIndianFormatForColumn (from column def): $useIndianFormatForColumn');
                    debugPrint('  decimalPoints (from column def): $decimalPoints');
                    debugPrint('  rawCellValue (from PlutoCell): $rawCellValue (Type: ${rawCellValue.runtimeType})');
                    debugPrint('  valueString (rawCellValue.toString()): "$valueString"');
                    debugPrint('  isSubtotalRow: $isSubtotalRow');
                    debugPrint('--------------------------');
                  }


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
                            debugPrint('Image loading error for $fieldName: $exception, URL: $valueString');
                            return Center(
                              child: Icon(Icons.broken_image, color: Colors.red[300], size: 24),
                            );
                          },
                        ),
                      ),
                    );
                  }

                  Widget textWidget;

                  if (isNumericField && valueString.isNotEmpty) {
                    final number = double.tryParse(valueString) ?? 0.0;
                    if (fieldName == 'Qty') {
                      debugPrint('  Parsed number (in renderer): $number');
                    }
                    final String formattedNumber = useIndianFormatForColumn
                        ? formatIndianNumber(number, decimalPoints)
                        : number.toStringAsFixed(decimalPoints);
                    if (fieldName == 'Qty') {
                      debugPrint('  Final formatted number (in renderer): "$formattedNumber"');
                    }

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
            debugPrint('TableMainUI: Will render actions column: $showActionsColumnFromState (from BLoC state)');

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
                    debugPrint('Action renderer: Original row data from __raw_data__ cell: $originalRowData');


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

                          final Map<String, String> dynamicApiParams = {};
                          for (var paramConfig in actionParamsConfig) {
                            final paramName = paramConfig['parameterName']?.toString() ?? '';
                            final sourceFieldName = paramConfig['parameterValue']?.toString() ?? '';

                            String valueFromRow = originalRowData[sourceFieldName]?.toString() ?? '';
                            debugPrint('  Action param: $paramName, sourceFieldName: $sourceFieldName, valueFromRow: "$valueFromRow"');

                            if (paramName.isNotEmpty) {
                              dynamicApiParams[paramName] = valueFromRow;
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                            child: ElevatedButton(
                              onPressed: () async {
                                debugPrint('TableMainUI Action button pressed: $actionName (Type: $actionType)');
                                debugPrint('TableMainUI Action API URL (template): $actionApiUrlTemplate');
                                debugPrint('TableMainUI Dynamic Params for action: $dynamicApiParams');

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
                                          displayValue = pickerOptions.firstWhere(
                                                (opt) => opt['value'] == currentApiValue,
                                            orElse: () => {'label': currentApiValue, 'value': currentApiValue},
                                          )['label']!;
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
                                        displayValue = opts.firstWhere(
                                              (opt) => opt['value'] == currentApiValue,
                                          orElse: () => {'label': currentApiValue, 'value': currentApiValue},
                                        )['label']!;
                                      } else if (pConfigType == 'database' && currentApiValue.isNotEmpty && state.pickerOptions.containsKey(pName)) {
                                        final pOpts = state.pickerOptions[pName] ?? [];
                                        displayValue = pOpts.firstWhere(
                                              (opt) => opt['value'] == currentApiValue,
                                          orElse: () => {'label': currentApiValue, 'value': currentApiValue},
                                        )['label']!;
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
                                      builder: (context) => BlocProvider<TableBlocEvents.TableBlocGenerate>(
                                        create: (context) => TableBlocEvents.TableBlocGenerate(ReportAPIService())
                                          ..add(TableBlocEvents.FetchApiDetails(actionApiNameResolved, const []))
                                          ..add(TableBlocEvents.FetchFieldConfigs(
                                            actionRecNoResolved,
                                            actionApiNameResolved,
                                            actionReportLabel,
                                            actionApiUrlTemplate: actionApiUrlTemplate,
                                            dynamicApiParams: dynamicApiParams,
                                          )),
                                        child: TableMainUI(
                                          recNo: actionRecNoResolved,
                                          apiName: actionApiNameResolved,
                                          reportLabel: actionReportLabel,
                                          userParameterValues: dynamicApiParams,
                                          actionsConfig: const [],
                                          displayParameterValues: nestedDisplayValuesForExport,
                                          companyName: companyName,
                                          // NEW: Pass the parent's display parameter values to the nested TableMainUI
                                          parentDisplayParameterValues: this.displayParameterValues,
                                        ),
                                      ),
                                    ),
                                  );
                                } else if (actionType == 'print') {
                                  // Directly read template and color from the action config
                                  final String templateName = action['printTemplate']?.toString() ?? PrintTemplateForMaker.premium.name;
                                  final PrintTemplate selectedTemplate = PrintTemplateForMaker.values
                                      .firstWhere(
                                        (e) => e.name == templateName,
                                    orElse: () => PrintTemplateForMaker.premium,
                                  )
                                      .toPrintTemplate(); // Use the new extension

                                  final String colorName = action['printColor']?.toString() ?? 'Blue';
                                  // This `predefinedPdfColors` map needs to be accessible here.
                                  // It's defined in EditDetailMaker.dart. You might need to import it here.
                                  // For simplicity, let's assume it's globally accessible or copied here if circular dependencies are an issue.
                                  // If not imported globally, ensure it's imported correctly.
                                  final PdfColor selectedColor = predefinedPdfColors[colorName] ?? PdfColors.blue;

                                  debugPrint('Navigating to PrintPreview with template: ${selectedTemplate.displayName}, color: $colorName');
                                  debugPrint('Passing companyName: $companyName, NOT passing includePdfFooterDateTime to PrintPreviewPage.'); // DEBUG

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PrintPreviewPage(
                                        actionApiUrlTemplate: actionApiUrlTemplate,
                                        dynamicApiParams: dynamicApiParams,
                                        reportLabel: actionReportLabel,
                                        selectedTemplate: selectedTemplate,
                                        selectedColor: selectedColor,
                                        // includePdfFooterDateTime: includePdfFooterDateTime, // REMOVED: NO LONGER PASSED TO PRINTPREVIEW
                                      ),
                                    ),
                                  );
                                } else if (actionType == 'form') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Form action triggered for $actionName. (Not yet implemented)'), backgroundColor: Colors.orange),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: const Size(60, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 2,
                                shadowColor: Colors.blueAccent.withOpacity(0.4),
                              ),
                              child: Text(
                                actionName,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
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
            List<Map<String, dynamic>> currentReportData = List.from(state.reportData);

            if (breakpointColumnName != null) {
              currentReportData.sort((a, b) {
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

              for (int i = 0; i < currentReportData.length; i++) {
                final data = currentReportData[i];
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

                if (i == currentReportData.length - 1) {
                  addSubtotalRowForGroup(currentBreakpointValue, currentGroupDataRows);
                }
              }
            } else {
              finalRows.addAll(state.reportData.map((data) {
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

            debugPrint('TableMainUI: CustomPlutoGrid created for "${reportLabel}" with columns=${columns.length}, rows=${finalRows.length}');

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
                    displayParameterValues: displayParameterValues,
                    apiParameters: state.selectedApiParameters,
                    pickerOptions: state.pickerOptions,
                    companyName: companyName,
                    includePdfFooterDateTime: includePdfFooterDateTime,
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
                      onChanged: (PlutoGridOnChangedEvent event) {
                        // This callback is for changes *within* the grid cells.
                      },
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