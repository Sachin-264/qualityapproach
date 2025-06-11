// ReportDynamic/TableGenerator/TableMainUI.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:intl/intl.dart'; // REQUIRED for formatIndianNumber
// Assuming this path is correct for your project
import 'package:qualityapproach/ReportDynamic/ReportGenerator/PrintTemp/printpreview.dart';
import 'package:qualityapproach/ReportDynamic/ReportGenerator/PrintTemp/print_template_selection.dart'; // Add this for print template selection

import '../../../ReportUtils/Appbar.dart';
import '../../../ReportUtils/CustomPlutogrid.dart';
import '../../../ReportUtils/Export_widget.dart'; // This is the file we're modifying
import '../../../ReportUtils/subtleloader.dart';
import '../../ReportAPIService.dart'; // Adjust path
import 'TableBLoc.dart'; // Ensure TableBLoc.dart has the ReportState with actionsConfig

class TableMainUI extends StatelessWidget {
  final String recNo;
  final String apiName;
  final String reportLabel;
  final Map<String, String> userParameterValues;
  final List<Map<String, dynamic>> actionsConfig; // Actions specific to this table UI
  final Map<String, String> displayParameterValues; // Added for ExportWidget
  final String companyName; // NEW: Added companyName to TableMainUI

  const TableMainUI({
    super.key,
    required this.recNo,
    required this.apiName,
    required this.reportLabel,
    required this.userParameterValues,
    this.actionsConfig = const [], // This TableMainUI instance will use the actions it's configured with
    required this.displayParameterValues,
    required this.companyName, // NEW: Make companyName required
  });

