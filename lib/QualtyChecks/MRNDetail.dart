// First, let's create a constants file for better maintainability
// mrn_constants.dart
// mrn_details_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:qualityapproach/QualtyChecks/MRNDetailBLoc.dart';
import 'package:signature/signature.dart';

import 'package:flutter/material.dart';

class MRNConstants {
  // UI Constants
  static const double padding = 16.0;
  static const double spacing = 16.0;
  static const double gridHeight = 400.0;
  static const double signatureHeight = 100.0;

  // Styles
  static const headerStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
  );

  static const valueStyle = TextStyle(fontSize: 16);

  // Grid Configurations
  static const gridColumns = [
    'QUALITY STANDARD NAME',
    'STANDARD RANGE',
    'STANDARD OPTIONS',
    'OBSERVED VALUE',
  ];
}

// Optimized main page widget
class MRNDetailsPage extends StatelessWidget {
  final String branchCode;
  final String mrnNo;
  final String mrnDate;
  final String vendorName;
  final String itemName;
  final String itemNo;

  const MRNDetailsPage({
    Key? key,
    required this.branchCode,
    required this.mrnNo,
    required this.mrnDate,
    required this.vendorName,
    required this.itemName,
    required this.itemNo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MRNDetailBloc()
        ..add(FetchMRNDetailEvent(branchCode: branchCode, itemNo: itemNo)),
      child: MRNDetailsView(
        mrnNo: mrnNo,
        mrnDate: mrnDate,
        vendorName: vendorName,
        itemName: itemName,
      ),
    );
  }
}

// Separate view widget for better state management
class MRNDetailsView extends StatefulWidget {
  final String mrnNo;
  final String mrnDate;
  final String vendorName;
  final String itemName;

  const MRNDetailsView({
    Key? key,
    required this.mrnNo,
    required this.mrnDate,
    required this.vendorName,
    required this.itemName,
  }) : super(key: key);

  @override
  State<MRNDetailsView> createState() => _MRNDetailsViewState();
}

class _MRNDetailsViewState extends State<MRNDetailsView> {
  late final SignatureController _signatureController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(MRNConstants.padding),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  HeaderCard(
                    mrnNo: widget.mrnNo,
                    mrnDate: widget.mrnDate,
                    vendorName: widget.vendorName,
                    itemName: widget.itemName,
                  ),
                  const SizedBox(height: MRNConstants.spacing),
                  const QualityParametersGrid(),
                  const SizedBox(height: MRNConstants.spacing),
                  SignatureSection(controller: _signatureController),
                  const SizedBox(height: MRNConstants.spacing),
                  const ActionButtonsSection(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('MRN Details'),
      backgroundColor: Colors.blue,
    );
  }
}

// Optimized header card component
class HeaderCard extends StatelessWidget {
  final String mrnNo;
  final String mrnDate;
  final String vendorName;
  final String itemName;

  const HeaderCard({
    Key? key,
    required this.mrnNo,
    required this.mrnDate,
    required this.vendorName,
    required this.itemName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(MRNConstants.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailRow(label: 'MRN No:', value: mrnNo),
            const SizedBox(height: MRNConstants.spacing),
            DetailRow(label: 'MRN Date:', value: mrnDate),
            const SizedBox(height: MRNConstants.spacing),
            DetailRow(label: 'Vendor Name:', value: vendorName),
            const SizedBox(height: MRNConstants.spacing),
            DetailRow(label: 'Item Name:', value: itemName),
          ],
        ),
      ),
    );
  }
}

// Optimized detail row component
class DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const DetailRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: MRNConstants.headerStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: Text(
            value, style: MRNConstants.valueStyle,
            maxLines: 2, // Allow the value to wrap into two lines if necessary
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Optimized grid component with lazy loading
class QualityParametersGrid extends StatelessWidget {
  const QualityParametersGrid({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MRNDetailBloc, MRNDetailState>(
      buildWhen: (previous, current) => current is MRNDetailLoaded,
      builder: (context, state) {
        if (state is MRNDetailLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is MRNDetailError) {
          return Center(child: Text(state.message));
        }

        if (state is MRNDetailLoaded) {
          return SizedBox(
            height: MRNConstants.gridHeight,
            child: PlutoGrid(
              columns: _buildColumns(),
              rows: _buildRows(state.qualityParameters),
              onLoaded: (PlutoGridOnLoadedEvent event) {
                event.stateManager.setShowColumnFilter(true);
              },
              configuration: const PlutoGridConfiguration(
                columnSize: PlutoGridColumnSizeConfig(
                  autoSizeMode: PlutoAutoSizeMode.scale,
                ),
                style: PlutoGridStyleConfig(
                  cellTextStyle: TextStyle(fontSize: 14),
                  columnTextStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  List<PlutoColumn> _buildColumns() {
    return [
      PlutoColumn(
        title: 'QUALITY STANDARD NAME',
        field: 'QualityParameter',

        type: PlutoColumnType.text(),
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'STANDARD RANGE',
        field: 'StdRange',


        type: PlutoColumnType.text(),
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'STANDARD OPTIONS',
        field: 'StdOptions',


        type: PlutoColumnType.text(),
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Observed Value',
        field: 'ObservedValue',
    
        type: PlutoColumnType.text(),
        enableEditingMode: true,
        renderer: _buildObservedValueRenderer,
      ),
    ];
  }

  Widget _buildHeaderText(String title) {
    return Container(
      constraints: BoxConstraints(maxWidth: 100), // Adjust maxWidth as needed
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        maxLines: 2,
        overflow: TextOverflow.visible,
      ),
    );
  }

  Widget _buildObservedValueRenderer(PlutoColumnRendererContext context) {
    return Text(
      context.cell.value.isEmpty ? 'Enter observed value' : context.cell.value,
      style: TextStyle(
        fontSize: 14,
        color: context.cell.value.isEmpty ? Colors.grey : Colors.black,
      ),
    );
  }

  List<PlutoRow> _buildRows(List<Map<String, dynamic>> parameters) {
    return parameters.map((parameter) {
      return PlutoRow(
        cells: {
          'QualityParameter':
              PlutoCell(value: parameter['QualityParameter'] ?? ''),
          'StdRange': PlutoCell(value: parameter['StdRange'] ?? ''),
          'StdOptions': PlutoCell(value: parameter['StdOptions'] ?? ''),
          'ObservedValue': PlutoCell(value: ''),
        },
      );
    }).toList();
  }
}

// Optimized signature section
class SignatureSection extends StatelessWidget {
  final SignatureController controller;

  const SignatureSection({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              "Signature:",
              style: MRNConstants.headerStyle,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: SignaturePad(controller: controller),
          ),
        ],
      ),
    );
  }
}

// Separate signature pad component
class SignaturePad extends StatelessWidget {
  final SignatureController controller;

  const SignaturePad({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: MRNConstants.signatureHeight,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black54),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Signature(
              controller: controller,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: ElevatedButton(
            onPressed: controller.clear,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
            ),
            child: const Text(
              "Clear",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Optimized action buttons section
class ActionButtonsSection extends StatelessWidget {
  const ActionButtonsSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: () {
            // Implement reset functionality
            BlocProvider.of<MRNDetailBloc>(context)
                .add(ResetObservedValueEvent());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text(
            'Reset',
            style: TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: MRNConstants.spacing),
        ElevatedButton(
          onPressed: () {
            // Implement submit functionality
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text(
            'Submit',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
