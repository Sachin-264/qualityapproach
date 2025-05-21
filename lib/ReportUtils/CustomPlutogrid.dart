import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';

class CustomPlutoGrid extends StatelessWidget {
  final List<PlutoColumn> columns;
  final List<PlutoRow> rows;
  final void Function(PlutoGridOnChangedEvent)? onChanged;

  const CustomPlutoGrid({
    super.key,
    required this.columns,
    required this.rows,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: PlutoGrid(
        columns: columns,
        rows: rows,
        configuration: PlutoGridConfiguration(
          style: PlutoGridStyleConfig(
            gridBackgroundColor: Colors.white,
            cellTextStyle: GoogleFonts.poppins(fontSize: 12),
            columnTextStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey[800],
            ),
            gridBorderColor: Colors.grey[400]!,
            borderColor: Colors.grey[400]!,
            activatedBorderColor: Colors.blueGrey[300]!,
            inactivatedBorderColor: Colors.grey[400]!,
          ),
          columnSize: const PlutoGridColumnSizeConfig(
            autoSizeMode: PlutoAutoSizeMode.none,
          ),
          columnFilter: const PlutoGridColumnFilterConfig(
            filters: [PlutoFilterTypeContains()],
          ),
        ),
        rowColorCallback: (PlutoRowColorContext context) {
          return context.rowIdx % 2 == 0 ? Colors.white : Colors.grey[50]!;
        },
        onChanged: onChanged,
        onLoaded: (PlutoGridOnLoadedEvent event) {
          event.stateManager.setShowColumnFilter(true);
        },
      ),
    );
  }
}