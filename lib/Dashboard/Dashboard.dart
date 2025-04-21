import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ReportUtils/Appbar.dart';
import '../ReportUtils/subtleloader.dart';
import 'Dashboard.bloc.dart';
import 'Detaildashpage.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Define the query parameters for each of the 9 boxes
    final List<Map<String, String>> queryParams = [
      // Query 1: Box 1
      {'Opt1': 'N', 'Opt2': 'Y', 'ActionTaken': ''},
      // Query 2: Box 2
      {'Opt1': 'Y', 'Opt2': 'N', 'ActionTaken': 'Approve'},
      // Query 3: Box 3
      {'ActionTaken': 'Hold'},
      // Query 4: Box 4
      {'ActionTaken': 'Discuss'},
      // Query 5: Box 5
      {'Level1': 'N', 'Opt1': 'N', 'Opt2': 'Y', 'ActionTaken': ''},
      // Query 6: Box 6
      {'Opt1': 'Y', 'Opt2': 'N', 'ActionTaken': 'Approve'},
      // Query 7: Box 7
      {'ActionTaken': 'Hold'},
      // Query 8: Box 8
      {'ActionTaken': 'Discuss'},
      // Query 9: Box 9
      {'ActionTaken': 'Cancel'},
    ];

    return Scaffold(
      appBar: AppBarWidget(
        title: 'Dashboard',
        onBackPress: () => Navigator.pop(context),
      ),
      body: BlocProvider(
        create: (context) => DashboardBloc()..add(FetchDashboardData()),
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            if (state is DashboardLoading) {
              return const Center(child: SubtleLoader());
            } else if (state is DashboardError) {
              return Center(
                child: Text(
                  state.message,
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
              );
            } else if (state is DashboardLoaded) {
              // Extract data and fields from state
              final dataItem = state.data.isNotEmpty ? state.data[0] : {};
              final fields = state.fields;

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5, // 5 boxes per row
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                    ),
                    itemCount: fields.length, // 10 fields from API
                    itemBuilder: (context, index) {
                      final field = fields[index];
                      final displayField = field.replaceAll('VQ_', '').replaceAll('_', ' ');
                      final value = dataItem[field]?.toString() == '0' ? '' : dataItem[field]?.toString() ?? '';

                      // Prepare boxData for navigation
                      Map<String, String> boxData = {displayField: value};

                      // Add query parameters for boxes 1–9 (indices 0–8)
                      if (index < 9) {
                        boxData.addAll(queryParams[index]);
                      }
                      // Box 10 (index 9) only includes displayField and value, no query params

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailDashPage(
                                boxData: boxData,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Container(
                            width: 70, // Hardcoded width
                            height: 100, // Hardcoded height
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[600]!, Colors.blue[400]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    displayField,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    value,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}