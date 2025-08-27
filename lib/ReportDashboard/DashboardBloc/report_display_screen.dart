// lib/Dashboard/DashboardBloc/report_display_screen.dart

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../ReportDynamic/ReportGenerator/ReportMainUI.dart';
import '../../ReportDynamic/ReportGenerator/Reportbloc.dart';

class ReportDisplayScreen extends StatefulWidget {
  final ReportBlocGenerate bloc;
  final Map<String, dynamic> reportDefinition;

  const ReportDisplayScreen({
    super.key,
    required this.bloc,
    required this.reportDefinition,
  });

  @override
  State<ReportDisplayScreen> createState() => _ReportDisplayScreenState();
}

class _ReportDisplayScreenState extends State<ReportDisplayScreen> {
  @override
  void dispose() {
    // This is the ONLY place the BLoC should be closed.
    widget.bloc.close();
    super.dispose();
  }

  // Helper methods to calculate derived values from the state.
  Map<String, String> _calculateDisplayValues(ReportState state) {
    debugPrint('--- [ReportDisplayScreen] Calculating Display Parameter Values ---');
    String? companyNameParamLabelToExclude;
    final companyParam = state.selectedApiParameters.firstWhereOrNull((p) => p['is_company_name_field'] == true);
    if (companyParam != null) {
      final paramName = companyParam['name'].toString();
      companyNameParamLabelToExclude = companyParam['field_label']?.isNotEmpty == true ? companyParam['field_label'] : paramName;
    }
    debugPrint('Excluding company label for export: $companyNameParamLabelToExclude');

    final Map<String, String> displayValuesForExport = {};
    for (var param in state.selectedApiParameters) {
      final paramName = param['name'].toString();
      final paramLabel = param['field_label']?.isNotEmpty == true ? param['field_label'] : paramName;

      if (param['is_company_name_field'] == true && paramLabel == companyNameParamLabelToExclude) {
        debugPrint('  - Skipping param "$paramName" as it is the company field.');
        continue;
      }

      if (param['show'] == true) {
        final String currentApiValue = state.userParameterValues[paramName] ?? '';
        String displayValue = '';
        final String configType = param['config_type']?.toString().toLowerCase() ?? '';
        debugPrint('  - Processing param "$paramName" (Label: "$paramLabel") with value "$currentApiValue" and type "$configType"');

        if ((configType == 'radio' || configType == 'checkbox') && currentApiValue.isNotEmpty) {
          debugPrint('    -> Using radio/checkbox logic.');
          final List<Map<String, String>> options = List<Map<String, String>>.from(param['options']?.map((e) => Map<String, String>.from(e ?? {})) ?? []);
          displayValue = options.firstWhere((opt) => opt['value'] == currentApiValue, orElse: () => {'label': currentApiValue})['label']!;
        } else if (configType == 'database' && currentApiValue.isNotEmpty && state.pickerOptions.containsKey(paramName)) {
          debugPrint('    -> Using database picker logic.');
          final List<Map<String, String>> pickerOptions = state.pickerOptions[paramName] ?? [];
          debugPrint('    -> Options found for "$paramName": ${pickerOptions.length} items.');
          displayValue = pickerOptions.firstWhere((opt) => opt['value'] == currentApiValue, orElse: () => {'label': currentApiValue})['label']!;
        } else {
          debugPrint('    -> Using direct value logic.');
          displayValue = currentApiValue;
        }

        if (displayValue.isNotEmpty) {
          displayValuesForExport[paramLabel] = displayValue;
        }
        debugPrint('    -> Resolved display value: "$displayValue"');
      } else {
        debugPrint('  - Skipping param "$paramName" because show is not true.');
      }
    }
    debugPrint('Final Display Export Values: $displayValuesForExport');
    return displayValuesForExport;
  }

  String _calculateCompanyName(ReportState state) {
    debugPrint('--- [ReportDisplayScreen] Calculating Company Name ---');
    String companyName = '';

    // Find the parameter marked as the company name field
    final companyParam = state.selectedApiParameters.firstWhereOrNull((p) => p['is_company_name_field'] == true);

    if (companyParam != null) {
      final paramName = companyParam['name'].toString();
      debugPrint('Found company parameter config: {name: $paramName, show: ${companyParam['show']}, config_type: ${companyParam['config_type']}}');

      final String companyCodeValue = state.userParameterValues[paramName] ?? '';
      debugPrint('Raw company code from userParameterValues: "$companyCodeValue"');

      if (companyParam['show'] == true) {
        final String configType = companyParam['config_type']?.toString().toLowerCase() ?? '';
        if (configType == 'database' && state.pickerOptions.containsKey(paramName)) {
          debugPrint('Company field is a visible database picker. Looking up display name.');
          final List<Map<String, String>> pickerOptions = state.pickerOptions[paramName] ?? [];
          debugPrint('Picker options for "$paramName": ${pickerOptions.isNotEmpty ? pickerOptions.take(5).toList().toString() + '...' : '[]'}');

          final foundOption = pickerOptions.firstWhereOrNull((opt) => opt['value'] == companyCodeValue);

          if (foundOption != null) {
            companyName = foundOption['label']!;
            debugPrint('SUCCESS: Found matching label: "$companyName"');
          } else {
            companyName = companyCodeValue; // Fallback
            debugPrint('WARNING: Could not find a matching label for value "$companyCodeValue". Using raw value as fallback.');
          }
        } else {
          companyName = companyCodeValue;
          debugPrint('Company field is visible but not a database picker. Using raw value: "$companyName"');
        }
      } else if (companyParam['show'] == false && companyParam['display_value_cache']?.toString().isNotEmpty == true) {
        companyName = companyParam['display_value_cache'].toString();
        debugPrint('Company field is hidden. Using display_value_cache: "$companyName"');
      } else {
        debugPrint('Company field did not match any logic. Result is empty.');
      }
    } else {
      debugPrint('No parameter found with "is_company_name_field: true"');
    }

    debugPrint('Final Calculated Company Name: "$companyName"');
    return companyName;
  }

  @override
  Widget build(BuildContext context) {
    // We use BlocProvider.value to provide the BLoC that was passed in.
    return BlocProvider.value(
      value: widget.bloc,
      child: BlocBuilder<ReportBlocGenerate, ReportState>(
        builder: (context, state) {
          debugPrint('\n\n======================================================');
          debugPrint('=== [ReportDisplayScreen] BUILD METHOD TRIGGERED ===');
          debugPrint('======================================================');

          final companyName = _calculateCompanyName(state);
          final displayParameterValues = _calculateDisplayValues(state);

          debugPrint('\n--- [ReportDisplayScreen] FINAL VALUES TO BE PASSED TO ReportMainUI ---');
          debugPrint('companyName: "$companyName"');
          debugPrint('displayParameterValues: $displayParameterValues');
          debugPrint('---------------------------------------------------------------------');


          return ReportMainUI(
            recNo: state.selectedRecNo!,
            apiName: state.selectedApiName!,
            reportLabel: state.selectedReportLabel!,
            userParameterValues: state.userParameterValues,
            actionsConfig: state.actionsConfig,
            companyName: companyName, // Passing the calculated name
            displayParameterValues: displayParameterValues, // Passing the calculated display values
            includePdfFooterDateTime: state.includePdfFooterDateTime,
            reportDefinition: widget.reportDefinition,
          );
        },
      ),
    );
  }
}