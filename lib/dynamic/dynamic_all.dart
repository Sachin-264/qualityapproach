import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ReportUtils/Appbar.dart';
import '../ReportUtils/subtleloader.dart';
import 'dynamic_all_bloc.dart';
import 'dynamic_detail.dart';

class DynamicAll extends StatelessWidget {
  const DynamicAll({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DynamicAllBloc()..add(FetchForms()),
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Dynamic Forms',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocBuilder<DynamicAllBloc, DynamicAllState>(
          builder: (context, state) {
            if (state is DynamicAllLoading) {
              return const Center(child: SubtleLoader());
            } else if (state is DynamicAllLoaded) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Table(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(3),
                    3: FlexColumnWidth(1),
                    4: FlexColumnWidth(1),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.blue.shade100),
                      children: [
                        _buildTableCell('SNo', isHeader: true),
                        _buildTableCell('Form Name', isHeader: true),
                        _buildTableCell('Form Label', isHeader: true),
                        _buildTableCell('Edit', isHeader: true),
                        _buildTableCell('Select', isHeader: true),
                      ],
                    ),
                    ...state.forms.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final form = entry.value;
                      return TableRow(
                        children: [
                          _buildTableCell('$index'),
                          _buildTableCell(form['FORM NAME'] ?? ''),
                          _buildTableCell(form['FORM LABEL'] ?? ''),
                          _buildTableCell(
                            '',
                            widget: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DynamicDetail(
                                      recNo: form['RECNO'] ?? '',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          _buildTableCell(
                            '',
                            widget: IconButton(
                              icon: const Icon(Icons.arrow_forward, color: Colors.green),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DynamicDetail(
                                      recNo: form['RECNO'] ?? '',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              );
            } else if (state is DynamicAllError) {
              return Center(
                child: Text(
                  state.message,
                  style: GoogleFonts.roboto(color: Colors.red),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, Widget? widget}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: widget ??
          Text(
            text,
            style: GoogleFonts.roboto(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              fontSize: isHeader ? 16 : 14,
            ),
            textAlign: TextAlign.center,
          ),
    );
  }
}