import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:intl/intl.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/CustomPlutogrid.dart';
import '../../ReportUtils/Export_widget.dart';
import '../../ReportUtils/subtleloader.dart';
import 'Reportbloc.dart';

class ReportMainUI extends StatelessWidget {
  final String recNo;
  final String apiName;
  final String reportLabel;

  const ReportMainUI({
    super.key,
    required this.recNo,
    required this.apiName,
    required this.reportLabel,
  });

  // Custom Indian number formatter
  String formatIndianNumber(double number, int decimalPoints) {
    String numStr = number.toStringAsFixed(decimalPoints);
    List<String> parts = numStr.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    // Handle negative numbers
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

    // For numbers > 999, apply Indian formatting
    String lastThree = integerPart.substring(integerPart.length - 3);
    String remaining = integerPart.substring(0, integerPart.length - 3);

    // Add commas every 2 digits for the remaining part
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: reportLabel,
        onBackPress: () => Navigator.pop(context),
      ),
      body: BlocListener<ReportBlocGenerate, ReportState>(
        listener: (context, state) {
          if (state.error != null) {
            print('ReportMainUI error: ${state.error}');
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
                'reportData.length=${state.reportData.length}, '
                'fieldConfigs.sample=${state.fieldConfigs.isNotEmpty ? state.fieldConfigs.first : {}}, '
                'reportData.sample=${state.reportData.isNotEmpty ? state.reportData.first : {}}, '
                'stateHash=${state.hashCode}');

            if (state.isLoading) {
              print('ReportMainUI: Showing loader');
              return const Center(child: SubtleLoader());
            }

            if (state.fieldConfigs.isEmpty && state.reportData.isEmpty) {
              print('ReportMainUI: No field configurations or report data available');
              return const Center(child: Text('No data available'));
            }
            if (state.fieldConfigs.isEmpty) {
              print('ReportMainUI: No field configurations available');
              return const Center(child: Text('No field configurations available'));
            }
            if (state.reportData.isEmpty) {
              print('ReportMainUI: No report data available');
              return const Center(child: Text('No report data available'));
            }

            final sortedFieldConfigs = List<Map<String, dynamic>>.from(state.fieldConfigs)
              ..sort((a, b) => int.parse(a['Sequence_no']?.toString() ?? '0')
                  .compareTo(int.parse(b['Sequence_no']?.toString() ?? '0')));

            final headerMap = {
              for (var config in sortedFieldConfigs)
                config['Field_label']?.toString() ?? '': config['Field_name']?.toString() ?? ''
            };

            final columns = sortedFieldConfigs.map((config) {
              final fieldName = config['Field_name']?.toString() ?? '';
              final fieldLabel = config['Field_label']?.toString() ?? '';
              final width = double.tryParse(config['width']?.toString() ?? '100') ?? 100.0;
              final total = config['Total']?.toString() == '1';
              final alignment = config['num_alignment']?.toString().toLowerCase() ?? 'left';
              final decimalPoints = int.tryParse(config['decimal_points']?.toString() ?? '0') ?? 0;
              final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'GrandTotal'].contains(fieldName);

              // Debug field configuration
              print('Field Config: name=$fieldName, total=$total, decimalPoints=$decimalPoints, isNumeric=$isNumeric');

              // Create format string for PlutoGrid footer
              String formatString = '#,##,##0';
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
                footerRenderer: total
                    ? (rendererContext) {
                  // Debug all values being summed
                  double sum = 0.0;
                  for (var row in rendererContext.stateManager.rows) {
                    final cellValue = row.cells[fieldName]?.value;
                    final parsedValue = double.tryParse(cellValue.toString()) ?? 0.0;
                    sum += parsedValue;
                    print('Summing $fieldName: cellValue=$cellValue, parsed=$parsedValue, runningSum=$sum');
                  }
                  final formattedTotal = formatIndianNumber(sum, decimalPoints);
                  print('Footer total for $fieldName: calculatedSum=$sum, formatted=$formattedTotal');
                  return PlutoAggregateColumnFooter(
                    rendererContext: rendererContext,
                    type: PlutoAggregateColumnType.sum,
                    format: formatString,
                    alignment: Alignment.center,
                    titleSpanBuilder: (text) {
                      return [
                        const TextSpan(text: 'Total: '),
                        TextSpan(
                          text: formattedTotal,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        ),
                      ];
                    },
                  );
                }
                    : null,
                renderer: (rendererContext) {
                  final value = rendererContext.cell.value?.toString() ?? '';
                  if (isNumeric && value.isNotEmpty) {
                    final number = double.tryParse(value) ?? 0.0;
                    final formattedNumber = formatIndianNumber(number, decimalPoints);
                    print('Rendering $fieldName: raw=$value, formatted=$formattedNumber');
                    return Text(
                      formattedNumber,
                      style: GoogleFonts.poppins(fontSize: 12),
                      textAlign: alignment == 'center'
                          ? TextAlign.center
                          : alignment == 'right'
                          ? TextAlign.right
                          : TextAlign.left,
                    );
                  }
                  return Text(
                    value,
                    style: GoogleFonts.poppins(fontSize: 12),
                    textAlign: alignment == 'center'
                        ? TextAlign.center
                        : alignment == 'right'
                        ? TextAlign.right
                        : TextAlign.left,
                  );
                },
              );
            }).toList();

            final rows = state.reportData.map((data) {
              final rowCells = <String, PlutoCell>{};
              for (var config in sortedFieldConfigs) {
                final fieldName = config['Field_name']?.toString() ?? '';
                final value = data[fieldName] ?? '';
                final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'GrandTotal'].contains(fieldName);
                if (isNumeric && (value == null || (value is String && value.isEmpty))) {
                  print('Invalid GrandTotal data for $fieldName: value=$value');
                }
                rowCells[fieldName] = PlutoCell(
                  value: isNumeric && value is String && value.isNotEmpty
                      ? double.tryParse(value) ?? 0.0
                      : value,
                );
                if (isNumeric) {
                  print('Row data for $fieldName: raw=$value, parsed=${double.tryParse(value.toString()) ?? 0.0}');
                }
              }
              return PlutoRow(cells: rowCells);
            }).toList();

            print('ReportMainUI: CustomPlutoGrid created with columns=${columns.length}, rows=${rows.length}');

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ExportWidget(
                    data: state.reportData,
                    fileName: reportLabel,
                    headerMap: headerMap,
                    fieldConfigs: sortedFieldConfigs,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: CustomPlutoGrid(
                      columns: columns,
                      rows: rows,
                      onChanged: (PlutoGridOnChangedEvent event) {
                        print('CustomPlutoGrid: Filter applied on column ${event.column?.title}, value: ${event.value}');
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