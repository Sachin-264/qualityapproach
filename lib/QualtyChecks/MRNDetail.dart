import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:qualityapproach/QualtyChecks/MRNDetailBLoc.dart';
import 'package:signature/signature.dart';

class MRNConstants {
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
}

class MRNDetailsPage extends StatelessWidget {
  final String str;
  final String branchCode;
  final String mrnNo;
  final String mrnDate;
  final String vendorName;
  final String itemName;
  final String itemNo;
  final String itemSno;
  final double UserCode;
  final int UserGroupCode;
  final String RecNo;

  const MRNDetailsPage({
    Key? key,
    required this.str,
    required this.branchCode,
    required this.mrnNo,
    required this.mrnDate,
    required this.vendorName,
    required this.itemName,
    required this.itemNo,
    required this.itemSno,
    required this.UserCode,
    required this.UserGroupCode,
    required this.RecNo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('STR: $str');
    return BlocProvider(
      create: (context) => MRNDetailBloc(
        str: str,
        UserCode: UserCode,
        UserGroupCode: UserGroupCode,
        itemSno: itemSno,
        itemNo: itemNo,
        RecNo: RecNo,
      )..add(FetchMRNDetailEvent(branchCode: branchCode, itemNo: itemNo, str: str)),
      child: MRNDetailsView(
        mrnNo: mrnNo,
        mrnDate: mrnDate,
        vendorName: vendorName,
        itemName: itemName,
        branchCode: branchCode,
        itemNo: itemNo,
        str: str,
      ),
    );
  }
}

class MRNDetailsView extends StatefulWidget {
  final String mrnNo;
  final String mrnDate;
  final String vendorName;
  final String itemName;
  final String branchCode;
  final String itemNo;
  final String str;

  const MRNDetailsView({
    Key? key,
    required this.mrnNo,
    required this.mrnDate,
    required this.vendorName,
    required this.itemName,
    required this.branchCode,
    required this.itemNo,
    required this.str,
  }) : super(key: key);

