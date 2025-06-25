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
    String? companyNameParamLabelToExclude;
    final companyParam = state.selectedApiParameters.firstWhereOrNull((p) => p['is_company_name_field'] == true);
    if (companyParam != null) {
      final paramName = companyParam['name'].toString();
      companyNameParamLabelToExclude = companyParam['field_label']?.isNotEmpty == true ? companyParam['field_label'] : paramName;
    }
    final Map<String, String> displayValuesForExport = {};
    for (var param in state.selectedApiParameters) {
      final paramName = param['name'].toString();
      final paramLabel = param['field_label']?.isNotEmpty == true ? param['field_label'] : paramName;
      if (param['is_company_name_field'] == true && paramLabel == companyNameParamLabelToExclude) continue;
      if (param['show'] == true) {
        final String currentApiValue = state.userParameterValues[paramName] ?? '';
        String displayValue = '';
        final String configType = param['config_type']?.toString().toLowerCase() ?? '';
        if ((configType == 'radio' || configType == 'checkbox') && currentApiValue.isNotEmpty) {
          final List<Map<String, String>> options = List<Map<String, String>>.from(param['options']?.map((e) => Map<String, String>.from(e ?? {})) ?? []);
          displayValue = options.firstWhere((opt) => opt['value'] == currentApiValue, orElse: () => {'label': currentApiValue})['label']!;
        } else if (configType == 'database' && currentApiValue.isNotEmpty && state.pickerOptions.containsKey(paramName)) {
          final List<Map<String, String>> pickerOptions = state.pickerOptions[paramName] ?? [];
          displayValue = pickerOptions.firstWhere((opt) => opt['value'] == currentApiValue, orElse: () => {'label': currentApiValue})['label']!;
        } else {
          displayValue = currentApiValue;
        }
        if (displayValue.isNotEmpty) displayValuesForExport[paramLabel] = displayValue;
      }
    }
    return displayValuesForExport;
  }

  String _calculateCompanyName(ReportState state) {
    String companyName = '';
    final companyParam = state.selectedApiParameters.firstWhereOrNull((p) => p['is_company_name_field'] == true);
    if (companyParam != null) {
      final paramName = companyParam['name'].toString();
      if (companyParam['show'] == true) {
        final String configType = companyParam['config_type']?.toString().toLowerCase() ?? '';
        if (configType == 'database' && state.pickerOptions.containsKey(paramName)) {
          final List<Map<String, String>> pickerOptions = state.pickerOptions[paramName] ?? [];
          companyName = pickerOptions.firstWhere((opt) => opt['value'] == state.userParameterValues[paramName], orElse: () => {'label': state.userParameterValues[paramName] ?? ''})['label']!;
        } else {
          companyName = state.userParameterValues[paramName] ?? '';
        }
      } else if (companyParam['show'] == false && companyParam['display_value_cache']?.toString().isNotEmpty == true) {
        companyName = companyParam['display_value_cache'].toString();
      }
    }
    return companyName;
  }

  @override
  Widget build(BuildContext context) {
    // We use BlocProvider.value to provide the BLoC that was passed in.
    return BlocProvider.value(
      value: widget.bloc,
      child: BlocBuilder<ReportBlocGenerate, ReportState>(
        builder: (context, state) {
          final companyName = _calculateCompanyName(state);
          final displayParameterValues = _calculateDisplayValues(state);

          return ReportMainUI(
            recNo: state.selectedRecNo!,
            apiName: state.selectedApiName!,
            reportLabel: state.selectedReportLabel!,
            userParameterValues: state.userParameterValues,
            actionsConfig: state.actionsConfig,
            companyName: companyName,
            displayParameterValues: displayParameterValues,
            includePdfFooterDateTime: state.includePdfFooterDateTime,
            reportDefinition: widget.reportDefinition,
          );
        },
      ),
    );
  }
}