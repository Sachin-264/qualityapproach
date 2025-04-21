import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../ReportUtils/Appbar.dart';
import 'comparisonbloc.dart';

class ComparisonPage extends StatefulWidget {
  final String bidRecNo;
  final String indentRecNo;

  const ComparisonPage({
    super.key,
    required this.bidRecNo,
    required this.indentRecNo,
  });

  @override
  ComparisonPageState createState() => ComparisonPageState();
}

class ComparisonPageState extends State<ComparisonPage> {
  String? selectedItemNo;
  final ScrollController _scrollController = ScrollController();
  PlutoGridStateManager? _gridStateManager;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ComparisonBloc()
        ..add(FetchComparisonData(widget.bidRecNo, widget.indentRecNo)),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBarWidget(
          title: 'Vendor Comparison',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocBuilder<ComparisonBloc, ComparisonState>(
          builder: (context, state) {
            if (state is ComparisonLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.blue,
                ),
              );
            } else if (state is ComparisonLoaded) {
              // Set default selectedItemNo to the first item's ItemNo
              if (selectedItemNo == null && state.itemDetails.isNotEmpty) {
                selectedItemNo = state.itemDetails[0].itemNo;
              }

              // Limit to two vendors for comparison
              final vendors = state.vendors.length > 2 ? state.vendors.sublist(0, 2) : state.vendors;

              // Define distinct colors for vendors
              final vendorColors = [
                Colors.green[100]!, // Vendor 1
                Colors.orange[100]!, // Vendor 2
              ];

              // Create columns for the unified PlutoGrid
              final columns = [
                // Item Details Columns (Fixed Parameters)
                PlutoColumn(
                  title: 'SNo',
                  field: 'sno',
                  type: PlutoColumnType.text(),
                  width: 80,
                  textAlign: PlutoColumnTextAlign.center,
                  titleTextAlign: PlutoColumnTextAlign.center,
                  backgroundColor: Colors.blue[100],
                  titleSpan: WidgetSpan(
                    child: Text(
                      'SNo',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ),
                PlutoColumn(
                  title: 'Indent No',
                  field: 'indentNo',
                  type: PlutoColumnType.text(),
                  width: 120,
                  textAlign: PlutoColumnTextAlign.center,
                  titleTextAlign: PlutoColumnTextAlign.center,
                  backgroundColor: Colors.blue[100],
                  titleSpan: WidgetSpan(
                    child: Text(
                      'Indent No',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                  renderer: (rendererContext) {
                    final value = rendererContext.cell.value;
                    return Text(
                      value.toString().split('.')[0], // Remove decimal point
                      style: GoogleFonts.poppins(fontSize: 14),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
                PlutoColumn(
                  title: 'Item Name',
                  field: 'itemName',
                  type: PlutoColumnType.text(),
                  width: 200,
                  textAlign: PlutoColumnTextAlign.left,
                  titleTextAlign: PlutoColumnTextAlign.center,
                  backgroundColor: Colors.blue[100],
                  titleSpan: WidgetSpan(
                    child: Text(
                      'Item Name',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ),
                PlutoColumn(
                  title: 'Required Qty',
                  field: 'requiredQtyUnit',
                  type: PlutoColumnType.text(),
                  width: 150,
                  textAlign: PlutoColumnTextAlign.center,
                  titleTextAlign: PlutoColumnTextAlign.center,
                  backgroundColor: Colors.blue[100],
                  titleSpan: WidgetSpan(
                    child: Text(
                      'Required Qty',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ),
                PlutoColumn(
                  title: 'Last/Prev',
                  field: 'lastPrev',
                  type: PlutoColumnType.text(),
                  width: 300,
                  textAlign: PlutoColumnTextAlign.center,
                  titleTextAlign: PlutoColumnTextAlign.center,
                  backgroundColor: Colors.blue[100],
                  titleSpan: WidgetSpan(
                    child: Text(
                      'Last/Prev',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ),
              ];

              // Add vendor columns (Net Rate, L-1 Action, L-2 Action for each vendor)
              vendors.asMap().forEach((index, vendor) {
                final vendorColor = vendorColors[index];
                final headerTextColor = index == 0 ? Colors.green[900] : Colors.orange[900];
                columns.addAll([
                  PlutoColumn(
                    title: 'Net Rate',
                    field: 'netRate_$index',
                    type: PlutoColumnType.text(),
                    width: 200,
                    textAlign: PlutoColumnTextAlign.right,
                    titleTextAlign: PlutoColumnTextAlign.center,
                    backgroundColor: vendorColor,
                    titleSpan: WidgetSpan(
                      child: Column(
                        children: [
                          Text(
                            vendor.accountName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: headerTextColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'Net Rate',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    renderer: (rendererContext) {
                      final value = rendererContext.cell.value;
                      return Text(
                        value != 'N/A' ? double.parse(value).toStringAsFixed(2) : 'N/A',
                        style: GoogleFonts.poppins(fontSize: 14),
                        textAlign: TextAlign.right,
                      );
                    },
                  ),
                  PlutoColumn(
                    title: 'L-1 Action',
                    field: 'actionL1_$index',
                    type: PlutoColumnType.text(),
                    width: 200,
                    textAlign: PlutoColumnTextAlign.center,
                    titleTextAlign: PlutoColumnTextAlign.center,
                    backgroundColor: vendorColor,
                    titleSpan: WidgetSpan(
                      child: Column(
                        children: [
                          Text(
                            vendor.accountName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: headerTextColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'L-1 Action',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    renderer: (rendererContext) {
                      final value = rendererContext.cell.value;
                      return Text(
                        value,
                        style: GoogleFonts.poppins(fontSize: 14),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  PlutoColumn(
                    title: 'L-2 Action',
                    field: 'actionL2_$index',
                    type: PlutoColumnType.text(),
                    width: 200,
                    textAlign: PlutoColumnTextAlign.center,
                    titleTextAlign: PlutoColumnTextAlign.center,
                    backgroundColor: vendorColor,
                    titleSpan: WidgetSpan(
                      child: Column(
                        children: [
                          Text(
                            vendor.accountName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: headerTextColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'L-2 Action',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    renderer: (rendererContext) {
                      final value = rendererContext.cell.value;
                      return Text(
                        value,
                        style: GoogleFonts.poppins(fontSize: 14),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ]);
              });

              // Create rows for the unified PlutoGrid
              final rows = state.itemDetails.map((item) {
                final vendorQuotes = state.vendorQuotes
                    .where((quote) => quote.itemNo == item.itemNo)
                    .toList();
                final cells = <String, PlutoCell>{
                  'sno': PlutoCell(value: item.sno),
                  'indentNo': PlutoCell(value: item.indentNo),
                  'itemName': PlutoCell(value: item.itemName),
                  'requiredQtyUnit': PlutoCell(value: '${item.qty}, ${item.unit}'), // Combined qty and unit
                  'lastPrev': PlutoCell(value: item.previousPurchase),
                };

                // Add vendor quote cells for each vendor
                vendors.asMap().forEach((index, vendor) {
                  final quote = vendorQuotes.firstWhere(
                        (q) => q.accountCode == vendor.accountCode,
                    orElse: () => VendorQuote(
                      accountCode: vendor.accountCode,
                      itemNo: item.itemNo,
                      itemRate: '',
                      netRate: '',
                      discountPercent: '',
                      discountAmount: '',
                      netValue: '',
                      gstPercent: '',
                      gstAmount: '',
                      subTotal: '',
                      totalBeforeTax: '',
                      grandTotal: '',
                      deliveryPeriod: '',
                      paymentTerms: '',
                      freightRemarks: '',
                      gstRemarks: '',
                      actionL1: '',
                      actionL1Remark: '',
                      actionL2: '',
                      actionL2Remark: '',
                    ),
                  );

                  // Combine actionL1 and actionL1Remark with space
                  final l1Action = quote.actionL1?.isNotEmpty ?? false
                      ? '${quote.actionL1} ${quote.actionL1Remark ?? ""}'.trim()
                      : 'N/A';

                  // Combine actionL2 and actionL2Remark with space
                  final l2Action = quote.actionL2?.isNotEmpty ?? false
                      ? '${quote.actionL2} ${quote.actionL2Remark ?? ""}'.trim()
                      : 'N/A';

                  cells['netRate_$index'] = PlutoCell(value: quote.netRate.isNotEmpty ? quote.netRate : 'N/A');
                  cells['actionL1_$index'] = PlutoCell(value: l1Action);
                  cells['actionL2_$index'] = PlutoCell(value: l2Action);
                });

                return PlutoRow(cells: cells);
              }).toList();

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [Colors.blue[200]!, Colors.blue[50]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      width: double.infinity,
                      child: Text(
                        'Vendor Comparison Table',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue[900],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Unified PlutoGrid
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 3,
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: PlutoGrid(
                          columns: columns,
                          rows: rows,
                          onSelected: (event) {
                            if (event.row != null) {
                              setState(() {
                                selectedItemNo = event.row!.cells['itemName']!.value;
                              });
                            }
                          },
                          onLoaded: (PlutoGridOnLoadedEvent event) {
                            _gridStateManager = event.stateManager;
                            _gridStateManager!.setShowColumnFilter(true);
                          },
                          configuration: PlutoGridConfiguration(
                            style: PlutoGridStyleConfig(
                              gridBorderColor: Colors.grey[300]!,
                              gridBackgroundColor: Colors.white,
                              columnTextStyle: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[900],
                              ),
                              cellTextStyle: GoogleFonts.poppins(fontSize: 14),
                              activatedBorderColor: Colors.blue[400]!,
                              activatedColor: Colors.blue[50]!,
                              columnHeight: 80, // Increased to accommodate two-line headers
                              rowHeight: 45,
                              borderColor: Colors.grey[200]!,
                            ),
                            scrollbar: PlutoGridScrollbarConfig(
                              isAlwaysShown: true,
                              scrollbarThickness: 10,
                            ),
                            columnSize: const PlutoGridColumnSizeConfig(
                              autoSizeMode: PlutoAutoSizeMode.none,
                            ),
                            enableMoveDownAfterSelecting: false,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } else if (state is ComparisonError) {
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
            return Center(
              child: Text(
                'Please wait...',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
            );
          },
        ),
      ),
    );
  }
}