  // Helper function to format numbers using Indian locale
  // This function now uses the intl package for more robust and accurate formatting.
  static String formatIndianNumber(double number, int decimalPoints) {
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
    required List<Map<String, dynamic>> actionsConfigForSubtotalRow, // Renamed for clarity
    required Map<String, bool> numericColumnMap, // New: Added numericColumnMap
    required Map<String, int> subtotalColumnDecimals, // New: Added subtotalColumnDecimals
    required Map<String, bool> indianFormatColumnMap, // New: Added indianFormatColumnMap
  }) {
    final Map<String, PlutoCell> subtotalCells = {};
    // Iterate over all possible field names to ensure we populate cells for them
    final allFieldNames = sortedFieldConfigs.map((c) => c['Field_name'].toString()).toSet();
    // Also include any 'parameterValue' from actionsConfig to ensure those cells exist
    for (var action in actionsConfigForSubtotalRow) { // Use the passed actionsConfig
      final params = List<dynamic>.from(action['params'] ?? []);
      for (var param in params) {
        allFieldNames.add(param['parameterValue'].toString());
      }
    }

    for (var fieldName in allFieldNames) {
      final config = sortedFieldConfigs.firstWhere(
            (cfg) => cfg['Field_name']?.toString() == fieldName,
        // CORRECTED: Provide a default PlutoColumnType.text()
        orElse: () => {'Field_name': fieldName, 'data_type': 'text', 'decimal_points': '0', 'indian_format': '0'},
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
    debugPrint('TableMainUI: BUILDING "${reportLabel}" (RecNo: $recNo, ApiName: $apiName)');
    debugPrint('TableMainUI: Company Name passed: ${companyName}'); // NEW: Log company name

    // IMPORTANT: Now we use the `actionsConfig` that was passed to this specific instance's constructor.
    // The BLoC's state will contain the actions for the currently loaded API, but this widget instance
    // will operate on the actions it was configured with. This is the correct behavior for nested
    // reports, as the nested report should display its own actions, not its parent's.
    // However, for the nested TableMainUI, its actionsConfig from the constructor is typically empty,
    // and its BLoC will fetch its actions from the API definition.
    // We will now correctly use state.actionsConfig for rendering the actions column
    // as it represents the actions specific to the currently loaded report data.

    return Scaffold(
      appBar: AppBarWidget(
        title: reportLabel,
        onBackPress: () => Navigator.pop(context),
      ),
      body: BlocListener<TableBlocGenerate, ReportState>( // Use TableBlocGenerate
        listener: (context, state) {
          if (state.error != null) {
            debugPrint('TableMainUI Listener error: ${state.error}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        child: BlocBuilder<TableBlocGenerate, ReportState>( // Use TableBlocGenerate
          builder: (context, state) {
            debugPrint('TableMainUI BlocBuilder rebuild for "${reportLabel}": isLoading=${state.isLoading}, '
                'fieldConfigs.length=${state.fieldConfigs.length}, '
                'reportData.length=${state.reportData.length}, '
                'state.actionsConfig.length=${state.actionsConfig.length}'); // Log state's actions
            debugPrint('TableMainUI BlocBuilder: Actions in BLoC state for "$reportLabel": ${state.actionsConfig.length} items.');


            // --- IMPROVEMENT START: Reorder rendering conditions to prevent flicker ---

            // 1. If currently loading, always show the loader.
            if (state.isLoading) {
              debugPrint('TableMainUI: Showing loader for "${reportLabel}"');
              return const Center(child: SubtleLoader());
            }

            // 2. If not loading but there's an error, show the error.
            if (state.error != null) {
              debugPrint('TableMainUI: Showing error for "${reportLabel}": ${state.error}');
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
              debugPrint('TableMainUI: No field configurations available for "${reportLabel}"');
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
              debugPrint('TableMainUI: No report data available for "${reportLabel}" for selected parameters.');
              return Center(
                child: Text(
                  'No report data available for the selected parameters.',
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }
            // --- IMPROVEMENT END: Reorder rendering conditions ---


            // If we reach here, it means we have data and configurations to display.
            final sortedFieldConfigs = List<Map<String, dynamic>>.from(state.fieldConfigs)
              ..sort((a, b) => int.parse(a['Sequence_no']?.toString() ?? '0')
                  .compareTo(int.parse(b['Sequence_no']?.toString() ?? '0')));

            String? breakpointColumnName;
            final List<String> subtotalColumnNames = [];
            final Map<String, int> subtotalColumnDecimals = {};
            final Map<String, bool> numericColumnMap = {};
            final Map<String, bool> imageColumnMap = {};
            final Map<String, bool> indianFormatColumnMap = {}; // New: Map to store indian_format flag

            bool hasGrandTotals = false;

            // --- Diagnostic Log for Field Configurations ---
            debugPrint('--- TableMainUI: Field Configs for "$reportLabel" (RecNo: $recNo) ---');
            for (var config in sortedFieldConfigs) {
              final fieldName = config['Field_name']?.toString() ?? 'N/A';
              final fieldLabel = config['Field_label']?.toString() ?? 'N/A';
              final dataType = config['data_type']?.toString().toLowerCase();

              // --- IMPROVED ISNUMERIC DETECTION LOGIC ---
              bool currentFieldIsNumeric = false;
              if (dataType == 'number' || dataType == 'decimal' || dataType == 'integer') {
                currentFieldIsNumeric = true;
              } else if (
              ['vq_grandtotal', 'qty', 'rate', 'netrate', 'grandtotal', 'value', 'amount',
                'excise', 'cess', 'hscess', 'freight', 'tcs'].contains(fieldName.toLowerCase())
              ) {
                currentFieldIsNumeric = true;
              }
              // Also consider Total or SubTotal flags for numeric inference if data_type isn't explicitly 'number'
              if (!currentFieldIsNumeric && (config['Total']?.toString() == '1' || config['SubTotal']?.toString() == '1')) {
                currentFieldIsNumeric = true;
              }
              numericColumnMap[fieldName] = currentFieldIsNumeric;
              // --- END IMPROVED ISNUMERIC DETECTION LOGIC ---


              final isImage = config['image']?.toString() == '1';
              imageColumnMap[fieldName] = isImage;

              // New: Read 'indian_format' flag
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
              debugPrint('  Field: $fieldName, Label: $fieldLabel, Type: $dataType, '
                  'Total: ${config['Total']}, SubTotal: ${config['SubTotal']}, Breakpoint: ${config['Breakpoint']}, '
                  'Decimal: ${config['decimal_points']}, Width: ${config['width']}, DetectedNumeric: ${numericColumnMap[fieldName]}, indian_format: $useIndianFormat');
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
              final decimalPoints = int.tryParse(config['decimal_points']?.toString().trim() ?? '0') ?? 0;
              final bool isNumericField = numericColumnMap[fieldName] ?? false; // Use the map here
              final bool isImageColumn = imageColumnMap[fieldName] ?? false;
              final bool useIndianFormatForColumn = indianFormatColumnMap[fieldName] ?? false; // New: Get conditional flag

              String plutoGridFormatString = '#,##0'; // For PlutoGrid's internal formatting
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

                  if (i == 0) { // Place 'Grand Total' label on the first column
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
                  } else if (total && isNumericField) { // Only render sum for numeric columns marked as 'Total'
                    double sum = 0.0;
                    for (var row in rendererContext.stateManager.rows) {
                      // Exclude subtotal rows from grand total calculation
                      if (row.cells.containsKey('__isSubtotal__') && row.cells['__isSubtotal__']!.value == true) {
                        continue;
                      }
                      final cellValue = row.cells[fieldName]?.value;
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
                    // Apply Indian formatting for data cells IF the flag is true
                    final String formattedNumber = useIndianFormatForColumn
                        ? formatIndianNumber(number, decimalPoints)
                        : number.toStringAsFixed(decimalPoints); // Fallback to standard if not Indian format

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

            // Use the actions from the BLoC state for rendering the actions column
            final bool showActionsColumnFromState = state.actionsConfig.isNotEmpty;
            debugPrint('TableMainUI: Will render actions column: $showActionsColumnFromState (from BLoC state)');

            if (showActionsColumnFromState) {
              columns.add(
                PlutoColumn(
                  title: 'Actions',
                  field: '__actions__',
                  type: PlutoColumnType.text(),
                  width: state.actionsConfig.length * 100.0, // Use BLoC state's actions for width
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
                        children: state.actionsConfig.map((action) { // Use BLoC state's actions here
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
                              onPressed: () async { // Changed to async for await dialog
                                debugPrint('TableMainUI Action button pressed: $actionName (Type: $actionType)');
                                debugPrint('TableMainUI Action API URL (template): $actionApiUrlTemplate');
                                debugPrint('TableMainUI Dynamic Params for action: $dynamicApiParams');

                                if (actionType == 'table') {
                                  // --- IMPORTANT: Prepare display values for nested TableMainUI ---
                                  final Map<String, String> nestedDisplayValuesForExport = {};
                                  for (var param in state.selectedApiParameters) {
                                    final pName = param['name'].toString();
                                    final pValue = state.userParameterValues[pName] ?? '';

                                    String dValue = '';
                                    if (param['is_company_name_field'] == true) {
                                      // If the company field is *shown* in UI, use the value from user input/picker
                                      if (param['show'] == true && pValue.isNotEmpty) {
                                        final String configType = param['config_type']?.toString().toLowerCase() ?? '';
                                        if (configType == 'database' && state.pickerOptions.containsKey(pName)) {
                                          final List<Map<String, String>> pickerOptions = state.pickerOptions[pName] ?? [];
                                          dValue = pickerOptions.firstWhere(
                                                (opt) => opt['value'] == pValue,
                                            orElse: () => {'label': pValue, 'value': pValue},
                                          )['label']!;
                                        } else {
                                          dValue = pValue; // For other types of company fields
                                        }
                                      }
                                      // If the company field is *not shown* (show: false), use its display_value_cache
                                      else if (param['show'] == false && param['display_value_cache']?.toString().isNotEmpty == true) {
                                        dValue = param['display_value_cache'].toString();
                                      }
                                    } else { // For all other parameters
                                      final pConfigType = param['config_type']?.toString().toLowerCase() ?? '';
                                      if (pConfigType == 'radio' || pConfigType == 'checkbox') {
                                        final opts = List<Map<String, String>>.from(param['options']?.map((e) => Map<String, String>.from(e)) ?? []);
                                        dValue = opts.firstWhere((opt) => opt['value'] == pValue, orElse: () => {'label': pValue, 'value': pValue})['label']!;
                                      } else if (pConfigType == 'database' && pValue.isNotEmpty && state.pickerOptions.containsKey(pName)) {
                                        final pOpts = state.pickerOptions[pName] ?? [];
                                        dValue = pOpts.firstWhere((opt) => opt['value'] == pValue, orElse: () => {'label': pValue, 'value': pValue})['label']!;
                                      } else {
                                        dValue = pValue;
                                      }
                                    }
                                    if (dValue.isNotEmpty) {
                                      final paramLabel = param['field_label']?.isNotEmpty == true ? param['field_label'] : pName;
                                      nestedDisplayValuesForExport[paramLabel] = dValue;
                                    }
                                  }
                                  // --- End preparation for nested TableMainUI ---

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider(
                                        create: (context) => TableBlocGenerate(ReportAPIService())
                                          ..add(FetchApiDetails(actionApiNameResolved, const []))
                                          ..add(FetchFieldConfigs(
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
                                          actionsConfig: const [], // Actions will be fetched by the nested TableBloc
                                          displayParameterValues: nestedDisplayValuesForExport, // Pass display values to nested UI
                                          companyName: companyName, // NEW: Pass companyName to nested TableMainUI
                                        ),
                                      ),
                                    ),
                                  );
                                } else if (actionType == 'print') {
                                  // Show template and color selection dialog
                                  final TemplateSelectionResult? result = await showDialog<TemplateSelectionResult>(
                                    context: context,
                                    builder: (BuildContext dialogContext) {
                                      return const ReportTemplateSelectionDialog();
                                    },
                                  );

                                  if (result != null) {
                                    // debugPrint('Selected print template: ${result.template.displayName}, Color: ${result.color}');
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
                    hasActionsColumn: showActionsColumnFromState, // Use BLoC state's actions
                    actionsConfigForSubtotalRow: state.actionsConfig, // Pass this to the helper
                    numericColumnMap: numericColumnMap, // Pass the numeric map
                    subtotalColumnDecimals: subtotalColumnDecimals, // Pass subtotal decimals
                    indianFormatColumnMap: indianFormatColumnMap, // Pass indian format map
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
                // Iterate through sortedFieldConfigs to ensure all expected fields are present
                for (var config in sortedFieldConfigs) {
                  final fieldName = config['Field_name']?.toString() ?? '';
                  final rawValue = data[fieldName]; // Get value from data row
                  final bool isNumeric = numericColumnMap[fieldName] ?? false; // Use the value determined earlier

                  // Ensure value is non-null for PlutoCell
                  dynamic cellValue;
                  if (isNumeric) {
                    cellValue = double.tryParse(rawValue?.toString().trim() ?? '') ?? 0.0;
                  } else {
                    cellValue = rawValue?.toString() ?? '';
                  }
                  rowCells[fieldName] = PlutoCell(value: cellValue);
                }

                if (showActionsColumnFromState) { // Add dummy cell only if actions column is present
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
                // Iterate through sortedFieldConfigs to ensure all expected fields are present
                for (var config in sortedFieldConfigs) {
                  final fieldName = config['Field_name']?.toString() ?? '';
                  final rawValue = data[fieldName]; // Get value from data row
                  final bool isNumeric = numericColumnMap[fieldName] ?? false; // Use the value determined earlier

                  // Ensure value is non-null for PlutoCell
                  dynamic cellValue;
                  if (isNumeric) {
                    cellValue = double.tryParse(rawValue?.toString().trim() ?? '') ?? 0.0;
                  } else {
                    cellValue = rawValue?.toString() ?? '';
                  }
                  rowCells[fieldName] = PlutoCell(value: cellValue);
                }
                if (showActionsColumnFromState) { // Add dummy cell only if actions column is present
                  rowCells['__actions__'] = PlutoCell(value: '');
                }
                rowCells['__isSubtotal__'] = PlutoCell(value: false);
                return PlutoRow(cells: rowCells);
              }));
            }

            debugPrint('TableMainUI: CustomPlutoGrid created for "${reportLabel}" with columns=${columns.length}, rows=${finalRows.length}');

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // CORRECTED: Pass PlutoColumns and PlutoRows instead of raw data
                  ExportWidget(
                    columns: columns, // Pass the PlutoColumns
                    plutoRows: finalRows, // Pass the PlutoRows (processed data with subtotals)
                    fileName: reportLabel,
                    // headerMap: headerMap, // Still useful for initial header mapping logic if needed
                    fieldConfigs: sortedFieldConfigs, // Still useful for detailed config
                    reportLabel: reportLabel,
                    parameterValues: userParameterValues,
                    displayParameterValues: displayParameterValues, // Pass the map here
                    apiParameters: state.selectedApiParameters,
                    pickerOptions: state.pickerOptions,
                    companyName: companyName, // Pass the company name here
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