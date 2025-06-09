// lib/ReportDynamic/ReportGenerator/ReportMainUI.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:intl/intl.dart'; // REQUIRED for formatIndianNumber

// ORIGINAL IMPORTS FROM YOUR OLD WORKING CODE
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/CustomPlutogrid.dart';
import '../../ReportUtils/Export_widget.dart'; // This is the file we're modifying
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart';
import 'PrintTemp/print_template_selection.dart';
import 'PrintTemp/printpreview.dart';
import 'PrintTemp/printservice.dart';
import 'Reportbloc.dart';
import 'TableGenerate/TableBLoc.dart' as TableBlocEvents;
import 'TableGenerate/TableMainUI.dart';


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

  // Helper function to format numbers using Indian locale
  // This function now uses the intl package for more robust and accurate formatting.
  static String formatIndianNumber(double number, int decimalPoints) {
    debugPrint('formatIndianNumber called for number: $number, decimalPoints: $decimalPoints'); // DEBUG PRINT
    // Build the pattern dynamically for decimal places.
    // '##,##,##0' ensures the Indian grouping (lakh/crore).
    // '.${'0' * decimalPoints}' ensures the required decimal places, padding with zeros if needed.
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
    required Map<String, bool> indianFormatColumnMap, // Pass indianFormatMap for subtotals
  }) {
    final Map<String, PlutoCell> subtotalCells = {};
    // Iterate over all possible field names to ensure we populate cells for them
    final allFieldNames = sortedFieldConfigs.map((c) => c['Field_name'].toString()).toSet();
    // Also include any 'parameterValue' from actionsConfig to ensure those cells exist
    for (var action in actionsConfigForSubtotalRow) {
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
      final isNumeric = numericColumnMap[fieldName] ?? false; // Use the passed numericColumnMap

      if (fieldName == breakpointColumnName) {
        subtotalCells[fieldName] = PlutoCell(value: 'Subtotal ($groupName)');
      } else if (isSubtotalColumn && isNumeric) { // Ensure it's marked for subtotal AND is numeric
        final sum = subtotals[fieldName] ?? 0.0;
        // Store as double for internal handling. The column renderer will format it.
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

            // --- Reorder rendering conditions to prevent flicker ---

            // 1. If currently loading, always show the loader.
            if (state.isLoading) {
              debugPrint('ReportMainUI: Showing loader');
              return const Center(child: SubtleLoader());
            }

            // 2. If not loading but there's an error, show the error.
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

            // 3. If not loading, no error, but field configurations are empty, it's a configuration issue.
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

            // 4. If not loading, no error, field configurations exist, but report data is empty.
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


            // If we reach here, it means we have data and configurations to display.
            final sortedFieldConfigs = List<Map<String, dynamic>>.from(state.fieldConfigs)
              ..sort((a, b) => int.parse(a['Sequence_no']?.toString() ?? '0')
                  .compareTo(int.parse(b['Sequence_no']?.toString() ?? '0')));

            String? breakpointColumnName;
            final List<String> subtotalColumnNames = [];
            final Map<String, int> subtotalColumnDecimals = {};
            final Map<String, bool> numericColumnMap = {};
            final Map<String, bool> imageColumnMap = {};
            final Map<String, bool> indianFormatColumnMap = {}; // Map to store indian_format flag

            bool hasGrandTotals = false;

            // --- Diagnostic Log for Field Configs ---
            debugPrint('--- ReportMainUI: Field Configs for "$reportLabel" (RecNo: $recNo) ---');
            for (var config in sortedFieldConfigs) {
              final fieldName = config['Field_name']?.toString() ?? 'N/A';

              // Ensure numeric detection is robust
              final bool isNumeric = [
                'VQ_GrandTotal', 'Qty', 'Rate', 'NetRate', 'GrandTotal', 'Value', 'Amount',
                'Excise', 'Cess', 'HSCess', 'Freight', 'TCS'
              ].contains(fieldName) || (config['data_type']?.toString().toLowerCase() == 'number');
              numericColumnMap[fieldName] = isNumeric;

              final bool isImage = config['image']?.toString() == '1';
              imageColumnMap[fieldName] = isImage;

              // This line now strictly reads the 'indian_format' flag from the backend configuration.
              final bool useIndianFormat = config['indian_format']?.toString() == '1';
              indianFormatColumnMap[fieldName] = useIndianFormat;


              if (config['Breakpoint']?.toString() == '1') {
                breakpointColumnName = fieldName;
              }
              if (config['SubTotal']?.toString() == '1' && isNumeric) {
                subtotalColumnNames.add(fieldName);
                // Trim the decimal_points string for robust parsing
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
            // --- End Diagnostic Log ---

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
              // Trim the decimal_points string for robust parsing
              final int decimalPoints = int.tryParse(config['decimal_points']?.toString().trim() ?? '0') ?? 0;
              final bool isNumericField = numericColumnMap[fieldName] ?? false; // Use the value determined earlier
              final bool isImageColumn = imageColumnMap[fieldName] ?? false;
              final bool useIndianFormatForColumn = indianFormatColumnMap[fieldName] ?? false; // Get conditional flag

              // PlutoGrid's internal format. The visual formatting is controlled by the `renderer`.
              String plutoGridFormatString = '#,##0';
              if (decimalPoints > 0) {
                plutoGridFormatString += '.' + '0' * decimalPoints;
              }

              return PlutoColumn(
                title: fieldLabel,
                field: fieldName,
                // Use PlutoColumnType.number for internal sorting/filtering,
                // but the `renderer` will control visual formatting.
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

                  // The "Grand Total" label should ideally be on a non-numeric column, or the first column.
                  // This condition places the 'Grand Total' label on the first column (index 0).
                  if (i == 0) {
                    return PlutoAggregateColumnFooter(
                      rendererContext: rendererContext,
                      type: PlutoAggregateColumnType.count, // Type count just to get the aggregate footer layout
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
                  } else if (total && isNumericField) { // This condition correctly applies to other numeric total columns
                    double sum = 0.0;
                    for (var row in rendererContext.stateManager.rows) {
                      // Exclude subtotal rows from grand total calculation
                      if (row.cells.containsKey('__isSubtotal__') && row.cells['__isSubtotal__']!.value == true) {
                        continue;
                      }
                      final cellValue = row.cells[fieldName]?.value;
                      // Ensure parsing from potentially string values to double
                      final parsedValue = double.tryParse(cellValue.toString()) ?? 0.0;
                      sum += parsedValue;
                    }
                    // Apply Indian formatting for grand total IF the flag is true
                    final String formattedTotal = useIndianFormatForColumn
                        ? formatIndianNumber(sum, decimalPoints)
                        : sum.toStringAsFixed(decimalPoints); // Fallback to standard if not Indian format

                    return PlutoAggregateColumnFooter(
                      rendererContext: rendererContext,
                      type: PlutoAggregateColumnType.sum,
                      format: plutoGridFormatString, // Internal format
                      alignment: Alignment.centerRight,
                      titleSpanBuilder: (text) {
                        // Custom rendering to apply your determined format
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
                  final rawCellValue = rendererContext.cell.value; // Get the raw value from the cell
                  final String valueString = rawCellValue?.toString() ?? ''; // Convert to string for display/parsing
                  final isSubtotalRow = rendererContext.row.cells.containsKey('__isSubtotal__') && rendererContext.row.cells['__isSubtotal__']!.value == true;

                  if (fieldName == 'Qty') { // DEBUG PRINT for the Qty column
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
                    if (fieldName == 'Qty') { // DEBUG PRINT
                      debugPrint('  Parsed number (in renderer): $number');
                    }
                    // Apply Indian formatting for data cells IF the flag is true
                    final String formattedNumber = useIndianFormatForColumn
                        ? formatIndianNumber(number, decimalPoints)
                        : number.toStringAsFixed(decimalPoints); // Fallback to standard if not Indian format
                    if (fieldName == 'Qty') { // DEBUG PRINT
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

                          // 1. Gather dynamic parameters from the current row
                          final Map<String, String> dynamicApiParams = {};
                          for (var paramConfig in actionParamsConfig) {
                            final paramName = paramConfig['parameterName']?.toString() ?? '';
                            final sourceFieldName = paramConfig['parameterValue']?.toString() ?? '';

                            final PlutoCell? cell = rendererContext.row.cells[sourceFieldName];
                            String valueFromRow = '';
                            if (cell != null && cell.value != null) {
                              valueFromRow = cell.value.toString();
                            }
                            if (paramName.isNotEmpty) {
                              dynamicApiParams[paramName] = valueFromRow;
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                            child: ElevatedButton(
                              onPressed: () async { // Keep async as we await dialog
                                debugPrint('Action button pressed: $actionName (Type: $actionType)');
                                debugPrint('Action API URL (template): $actionApiUrlTemplate');
                                debugPrint('Dynamic Params for action: $dynamicApiParams');

                                if (actionType == 'table') {
                                  // Navigate to a new ReportMainUI instance
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider(
                                        create: (context) => TableBlocEvents.TableBlocGenerate(ReportAPIService())
                                          ..add(TableBlocEvents.FetchApiDetails(actionReportLabel, const [])) // Pass a logical name for ApiDetails, not a URL
                                          ..add(TableBlocEvents.FetchFieldConfigs(
                                            actionRecNoResolved,
                                            actionReportLabel, // Use label as the API name identifier here if it's unique enough for your config system
                                            actionReportLabel,
                                            actionApiUrlTemplate: actionApiUrlTemplate,
                                            dynamicApiParams: dynamicApiParams,
                                          )),
                                        child: TableMainUI(
                                          recNo: actionRecNoResolved,
                                          apiName: actionReportLabel, // Use label as the API name identifier here
                                          reportLabel: actionReportLabel,
                                          userParameterValues: dynamicApiParams,
                                          actionsConfig: const [],
                                        ),
                                      ),
                                    ),
                                  );
                                }else if (actionType == 'print') {
                                  // Show template and color selection dialog
                                  final TemplateSelectionResult? result = await showDialog<TemplateSelectionResult>(
                                    context: context,
                                    builder: (BuildContext dialogContext) {
                                      return const ReportTemplateSelectionDialog();
                                    },
                                  );

                                  if (result != null) {
                                    debugPrint('Selected print template: ${result.template.displayName}, Color: ${result.color}');
                                    // Navigate to PrintPreviewPage
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PrintPreviewPage(
                                          actionApiUrlTemplate: actionApiUrlTemplate,
                                          dynamicApiParams: dynamicApiParams,
                                          reportLabel: actionReportLabel,
                                          selectedTemplate: result.template,
                                          selectedColor: result.color,
                                        ),
                                      ),
                                    );
                                  } else {
                                    debugPrint('No print template or color selected.');
                                  }
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
                    hasActionsColumn: showActionsColumn,
                    actionsConfigForSubtotalRow: actionsConfig,
                    numericColumnMap: numericColumnMap,
                    subtotalColumnDecimals: subtotalColumnDecimals,
                    indianFormatColumnMap: indianFormatColumnMap, // Pass the map
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
                  // Retrieve the actual field configuration to check data type and decimal points
                  // Note: `orElse` provides a default if field config isn't found (e.g., dynamic fields not in config)
                  final Map<String, dynamic> fieldConfig = sortedFieldConfigs.firstWhere(
                        (cfg) => cfg['Field_name']?.toString() == fieldName,
                    orElse: () => {'Field_name': fieldName, 'data_type': 'text', 'decimal_points': '0', 'indian_format': '0'},
                  );
                  final bool isNumericField = numericColumnMap[fieldName] ?? (fieldConfig['data_type']?.toString().toLowerCase() == 'number');

                  rowCells[fieldName] = PlutoCell(
                    // Store numeric values as doubles internally for correct sorting/calculations
                    value: isNumericField && value is String && value.isNotEmpty
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
                  // Note: `orElse` provides a default if field config isn't found (e.g., dynamic fields not in config)
                  final Map<String, dynamic> fieldConfig = sortedFieldConfigs.firstWhere(
                        (cfg) => cfg['Field_name']?.toString() == fieldName,
                    orElse: () => {'Field_name': fieldName, 'data_type': 'text', 'decimal_points': '0', 'indian_format': '0'},
                  );
                  final bool isNumericField = numericColumnMap[fieldName] ?? (fieldConfig['data_type']?.toString().toLowerCase() == 'number');

                  rowCells[fieldName] = PlutoCell(
                    value: isNumericField && value is String && value.isNotEmpty
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

            debugPrint('ReportMainUI: CustomPlutoGrid created with columns=${columns.length}, rows=${finalRows.length}');

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // MODIFIED: Pass columns and finalRows to ExportWidget
                  ExportWidget(
                    columns: columns, // Pass the PlutoColumns
                    plutoRows: finalRows, // Pass the PlutoRows (processed data with subtotals)
                    fileName: reportLabel,
                    // headerMap: headerMap, // Still useful for initial header mapping logic if needed
                    fieldConfigs: sortedFieldConfigs, // Still useful for detailed config
                    reportLabel: reportLabel,
                    parameterValues: userParameterValues,
                    apiParameters: state.selectedApiParameters,
                    pickerOptions: state.pickerOptions,
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