  @override
  State<MRNDetailsView> createState() => _MRNDetailsViewState();
}

class _MRNDetailsViewState extends State<MRNDetailsView> {
  late final SignatureController _signatureController;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _latestParameters = [];

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  void updateLatestParameters(List<Map<String, dynamic>> parameters) {
    setState(() {
      _latestParameters = parameters;
    });
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
                  QualityParametersTable(
                    branchCode: widget.branchCode,
                    itemNo: widget.itemNo,
                    str: widget.str,
                    onParametersUpdated: updateLatestParameters,
                  ),
                  const SizedBox(height: MRNConstants.spacing),
                  SignatureSection(controller: _signatureController),
                  const SizedBox(height: MRNConstants.spacing),
                  ActionButtonsSection(
                    signatureController: _signatureController,
                    latestParameters: _latestParameters,
                  ),
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
            value,
            style: MRNConstants.valueStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class QualityParametersTable extends StatefulWidget {
  final String branchCode;
  final String itemNo;
  final String str;
  final Function(List<Map<String, dynamic>>) onParametersUpdated;

  const QualityParametersTable({
    Key? key,
    required this.branchCode,
    required this.itemNo,
    required this.str,
    required this.onParametersUpdated,
  }) : super(key: key);

  @override
  _QualityParametersTableState createState() => _QualityParametersTableState();
}

class _QualityParametersTableState extends State<QualityParametersTable> {
  final Map<int, Map<String, TextEditingController>> _controllers = {};
  final Map<int, String?> _passDropdownValues = {}; // Store dropdown values
  List<Map<String, dynamic>> _latestParameters = [];

  void _onValueChanged(int index, String field, String value) {
    setState(() {
      _latestParameters[index][field] = value;
    });

    widget.onParametersUpdated(_latestParameters);
  }

  @override
  void dispose() {
    _controllers.forEach((_, rowControllers) {
      rowControllers.forEach((_, controller) {
        controller.dispose();
      });
    });
    super.dispose();
  }

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
          _latestParameters = state.qualityParameters;
          _initializeControllers(state.qualityParameters);
          return Card(
            color: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                  child: DataTable(
                    columnSpacing: 20,
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columns: _buildColumns(),
                    rows: _buildRows(context),
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

  void _initializeControllers(List<Map<String, dynamic>> parameters) {
    for (int i = 0; i < parameters.length; i++) {
      _controllers[i] ??= {
        'ObservedValue': TextEditingController(text: parameters[i]['ObservedValue']?.toString() ?? ''),
        'Remarks': TextEditingController(text: parameters[i]['Remarks']?.toString() ?? ''),
        'Pass(Yes/No)': TextEditingController(text: parameters[i]['Pass(Yes/No)']?.toString() ?? ''),
      };
      // Initialize dropdown value
      _passDropdownValues[i] = parameters[i]['Pass(Yes/No)']?.toString();
    }
  }

  List<DataColumn> _buildColumns() {
    return [
      DataColumn(label: Text('Quality Standard Name', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Standard Range', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Standard Options', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Observed Value', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Pass(Yes/No)', style: TextStyle(fontWeight: FontWeight.bold))),
    ];
  }

  List<DataRow> _buildRows(BuildContext parentContext) {
    return List.generate(_latestParameters.length, (index) {
      final param = _latestParameters[index];
      return DataRow(cells: [
        DataCell(Text(param['QualityParameter']?.toString() ?? '')),
        DataCell(Text(param['StdRange']?.toString() ?? '')),
        DataCell(Text(param['StdOptions']?.toString() ?? '')),
        DataCell(_editableCell(index, 'ObservedValue', parentContext)),
        DataCell(_editableCell(index, 'Remarks', parentContext)),
        DataCell(_dropdownCell(index, parentContext)), // Use dropdown for Pass(Yes/No)
      ]);
    });
  }

  Widget _editableCell(int index, String field, BuildContext parentContext) {
    return TextField(
      controller: _controllers[index]![field],
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        hintText: 'Enter',
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),
      onChanged: (value) {
        _onValueChanged(index, field, value);
      },
    );
  }

  Widget _dropdownCell(int index, BuildContext parentContext) {
    return DropdownButton<String>(
      value: _passDropdownValues[index],
      items: ['Yes', 'No'].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _passDropdownValues[index] = newValue;
          _onValueChanged(index, 'Pass(Yes/No)', newValue ?? '');
        });
      },
      underline: Container(), // Remove the default underline
      isExpanded: true, // Ensure dropdown takes full width
    );
  }
}

class SignatureSection extends StatelessWidget {
  final SignatureController controller;

  const SignatureSection({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            ),
            child: const Text(
              "Clear",
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class ActionButtonsSection extends StatelessWidget {
  final SignatureController signatureController;
  final List<Map<String, dynamic>> latestParameters;

  const ActionButtonsSection({
    Key? key,
    required this.signatureController,
    required this.latestParameters,
  }) : super(key: key);

  bool _areAllObservedValuesFilled() {
    for (var param in latestParameters) {
      if (param['ObservedValue'] == null || param['ObservedValue'].toString().isEmpty) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MRNDetailBloc, MRNDetailState>(
      listener: (context, state) {
        if (state is MRNDetailSubmitSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully submitted MRN details')),
          );
          Navigator.pop(context);
        } else if (state is MRNDetailSubmitError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}')),
          );
        }
      },
      builder: (context, state) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: state is MRNDetailSubmitting
                  ? null
                  : () {
                context.read<MRNDetailBloc>().add(ResetObservedValueEvent());
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Reset',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: state is MRNDetailSubmitting
                  ? null
                  : () async {
                if (signatureController.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide a signature')),
                  );
                  return;
                }

                if (!_areAllObservedValuesFilled()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all observed values')),
                  );
                  return;
                }

                if (state is MRNDetailLoaded) {
                  final signature = await signatureController.toPngBytes();
                  print("Latest Parameters before submission: $latestParameters");

                  if (signature != null) {
                    final base64Signature = base64Encode(signature);

                    context.read<MRNDetailBloc>().add(
                      SubmitMRNDetailEvent(
                        signature: base64Signature,
                        qualityParameters: latestParameters,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: state is MRNDetailSubmitting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white),
              )
                  : const Text(
                'Submit',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}