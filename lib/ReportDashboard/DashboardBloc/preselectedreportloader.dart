import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert'; // Add this if not present

import '../../ReportDynamic/ReportAPIService.dart';
import '../../ReportDynamic/ReportGenerator/ReportMainUI.dart';
import '../../ReportDynamic/ReportGenerator/Reportbloc.dart';
import '../../ReportUtils/Appbar.dart'; // Import your AppBarWidget
import '../../ReportUtils/subtleloader.dart';

// This is the main widget that will be pushed onto the navigation stack.
class PreSelectedReportLoader extends StatelessWidget {
  final Map<String, dynamic> reportDefinition;
  final Map<String, String> initialParameters;
  final ReportAPIService apiService;

  const PreSelectedReportLoader({
    super.key,
    required this.reportDefinition,
    required this.apiService,
    this.initialParameters = const {},
  });

  // Helper method to calculate display values.
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
  // Helper method to calculate company name.
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
    return BlocProvider<ReportBlocGenerate>(
      create: (context) => ReportBlocGenerate(apiService)
        ..add(StartPreselectedReportChain(reportDefinition, initialParameters)),
      child: BlocBuilder<ReportBlocGenerate, ReportState>(
        builder: (context, state) {
          // Determine if the report is ready to be displayed.
          final bool isReady = !state.isLoading &&
              state.error == null &&
              (state.fieldConfigs.isNotEmpty || state.reportData.isNotEmpty);

          // Get the report label from the initial definition to show in the AppBar.
          final String reportLabel = reportDefinition['Report_label']?.toString() ?? 'Loading Report...';

          if (isReady) {
            // If ready, calculate the derived values and show the main UI.
            final String companyName = _calculateCompanyName(state);
            final Map<String, String> displayParameterValues = _calculateDisplayValues(state);

            // ReportMainUI already has its own Scaffold and AppBar, so we just return it directly.
            return ReportMainUI(
              recNo: state.selectedRecNo!,
              apiName: state.selectedApiName!,
              reportLabel: state.selectedReportLabel!,
              userParameterValues: state.userParameterValues,
              actionsConfig: state.actionsConfig,
              companyName: companyName,
              displayParameterValues: displayParameterValues,
              includePdfFooterDateTime: state.includePdfFooterDateTime,
            );
          }
          // --- NEW IMPROVED LOADING AND ERROR STATES ---
          else {
            // While loading or if there's an error, we show a consistent Scaffold.
            return Scaffold(
              appBar: AppBarWidget(
                title: reportLabel,
                onBackPress: () => Navigator.of(context).pop(),
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: state.error != null
                // If there's an error, show a helpful error message.
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to Load Report',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.error!,
                        style: GoogleFonts.poppins(color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                // Otherwise, show the new, improved loader with context.
                    : SubtleLoader(
                  loadingText: 'Preparing "$reportLabel"...',
                ),
              ),
            );
          }
        },
      ),
    );
  }
}