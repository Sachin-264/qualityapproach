import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qualityapproach/SparePart/spare_bloc.dart';
import 'package:logging/logging.dart';

import '../ReportUtils/Appbar.dart';
import '../ReportUtils/ExportsButton.dart';
import '../ReportUtils/subtleloader.dart';
import 'SpareDetail_UI.dart';

// Initialize logger
final Logger _logger = Logger('SparePartScreen');

class SparePartScreen extends StatelessWidget {
  const SparePartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Configure logging
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    });

    return BlocProvider(
      create: (context) => SparePartBloc()..add(FetchSpareParts()),
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Spare Parts',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocBuilder<SparePartBloc, SparePartState>(
          builder: (context, state) {
            if (state is SparePartLoading) return const SubtleLoader();
            if (state is SparePartError) {
              _logger.severe('Error loading spare parts: ${state.message}');
              return Center(
                child: Text(
                  state.message,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
              );
            }
            if (state is SparePartLoaded) {
              _logger.info('Spare parts loaded successfully. Sample: ${state.spareParts[0]}');
              return Column(
                children: [
                  ExportButtons(
                    data: state.spareParts.map((part) {
                      final complaintNoRaw = part['ComplaintNo'];
                      final complaintNoFormatted = _formatComplaintNo(complaintNoRaw);
                      _logger.fine(
                          'Export - ComplaintNo raw: $complaintNoRaw (type: ${complaintNoRaw.runtimeType}), formatted: $complaintNoFormatted');
                      return {
                        'S.No': part['SNo'] ?? '',
                        'Complaint No': complaintNoFormatted,
                        'Entry Date': part['EntryDate'] ?? '',
                        'Customer Name': part['AccountName'] ?? '',
                        'Mobile No': part['CustomerMobileNo'] ?? '',
                        'Technician Name': part['LastRepName'] ?? '',
                        'Last Visited On': part['LastVisitDate'] ?? '',
                      };
                    }).toList(),
                    fileName: 'Spare_Parts_Report',
                    headerMap: {
                      'S.No': 'S.No',
                      'Complaint No': 'Complaint No',
                      'Entry Date': 'Entry Date',
                      'Customer Name': 'Customer Name',
                      'Mobile No': 'Mobile No',
                      'Technician Name': 'Technician Name',
                      'Last Visited On': 'Last Visited On',
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _buildGrid(context, state.spareParts),
                  ),
                ],
              );
            }
            return Container();
          },
        ),
      ),
    );
  }

  String _formatComplaintNo(dynamic value) {
    if (value == null) return '';
    if (value is num) return value.toInt().toString();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed != null ? parsed.toInt().toString() : value;
    }
    return value.toString();
  }

  Widget _buildGrid(BuildContext context, List<Map<String, dynamic>> spareParts) {
    final columns = <PlutoColumn>[
      PlutoColumn(
        title: 'S.No',
        field: 'SNo',
        type: PlutoColumnType.text(),
        width: 80,
        titleTextAlign: PlutoColumnTextAlign.center,
      ),
      PlutoColumn(
        title: 'Complaint No',
        field: 'ComplaintNo',
        type: PlutoColumnType.text(),
        renderer: (rendererContext) {
          final complaintNo = rendererContext.row.cells['ComplaintNo']?.value;
          final formattedComplaintNo = _formatComplaintNo(complaintNo);
          _logger.fine(
              'Renderer - ComplaintNo raw: $complaintNo (type: ${complaintNo.runtimeType}), formatted: $formattedComplaintNo');
          return Text(
            formattedComplaintNo,
            style: GoogleFonts.poppins(fontSize: 13),
          );
        },
      ),
      PlutoColumn(
        title: 'Entry Date',
        field: 'EntryDate',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Customer Name',
        field: 'AccountName',
        type: PlutoColumnType.text(),
        width: 200,
      ),
      PlutoColumn(
        title: 'Mobile No',
        field: 'CustomerMobileNo',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Technician',
        field: 'LastRepName',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Last Visited',
        field: 'LastVisitDate',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Action',
        field: 'action',
        type: PlutoColumnType.text(),
        width: 120,
        renderer: (rendererContext) {
          final part = spareParts[rendererContext.rowIdx];
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                _logger.info('Selected spare part: ${part['SNo']}');
                context.read<SparePartBloc>().add(SelectSparePart(part));
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SparePartDetailScreen(selectedPart: part),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Select',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ];

    return PlutoGrid(
      columns: columns,
      rows: spareParts.map((part) {
        final complaintNoRaw = part['ComplaintNo'];
        final complaintNoFormatted = _formatComplaintNo(complaintNoRaw);
        _logger.fine(
            'Row - ComplaintNo raw: $complaintNoRaw (type: ${complaintNoRaw.runtimeType}), formatted: $complaintNoFormatted');
        return PlutoRow(
          cells: {
            'SNo': PlutoCell(value: part['SNo'] ?? ''),
            'ComplaintNo': PlutoCell(value: complaintNoFormatted),
            'EntryDate': PlutoCell(value: part['EntryDate'] ?? ''),
            'AccountName': PlutoCell(value: part['AccountName'] ?? ''),
            'CustomerMobileNo': PlutoCell(value: part['CustomerMobileNo'] ?? ''),
            'LastRepName': PlutoCell(value: part['LastRepName'] ?? ''),
            'LastVisitDate': PlutoCell(value: part['LastVisitDate'] ?? ''),
            'action': PlutoCell(value: 'Select'),
          },
        );
      }).toList(),
      configuration: PlutoGridConfiguration(
        style: PlutoGridStyleConfig(
          activatedColor: Colors.blue[100]!,
          activatedBorderColor: Colors.blue,
          gridBorderColor: Colors.grey[300]!,
          cellTextStyle: GoogleFonts.poppins(fontSize: 13),
          columnTextStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        columnSize: PlutoGridColumnSizeConfig(
          autoSizeMode: PlutoAutoSizeMode.scale,
        ),
      ),
    );
  }
}