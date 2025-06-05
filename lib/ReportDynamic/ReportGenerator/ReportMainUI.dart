import 'dart:async'; // Keep this import if needed elsewhere, otherwise can be removed.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:intl/intl.dart'; // Keep this import if needed elsewhere, otherwise can be removed.
import 'package:qualityapproach/ReportDynamic/ReportGenerator/printdoc.dart';
import '../../ReportUtils/Appbar.dart'; // Assuming Appbar.dart is still needed for other parts of the app, or this main UI.
import '../../ReportUtils/CustomPlutogrid.dart';
import '../../ReportUtils/Export_widget.dart';
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart';
import 'Reportbloc.dart'; // Assuming Reportbloc.dart contains ReportBlocGenerate and ReportState

class ReportMainUI extends StatelessWidget {
  final String recNo;
  final String apiName;
  final String reportLabel;
  final Map<String, String> userParameterValues;
  final List<Map<String, dynamic>> actionsConfig;

  const ReportMainUI({
    super.key,
    required this.recNo,
    required this.apiName,
    required this.reportLabel,
    required this.userParameterValues,
    this.actionsConfig = const [],
  });

  // Helper function to format numbers (can be shared or put in a utility file)
  static String formatIndianNumber(double number, int decimalPoints) {
    String numStr = number.toStringAsFixed(decimalPoints);
    List<String> parts = numStr.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    bool isNegative = integerPart.startsWith('-');
    if (isNegative) {
      integerPart = integerPart.substring(1);
    }

    if (integerPart.length <= 3) {
      String result = integerPart;
      if (decimalPoints > 0 && decimalPart.isNotEmpty) {
        result += '.$decimalPart';
      }
      return isNegative ? '-$result' : result;
    }

    String lastThree = integerPart.substring(integerPart.length - 3);
    String remaining = integerPart.substring(0, integerPart.length - 3);

    String formatted = '';
    for (int i = remaining.length; i > 0; i -= 2) {
      int start = (i - 2 < 0) ? 0 : i - 2;
      String chunk = remaining.substring(start, i);
      if (formatted.isEmpty) {
        formatted = chunk;
      } else {
        formatted = '$chunk,$formatted';
      }
    }

    String result = '$formatted,$lastThree';
    if (decimalPoints > 0 && decimalPart.isNotEmpty) {
      result += '.$decimalPart';
    }

    return isNegative ? '-$result' : result;
  }

  // Helper function to create a subtotal row
  PlutoRow _createSubtotalRow({
    required String groupName,
    required Map<String, double> subtotals,
    required List<Map<String, dynamic>> sortedFieldConfigs,
    required String? breakpointColumnName,
    required bool hasActionsColumn,
  }) {
    final Map<String, PlutoCell> subtotalCells = {};
    // Iterate over all possible field names to ensure we populate cells for them
    final allFieldNames = sortedFieldConfigs.map((c) => c['Field_name'].toString()).toSet();
    // Also include any 'parameterValue' from actionsConfig to ensure those cells exist
    for (var action in actionsConfig) {
      final params = List<dynamic>.from(action['params'] ?? []);
      for (var param in params) {
        allFieldNames.add(param['parameterValue'].toString());
      }
    }

    for (var fieldName in allFieldNames) {
      final config = sortedFieldConfigs.firstWhere(
            (cfg) => cfg['Field_name']?.toString() == fieldName,
        orElse: () => {}, // Provide an empty map if config not found (for hidden fields)
      );
      final isSubtotalColumn = config['SubTotal']?.toString() == '1';

      if (fieldName == breakpointColumnName) {
        subtotalCells[fieldName] = PlutoCell(value: 'Subtotal ($groupName)');
      } else if (isSubtotalColumn) {
        final sum = subtotals[fieldName] ?? 0.0;
        subtotalCells[fieldName] = PlutoCell(value: sum);
      } else {
        subtotalCells[fieldName] = PlutoCell(value: ''); // Empty for non-subtotal columns
      }
    }
    subtotalCells['__actions__'] = PlutoCell(value: ''); // Dummy cell for actions column
    // Mark this row as a subtotal row for custom styling and grand total exclusion
    subtotalCells['__isSubtotal__'] = PlutoCell(value: true);
    return PlutoRow(cells: subtotalCells);
  }

