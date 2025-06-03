// ReportMainUI.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:intl/intl.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/CustomPlutogrid.dart';
import '../../ReportUtils/Export_widget.dart';
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart'; // Import ReportAPIService for new Bloc instance
import 'Reportbloc.dart';

class ReportMainUI extends StatelessWidget {
  final String recNo;
  final String apiName;
  final String reportLabel;
  final Map<String, String> userParameterValues;
  final List<Map<String, dynamic>> actionsConfig; // NEW: Add actionsConfig

  const ReportMainUI({
    super.key,
    required this.recNo,
    required this.apiName,
    required this.reportLabel,
    required this.userParameterValues,
    this.actionsConfig = const [], // NEW: Initialize with empty list
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
    required bool hasActionsColumn, // NEW: Parameter to indicate if actions column exists
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
            (cfg) => cfg['Field_name'].toString() == fieldName,
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
    // NEW: Add dummy cell for actions column in subtotal row if it exists
    if (hasActionsColumn) {
      subtotalCells['__actions__'] = PlutoCell(value: '');
    }
    // Mark this row as a subtotal row for custom styling and grand total exclusion
    subtotalCells['__isSubtotal__'] = PlutoCell(value: true);
    return PlutoRow(cells: subtotalCells);
  }

  @override
  Widget build(BuildContext context) {
    // Determine if an actions column should be displayed
    final bool showActionsColumn = actionsConfig.isNotEmpty;

    return Scaffold(
      appBar: AppBarWidget(
        title: reportLabel,
        onBackPress: () => Navigator.pop(context),
      ),
      body: BlocListener<ReportBlocGenerate, ReportState>(
        listener: (context, state) {
          if (state.error != null) {
            print('ReportMainUI error: ${state.error}'); // Log
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
                'reportData.length=${state.reportData.length}'); // Log

            if (state.isLoading) {
              print('ReportMainUI: Showing loader'); // Log
              return const Center(child: SubtleLoader());
            }

            // Handle cases where data or configs are empty
            if (state.reportData.isEmpty && !state.isLoading && state.error == null) {
              print('ReportMainUI: No report data available'); // Log
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
              print('ReportMainUI: No field configurations available'); // Log
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

            // Identify breakpoint, subtotal, and IMAGE columns
            String? breakpointColumnName;
            final List<String> subtotalColumnNames = [];
            final Map<String, int> subtotalColumnDecimals = {};
            final Map<String, bool> numericColumnMap = {}; // To quickly check if a column is numeric
            final Map<String, bool> imageColumnMap = {}; // NEW: To quickly check if a column is an image column

            for (var config in sortedFieldConfigs) {
              final fieldName = config['Field_name']?.toString() ?? '';
              // Consolidated numeric check logic
              final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'GrandTotal', 'Value', 'Amount'].contains(fieldName) ||
                  (config['data_type']?.toString().toLowerCase() == 'number');
              numericColumnMap[fieldName] = isNumeric;

              // NEW: Check for image column
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

            // Define PlutoGrid columns
            final List<PlutoColumn> columns = [];

            // Add standard data columns
            columns.addAll(sortedFieldConfigs.asMap().entries.map((entry) {
              final i = entry.key;
              final config = entry.value;
              final fieldName = config['Field_name']?.toString() ?? '';
              final fieldLabel = config['Field_label']?.toString() ?? '';
              // MODIFIED: Increased default width for standard columns
              final width = double.tryParse(config['width']?.toString() ?? '120') ?? 120.0;
              final total = config['Total']?.toString() == '1'; // For grand total footer
              final alignment = config['num_alignment']?.toString().toLowerCase() ?? 'left';
              final decimalPoints = int.tryParse(config['decimal_points']?.toString() ?? '0') ?? 0;
              final isNumeric = numericColumnMap[fieldName] ?? false;
              final isImageColumn = imageColumnMap[fieldName] ?? false; // Get image column flag

              // Create format string for PlutoGrid's internal number type
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
                  // This section is for Grand Totals at the very bottom of the grid.
                  if (i == 0) { // For the first column, display 'Grand Total' label
                    return PlutoAggregateColumnFooter(
                      rendererContext: rendererContext,
                      type: PlutoAggregateColumnType.count, // Type doesn't matter, we override titleSpanBuilder
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
                  } else if (total && isNumeric) { // For numeric columns marked as 'Total'
                    double sum = 0.0;
                    for (var row in rendererContext.stateManager.rows) {
                      // IMPORTANT: Exclude subtotal rows from grand total calculation
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
                      format: formatString, // PlutoGrid's format for display if not using titleSpanBuilder
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
                  // For other columns in the footer, show nothing
                  return const SizedBox.shrink();
                },
                renderer: (rendererContext) {
                  final value = rendererContext.cell.value?.toString() ?? '';
                  // Check if the current row is a subtotal row using our custom cell marker
                  final isSubtotalRow = rendererContext.row.cells.containsKey('__isSubtotal__') && rendererContext.row.cells['__isSubtotal__']!.value == true;

                  // --- NEW IMAGE RENDERING LOGIC ---
                  // Only render image if it's an image column, value is not empty, and starts with http(s)
                  if (isImageColumn && value.isNotEmpty && (value.startsWith('http://') || value.startsWith('https://'))) {
                    return Padding( // Add some padding for visual appeal
                      padding: const EdgeInsets.all(2.0),
                      child: ClipRRect( // Clip the image to rounded corners
                        borderRadius: BorderRadius.circular(4.0),
                        child: Image.network(
                          value,
                          fit: BoxFit.contain, // Ensure image fits within cell boundaries
                          alignment: Alignment.center,
                          loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: SizedBox( // Give the progress indicator a size
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
                            print('Image loading error for $fieldName: $exception, URL: $value'); // Log
                            return Center(
                              child: Icon(Icons.broken_image, color: Colors.red[300], size: 24),
                            );
                          },
                        ),
                      ),
                    );
                  }
                  // --- END NEW IMAGE RENDERING LOGIC ---

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
                    // For non-numeric cells, especially the subtotal label cell
                    textWidget = Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isSubtotalRow ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: isSubtotalRow && fieldName == breakpointColumnName // If it's the subtotal label cell
                          ? TextAlign.left // Force left alignment for the subtotal label
                          : alignment == 'center' // Otherwise, use configured alignment
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

            // NEW: Add Actions Column if actionsConfig is present and not empty
            if (showActionsColumn) {
              columns.add(
                PlutoColumn(
                  title: 'Actions',
                  field: '__actions__', // A dummy field for the actions column
                  type: PlutoColumnType.text(),
                  // MODIFIED: Increased width factor for action column
                  width: actionsConfig.length * 100.0, // Adjust width based on number of buttons, e.g., 100 per button
                  minWidth: 120, // Minimum width for the column
                  enableFilterMenuItem: false,
                  enableSorting: false,
                  enableRowChecked: false,
                  enableContextMenu: false,
                  renderer: (rendererContext) {
                    // Don't show action buttons for subtotal rows
                    final isSubtotalRow = rendererContext.row.cells.containsKey('__isSubtotal__') && rendererContext.row.cells['__isSubtotal__']!.value == true;
                    if (isSubtotalRow) {
                      return const SizedBox.shrink();
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // Ensure row only takes needed space
                        children: actionsConfig.map((action) {
                          final String actionName = action['name']?.toString() ?? 'Action';
                          final String actionApiUrlTemplate = action['api']?.toString() ?? ''; // This is the URL template from actions_config
                          final List<dynamic> actionParamsConfig = List<dynamic>.from(action['params'] ?? []);
                          final String actionRecNoResolved = action['recNo_resolved']?.toString() ?? '';
                          final String actionReportLabel = action['reportLabel']?.toString() ?? 'Action Report';
                          final String actionApiNameResolved = action['apiName_resolved']?.toString() ?? '';

                          return Padding(
                            // MODIFIED: Increased horizontal padding for buttons
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                            child: ElevatedButton(
                              onPressed: () {
                                // 1. Gather dynamic parameters from the current row
                                final Map<String, String> dynamicApiParams = {};
                                for (var paramConfig in actionParamsConfig) {
                                  final paramName = paramConfig['parameterName']?.toString() ?? '';
                                  final sourceFieldName = paramConfig['parameterValue']?.toString() ?? '';

                                  // --- CRITICAL FIX & LOGGING HERE ---
                                  final PlutoCell? cell = rendererContext.row.cells[sourceFieldName];
                                  String valueFromRow = '';
                                  if (cell != null && cell.value != null) {
                                    valueFromRow = cell.value.toString();
                                    print('DEBUG: Extracted value for parameter "$paramName" from row field "$sourceFieldName": "$valueFromRow" (Type: ${cell.value.runtimeType})');
                                  } else {
                                    print('DEBUG: WARNING: Cell for source field "$sourceFieldName" is null or its value is null. Parameter "$paramName" will be empty.');
                                  }
                                  // --- END CRITICAL FIX & LOGGING ---

                                  // Always add the parameter to dynamicApiParams, even if its value is empty.
                                  // This allows an empty value from the row to override a default in the template.
                                  if (paramName.isNotEmpty) {
                                    dynamicApiParams[paramName] = valueFromRow;
                                  }
                                }

                                print('Action button pressed: $actionName'); // Log
                                print('Action API URL (template): $actionApiUrlTemplate'); // Log
                                print('Dynamic Params for action: $dynamicApiParams'); // Log // Confirm this now shows the value!
                                print('Action Report Label: $actionReportLabel'); // Log
                                print('Action API Name (resolved): $actionApiNameResolved'); // Log
                                print('Action RecNo (resolved): $actionRecNoResolved'); // Log

                                // 3. Navigate to a new ReportMainUI instance
                                // It will fetch its own details and data based on apiName and recNo.
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BlocProvider(
                                      create: (context) => ReportBlocGenerate(ReportAPIService())
                                        ..add(FetchApiDetails(actionApiNameResolved, const [])) // Fetch API parameters first
                                      // Pass the actionApiUrlTemplate to FetchFieldConfigs for API call
                                        ..add(FetchFieldConfigs(actionRecNoResolved, actionApiNameResolved, actionReportLabel, actionApiUrlTemplate: actionApiUrlTemplate)),
                                      child: ReportMainUI(
                                        recNo: actionRecNoResolved,
                                        apiName: actionApiNameResolved,
                                        reportLabel: actionReportLabel,
                                        userParameterValues: dynamicApiParams, // Pass derived parameters for the new report
                                        actionsConfig: const [], // Action reports typically don't have further nested actions
                                      ),
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent, // Consistent button color
                                // MODIFIED: Enhanced button style
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: const Size(60, 30), // Increased minimum size for better tap target
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 2, // A subtle elevation
                                shadowColor: Colors.blueAccent.withOpacity(0.4),
                              ),
                              child: Text(
                                actionName,
                                style: GoogleFonts.poppins(
                                  // MODIFIED: Increased font size for readability
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600, // Slightly bolder font
                                ),
                                overflow: TextOverflow.ellipsis, // Handle long button names
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
              // Sort data by the breakpoint column to ensure groups are contiguous
              currentReportData.sort((a, b) {
                final aValue = a[breakpointColumnName]?.toString() ?? '';
                final bValue = b[breakpointColumnName]?.toString() ?? '';
                return aValue.compareTo(bValue);
              });

              String? currentBreakpointValue;
              Map<String, double> currentGroupSubtotals = {
                for (var colName in subtotalColumnNames) colName: 0.0
              };
              List<Map<String, dynamic>> currentGroupDataRows = []; // To hold original data rows of the current group

              // Helper to add a subtotal row for the completed group
              void addSubtotalRowForGroup(String groupName, List<Map<String, dynamic>> groupRows) {
                // ONLY add subtotal if there's more than 1 row in the group
                if (groupRows.length > 1 && subtotalColumnNames.isNotEmpty) {
                  finalRows.add(_createSubtotalRow(
                    groupName: groupName,
                    subtotals: currentGroupSubtotals,
                    sortedFieldConfigs: sortedFieldConfigs,
                    breakpointColumnName: breakpointColumnName,
                    hasActionsColumn: showActionsColumn, // NEW: Pass this flag
                  ));
                }
                // Reset subtotals and group rows for the next group
                currentGroupSubtotals = {
                  for (var colName in subtotalColumnNames) colName: 0.0
                };
                currentGroupDataRows.clear(); // Clear the group rows for next group
              }

              for (int i = 0; i < currentReportData.length; i++) {
                final data = currentReportData[i];
                final rowBreakpointValue = data[breakpointColumnName]?.toString() ?? '';

                // If breakpoint value changes AND we have a previous group to subtotal
                if (currentBreakpointValue != null && rowBreakpointValue != currentBreakpointValue) {
                  addSubtotalRowForGroup(currentBreakpointValue, currentGroupDataRows);
                  // After adding subtotal, currentGroupDataRows and subtotals are reset
                }

                // --- CRITICAL FIX: Populate rowCells with ALL original data keys ---
                final rowCells = <String, PlutoCell>{};
                data.forEach((key, value) {
                  final String fieldName = key.toString();
                  // Find the corresponding config to check if it's numeric/image, etc.
                  // Default to non-numeric if no config is found for this field.
                  final Map<String, dynamic> fieldConfig = sortedFieldConfigs.firstWhere(
                        (cfg) => cfg['Field_name']?.toString() == fieldName,
                    orElse: () => {'Field_name': fieldName, 'data_type': 'text'},
                  );
                  final bool isNumeric = numericColumnMap[fieldName] ?? (fieldConfig['data_type']?.toString().toLowerCase() == 'number');

                  rowCells[fieldName] = PlutoCell(
                    value: isNumeric && value is String && value.isNotEmpty
                        ? (double.tryParse(value) ?? 0.0) // Convert to double if numeric string
                        : value, // Use value as-is for other types or non-numeric
                  );
                });
                // --- END CRITICAL FIX ---

                // NEW: Add dummy cell for actions column if it's shown
                if (showActionsColumn) {
                  rowCells['__actions__'] = PlutoCell(value: ''); // Action buttons are rendered by the renderer, not based on cell value
                }
                // Mark this row as not a subtotal row
                rowCells['__isSubtotal__'] = PlutoCell(value: false);
                finalRows.add(PlutoRow(cells: rowCells));
                currentGroupDataRows.add(data); // Add original data to the current group list

                // Update subtotals for the current group
                for (var colName in subtotalColumnNames) {
                  final value = data[colName];
                  if (value != null) {
                    final parsedValue = double.tryParse(value.toString()) ?? 0.0;
                    currentGroupSubtotals[colName] = (currentGroupSubtotals[colName] ?? 0.0) + parsedValue;
                  }
                }

                currentBreakpointValue = rowBreakpointValue;

                // If this is the last row, add subtotal for the last group
                if (i == currentReportData.length - 1) {
                  addSubtotalRowForGroup(currentBreakpointValue, currentGroupDataRows);
                }
              }
            } else {
              // No breakpoint column, just add all rows as is without grouping/subtotals
              finalRows.addAll(state.reportData.map((data) {
                // --- CRITICAL FIX: Populate rowCells with ALL original data keys ---
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
                // --- END CRITICAL FIX ---

                // NEW: Add dummy cell for actions column if it's shown
                if (showActionsColumn) {
                  rowCells['__actions__'] = PlutoCell(value: '');
                }
                rowCells['__isSubtotal__'] = PlutoCell(value: false);
                return PlutoRow(cells: rowCells);
              }));
            }

            print('ReportMainUI: CustomPlutoGrid created with columns=${columns.length}, rows=${finalRows.length}'); // Log

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ExportWidget(
                    data: state.reportData, // Pass original data for export
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
                      rows: finalRows, // Use the processed rows with subtotals
                      // Callback to apply background color to subtotal rows and alternating colors
                      rowColorCallback: (rowContext) {
                        if (rowContext.row.cells.containsKey('__isSubtotal__') && rowContext.row.cells['__isSubtotal__']!.value == true) {
                          return Colors.grey[200]!; // Light grey background for subtotal rows
                        }
                        // For non-subtotal rows, apply alternating colors
                        return rowContext.rowIdx % 2 == 0 ? Colors.white : Colors.grey[50]!;
                      },
                      onChanged: (PlutoGridOnChangedEvent event) {
                        // This callback is for changes *within* the grid cells.
                        // Removed logging for minor changes
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