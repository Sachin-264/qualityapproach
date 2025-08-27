// lib/ReportDynamic/ReportGenerator/ReportMainUI.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/CustomPlutogrid.dart';
import '../../ReportUtils/Export_widget.dart';
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart';
import '../ReportMakeEdit/EditDetailMaker.dart';
import 'Graph/graph_view.dart';
import 'PrintTemp/printpreview.dart';
import 'PrintTemp/printservice.dart';
import 'ReportUI.dart';
import 'Reportbloc.dart';
import 'TableGenerate/TableBLoc.dart' as TableBlocEvents;
import 'TableGenerate/TableMainUI.dart';
import 'api_driven_dropdown.dart';


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
  final Map<String, String> displayParameterValues;
  final String companyName;
  final bool includePdfFooterDateTime;
  final Map<String, dynamic> reportDefinition;

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
    required this.reportDefinition,
  });

  static String formatIndianNumber(double number, int decimalPoints) {
    String pattern = '##,##,##0';
    if (decimalPoints > 0) {
      pattern += '.${'0' * decimalPoints}';
    }
    final NumberFormat indianFormat = NumberFormat(pattern, 'en_IN');
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

  void _showUserInputDialog(
      BuildContext context,
      Map<String, dynamic> originalRowData,
      String updatedUrl,
      List<dynamic> payloadStructureConfig,
      String fieldName,
      PlutoCell cellToUpdate,
      PlutoGridStateManager stateManager,
      ) async {
    if (updatedUrl.isEmpty || payloadStructureConfig.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update URL or Payload structure missing for this action.'), backgroundColor: Colors.red),
      );
      return;
    }

    TextEditingController textController = TextEditingController(text: cellToUpdate.value?.toString() ?? '');

    await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Edit $fieldName', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: textController,
            decoration: InputDecoration(
              labelText: 'Enter new value for $fieldName',
              border: OutlineInputBorder(),
            ),
            maxLines: null,
            keyboardType: TextInputType.multiline,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              child: Text('Submit', style: GoogleFonts.poppins(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () => Navigator.of(dialogContext).pop(textController.text),
            ),
          ],
        );
      },
    ).then((result) async {
      if (result != null) {
        String finalUserInput = result;
        try {
          final Map<String, dynamic> payload = {};
          for (var item in payloadStructureConfig) {
            final String key = item['key']?.toString() ?? '';
            final String valueType = item['value_type']?.toString().toLowerCase() ?? '';
            final bool isUserInput = (item['is_user_input'] == true) || (item['is_user_input']?.toString().toLowerCase() == 'true');
            if (key.isEmpty) continue;

            if (isUserInput) {
              payload[key] = finalUserInput;
            } else if (valueType == 'static') {
              payload[key] = item['value'];
            } else if (valueType == 'dynamic') {
              final String dynamicFieldName = item['value']?.toString() ?? '';
              if (dynamicFieldName.isNotEmpty && originalRowData.containsKey(dynamicFieldName)) {
                payload[key] = originalRowData[dynamicFieldName];
              } else {
                payload[key] = '';
              }
            } else {
              payload[key] = '';
            }
          }


          final String payloadJson = jsonEncode(payload);
          debugPrint('--- PAYLOAD BEING SENT ---');
          debugPrint('URL: $updatedUrl');
          debugPrint('Payload: $payloadJson');
          debugPrint('--------------------------');

          final ReportAPIService apiService = context.read<ReportBlocGenerate>().apiService;
          final response = await apiService.postJson(updatedUrl, payload);

          if (response['status'] == 'success') {
            final successMessage = response['ResultMsg'] ?? 'Update successful!';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: Colors.green));

            cellToUpdate.value = finalUserInput;
            stateManager.notifyListeners();
          } else {
            final errorMessage = response['message'] ?? response['ResultMsg'] ?? 'Update failed.';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error processing update: $e'), backgroundColor: Colors.red));
        }
      }
    });
  }

  // =========== NEW WIDGET TO DISPLAY FILTERS ===========
  Widget _buildFilterChips(BuildContext context) {
    // Filter out parameters with empty or null values before displaying
    final activeFilters = Map.fromEntries(
        displayParameterValues.entries.where((entry) => entry.value.isNotEmpty)
    );

    if (activeFilters.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no filters are active
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10.0, // Horizontal space between chips
            runSpacing: 8.0, // Vertical space between lines of chips
            children: activeFilters.entries.map((entry) {
              return Chip(
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey.shade300),
                avatar: Icon(Icons.check_circle_outline, color: Colors.blueAccent, size: 18),
                label: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${entry.key}: ',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.8),
                        ),
                      ),
                      TextSpan(
                        text: entry.value,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: Colors.black.withOpacity(0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  // =========== END OF NEW WIDGET ===========


  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReportBlocGenerate, ReportState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!),
                  backgroundColor: Colors.redAccent));
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBarWidget(
            title: reportLabel,
            onBackPress: () => Navigator.pop(context),
            actions: [
              TextButton(
                onPressed: () async {
                  final bloc = context.read<ReportBlocGenerate>();

                  // Navigate to ReportUI and wait for it to be popped.
                  final bool? shouldRefresh = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      // Pass the existing BLoC instance down to the child route
                      // so that changes made in ReportUI are reflected in the same BLoC instance.
                      builder: (newContext) => BlocProvider.value(
                        value: bloc,
                        child: ReportUI(
                          reportToPreload: reportDefinition,
                          initialParameters: state.userParameterValues,
                        ),
                      ),
                    ),
                  );

                  // Check if ReportUI popped with a `true` value, and if the widget is still mounted.
                  if (shouldRefresh == true && context.mounted) {
                    debugPrint('[ReportMainUI] Received refresh signal from ReportUI. Refetching data...');
                    // Re-dispatch the event to fetch the report data with the new parameters
                    bloc.add(FetchFieldConfigs(
                      recNo,
                      apiName,
                      reportLabel,
                      dynamicApiParams: bloc.state.userParameterValues, // Use the updated params from the bloc
                    ));
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      'Filter',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ReportState state) {
    debugPrint('\n--- [ReportMainUI Body] Rebuilding ---');
    debugPrint('State isLoading: ${state.isLoading}');
    debugPrint('State error: ${state.error}');
    debugPrint('State fieldConfigs count: ${state.fieldConfigs.length}');
    debugPrint('State reportData count: ${state.reportData.length}');
    debugPrint("the companyCode we are sending is $companyName");
    if (state.isLoading) {
      return const Center(child: SubtleLoader());
    }

    if (state.error != null) {
      return Center(child: Text('Error: ${state.error}', style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 16), textAlign: TextAlign.center));
    }

    if (state.fieldConfigs.isEmpty && state.reportData.isEmpty) {
      return Center(child: Text('Report is empty or still loading...', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16), textAlign: TextAlign.center));
    }

    final allActions = state.actionsConfig;
    final rowActions = allActions.where((action) => action['type'] != 'graph').toList();
    final topLevelGraphActions = allActions.where((action) => action['type'] == 'graph').toList();

    final List<Widget> topLevelGraphButtons = topLevelGraphActions.map((action) {
      final String actionName = action['name']?.toString() ?? 'View Graph';
      final String graphType = action['graphType']?.toString() ?? '';
      final String xAxisField = action['xAxisField']?.toString() ?? '';
      final String yAxisField = action['yAxisField']?.toString() ?? '';
      return ElevatedButton.icon(
        icon: const Icon(Icons.bar_chart, size: 18),
        label: Text(actionName, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
        onPressed: () {
          if (xAxisField.isEmpty || yAxisField.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Graph action "$actionName" is not configured correctly (X/Y axis missing).'), backgroundColor: Colors.orange));
            return;
          }
          Navigator.push(context, MaterialPageRoute(builder: (_) => GraphView(graphTitle: actionName, graphType: graphType, xAxisField: xAxisField, yAxisField: yAxisField, reportData: state.reportData)));
        },
        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 2),
      );
    }).toList();


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
      final bool isMarkedForAggregation = config['Total']?.toString() == '1' || config['SubTotal']?.toString() == '1';
      final bool isNumeric = ['number', 'decimal'].contains(config['data_type']?.toString().toLowerCase()) || ['Qty', 'Rate', 'GrandTotal', 'Value', 'Amount'].contains(fieldName) || isMarkedForAggregation;
      numericColumnMap[fieldName] = isNumeric;
      imageColumnMap[fieldName] = config['image']?.toString() == '1';
      indianFormatColumnMap[fieldName] = config['indian_format']?.toString() == '1';
      if (config['Breakpoint']?.toString() == '1') breakpointColumnName = fieldName;
      if (config['SubTotal']?.toString() == '1' && isNumeric) {
        subtotalColumnNames.add(fieldName);
        subtotalColumnDecimals[fieldName] = int.tryParse(config['decimal_points']?.toString().trim() ?? '0') ?? 0;
      }
      if (config['Total']?.toString() == '1' && isNumeric) hasGrandTotals = true;
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
      final bool isApiDriven = config['is_api_driven'] == true;
      final bool isUserFilling = config['is_user_filling'] == true;
      PlutoColumnType columnType = isNumericField ? PlutoColumnType.number(format: '#,##0${decimalPoints > 0 ? '.${'0' * decimalPoints}' : ''}') : PlutoColumnType.text();
      return PlutoColumn(
        title: fieldLabel,
        field: fieldName,
        type: columnType,
        width: width,
        textAlign: alignment == 'center' ? PlutoColumnTextAlign.center : (alignment == 'right' ? PlutoColumnTextAlign.right : PlutoColumnTextAlign.left),
        enableEditingMode: isUserFilling || isApiDriven,
        enableFilterMenuItem: true,
        footerRenderer: (rendererContext) {
          if (!hasGrandTotals) return const SizedBox.shrink();
          if (i == 0) {
            return PlutoAggregateColumnFooter(rendererContext: rendererContext, type: PlutoAggregateColumnType.count, alignment: Alignment.centerLeft, titleSpanBuilder: (text) => [TextSpan(text: 'Grand Total', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))]);
          } else if (total && isNumericField) {
            double sum = rendererContext.stateManager.rows.where((row) => row.cells['__isSubtotal__']?.value != true).fold(0.0, (prev, row) => prev + (double.tryParse(row.cells[fieldName]?.value.toString() ?? '0') ?? 0.0));
            final String formattedTotal = useIndianFormatForColumn ? formatIndianNumber(sum, decimalPoints) : sum.toStringAsFixed(decimalPoints);
            return PlutoAggregateColumnFooter(rendererContext: rendererContext, type: PlutoAggregateColumnType.sum, format: '#,##0${decimalPoints > 0 ? '.${'0' * decimalPoints}' : ''}', alignment: Alignment.centerRight, titleSpanBuilder: (text) => [TextSpan(text: formattedTotal, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))]);
          }
          return const SizedBox.shrink();
        },
        renderer: (rendererContext) {
          final rawCellValue = rendererContext.cell.value;
          final String valueString = rawCellValue?.toString() ?? '';
          final bool isSubtotalRow = rendererContext.row.cells['__isSubtotal__']?.value == true;
          if (isSubtotalRow) {
            return Align(alignment: alignment == 'center' ? Alignment.center : (alignment == 'right' ? Alignment.centerRight : Alignment.centerLeft), child: Text(valueString, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)));
          }
          if (isApiDriven) {
            return ApiDrivenDropdown(columnConfig: config, rowData: rendererContext.row.cells['__raw_data__']!.value as Map<String, dynamic>, initialValue: valueString, apiService: context.read<ReportBlocGenerate>().apiService, onSelectionChanged: (newValue) { if (newValue != null) { rendererContext.stateManager.changeCellValue(rendererContext.cell, newValue, force: true); } });
          }
          if (isUserFilling) {
            final String updatedUrl = config['updated_url']?.toString() ?? '';
            final List<dynamic> payloadStructureConfig = config['payload_structure'] as List<dynamic>? ?? [];
            return GestureDetector(onTap: () { _showUserInputDialog(context, rendererContext.row.cells['__raw_data__']!.value as Map<String, dynamic>, updatedUrl, payloadStructureConfig, fieldName, rendererContext.cell, rendererContext.stateManager); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8.0), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), border: Border.all(color: Colors.blue.withOpacity(0.2)), borderRadius: BorderRadius.circular(4)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(valueString.isEmpty ? 'Tap to edit...' : valueString, style: GoogleFonts.poppins(fontSize: 12, color: valueString.isEmpty ? Colors.grey.shade600 : Colors.black87, fontStyle: valueString.isEmpty ? FontStyle.italic : FontStyle.normal), overflow: TextOverflow.ellipsis)), const SizedBox(width: 4), Icon(Icons.edit, size: 14, color: Colors.blue.shade700)])));
          }
          if (isImageColumn && valueString.isNotEmpty && (valueString.startsWith('http://') || valueString.startsWith('https://'))) {
            return Padding(padding: const EdgeInsets.all(2.0), child: ClipRRect(borderRadius: BorderRadius.circular(4.0), child: Image.network(valueString, fit: BoxFit.contain, alignment: Alignment.center, loadingBuilder: (ctx, child, progress) => progress == null ? child : Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0, value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null))), errorBuilder: (ctx, err, st) => Center(child: Icon(Icons.broken_image, color: Colors.red[300], size: 24)))));
          }
          if (isNumericField && valueString.isNotEmpty) {
            final number = double.tryParse(valueString) ?? 0.0;
            final String formattedNumber = useIndianFormatForColumn ? formatIndianNumber(number, decimalPoints) : number.toStringAsFixed(decimalPoints);
            return Text(formattedNumber, style: GoogleFonts.poppins(fontSize: 12), textAlign: alignment == 'center' ? TextAlign.center : (alignment == 'right' ? TextAlign.right : TextAlign.left));
          }
          return Text(valueString, style: GoogleFonts.poppins(fontSize: 12), textAlign: alignment == 'center' ? TextAlign.center : (alignment == 'right' ? TextAlign.right : TextAlign.left));
        },
      );
    }));

    columns.add(PlutoColumn(title: 'Raw Data (Hidden)', field: '__raw_data__', type: PlutoColumnType.text(), hide: true, width: 1, enableEditingMode: false, enableFilterMenuItem: false, enableSorting: false, enableRowChecked: false, enableContextMenu: false));

    final bool showRowActionsColumn = rowActions.isNotEmpty;
    if (showRowActionsColumn) {
      columns.add(PlutoColumn(title: 'Actions', field: '__actions__', type: PlutoColumnType.text(), width: rowActions.length * 100.0, minWidth: 120, enableEditingMode: false, enableFilterMenuItem: false, enableSorting: false, enableRowChecked: false, enableContextMenu: false, renderer: (rendererContext) {
        if (rendererContext.row.cells['__isSubtotal__']?.value == true) return const SizedBox.shrink();
        final Map<String, dynamic> originalRowData = (rendererContext.row.cells['__raw_data__']?.value as Map<String, dynamic>?) ?? {};
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(mainAxisSize: MainAxisSize.min, children: rowActions.map((action) {
          final String actionName = action['name']?.toString() ?? 'Action';
          final String actionType = action['type']?.toString() ?? 'unknown';
          final String actionApiUrlTemplate = action['api']?.toString() ?? '';
          final List<dynamic> actionParamsConfig = List<dynamic>.from(action['params'] ?? []);
          final String actionRecNoResolved = action['recNo_resolved']?.toString() ?? '';
          final String actionReportLabel = action['reportLabel']?.toString() ?? 'Action Report';
          final String actionApiNameResolved = action['apiName_resolved']?.toString() ?? '';
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0), child: ElevatedButton(onPressed: () {
            final Map<String, String> dynamicApiParams = {};
            for (var paramConfig in actionParamsConfig) {
              final paramName = paramConfig['parameterName']?.toString() ?? '';
              final sourceFieldName = paramConfig['parameterValue']?.toString() ?? '';
              if (paramName.isNotEmpty && sourceFieldName.isNotEmpty && originalRowData.containsKey(sourceFieldName)) {
                String valueFromRow = originalRowData[sourceFieldName]?.toString() ?? '';
                final double? numericValue = double.tryParse(valueFromRow);
                if (numericValue != null && numericValue == numericValue.truncate()) valueFromRow = numericValue.toInt().toString();
                dynamicApiParams[paramName] = valueFromRow;
              }
            }
            if (actionType == 'table') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider<TableBlocEvents.TableBlocGenerate>(create: (_) => TableBlocEvents.TableBlocGenerate(ReportAPIService())..add(TableBlocEvents.FetchApiDetails(actionApiNameResolved, const []))..add(TableBlocEvents.FetchFieldConfigs(actionRecNoResolved, actionApiNameResolved, actionReportLabel, actionApiUrlTemplate: actionApiUrlTemplate, dynamicApiParams: dynamicApiParams)), child: TableMainUI(recNo: actionRecNoResolved, apiName: actionApiNameResolved, reportLabel: actionReportLabel, userParameterValues: dynamicApiParams, actionsConfig: const [], displayParameterValues: {}, companyName: companyName, parentDisplayParameterValues: displayParameterValues))));
            } else if (actionType == 'print') {
              final templateName = action['printTemplate']?.toString() ?? PrintTemplateForMaker.premium.name;
              final selectedTemplate = PrintTemplateForMaker.values.firstWhere((e) => e.name == templateName, orElse: () => PrintTemplateForMaker.premium).toPrintTemplate();
              final colorName = action['printColor']?.toString() ?? 'Blue';
              final selectedColor = predefinedPdfColors[colorName] ?? PdfColors.blue;
              Navigator.push(context, MaterialPageRoute(builder: (_) => PrintPreviewPage(actionApiUrlTemplate: actionApiUrlTemplate, dynamicApiParams: dynamicApiParams, reportLabel: actionReportLabel, selectedTemplate: selectedTemplate, selectedColor: selectedColor)));
            }
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: const Size(60, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 2, shadowColor: Colors.blueAccent.withOpacity(0.4)), child: Text(actionName, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)));
        }).toList()));
      }));
    }
    final List<PlutoRow> finalRows = [];
    List<Map<String, dynamic>> currentReportData = List.from(state.reportData);
    if (breakpointColumnName != null) {
      currentReportData.sort((a, b) => (a[breakpointColumnName]?.toString() ?? '').compareTo(b[breakpointColumnName]?.toString() ?? ''));
      String? currentBreakpointValue;
      Map<String, double> currentGroupSubtotals = { for (var colName in subtotalColumnNames) colName: 0.0 };
      for (int i = 0; i < currentReportData.length; i++) {
        final data = currentReportData[i];
        final rowBreakpointValue = data[breakpointColumnName]?.toString() ?? '';
        if (currentBreakpointValue != null && rowBreakpointValue != currentBreakpointValue) {
          finalRows.add(_createSubtotalRow(groupName: currentBreakpointValue, subtotals: currentGroupSubtotals, sortedFieldConfigs: sortedFieldConfigs, breakpointColumnName: breakpointColumnName, hasActionsColumn: showRowActionsColumn, actionsConfigForSubtotalRow: rowActions, numericColumnMap: numericColumnMap, subtotalColumnDecimals: subtotalColumnDecimals, indianFormatColumnMap: indianFormatColumnMap));
          currentGroupSubtotals = { for (var colName in subtotalColumnNames) colName: 0.0 };
        }
        currentBreakpointValue = rowBreakpointValue;
        final rowCells = <String, PlutoCell>{};
        for (var config in sortedFieldConfigs) {
          final fieldName = config['Field_name']?.toString() ?? '';
          final rawValue = data[fieldName];
          rowCells[fieldName] = PlutoCell(value: numericColumnMap[fieldName] == true ? (double.tryParse(rawValue?.toString().trim() ?? '') ?? 0.0) : (rawValue?.toString() ?? ''));
        }
        if (showRowActionsColumn) rowCells['__actions__'] = PlutoCell(value: '');
        rowCells['__isSubtotal__'] = PlutoCell(value: false);
        rowCells['__raw_data__'] = PlutoCell(value: data);
        finalRows.add(PlutoRow(cells: rowCells));
        for (var colName in subtotalColumnNames) {
          final value = data[colName];
          if (value != null) {
            currentGroupSubtotals[colName] = (currentGroupSubtotals[colName] ?? 0.0) + (double.tryParse(value.toString()) ?? 0.0);
          }
        }
        if (i == currentReportData.length - 1) {
          finalRows.add(_createSubtotalRow(groupName: currentBreakpointValue, subtotals: currentGroupSubtotals, sortedFieldConfigs: sortedFieldConfigs, breakpointColumnName: breakpointColumnName, hasActionsColumn: showRowActionsColumn, actionsConfigForSubtotalRow: rowActions, numericColumnMap: numericColumnMap, subtotalColumnDecimals: subtotalColumnDecimals, indianFormatColumnMap: indianFormatColumnMap));
        }
      }
    } else {
      finalRows.addAll(state.reportData.map((data) {
        final rowCells = <String, PlutoCell>{};
        for (var config in sortedFieldConfigs) {
          final fieldName = config['Field_name']?.toString() ?? '';
          final rawValue = data[fieldName];
          rowCells[fieldName] = PlutoCell(value: numericColumnMap[fieldName] == true ? (double.tryParse(rawValue?.toString().trim() ?? '') ?? 0.0) : (rawValue?.toString() ?? ''));
        }
        if (showRowActionsColumn) rowCells['__actions__'] = PlutoCell(value: '');
        rowCells['__isSubtotal__'] = PlutoCell(value: false);
        rowCells['__raw_data__'] = PlutoCell(value: data);
        return PlutoRow(cells: rowCells);
      }));
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // =========== UI PLACEMENT MODIFICATION ===========
          _buildFilterChips(context),
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
            topLevelActions: topLevelGraphButtons,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomPlutoGrid(
              columns: columns,
              rows: finalRows,
              rowColorCallback: (rowContext) {
                if (rowContext.row.cells['__isSubtotal__']?.value == true) return Colors.grey[200]!;
                return rowContext.rowIdx % 2 == 0 ? Colors.white : Colors.grey[50]!;
              },
              onChanged: (PlutoGridOnChangedEvent event) {
                debugPrint('PlutoGrid onChanged: Column: ${event.column.field}, Row Index: ${event.rowIdx}, Value: ${event.value}');
              },
            ),
          ),
        ],
      ),
    );
  }
}