  @override
  Widget build(BuildContext context) {
    final bool showActionsColumn = actionsConfig.isNotEmpty;

    return Scaffold(
      appBar: AppBarWidget( // Assuming AppbarWidget is still desired for the main report UI.
        title: reportLabel,
        onBackPress: () => Navigator.pop(context),
      ),
      body: BlocListener<ReportBlocGenerate, ReportState>(
        listener: (context, state) {
          if (state.error != null) {
            print('ReportMainUI error: ${state.error}');
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
            print('ReportMainUI rebuild: isLoading=${state.isLoading}, '
                'fieldConfigs.length=${state.fieldConfigs.length}, '
                'reportData.length=${state.reportData.length}');

            if (state.isLoading) {
              print('ReportMainUI: Showing loader');
              return const Center(child: SubtleLoader());
            }

            if (state.reportData.isEmpty && !state.isLoading && state.error == null) {
              print('ReportMainUI: No report data available');
              return Center(
                child: Text(
                  state.fieldConfigs.isEmpty
                      ? 'No field configurations or report data available.'
                      : 'No report data available for the selected parameters.',
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }
            if (state.fieldConfigs.isEmpty) {
              print('ReportMainUI: No field configurations available');
              return Center(
                child: Text(
                  'No field configurations available for this report. Please check the report design.',
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

            for (var config in sortedFieldConfigs) {
              final fieldName = config['Field_name']?.toString() ?? '';
              final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'GrandTotal', 'Value', 'Amount'].contains(fieldName) ||
                  (config['data_type']?.toString().toLowerCase() == 'number');
              numericColumnMap[fieldName] = isNumeric;

              final isImage = config['image']?.toString() == '1';
              imageColumnMap[fieldName] = isImage;

              if (config['Breakpoint']?.toString() == '1') {
                breakpointColumnName = fieldName;
              }
              if (config['SubTotal']?.toString() == '1' && isNumeric) {
                subtotalColumnNames.add(fieldName);
                subtotalColumnDecimals[fieldName] = int.tryParse(config['decimal_points']?.toString() ?? '0') ?? 0;
              }
            }

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
              final decimalPoints = int.tryParse(config['decimal_points']?.toString() ?? '0') ?? 0;
              final isNumeric = numericColumnMap[fieldName] ?? false;
              final isImageColumn = imageColumnMap[fieldName] ?? false;

              String formatString = '#,##0';
              if (decimalPoints > 0) {
                formatString += '.' + '0' * decimalPoints;
              }

              return PlutoColumn(
                title: fieldLabel,
                field: fieldName,
                type: isNumeric ? PlutoColumnType.number(format: formatString) : PlutoColumnType.text(),
                width: width,
                textAlign: alignment == 'center'
                    ? PlutoColumnTextAlign.center
                    : alignment == 'right'
                    ? PlutoColumnTextAlign.right
                    : PlutoColumnTextAlign.left,
                enableFilterMenuItem: true,
                footerRenderer: (rendererContext) {
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
                  } else if (total && isNumeric) {
                    double sum = 0.0;
                    for (var row in rendererContext.stateManager.rows) {
                      if (row.cells.containsKey('__isSubtotal__') && row.cells['__isSubtotal__']!.value == true) {
                        continue;
                      }
                      final cellValue = row.cells[fieldName]?.value;
                      final parsedValue = double.tryParse(cellValue.toString()) ?? 0.0;
                      sum += parsedValue;
                    }
                    final formattedTotal = formatIndianNumber(sum, decimalPoints);
                    return PlutoAggregateColumnFooter(
                      rendererContext: rendererContext,
                      type: PlutoAggregateColumnType.sum,
                      format: formatString,
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
                  final value = rendererContext.cell.value?.toString() ?? '';
                  final isSubtotalRow = rendererContext.row.cells.containsKey('__isSubtotal__') && rendererContext.row.cells['__isSubtotal__']!.value == true;

                  if (isImageColumn && value.isNotEmpty && (value.startsWith('http://') || value.startsWith('https://'))) {
                    return Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4.0),
                        child: Image.network(
                          value,
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
                            print('Image loading error for $fieldName: $exception, URL: $value');
                            return Center(
                              child: Icon(Icons.broken_image, color: Colors.red[300], size: 24),
                            );
                          },
                        ),
                      ),
                    );
                  }

                  Widget textWidget;

                  if (isNumeric && value.isNotEmpty) {
                    final number = double.tryParse(value) ?? 0.0;
                    final formattedNumber = formatIndianNumber(number, decimalPoints);
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
                      value,
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

            // Add Actions Column if actionsConfig is present and not empty
            if (showActionsColumn) {
              columns.add(
                PlutoColumn(
                  title: 'Actions',
                  field: '__actions__',
                  type: PlutoColumnType.text(),
                  width: actionsConfig.length * 100.0,
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

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actionsConfig.map((action) {
                          final String actionName = action['name']?.toString() ?? 'Action';
                          final String actionType = action['type']?.toString() ?? 'unknown';
                          final String actionApiUrlTemplate = action['api']?.toString() ?? '';
                          final List<dynamic> actionParamsConfig = List<dynamic>.from(action['params'] ?? []);
                          final String actionRecNoResolved = action['recNo_resolved']?.toString() ?? '';
                          final String actionReportLabel = action['reportLabel']?.toString() ?? 'Action Report';
                          final String actionApiNameResolved = action['apiName_resolved']?.toString() ?? '';

                          // 1. Gather dynamic parameters from the current row
                          final Map<String, String> dynamicApiParams = {};
                          for (var paramConfig in actionParamsConfig) {
                            final paramName = paramConfig['parameterName']?.toString() ?? '';
                            final sourceFieldName = paramConfig['parameterValue']?.toString() ?? '';

                            final PlutoCell? cell = rendererContext.row.cells[sourceFieldName];
                            String valueFromRow = '';
                            if (cell != null && cell.value != null) {
                              valueFromRow = cell.value.toString();
                              // print('DEBUG: Extracted value for parameter "$paramName" from row field "$sourceFieldName": "$valueFromRow" (Type: ${cell.value.runtimeType})');
                            } else {
                              // print('DEBUG: WARNING: Cell for source field "$sourceFieldName" is null or its value is null. Parameter "$paramName" will be empty.');
                            }
                            if (paramName.isNotEmpty) {
                              dynamicApiParams[paramName] = valueFromRow;
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                            child: ElevatedButton(
                              onPressed: () { // Removed 'async' keyword here
                                print('Action button pressed: $actionName (Type: $actionType)');
                                print('Action API URL (template): $actionApiUrlTemplate');
                                print('Dynamic Params for action: $dynamicApiParams');

                                if (actionType == 'table') {
                                  // Navigate to a new ReportMainUI instance
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider(
                                        create: (context) => ReportBlocGenerate(ReportAPIService())
                                          ..add(FetchApiDetails(actionApiNameResolved, const [])) // Fetches UI-related parameters for the *new* report
                                        // Pass dynamicApiParams here to override initial default params
                                          ..add(FetchFieldConfigs(
                                            actionRecNoResolved,
                                            actionApiNameResolved,
                                            actionReportLabel,
                                            actionApiUrlTemplate: actionApiUrlTemplate,
                                            dynamicApiParams: dynamicApiParams, // <<< CRITICAL FIX: Pass dynamic params
                                          )),
                                        child: ReportMainUI(
                                          recNo: actionRecNoResolved,
                                          apiName: actionApiNameResolved,
                                          reportLabel: actionReportLabel,
                                          userParameterValues: dynamicApiParams, // This is for the *new* ReportUI to display
                                          actionsConfig: const [], // Action reports typically don't have further nested actions
                                        ),
                                      ),
                                    ),
                                  );
                                } else if (actionType == 'print') {
                                  // FIX: Navigate directly to PrintDocumentPage,
                                  // and let PrintDocumentPage manage its own data fetching via a NEW Bloc instance.
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider( // Create a NEW Bloc instance for PrintDocumentPage
                                        create: (context) => ReportBlocGenerate(ReportAPIService())
                                          ..add(FetchDocumentData( // Dispatch data fetch event on this NEW bloc
                                            apiName: actionApiNameResolved.isNotEmpty ? actionApiNameResolved : apiName, // Fallback to current main apiName if action one is empty
                                            actionApiUrlTemplate: actionApiUrlTemplate,
                                            dynamicApiParams: dynamicApiParams,
                                          )),
                                        child: PrintDocumentPage( // PrintDocumentPage will read its own bloc's state
                                          apiName: actionApiNameResolved,
                                          actionApiUrlTemplate: actionApiUrlTemplate,
                                          dynamicApiParams: dynamicApiParams,
                                          reportLabel: actionReportLabel,
                                        ),
                                      ),
                                    ),
                                  );
                                } else if (actionType == 'form') {
                                  // Form action logic (if applicable)
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

            // ... (rest of the PlutoGrid setup and data processing remains the same) ...
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
                if (groupRows.length > 0 && subtotalColumnNames.isNotEmpty) { // Changed to > 0 to ensure subtotal even for single row groups
                  finalRows.add(_createSubtotalRow(
                    groupName: groupName,
                    subtotals: currentGroupSubtotals,
                    sortedFieldConfigs: sortedFieldConfigs,
                    breakpointColumnName: breakpointColumnName,
                    hasActionsColumn: showActionsColumn,
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
                data.forEach((key, value) {
                  final String fieldName = key.toString();
                  final Map<String, dynamic> fieldConfig = sortedFieldConfigs.firstWhere(
                        (cfg) => cfg['Field_name']?.toString() == fieldName,
                    orElse: () => {'Field_name': fieldName, 'data_type': 'text'},
                  );
                  final bool isNumeric = numericColumnMap[fieldName] ?? (fieldConfig['data_type']?.toString().toLowerCase() == 'number');

                  rowCells[fieldName] = PlutoCell(
                    value: isNumeric && value is String && value.isNotEmpty
                        ? (double.tryParse(value) ?? 0.0)
                        : value,
                  );
                });
                if (showActionsColumn) {
                  rowCells['__actions__'] = PlutoCell(value: '');
                }
                rowCells['__isSubtotal__'] = PlutoCell(value: false);
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
                data.forEach((key, value) {
                  final String fieldName = key.toString();
                  final Map<String, dynamic> fieldConfig = sortedFieldConfigs.firstWhere(
                        (cfg) => cfg['Field_name']?.toString() == fieldName,
                    orElse: () => {'Field_name': fieldName, 'data_type': 'text'},
                  );
                  final bool isNumeric = numericColumnMap[fieldName] ?? (fieldConfig['data_type']?.toString().toLowerCase() == 'number');

                  rowCells[fieldName] = PlutoCell(
                    value: isNumeric && value is String && value.isNotEmpty
                        ? (double.tryParse(value) ?? 0.0)
                        : value,
                  );
                });
                if (showActionsColumn) {
                  rowCells['__actions__'] = PlutoCell(value: '');
                }
                rowCells['__isSubtotal__'] = PlutoCell(value: false);
                return PlutoRow(cells: rowCells);
              }));
            }

            print('ReportMainUI: CustomPlutoGrid created with columns=${columns.length}, rows=${finalRows.length}');

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ExportWidget(
                    data: state.reportData,
                    fileName: reportLabel,
                    headerMap: headerMap,
                    fieldConfigs: sortedFieldConfigs,
                    reportLabel: reportLabel,
                    parameterValues: userParameterValues,
                    apiParameters: state.selectedApiParameters,
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