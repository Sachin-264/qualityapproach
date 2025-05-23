import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart';
import 'EditDetailMaker.dart';

class EditReportMakerBloc extends Cubit<EditReportMakerState> {
  final ReportAPIService apiService;

  EditReportMakerBloc(this.apiService) : super(EditReportMakerState()) {
    loadReports();
  }

  Future<void> loadReports() async {
    emit(state.copyWith(isLoading: true));
    try {
      final reports = await apiService.fetchDemoTable();
      emit(state.copyWith(
          reports: reports, filteredReports: reports, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
          error: 'Failed to load reports: $e', isLoading: false));
    }
  }

  void filterReports(String query) {
    final filtered = state.reports.where((report) {
      final reportName = report['Report_name']?.toString().toLowerCase() ?? '';
      final apiName = report['API_name']?.toString().toLowerCase() ?? '';
      return reportName.contains(query.toLowerCase()) ||
          apiName.contains(query.toLowerCase());
    }).toList();
    emit(state.copyWith(filteredReports: filtered));
  }

  Future<void> deleteReport(int recNo, BuildContext context) async {
    emit(state.copyWith(isLoading: true));
    try {
      final response = await apiService.deleteDemoTables(recNo: recNo);
      if (response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Record deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        await loadReports(); // Reload reports after successful deletion
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to delete report'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete report: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      emit(state.copyWith(isLoading: false));
    }
  }
}

class EditReportMakerState {
  final List<Map<String, dynamic>> reports;
  final List<Map<String, dynamic>> filteredReports;
  final bool isLoading;
  final String? error;

  EditReportMakerState({
    this.reports = const [],
    this.filteredReports = const [],
    this.isLoading = false,
    this.error,
  });

  EditReportMakerState copyWith({
    List<Map<String, dynamic>>? reports,
    List<Map<String, dynamic>>? filteredReports,
    bool? isLoading,
    String? error,
  }) {
    return EditReportMakerState(
      reports: reports ?? this.reports,
      filteredReports: filteredReports ?? this.filteredReports,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class EditReportMaker extends StatelessWidget {
  const EditReportMaker({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EditReportMakerBloc(ReportAPIService()),
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Edit Reports',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocListener<EditReportMakerBloc, EditReportMakerState>(
          listener: (context, state) {
            // Handle general errors outside of deletion
            if (state.error != null && !state.isLoading) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error!),
                  backgroundColor: Colors.redAccent,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: BlocBuilder<EditReportMakerBloc, EditReportMakerState>(
            builder: (context, state) {
              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Search Bar
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 8),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search Reports...',
                                hintStyle: GoogleFonts.poppins(
                                    color: Colors.grey[600], fontSize: 15),
                                prefixIcon:
                                Icon(Icons.search, color: Colors.blueAccent),
                                filled: true,
                                fillColor: Colors.grey[200],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Colors.blueAccent, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 12),
                              ),
                              onChanged: (value) => context
                                  .read<EditReportMakerBloc>()
                                  .filterReports(value),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Table View
                        Expanded(
                          child: state.isLoading && state.reports.isEmpty
                              ? const Center(child: SubtleLoader())
                              : state.filteredReports.isEmpty
                              ? Center(
                            child: Text(
                              'No reports found',
                              style: GoogleFonts.poppins(
                                  fontSize: 16, color: Colors.grey),
                            ),
                          )
                              : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(12)),
                                child: DataTable(
                                  columnSpacing: 20,
                                  headingRowColor:
                                  MaterialStateProperty.all(
                                      Colors.blueAccent
                                          .withOpacity(0.1)),
                                  dataRowColor:
                                  MaterialStateProperty.all(
                                      Colors.white),
                                  columns: [
                                    DataColumn(
                                      label: Text(
                                        'Report Name',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'API Name',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Actions',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: state.filteredReports
                                      .map((report) {
                                    final recNo = int.tryParse(
                                        report['RecNo']
                                            ?.toString() ??
                                            '') ??
                                        0;
                                    final reportName = report[
                                    'Report_name']
                                        ?.toString() ??
                                        '';
                                    final reportLabel = report[
                                    'Report_label']
                                        ?.toString() ??
                                        '';
                                    final apiName = report['API_name']
                                        ?.toString() ??
                                        '';
                                    return DataRow(cells: [
                                      DataCell(
                                        Text(
                                          reportName,
                                          style: GoogleFonts.poppins(
                                              fontSize: 14),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          apiName,
                                          style: GoogleFonts.poppins(
                                              fontSize: 14),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize:
                                          MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.edit,
                                                  color: Colors
                                                      .blueAccent),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        EditDetailMaker(
                                                          recNo: recNo,
                                                          reportName:
                                                          reportName,
                                                          reportLabel:
                                                          reportLabel,
                                                          apiName:
                                                          apiName,
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete,
                                                  color:
                                                  Colors.redAccent),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (dialogContext) =>
                                                      AlertDialog(
                                                        backgroundColor:
                                                        Colors.white,
                                                        title: Text(
                                                          'Confirm Delete',
                                                          style: GoogleFonts
                                                              .poppins(
                                                              fontWeight:
                                                              FontWeight.w600),
                                                        ),
                                                        content: Text(
                                                          'Are you sure you want to delete "$reportName"?',
                                                          style:
                                                          GoogleFonts
                                                              .poppins(),
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    dialogContext),
                                                            child: Text(
                                                              'Cancel',
                                                              style: GoogleFonts.poppins(
                                                                  color: Colors
                                                                      .grey),
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () {
                                                              context
                                                                  .read<
                                                                  EditReportMakerBloc>()
                                                                  .deleteReport(
                                                                  recNo,
                                                                  context);
                                                              Navigator.pop(
                                                                  dialogContext);
                                                            },
                                                            child: Text(
                                                              'Delete',
                                                              style: GoogleFonts.poppins(
                                                                  color: Colors
                                                                      .redAccent),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Full-screen loader when isLoading is true
                  if (state.isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: SubtleLoader(),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}