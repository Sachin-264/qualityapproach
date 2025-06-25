// lib/Dashboard/DashboardBloc/preselectedreportloader.dart

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../ReportDynamic/ReportAPIService.dart';
import '../../ReportDynamic/ReportGenerator/Reportbloc.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import 'report_display_screen.dart';

class PreSelectedReportLoader extends StatefulWidget {
  final Map<String, dynamic> reportDefinition;
  final Map<String, String> initialParameters;
  final ReportAPIService apiService;

  const PreSelectedReportLoader({
    super.key,
    required this.reportDefinition,
    required this.apiService,
    this.initialParameters = const {},
  });

  @override
  State<PreSelectedReportLoader> createState() => _PreSelectedReportLoaderState();
}

class _PreSelectedReportLoaderState extends State<PreSelectedReportLoader> {
  // BLoC is created here. It will be passed to the next screen and NOT closed here.
  // Its lifecycle will be managed by the ReportDisplayScreen.
  late final ReportBlocGenerate _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = ReportBlocGenerate(widget.apiService)
      ..add(StartPreselectedReportChain(widget.reportDefinition, widget.initialParameters));
  }

  // NOTE: We do NOT dispose the BLoC here anymore. It's passed on.

  @override
  Widget build(BuildContext context) {
    final String reportLabel = widget.reportDefinition['Report_label']?.toString() ?? 'Loading Report...';

    return BlocListener<ReportBlocGenerate, ReportState>(
      bloc: _bloc,
      listenWhen: (previous, current) {
        final wasLoading = previous.isLoading;
        final isReady = !current.isLoading && current.error == null && (current.fieldConfigs.isNotEmpty || current.reportData.isNotEmpty);
        return wasLoading && isReady;
      },
      listener: (context, state) {
        // Once data is loaded, REPLACE this screen with the permanent display screen.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ReportDisplayScreen(
              // Pass the LIVING bloc instance.
              bloc: _bloc,
              reportDefinition: widget.reportDefinition,
            ),
          ),
        );
      },
      child: Scaffold(
        appBar: AppBarWidget(
          title: reportLabel,
          onBackPress: () => Navigator.of(context).pop(),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BlocBuilder<ReportBlocGenerate, ReportState>(
            bloc: _bloc,
            builder: (context, state) {
              if (state.error != null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
                      const SizedBox(height: 16),
                      Text('Failed to Load Report', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(state.error!, style: GoogleFonts.poppins(color: Colors.grey[700]), textAlign: TextAlign.center),
                    ],
                  ),
                );
              }
              return SubtleLoader(loadingText: 'Preparing "$reportLabel"...');
            },
          ),
        ),
      ),
    );
  }
}