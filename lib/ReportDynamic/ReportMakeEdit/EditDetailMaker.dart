import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'dart:ui' as ui;
import 'dart:async';

import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart';
import 'EditDetailMakerBloc.dart';

// Extension to capitalize first letter of a string
extension StringCasingExtension on String {
String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
}

// Enum for print templates
enum PrintTemplateForMaker {
premium,
minimalist,
corporate,
modern,
}

extension PrintTemplateForMakerExtension on PrintTemplateForMaker {
String get displayName {
switch (this) {
case PrintTemplateForMaker.premium:
return 'Premium';
case PrintTemplateForMaker.minimalist:
return 'Minimalist';
case PrintTemplateForMaker.corporate:
return 'Corporate';
case PrintTemplateForMaker.modern:
return 'Modern';
}
}
}

// Map for predefined PDF colors for selection
final Map<String, PdfColor> predefinedPdfColors = {
'Blue': PdfColors.blue,
'Red': PdfColors.red,
'Green': PdfColors.green,
'Orange': PdfColors.orange,
'Purple': PdfColors.purple,
'Grey': PdfColors.grey,
'Black': PdfColors.black,
};

extension PdfColorToFlutterColor on PdfColor {
ui.Color toFlutterColor() {
return ui.Color.fromARGB(
(alpha * 255).round(),
(red * 255).round(),
(green * 255).round(),
(blue * 255).round(),
);
}
}


class EditDetailMaker extends StatefulWidget {
final int recNo;
final String reportName;
final String reportLabel;
final String apiName;

const EditDetailMaker({
super.key,
required this.recNo,
required this.reportName,
required this.reportLabel,
required this.apiName,
});

@override
_EditDetailMakerState createState() => _EditDetailMakerState();
}

class _EditDetailMakerState extends State<EditDetailMaker> with TickerProviderStateMixin {
final TextEditingController _reportNameController = TextEditingController();
final TextEditingController _reportLabelController = TextEditingController();
final TextEditingController _apiController = TextEditingController();
final TextEditingController _fieldNameController = TextEditingController();
final TextEditingController _fieldLabelController = TextEditingController();
final TextEditingController _sequenceController = TextEditingController();
final TextEditingController _widthController = TextEditingController();
final TextEditingController _decimalPointsController = TextEditingController();
final TextEditingController _apiDrivenUrlController = TextEditingController();
final TextEditingController _userFillingUrlController = TextEditingController();

final Map<String, TextEditingController> _userFillingPayloadKeyControllers = {};
final Map<String, TextEditingController> _userFillingPayloadStaticValueControllers = {};

String? _selectedApi;
bool _showConfigPanel = false;
bool _showMainReportDetails = true;
bool _showFieldsConfigurationContent = true;
late EditDetailMakerBloc _bloc;
late AnimationController _animationController;
late Animation<double> _fadeAnimation;
TabController? _tabController;

final Map<String, TextEditingController> _actionNameControllers = {};
final Map<String, TextEditingController> _actionApiControllers = {};
final Map<String, TextEditingController> _actionReportLabelControllers = {};
final Map<String, Map<String, TextEditingController>> _actionParamValueControllers = {};

final Uuid _uuid = const Uuid();
final Map<String, GlobalKey> _autocompleteFieldKeys = {};
Map<String, dynamic>? _previousCurrentField;


@override
void initState() {
super.initState();
_reportNameController.text = widget.reportName;
_reportLabelController.text = widget.reportLabel;
_apiController.text = widget.apiName;
_selectedApi = widget.apiName;

_bloc = EditDetailMakerBloc(ReportAPIService());

_animationController = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 300),
);
_fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
);

for (var controller in [
_reportNameController,
_reportLabelController,
_apiController,
]) {
controller.addListener(_ensureCursorAtEnd(controller));
}

WidgetsBinding.instance.addPostFrameCallback((_) {
_bloc.add(LoadPreselectedFields(widget.recNo, widget.apiName));
});
}

VoidCallback _ensureCursorAtEnd(TextEditingController controller) {
return () {
if (controller.text.isNotEmpty && controller.selection.baseOffset < controller.text.length) {
if (controller.selection.baseOffset != controller.text.length || controller.selection.extentOffset != controller.text.length) {
controller.selection = TextSelection.fromPosition(
TextPosition(offset: controller.text.length),
);
}
}
};
}

@override
void dispose() {
_tabController?.dispose();
_reportNameController.dispose();
_reportLabelController.dispose();
_apiController.dispose();
_fieldNameController.dispose();
_fieldLabelController.dispose();
_sequenceController.dispose();
_widthController.dispose();
_decimalPointsController.dispose();
_apiDrivenUrlController.dispose();
_userFillingUrlController.dispose();
_animationController.dispose();
_bloc.close();

_actionNameControllers.forEach((_, controller) => controller.dispose());
_actionApiControllers.forEach((_, controller) => controller.dispose());
_actionReportLabelControllers.forEach((_, controller) => controller.dispose());
_actionParamValueControllers.forEach((_, paramMap) {
paramMap.forEach((_, controller) => controller.dispose());
});

_actionNameControllers.clear();
_actionApiControllers.clear();
_actionReportLabelControllers.clear();
_actionParamValueControllers.clear();

_userFillingPayloadKeyControllers.forEach((_, controller) => controller.dispose());
_userFillingPayloadKeyControllers.clear();
_userFillingPayloadStaticValueControllers.forEach((_, controller) => controller.dispose());
_userFillingPayloadStaticValueControllers.clear();

super.dispose();
}

void _toggleConfigPanel() {
setState(() {
_showConfigPanel = true;
_showMainReportDetails = false;
_showFieldsConfigurationContent = true;
_animationController.forward();
});
}

void _returnToFieldSelection() {
setState(() {
_showConfigPanel = false;
_animationController.reverse(from: 1.0);
});
}

void _toggleMainReportDetails() {
setState(() {
_showMainReportDetails = !_showMainReportDetails;
if (_showMainReportDetails) {
_showConfigPanel = false;
_showFieldsConfigurationContent = false;
}
});
}

void _toggleFieldsConfigurationContent() {
setState(() {
_showFieldsConfigurationContent = !_showFieldsConfigurationContent;
if (_showFieldsConfigurationContent) {
_showMainReportDetails = false;
_showConfigPanel = false;
}
});
}

void _updateFieldConfigControllersFromBlocState(Map<String, dynamic>? field) {
if (field == null) {
_fieldNameController.clear();
_fieldLabelController.clear();
_sequenceController.clear();
_widthController.clear();
_decimalPointsController.clear();
_apiDrivenUrlController.clear();
_userFillingUrlController.clear();
_userFillingPayloadKeyControllers.forEach((_, controller) => controller.dispose());
_userFillingPayloadKeyControllers.clear();
_userFillingPayloadStaticValueControllers.forEach((_, controller) => controller.dispose());
_userFillingPayloadStaticValueControllers.clear();
} else {
if (_fieldNameController.text != (field['Field_name']?.toString() ?? '')) {
_fieldNameController.text = field['Field_name']?.toString() ?? '';
}
if (_fieldLabelController.text != (field['Field_label']?.toString() ?? '')) {
_fieldLabelController.text = field['Field_label']?.toString() ?? '';
}
if (_sequenceController.text != (field['Sequence_no']?.toString() ?? '')) {
_sequenceController.text = field['Sequence_no']?.toString() ?? '';
}
if (_widthController.text != (field['width']?.toString() ?? '')) {
_widthController.text = field['width']?.toString() ?? '';
}
if (_decimalPointsController.text != (field['decimal_points']?.toString() ?? '')) {
_decimalPointsController.text = field['decimal_points']?.toString() ?? '';
}
if (_apiDrivenUrlController.text != (field['api_url']?.toString() ?? '')) {
_apiDrivenUrlController.text = field['api_url']?.toString() ?? '';
}
if (_userFillingUrlController.text != (field['updated_url']?.toString() ?? '')) {
_userFillingUrlController.text = field['updated_url']?.toString() ?? '';
}

final List<dynamic> payloadStructure = field['payload_structure'] ?? [];
final Set<String> currentParamIds = payloadStructure.map<String>((p) => p['id'] as String).toSet();
_userFillingPayloadKeyControllers.keys.toList().forEach((paramId) {
if (!currentParamIds.contains(paramId)) {
_userFillingPayloadKeyControllers.remove(paramId)?.dispose();
_userFillingPayloadStaticValueControllers.remove(paramId)?.dispose();
}
});
for (var param in payloadStructure) {
final paramId = param['id'] as String;
_userFillingPayloadKeyControllers.putIfAbsent(paramId, () => TextEditingController());
if (_userFillingPayloadKeyControllers[paramId]!.text != (param['key']?.toString() ?? '')) {
_userFillingPayloadKeyControllers[paramId]!.text = param['key']?.toString() ?? '';
}

if (param['value_type'] == 'static') {
_userFillingPayloadStaticValueControllers.putIfAbsent(paramId, () => TextEditingController());
if (_userFillingPayloadStaticValueControllers[paramId]!.text != (param['value']?.toString() ?? '')) {
_userFillingPayloadStaticValueControllers[paramId]!.text = param['value']?.toString() ?? '';
}
} else {
_userFillingPayloadStaticValueControllers.remove(paramId)?.dispose();
}
}
}
}

void _updateActionControllers(List<Map<String, dynamic>> actions) {
final Set<String> existingActionIds = actions.map((a) => a['id'] as String).toSet();

_actionNameControllers.keys.toList().forEach((id) {
if (!existingActionIds.contains(id)) {
_actionNameControllers.remove(id)?.dispose();
_actionApiControllers.remove(id)?.dispose();
_actionReportLabelControllers.remove(id)?.dispose();
_actionParamValueControllers.remove(id)?.forEach((_, controller) => controller.dispose());
_actionParamValueControllers.remove(id);
_autocompleteFieldKeys.remove(id);
}
});

for (var action in actions) {
final actionId = action['id'] as String;
final actionType = action['type'] as String;

if (!_actionNameControllers.containsKey(actionId)) {
_actionNameControllers[actionId] = TextEditingController(text: action['name']?.toString() ?? '');
} else if (_actionNameControllers[actionId]!.text != (action['name']?.toString() ?? '')) {
_actionNameControllers[actionId]!.text = action['name']?.toString() ?? '';
}

if (actionType == 'print' || actionType == 'table') {
if (!_actionApiControllers.containsKey(actionId)) {
_actionApiControllers[actionId] = TextEditingController(text: action['api']?.toString() ?? '');
} else if (_actionApiControllers[actionId]!.text != (action['api']?.toString() ?? '')) {
_actionApiControllers[actionId]!.text = action['api']?.toString() ?? '';
}
} else {
_actionApiControllers.remove(actionId)?.dispose();
}

if (actionType == 'table') {
_autocompleteFieldKeys.putIfAbsent(actionId, () => GlobalKey());
if (!_actionReportLabelControllers.containsKey(actionId)) {
_actionReportLabelControllers[actionId] = TextEditingController(text: action['reportLabel']?.toString() ?? '');
_actionReportLabelControllers[actionId]!.addListener(_ensureCursorAtEnd(_actionReportLabelControllers[actionId]!));
} else if (_actionReportLabelControllers[actionId]!.text != (action['reportLabel']?.toString() ?? '')) {
_actionReportLabelControllers[actionId]!.text = action['reportLabel']?.toString() ?? '';
}
} else {
_autocompleteFieldKeys.remove(actionId);
_actionReportLabelControllers.remove(actionId)?.dispose();
}

if (actionType == 'print' || actionType == 'table') {
final params = action['params'] as List<dynamic>? ?? [];
if (!_actionParamValueControllers.containsKey(actionId)) {
_actionParamValueControllers[actionId] = {};
}

final currentParamMap = _actionParamValueControllers[actionId]!;
currentParamMap.keys.toList().forEach((paramId) {
if (!params.any((p) => p['id'] == paramId)) {
currentParamMap.remove(paramId)?.dispose();
}
});

for (var param in params) {
final paramId = param['id'] as String;
if (!currentParamMap.containsKey(paramId)) {
currentParamMap[paramId] = TextEditingController(text: param['parameterValue']?.toString() ?? '');
currentParamMap[paramId]!.addListener(_ensureCursorAtEnd(currentParamMap[paramId]!));
} else if (currentParamMap[paramId]!.text != (param['parameterValue']?.toString() ?? '')) {
currentParamMap[paramId]!.text = param['parameterValue']?.toString() ?? '';
}
}
} else {
if (_actionParamValueControllers.containsKey(actionId)) {
_actionParamValueControllers[actionId]?.forEach((_, controller) => controller.dispose());
_actionParamValueControllers.remove(actionId);
}
}
}
}

@override
Widget build(BuildContext context) {
return BlocProvider.value(
value: _bloc,
child: Scaffold(
appBar: AppBarWidget(
title: 'Edit Report Details',
onBackPress: () {
Navigator.pop(context, true);
},
),
body: BlocListener<EditDetailMakerBloc, EditDetailMakerState>(
listener: (context, state) {
if (state.error != null) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(
state.error!,
style: GoogleFonts.poppins(color: Colors.white),
),
backgroundColor: Colors.redAccent,
behavior: SnackBarBehavior.floating,
margin: const EdgeInsets.all(16),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
duration: const Duration(seconds: 5),
),
);
} else if (state.saveSuccess) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: const Text('Report and field configurations updated successfully!'),
backgroundColor: Colors.green,
behavior: SnackBarBehavior.floating,
margin: const EdgeInsets.all(16),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
duration: const Duration(seconds: 5),
),
);
Navigator.pop(context, true);
}
if (state.currentField != _previousCurrentField) {
_updateFieldConfigControllersFromBlocState(state.currentField);
_previousCurrentField = state.currentField;
}
_updateActionControllers(state.actions);
},
child: BlocBuilder<EditDetailMakerBloc, EditDetailMakerState>(
builder: (context, state) {
if (state.actions.isNotEmpty && (_tabController == null || _tabController!.length != state.actions.length)) {
final initialIndex = _tabController?.index ?? 0;
_tabController?.dispose();
_tabController = TabController(
initialIndex: (initialIndex < state.actions.length) ? initialIndex : state.actions.length - 1,
length: state.actions.length,
vsync: this
);
} else if (state.actions.isEmpty && _tabController != null) {
_tabController?.dispose();
_tabController = null;
}

return SingleChildScrollView(
child: Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
children: [
// Report Details Section Card
Card(
color: Colors.white,
elevation: 6,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
child: InkWell(
borderRadius: BorderRadius.circular(12),
onTap: _toggleMainReportDetails,
child: Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
'Report Details',
style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
),
Icon(
_showMainReportDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
color: Colors.grey[600],
),
],
),
AnimatedSwitcher(
duration: const Duration(milliseconds: 300),
transitionBuilder: (Widget child, Animation<double> animation) {
return SizeTransition(
sizeFactor: animation,
axisAlignment: -1.0,
child: FadeTransition(
opacity: animation,
child: child,
),
);
},
child: _showMainReportDetails
? Column(
key: const ValueKey('reportDetailsContent'),
children: [
const Divider(height: 20, thickness: 1),
Row(
children: [
Expanded(
child: _buildTextField(
controller: _reportNameController,
label: 'Report Name',
icon: Icons.description,
onChanged: (value) {},
),
),
const SizedBox(width: 16),
Expanded(
child: _buildTextField(
controller: _reportLabelController,
label: 'Report Label',
icon: Icons.label,
onChanged: (value) {},
),
),
],
),
const SizedBox(height: 20),
Row(
children: [
Expanded(
child: _buildTextField(
controller: _apiController,
label: 'API Name',
icon: Icons.api,
readOnly: true,
onChanged: (value) {},
),
),
],
),
const SizedBox(height: 20),
CheckboxListTile(
title: Text('Print Date/Time in Footer', style: GoogleFonts.poppins(fontSize: 16)),
value: state.includePdfFooterDateTime,
onChanged: (value) {
context.read<EditDetailMakerBloc>().add(ToggleIncludePdfFooterDateTime(value!));
},
activeColor: Colors.blueAccent,
controlAffinity: ListTileControlAffinity.leading,
contentPadding: EdgeInsets.zero,
),
const SizedBox(height: 20),
Row(
mainAxisAlignment: MainAxisAlignment.end,
children: [
_buildButton(
text: 'Reset Form',
color: Colors.redAccent,
onPressed: () {
context.read<EditDetailMakerBloc>().add(ResetFields());
_reportNameController.text = widget.reportName;
_reportLabelController.text = widget.reportLabel;
_apiController.text = widget.apiName;
setState(() {
_selectedApi = widget.apiName;
_showConfigPanel = false;
_showMainReportDetails = true;
_showFieldsConfigurationContent = false;
});
_animationController.reset();
},
icon: Icons.refresh,
),
],
),
],
)
    : const SizedBox.shrink(key: ValueKey('reportDetailsEmpty')),
),
],
),
),
),
),
const SizedBox(height: 16),
// Field Configuration Section Card
Card(
color: Colors.white,
elevation: 6,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
child: InkWell(
borderRadius: BorderRadius.circular(12),
onTap: _toggleFieldsConfigurationContent,
child: Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
'Fields Configuration',
style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
),
Icon(
_showFieldsConfigurationContent ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
color: Colors.grey[600],
),
],
),
AnimatedSwitcher(
duration: const Duration(milliseconds: 300),
transitionBuilder: (Widget child, Animation<double> animation) {
return SizeTransition(
sizeFactor: animation,
axisAlignment: -1.0,
child: FadeTransition(
opacity: animation,
child: child,
),
);
},
child: _showFieldsConfigurationContent
? Column(
key: const ValueKey('fieldsConfigContent'),
children: [
const Divider(height: 20, thickness: 1, color: Colors.grey),
if (state.isLoading)
const SizedBox(height: 200, child: SubtleLoader())
else if (state.error != null && state.fields.isEmpty)
Container(
padding: const EdgeInsets.symmetric(vertical: 20),
alignment: Alignment.center,
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Text(
'Error loading fields: ${state.error}',
style: GoogleFonts.poppins(fontSize: 16, color: Colors.redAccent),
textAlign: TextAlign.center,
),
const SizedBox(height: 16),
_buildButton(
text: 'Retry Load Fields',
color: Colors.blueAccent,
onPressed: () {
context.read<EditDetailMakerBloc>().add(
LoadPreselectedFields(widget.recNo, widget.apiName),
);
},
),
],
),
)
else if (state.fields.isEmpty && state.selectedFields.isEmpty)
Container(
padding: const EdgeInsets.symmetric(vertical: 20),
alignment: Alignment.center,
child: Text(
'No fields available from the API. Check API response.',
style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
textAlign: TextAlign.center,
),
)
else
_showConfigPanel ? _buildFieldConfigPanel(context, state) : _buildFieldSelection(context, state),
],
)
    : const SizedBox.shrink(key: ValueKey('fieldsConfigEmpty')),
),
],
),
),
),
),
const SizedBox(height: 16),
// Action Section
_buildActionSection(context, state),
const SizedBox(height: 16),
// Save button
Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
_buildButton(
text: 'Save Changes',
color: Colors.green,
onPressed: () {
if (_reportNameController.text.isEmpty ||
_reportLabelController.text.isEmpty ||
_selectedApi == null ||
state.selectedFields.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: const Text('Please fill all report details and select at least one field.'),
backgroundColor: Colors.redAccent,
behavior: SnackBarBehavior.floating,
margin: const EdgeInsets.all(16),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
duration: const Duration(seconds: 3),
),
);
return;
}
if (state.currentField != null) {
final currentFieldSeqControllerValue = int.tryParse(_sequenceController.text);
if (currentFieldSeqControllerValue != null &&
currentFieldSeqControllerValue >= 0 &&
(state.currentField!['Sequence_no'] != currentFieldSeqControllerValue)) {
context.read<EditDetailMakerBloc>().add(
UpdateFieldConfig('Sequence_no', currentFieldSeqControllerValue),
);
}
if (state.currentField!['is_api_driven'] == true &&
_apiDrivenUrlController.text != (state.currentField!['api_url']?.toString() ?? '')) {
context.read<EditDetailMakerBloc>().add(
UpdateFieldApiUrl(_apiDrivenUrlController.text),
);
}
if (state.currentField!['is_user_filling'] == true &&
_userFillingUrlController.text != (state.currentField!['updated_url']?.toString() ?? '')) {
context.read<EditDetailMakerBloc>().add(
UpdateFieldUserFillingUrl(_userFillingUrlController.text),
);
}
}
Future.delayed(const Duration(milliseconds: 100), () {
context.read<EditDetailMakerBloc>().add(
SaveReport(
recNo: widget.recNo,
reportName: _reportNameController.text,
reportLabel: _reportLabelController.text,
apiName: _apiController.text,
parameter: 'default',
needsAction: state.needsAction,
actions: state.actions,
includePdfFooterDateTime: state.includePdfFooterDateTime,
),
);
});
},
icon: Icons.save,
),
const SizedBox(width: 12),
],
),
],
),
),
);
},
),
),
),
);
}

Widget _buildActionSection(BuildContext context, EditDetailMakerState state) {
bool canAddMoreActions = state.actions.length < 5;
bool formExists = state.actions.any((a) => a['type'] == 'form');

return Card(
color: Colors.white,
elevation: 6,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
child: Padding(
padding: const EdgeInsets.all(20.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
CheckboxListTile(
title: Text(
'Do you need actions?',
style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
),
value: state.needsAction,
onChanged: (value) {
context.read<EditDetailMakerBloc>().add(ToggleNeedsActionEvent(value!));
setState(() {
_showMainReportDetails = false;
_showFieldsConfigurationContent = false;
});
},
activeColor: Colors.blueAccent,
),
if (state.needsAction) ...[
const Divider(height: 30, thickness: 1),
Text(
'Add Actions (Max 5)',
style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
),
const SizedBox(height: 12),
Wrap(
spacing: 10,
runSpacing: 10,
children: [
_buildButton(
text: 'Add Form',
color: Colors.purple,
icon: Icons.assignment,
onPressed: canAddMoreActions && !formExists ? () => context.read<EditDetailMakerBloc>().add(AddAction('form', _uuid.v4())) : null,
),
_buildButton(
text: 'Add Print',
color: Colors.orange,
icon: Icons.print,
onPressed: canAddMoreActions ? () => context.read<EditDetailMakerBloc>().add(AddAction('print', _uuid.v4())) : null,
),
_buildButton(
text: 'Add Report',
color: Colors.teal,
icon: Icons.table_chart,
onPressed: canAddMoreActions ? () => context.read<EditDetailMakerBloc>().add(AddAction('table', _uuid.v4())) : null,
),
_buildButton(
text: 'Add Graph',
color: Colors.indigo,
icon: Icons.bar_chart,
onPressed: canAddMoreActions ? () => context.read<EditDetailMakerBloc>().add(AddAction('graph', _uuid.v4())) : null,
),
],
),
const SizedBox(height: 20),
if (state.actions.isNotEmpty && _tabController != null)
Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
TabBar(
controller: _tabController,
isScrollable: true,
labelColor: Colors.blueAccent,
unselectedLabelColor: Colors.black54,
indicatorSize: TabBarIndicatorSize.label,
indicatorWeight: 3.0,
labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
unselectedLabelStyle: GoogleFonts.poppins(),
tabs: state.actions.map((action) {
final controller = _actionNameControllers[action['id']];
return Tab(
child: ListenableBuilder(
listenable: controller!,
builder: (context, child) {
return Text(
controller.text.isNotEmpty ? controller.text : (action['name'] ?? 'Action'),
overflow: TextOverflow.ellipsis,
);
},
),
);
}).toList(),
),
const Divider(height: 1, thickness: 1),
SizedBox(
height: 500,
child: TabBarView(
controller: _tabController,
children: state.actions.map((action) {
return SingleChildScrollView(
key: ValueKey(action['id']),
padding: const EdgeInsets.only(top: 16),
child: _buildActionConfigCard(context, state, action),
);
}).toList(),
),
),
],
)
else
Center(
child: Padding(
padding: const EdgeInsets.only(top: 20.0),
child: Text(
'No actions added yet.',
style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
),
),
),
],
],
),
),
);
}

Widget _buildActionConfigCard(
BuildContext context,
EditDetailMakerState state,
Map<String, dynamic> action,
) {
final actionId = action['id'] as String;
final actionType = action['type'] as String;
final List<dynamic> params = action['params'] as List<dynamic>? ?? [];
final bool isPrintOrTable = actionType == 'print' || actionType == 'table';
final bool isTableAction = actionType == 'table';
final List<String> apiParameters = state.apiParametersCache[actionId] ?? [];
final bool isFetchingParams = state.isFetchingApiParams && state.currentActionIdFetching == actionId;

final List<String> reportLabels = state.allReportLabels;
final List<String> allApiFieldNames = state.fields;

IconData typeIcon;
Color typeColor;
String headerText;
switch (actionType) {
case 'form':
typeIcon = Icons.assignment;
typeColor = Colors.purple;
headerText = 'Form Action';
break;
case 'print':
typeIcon = Icons.print;
typeColor = Colors.orange;
headerText = 'Print Action';
break;
case 'table':
typeIcon = Icons.table_chart;
typeColor = Colors.teal;
headerText = 'Report Action';
break;
case 'graph':
typeIcon = Icons.bar_chart;
typeColor = Colors.indigo;
headerText = 'Graph Action';
break;
default:
typeIcon = Icons.help_outline;
typeColor = Colors.grey;
headerText = 'Unknown Action';
}

final String selectedTemplate = action['printTemplate']?.toString() ?? PrintTemplateForMaker.premium.name;
final String selectedColor = action['printColor']?.toString() ?? 'Blue';
final String selectedGraphType = action['graphType']?.toString() ?? 'Line Chart';

return Card(
color: Colors.white,
elevation: 0,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
child: Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Row(
children: [
Icon(typeIcon, color: typeColor, size: 24),
const SizedBox(width: 8),
Text(
headerText,
style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: typeColor),
),
],
),
IconButton(
icon: const Icon(Icons.delete, color: Colors.redAccent),
onPressed: () {
context.read<EditDetailMakerBloc>().add(RemoveAction(actionId));
},
),
],
),
const Divider(),
const SizedBox(height: 8),
_buildTextField(
controller: _actionNameControllers[actionId]!,
label: '${StringCasingExtension(actionType).toCapitalized()} Name',
icon: Icons.title,
onChanged: (value) {
context.read<EditDetailMakerBloc>().add(UpdateActionConfig(actionId, 'name', value));
},
),
const SizedBox(height: 16),

if (actionType == 'graph') ...[
DropdownButtonFormField<String>(
decoration: InputDecoration(
labelText: 'Graph Type',
labelStyle: GoogleFonts.poppins(),
prefixIcon: const Icon(Icons.show_chart, color: Colors.blueAccent),
filled: true,
fillColor: Colors.white.withOpacity(0.9),
border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
),
style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
value: selectedGraphType,
items: ["Line Chart", "Bar Chart", "Pie Chart"].map((type) {
return DropdownMenuItem<String>(
value: type,
child: Text(type, style: GoogleFonts.poppins()),
);
}).toList(),
onChanged: (value) {
if (value != null) {
context.read<EditDetailMakerBloc>().add(UpdateActionConfig(actionId, 'graphType', value));
}
},
dropdownColor: Colors.white,
),
const SizedBox(height: 16),
_GraphAxisField(
key: ValueKey('${actionId}_x_axis'),
allApiFieldNames: allApiFieldNames,
actionId: actionId,
fieldKey: 'xAxisField',
initialValue: action['xAxisField'] as String? ?? '',
label: 'X-Axis Field',
icon: Icons.arrow_right_alt,
),
const SizedBox(height: 16),
_GraphAxisField(
key: ValueKey('${actionId}_y_axis'),
allApiFieldNames: allApiFieldNames,
actionId: actionId,
fieldKey: 'yAxisField',
initialValue: action['yAxisField'] as String? ?? '',
label: 'Y-Axis Field',
icon: Icons.arrow_upward,
),
],

if (isTableAction) ...[
Autocomplete<String>(
key: _autocompleteFieldKeys.putIfAbsent(actionId, () => GlobalKey()),
optionsBuilder: (TextEditingValue textEditingValue) {
if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
return reportLabels.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase())).toList();
},
onSelected: (String selection) {
_actionReportLabelControllers[actionId]!.text = selection;
context.read<EditDetailMakerBloc>().add(UpdateTableActionReport(actionId, selection));
},
fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
controller.text = _actionReportLabelControllers[actionId]!.text;
controller.selection = _actionReportLabelControllers[actionId]!.selection;
return _buildTextField(
controller: controller,
label: 'Select Report Name',
icon: Icons.description,
focusNode: focusNode,
onChanged: (value) {
_actionReportLabelControllers[actionId]!.text = value;
context.read<EditDetailMakerBloc>().add(UpdateActionConfig(actionId, 'reportLabel', value));
},
);
},
optionsViewBuilder: (context, onSelected, options) {
return LayoutBuilder(builder: (context, constraints) {
final renderBox = _autocompleteFieldKeys[actionId]?.currentContext?.findRenderObject() as RenderBox?;
final width = renderBox?.size.width ?? constraints.maxWidth;
return Align(
alignment: Alignment.topLeft,
child: Material(
elevation: 4.0,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
child: SizedBox(
width: width,
child: ListView.builder(
padding: EdgeInsets.zero,
shrinkWrap: true,
itemCount: options.length,
itemBuilder: (context, index) {
final originalOption = options.elementAt(index);
final displayedOption = originalOption.replaceAll(RegExp(r'\bTable\b', caseSensitive: false), 'Report');
return ListTile(
title: Text(displayedOption, style: GoogleFonts.poppins()),
onTap: () => onSelected(originalOption),
);
},
),
),
),
);
});
},
),
const SizedBox(height: 16),
_buildTextField(
controller: _actionApiControllers[actionId]!,
label: 'Resolved API URL',
icon: Icons.link,
readOnly: true,
onChanged: (value) {},
),
],

if (actionType == 'print') ...[
_buildTextField(
controller: _actionApiControllers[actionId]!,
label: 'API URL',
icon: Icons.link,
onChanged: (value) {
context.read<EditDetailMakerBloc>().add(UpdateActionConfig(actionId, 'api', value));
Future.delayed(const Duration(milliseconds: 700), () {
if (_actionApiControllers[actionId]?.text == value && value.isNotEmpty && Uri.tryParse(value)?.isAbsolute == true) {
context.read<EditDetailMakerBloc>().add(ExtractParametersFromUrl(actionId, value));
} else if (value.isEmpty) {
final currentAction = state.actions.firstWhere((element) => element['id'] == actionId);
if (currentAction['params'] != null && (currentAction['params'] as List).isNotEmpty) {
context.read<EditDetailMakerBloc>().add(UpdateActionConfig(actionId, 'params', []));
}
}
});
},
),
const SizedBox(height: 16),
DropdownButtonFormField<String>(
decoration: InputDecoration(
labelText: 'Print Template',
labelStyle: GoogleFonts.poppins(),
filled: true,
fillColor: Colors.white,
border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
),
style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
value: PrintTemplateForMaker.values.any((e) => e.name == selectedTemplate) ? selectedTemplate : PrintTemplateForMaker.premium.name,
items: PrintTemplateForMaker.values.map((template) => DropdownMenuItem<String>(
value: template.name,
child: Text(template.displayName, style: GoogleFonts.poppins()),
)).toList(),
onChanged: (value) => context.read<EditDetailMakerBloc>().add(UpdateActionConfig(actionId, 'printTemplate', value!)),
dropdownColor: Colors.white,
),
const SizedBox(height: 16),
DropdownButtonFormField<String>(
decoration: InputDecoration(
labelText: 'Theme Color',
labelStyle: GoogleFonts.poppins(),
filled: true,
fillColor: Colors.white,
border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
),
style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
value: predefinedPdfColors.keys.any((key) => key == selectedColor) ? selectedColor : 'Blue',
items: predefinedPdfColors.keys.map((colorName) => DropdownMenuItem<String>(
value: colorName,
child: Row(
children: [
Container(width: 20, height: 20, color: predefinedPdfColors[colorName]!.toFlutterColor()),
const SizedBox(width: 8),
Text(colorName, style: GoogleFonts.poppins()),
],
),
)).toList(),
onChanged: (value) => context.read<EditDetailMakerBloc>().add(UpdateActionConfig(actionId, 'printColor', value!)),
dropdownColor: Colors.white,
),
],

if (isPrintOrTable) ...[
const SizedBox(height: 16),
Row(
children: [
Text('Dynamic Parameters:', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
const Spacer(),
IconButton(
icon: const Icon(Icons.add_circle_outline, color: Colors.green),
onPressed: () => context.read<EditDetailMakerBloc>().add(AddActionParameter(actionId, _uuid.v4())),
),
],
),
if (isFetchingParams)
const Padding(
padding: EdgeInsets.symmetric(vertical: 12.0),
child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
SubtleLoader(),
SizedBox(width: 8),
Text('Fetching parameters...', style: TextStyle(color: Colors.grey)),
]),
)
else if (action['api']?.isNotEmpty == true && apiParameters.isEmpty)
Padding(
padding: const EdgeInsets.symmetric(vertical: 8.0),
child: Text(
'No parameters found for this API, or API is invalid.',
style: GoogleFonts.poppins(color: Colors.redAccent),
),
),
Column(
children: params.map<Widget>((param) {
final paramId = param['id'] as String;
if (!_actionParamValueControllers.containsKey(actionId) || !_actionParamValueControllers[actionId]!.containsKey(paramId)) {
_actionParamValueControllers[actionId] ??= {};
_actionParamValueControllers[actionId]![paramId] = TextEditingController(text: param['parameterValue']?.toString() ?? '');
_actionParamValueControllers[actionId]![paramId]!.addListener(_ensureCursorAtEnd(_actionParamValueControllers[actionId]![paramId]!));
}
final paramValueController = _actionParamValueControllers[actionId]![paramId]!;
return Padding(
padding: const EdgeInsets.symmetric(vertical: 8.0),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(
flex: 3,
child: DropdownButtonFormField<String>(
decoration: InputDecoration(
labelText: 'Parameter Name',
labelStyle: GoogleFonts.poppins(),
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
),
style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
value: apiParameters.contains(param['parameterName']) ? param['parameterName'] : null,
items: apiParameters.map((String name) => DropdownMenuItem<String>(value: name, child: Text(name, style: GoogleFonts.poppins()))).toList(),
onChanged: (String? newValue) {
if (newValue != null) {
context.read<EditDetailMakerBloc>().add(UpdateActionParameter(actionId, paramId, 'parameterName', newValue));
}
},
),
),
const SizedBox(width: 8),
Expanded(
flex: 2,
child: Autocomplete<String>(
optionsBuilder: (TextEditingValue textEditingValue) {
if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
return allApiFieldNames.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase())).toList();
},
onSelected: (String selection) {
FocusScope.of(context).unfocus();
paramValueController.text = selection;
context.read<EditDetailMakerBloc>().add(UpdateActionParameter(actionId, paramId, 'parameterValue', selection));
},
fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
controller.text = paramValueController.text;
return TextField(
controller: controller,
focusNode: focusNode,
style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
decoration: InputDecoration(
labelText: 'Value',
labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
filled: true,
fillColor: Colors.white.withOpacity(0.9),
border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
),
onChanged: (value) {
paramValueController.text = value;
context.read<EditDetailMakerBloc>().add(UpdateActionParameter(actionId, paramId, 'parameterValue', value));
},
);
},
optionsViewBuilder: (context, onSelected, options) {
final renderBox = context.findRenderObject() as RenderBox?;
final width = renderBox?.size.width ?? MediaQuery.of(context).size.width * 0.4;
return Align(
alignment: Alignment.topLeft,
child: Material(
elevation: 4.0,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
child: SizedBox(
width: width,
child: ListView.builder(
padding: EdgeInsets.zero,
shrinkWrap: true,
itemCount: options.length,
itemBuilder: (context, index) {
final option = options.elementAt(index);
return ListTile(title: Text(option, style: GoogleFonts.poppins()), onTap: () => onSelected(option));
},
),
),
),
);
},
),
),
IconButton(
icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
onPressed: () => context.read<EditDetailMakerBloc>().add(RemoveActionParameter(actionId, paramId)),
),
],
),
);
}).toList(),
),
],
],
),
),
);
}

Widget _buildTextField({
required TextEditingController controller,
String? label,
FocusNode? focusNode,
TextInputType? keyboardType,
Function(String)? onChanged,
IconData? icon,
bool readOnly = false,
}) {
return TextField(
controller: controller,
focusNode: focusNode,
keyboardType: keyboardType,
onChanged: onChanged,
readOnly: readOnly,
style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
decoration: InputDecoration(
labelText: label,
labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 22) : null,
filled: true,
fillColor: Colors.white.withOpacity(0.9),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: BorderSide(color: Colors.grey[500]!, width: 1),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: BorderSide(color: Colors.grey[500]!, width: 1),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
),
contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
floatingLabelBehavior: FloatingLabelBehavior.auto,
),
);
}

Widget _buildButton({
required String text,
required Color color,
required VoidCallback? onPressed,
IconData? icon,
}) {
return ElevatedButton(
onPressed: onPressed,
style: ElevatedButton.styleFrom(
backgroundColor: color,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
elevation: 4,
shadowColor: color.withOpacity(0.3),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
if (icon != null) ...[
Icon(icon, color: Colors.white, size: 20),
const SizedBox(width: 8),
],
Text(
text,
style: GoogleFonts.poppins(
color: Colors.white,
fontWeight: FontWeight.w600,
fontSize: 16,
),
),
],
),
);
}

Widget _buildFieldSelection(BuildContext context, EditDetailMakerState state) {
return Padding(
padding: const EdgeInsets.all(20.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: [
Text(
'Select Fields',
style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
),
const SizedBox(height: 16),
Flexible(
fit: FlexFit.loose,
child: SingleChildScrollView(
physics: const ClampingScrollPhysics(),
child: Wrap(
spacing: 12,
runSpacing: 12,
children: state.fields.map((field) {
final isSelected = state.selectedFields.any((f) => f['Field_name'] == field);
final isPreselected = state.preselectedFields.any((f) => f['Field_name'] == field);

return FilterChip(
label: Text(
field,
style: GoogleFonts.poppins(
fontSize: 13,
fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
color: isSelected ? Colors.white : Colors.black87,
),
),
selected: isSelected,
selectedColor: isPreselected && isSelected
? Colors.blueAccent
    : isSelected
? Colors.green
    : null,
checkmarkColor: Colors.white,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(20),
side: BorderSide(
color: isPreselected && isSelected
? Colors.blueAccent
    : isSelected
? Colors.green
    : Colors.grey.shade300,
),
),
backgroundColor: Colors.white,
labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
onSelected: (selected) {
if (selected) {
context.read<EditDetailMakerBloc>().add(SelectField(field));
} else {
context.read<EditDetailMakerBloc>().add(DeselectField(field));
}
},
);
}).toList(),
),
),
),
if (state.selectedFields.isNotEmpty) ...[
const SizedBox(height: 24),
Center(
child: _buildButton(
text: 'Configure Selected Fields',
color: Colors.blueAccent,
onPressed: _toggleConfigPanel,
icon: Icons.arrow_forward,
),
),
],
],
),
);
}

Widget _buildFieldConfigPanel(BuildContext context, EditDetailMakerState state) {
final sortedFields = List<Map<String, dynamic>>.from(state.selectedFields)
..sort((a, b) {
final aSeq = a['Sequence_no'] as int? ?? 9999;
final bSeq = b['Sequence_no'] as int? ?? 9999;
return aSeq.compareTo(bSeq);
});

return ConstrainedBox(
constraints: BoxConstraints(
maxHeight: MediaQuery.of(context).size.height * 0.6,
minHeight: 200,
),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
width: 220,
decoration: BoxDecoration(
color: Colors.white,
borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
boxShadow: [
BoxShadow(
color: Colors.grey.withOpacity(0.1),
blurRadius: 8,
offset: const Offset(2, 0),
),
],
),
child: Column(
children: [
Expanded(
child: ListView.builder(
padding: const EdgeInsets.symmetric(vertical: 12),
itemCount: sortedFields.length,
itemBuilder: (context, index) {
final field = sortedFields[index];
final isSelected = state.currentField?['Field_name'] == field['Field_name'];
return Column(
children: [
Padding(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
child: Material(
color: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent,
borderRadius: BorderRadius.circular(10),
child: InkWell(
borderRadius: BorderRadius.circular(10),
onTap: () {
if (state.currentField != null) {
final currentFieldSeqControllerValue = int.tryParse(_sequenceController.text);
if (currentFieldSeqControllerValue != null &&
currentFieldSeqControllerValue >= 0 &&
(state.currentField!['Sequence_no'] != currentFieldSeqControllerValue)) {
context.read<EditDetailMakerBloc>().add(
UpdateFieldConfig('Sequence_no', currentFieldSeqControllerValue),
);
}
if (state.currentField!['is_api_driven'] == true &&
_apiDrivenUrlController.text != (state.currentField!['api_url']?.toString() ?? '')) {
context.read<EditDetailMakerBloc>().add(
UpdateFieldApiUrl(_apiDrivenUrlController.text),
);
}
if (state.currentField!['is_user_filling'] == true &&
_userFillingUrlController.text != (state.currentField!['updated_url']?.toString() ?? '')) {
context.read<EditDetailMakerBloc>().add(
UpdateFieldUserFillingUrl(_userFillingUrlController.text),
);
}
}
context.read<EditDetailMakerBloc>().add(UpdateCurrentField(field));
},
child: Padding(
padding: const EdgeInsets.all(12),
child: Row(
children: [
CircleAvatar(
radius: 16,
backgroundColor: isSelected ? Colors.blueAccent : Colors.grey.shade300,
child: Text(
'${field['Sequence_no'] ?? 'N/A'}',
style: GoogleFonts.poppins(
color: isSelected ? Colors.white : Colors.black87,
fontWeight: FontWeight.w600,
fontSize: 12,
),
),
),
const SizedBox(width: 12),
Expanded(
child: Text(
field['Field_name'],
style: GoogleFonts.poppins(
fontSize: 15,
fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
color: isSelected ? Colors.blueAccent : Colors.black87,
),
overflow: TextOverflow.ellipsis,
),
),
IconButton(
icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
onPressed: () {
context.read<EditDetailMakerBloc>().add(DeselectField(field['Field_name']));
},
),
],
),
),
),
),
),
if (index < sortedFields.length - 1)
Divider(
height: 1,
thickness: 1,
color: Colors.grey.shade300,
indent: 24,
endIndent: 24,
),
],
);
},
),
),
Padding(
padding: const EdgeInsets.all(10.0),
child: ElevatedButton(
onPressed: _returnToFieldSelection,
style: ElevatedButton.styleFrom(
backgroundColor: Colors.blueAccent,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
elevation: 4,
shadowColor: Colors.blueAccent.withOpacity(0.3),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(Icons.arrow_back, color: Colors.white, size: 20),
const SizedBox(width: 8),
Text(
'Back to Selection',
style: GoogleFonts.poppins(
color: Colors.white,
fontWeight: FontWeight.w600,
fontSize: 14,
),
),
],
),
),
),
],
),
),
Container(
width: 1,
color: Colors.grey.shade300,
),
Expanded(
child: Padding(
padding: const EdgeInsets.all(20.0),
child: state.currentField == null
? Center(
child: Text(
'Select a field from the left panel to configure its properties.',
style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
textAlign: TextAlign.center,
),
)
    : SingleChildScrollView(
child: Column(
children: _buildFieldConfigWidgets(context, state),
),
),
),
),
],
),
);
}

List<Widget> _buildFieldConfigWidgets(BuildContext context, EditDetailMakerState state) {
if (state.currentField == null) {
return [];
}

final bool isApiDriven = state.currentField!['is_api_driven'] ?? false;
final bool isUserFilling = state.currentField!['is_user_filling'] ?? false;
final List<dynamic> payloadStructure = state.currentField!['payload_structure'] ?? [];
final List<String> fieldApiParameters = state.fieldApiParametersCache[state.currentField!['Field_name']] ?? [];
final bool isFetchingFieldApiParams = state.isFetchingFieldApiParams && state.currentFieldIdFetchingParams == state.currentField!['Field_name'];
final List<String> allApiFieldNames = state.fields;

return [
_buildTextField(
controller: _fieldNameController,
label: 'Field Name',
icon: Icons.text_fields,
readOnly: true,
onChanged: (value) {},
),
const SizedBox(height: 16),
_buildTextField(
controller: _fieldLabelController,
label: 'Field Label',
icon: Icons.label_outline,
onChanged: (value) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Field_label', value));
},
),
const SizedBox(height: 16),
CheckboxListTile(
title: Text('Is API Driven?', style: GoogleFonts.poppins()),
value: isApiDriven,
activeColor: Colors.blueAccent,
onChanged: isUserFilling
? null
    : (value) {
context.read<EditDetailMakerBloc>().add(ToggleFieldApiDriven(value!));
},
),
if (isApiDriven) ...[
const SizedBox(height: 16),
_buildTextField(
controller: _apiDrivenUrlController,
label: 'API URL',
icon: Icons.link,
onChanged: (value) {
context.read<EditDetailMakerBloc>().add(UpdateFieldApiUrl(value));
Future.delayed(const Duration(milliseconds: 700), () {
if (_apiDrivenUrlController.text == value && value.isNotEmpty && Uri.tryParse(value)?.isAbsolute == true) {
context.read<EditDetailMakerBloc>().add(ExtractFieldParametersFromUrl(state.currentField!['Field_name'] as String, value));
} else if (value.isEmpty) {
final currentFieldInBloc = state.currentField!;
if (currentFieldInBloc['field_params'] != null && (currentFieldInBloc['field_params'] as List).isNotEmpty) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('field_params', []));
}
}
});
},
),
const SizedBox(height: 16),
Text('API Parameters:', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
const SizedBox(height: 8),
if (isFetchingFieldApiParams)
const Padding(
padding: EdgeInsets.symmetric(vertical: 12.0),
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
SubtleLoader(),
SizedBox(width: 8),
Text('Fetching parameters...', style: TextStyle(color: Colors.grey)),
],
),
)
else if (_apiDrivenUrlController.text.isNotEmpty && fieldApiParameters.isEmpty && !isFetchingFieldApiParams)
Padding(
padding: const EdgeInsets.symmetric(vertical: 8.0),
child: Text(
'No parameters found in this API URL, or URL is invalid.',
style: GoogleFonts.poppins(color: Colors.redAccent),
),
)
else if (fieldApiParameters.isNotEmpty)
Column(
children: (state.currentField!['field_params'] as List<dynamic>?)?.map<Widget>((param) {
final paramId = param['id'] as String;

return Padding(
padding: const EdgeInsets.symmetric(vertical: 8.0),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(
flex: 3,
child: DropdownButtonFormField<String>(
decoration: InputDecoration(
labelText: 'Parameter Name',
labelStyle: GoogleFonts.poppins(),
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
),
style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
value: fieldApiParameters.contains(param['parameterName']) ? param['parameterName'] : null,
items: fieldApiParameters.map((String name) {
return DropdownMenuItem<String>(
value: name,
child: Text(name, style: GoogleFonts.poppins()),
);
}).toList(),
onChanged: (String? newValue) {
if (newValue != null) {
final List<Map<String, dynamic>> updatedParams =
(state.currentField!['field_params'] as List).map((p) {
return p['id'] == paramId ? {...p, 'parameterName': newValue} : p;
}).toList().cast<Map<String, dynamic>>();
context.read<EditDetailMakerBloc>().add(
UpdateFieldConfig('field_params', updatedParams),
);
}
},
),
),
const SizedBox(width: 8),
Expanded(
flex: 2,
child: Autocomplete<String>(
optionsBuilder: (TextEditingValue textEditingValue) {
if (textEditingValue.text.isEmpty) {
return const Iterable<String>.empty();
}
return allApiFieldNames.where((String option) {
return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
}).toList();
},
onSelected: (String selection) {
FocusScope.of(context).unfocus();
final List<Map<String, dynamic>> updatedParams =
(state.currentField!['field_params'] as List).map((p) {
return p['id'] == paramId ? {...p, 'parameterValue': selection} : p;
}).toList().cast<Map<String, dynamic>>();
context.read<EditDetailMakerBloc>().add(
UpdateFieldConfig('field_params', updatedParams),
);
},
fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
controller.text = param['parameterValue']?.toString() ?? '';
return TextField(
controller: controller,
focusNode: focusNode,
style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
decoration: InputDecoration(
labelText: 'Map to Field',
labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
filled: true,
fillColor: Colors.white.withOpacity(0.9),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
),
contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
),
onChanged: (value) {
final List<Map<String, dynamic>> updatedParams =
(state.currentField!['field_params'] as List).map((p) {
return p['id'] == paramId ? {...p, 'parameterValue': value} : p;
}).toList().cast<Map<String, dynamic>>();
context.read<EditDetailMakerBloc>().add(
UpdateFieldConfig('field_params', updatedParams),
);
},
);
},
optionsViewBuilder: (context, onSelected, options) {
final renderBox = context.findRenderObject() as RenderBox?;
final width = renderBox?.size.width ?? MediaQuery.of(context).size.width * 0.4;
return Align(
alignment: Alignment.topLeft,
child: Material(
elevation: 4.0,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
child: SizedBox(
width: width,
child: ListView.builder(
padding: EdgeInsets.zero,
shrinkWrap: true,
itemCount: options.length,
itemBuilder: (context, index) {
final option = options.elementAt(index);
return ListTile(
title: Text(option, style: GoogleFonts.poppins()),
onTap: () {
onSelected(option);
},
);
},
),
),
),
);
},
),
),
IconButton(
icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
onPressed: () {
final List<Map<String, dynamic>> updatedParams = (state.currentField!['field_params'] as List)
    .where((p) => p['id'] != paramId)
    .toList()
    .cast<Map<String, dynamic>>();
context.read<EditDetailMakerBloc>().add(
UpdateFieldConfig('field_params', updatedParams),
);
},
),
],
),
);
}).toList() ??
[],
),
],
const SizedBox(height: 16),
CheckboxListTile(
title: Text('Is User Filling?', style: GoogleFonts.poppins()),
value: isUserFilling,
activeColor: Colors.blueAccent,
onChanged: isApiDriven
? null
    : (value) {
context.read<EditDetailMakerBloc>().add(ToggleFieldUserFilling(value!));
},
),
if (isUserFilling) ...[
const SizedBox(height: 16),
_buildTextField(
controller: _userFillingUrlController,
label: 'Updated URL',
icon: Icons.link,
onChanged: (value) {
context.read<EditDetailMakerBloc>().add(UpdateFieldUserFillingUrl(value));
},
),
const SizedBox(height: 16),
Row(
children: [
Expanded(
flex: 3,
child: Text('Payload Structure:', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
),
const Spacer(),
IconButton(
icon: const Icon(Icons.add_circle_outline, color: Colors.green),
onPressed: () {
context.read<EditDetailMakerBloc>().add(AddFieldPayloadParameter(_uuid.v4()));
},
),
],
),
const SizedBox(height: 8),
Column(
children: payloadStructure.map<Widget>((param) {
final paramId = param['id'] as String;
final String fieldName = state.currentField!['Field_name'] as String;

final keyController = _userFillingPayloadKeyControllers.putIfAbsent(paramId, () => TextEditingController());
final staticValueController = _userFillingPayloadStaticValueControllers.putIfAbsent(paramId, () => TextEditingController());

return _PayloadParameterItem(
key: ValueKey(paramId),
param: Map<String, dynamic>.from(param),
allApiFieldNames: allApiFieldNames,
keyController: keyController,
staticValueController: staticValueController,
fieldName: fieldName,
onUpdate: (updatedPropertyMap) {
context.read<EditDetailMakerBloc>().add(
UpdateFieldPayloadParameter(
paramId,
updatedPropertyMap['property_name'] as String,
updatedPropertyMap['property_value'],
),
);
},
onToggleUserInput: (value) {
context.read<EditDetailMakerBloc>().add(
ToggleFieldPayloadParameterUserInput(fieldName, paramId, value),
);
},
onRemove: () {
context.read<EditDetailMakerBloc>().add(RemoveFieldPayloadParameter(paramId));
},
);
}).toList(),
),
] else if (!isApiDriven && !isUserFilling) ...[
const SizedBox(height: 16),
_buildTextField(
controller: _sequenceController,
label: 'Sequence No',
icon: Icons.sort,
keyboardType: TextInputType.number,
onChanged: (value) {
final parsed = int.tryParse(value);
if (parsed != null && parsed >= 0) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Sequence_no', parsed));
} else if (value.isEmpty) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Sequence_no', null));
}
},
),
const SizedBox(height: 16),
_buildTextField(
controller: _widthController,
label: 'Width',
icon: Icons.width_normal,
keyboardType: TextInputType.number,
onChanged: (value) {
final parsed = int.tryParse(value);
if (parsed != null && parsed >= 0) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('width', parsed));
} else if (value.isEmpty) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('width', null));
}
},
),
const SizedBox(height: 16),
CheckboxListTile(
title: Text('Total', style: GoogleFonts.poppins()),
value: state.currentField!['Total'] ?? false,
activeColor: Colors.blueAccent,
onChanged: (value) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Total', value!));
},
),
const SizedBox(height: 16),
CheckboxListTile(
title: Text('Breakpoint', style: GoogleFonts.poppins()),
value: state.currentField!['Breakpoint'] ?? false,
activeColor: Colors.blueAccent,
onChanged: (value) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Breakpoint', value!));
},
),
if (state.currentField!['Total'] == true) ...[
const SizedBox(height: 16),
CheckboxListTile(
title: Text('Subtotal', style: GoogleFonts.poppins()),
value: state.currentField!['SubTotal'] ?? false,
activeColor: Colors.blueAccent,
onChanged: (value) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('SubTotal', value!));
},
),
],
const SizedBox(height: 16),
CheckboxListTile(
title: Text('Image', style: GoogleFonts.poppins()),
value: state.currentField!['image'] ?? false,
activeColor: Colors.blueAccent,
onChanged: (value) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('image', value!));
},
),
const Divider(
color: Colors.grey,
thickness: 2,
height: 32,
),
DropdownButtonFormField<String>(
decoration: InputDecoration(
labelText: 'Number Alignment',
labelStyle: GoogleFonts.poppins(),
filled: true,
fillColor: Colors.white,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: BorderSide(color: Colors.grey[500]!, width: 1),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: BorderSide(color: Colors.grey[500]!, width: 1),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
),
contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
),
style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
value: (state.currentField!['num_alignment']?.toString().toLowerCase() ?? 'left').contains('left')
? 'left'
    : ((state.currentField!['num_alignment']?.toString().toLowerCase() ?? 'left').contains('center') ? 'center' : 'right'),
items: const [
DropdownMenuItem(value: 'left', child: Text('Left')),
DropdownMenuItem(value: 'center', child: Text('Center')),
DropdownMenuItem(value: 'right', child: Text('Right')),
]
    .map((item) => DropdownMenuItem(
value: item.value,
child: Text(StringCasingExtension(item.value!).toCapitalized(), style: GoogleFonts.poppins()),
))
    .toList(),
onChanged: (value) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('num_alignment', value!));
},
dropdownColor: Colors.white,
),
const SizedBox(height: 16),
CheckboxListTile(
title: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Indian Number Format', style: GoogleFonts.poppins()),
Text(
'Example: 1234555 becomes 12,34,555',
style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
),
],
),
value: state.currentField!['num_format'] ?? false,
activeColor: Colors.blueAccent,
onChanged: (value) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('num_format', value!));
},
),
const SizedBox(height: 16),
_buildTextField(
controller: _decimalPointsController,
label: 'Decimal Points',
icon: Icons.numbers,
keyboardType: TextInputType.number,
onChanged: (value) {
final parsed = int.tryParse(value);
if (parsed != null && parsed >= 0) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('decimal_points', parsed));
} else if (value.isEmpty) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('decimal_points', null));
}
},
),
if (state.currentField!['Field_name'].toString().toLowerCase().contains('date')) ...[
const SizedBox(height: 16),
CheckboxListTile(
title: Text('Time', style: GoogleFonts.poppins()),
value: state.currentField!['time'] ?? false,
activeColor: Colors.blueAccent,
onChanged: (value) {
context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('time', value!));
},
),
],
],
];
}
}

// NEW: A dedicated, debounced autocomplete field for graph axes.
class _GraphAxisField extends StatefulWidget {
final List<String> allApiFieldNames;
final String actionId;
final String fieldKey;
final String initialValue;
final String label;
final IconData icon;

const _GraphAxisField({
Key? key,
required this.allApiFieldNames,
required this.actionId,
required this.fieldKey,
required this.initialValue,
required this.label,
required this.icon,
}) : super(key: key);

@override
State<_GraphAxisField> createState() => _GraphAxisFieldState();
}

class _GraphAxisFieldState extends State<_GraphAxisField> {
Timer? _debounceTimer;

@override
void dispose() {
_debounceTimer?.cancel();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Autocomplete<String>(
initialValue: TextEditingValue(text: widget.initialValue),
optionsBuilder: (TextEditingValue textEditingValue) {
// Show all options (sorted) when empty, otherwise filter.
if (textEditingValue.text.isEmpty) {
return widget.allApiFieldNames;
}
return widget.allApiFieldNames.where((String option) {
return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
});
},
onSelected: (String selection) {
FocusScope.of(context).unfocus();
_debounceTimer?.cancel();
context.read<EditDetailMakerBloc>().add(UpdateActionConfig(widget.actionId, widget.fieldKey, selection));
},
fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
return TextField(
controller: textEditingController,
focusNode: focusNode,
style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
decoration: InputDecoration(
labelText: widget.label,
labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
prefixIcon: Icon(widget.icon, color: Colors.blueAccent, size: 22),
filled: true,
fillColor: Colors.white.withOpacity(0.9),
border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
),
onChanged: (value) {
if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
_debounceTimer = Timer(const Duration(milliseconds: 400), () {
if(mounted) {
context.read<EditDetailMakerBloc>().add(UpdateActionConfig(widget.actionId, widget.fieldKey, value));
}
});
},
);
},
optionsViewBuilder: (context, onSelected, options) {
final renderBox = context.findRenderObject() as RenderBox?;
final width = renderBox?.size.width ?? MediaQuery.of(context).size.width * 0.4;
return Align(
alignment: Alignment.topLeft,
child: Material(
elevation: 4.0,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
child: SizedBox(
width: width,
child: ListView.builder(
padding: EdgeInsets.zero,
shrinkWrap: true,
itemCount: options.length,
itemBuilder: (context, index) {
final option = options.elementAt(index);
return ListTile(title: Text(option, style: GoogleFonts.poppins()), onTap: () => onSelected(option));
},
),
),
),
);
},
);
}
}

// Unchanged _PayloadParameterItem...
class _PayloadParameterItem extends StatefulWidget {
final Map<String, dynamic> param;
final List<String> allApiFieldNames;
final Function(Map<String, dynamic> updatedParam) onUpdate;
final Function(bool value) onToggleUserInput;
final VoidCallback onRemove;
final TextEditingController keyController;
final TextEditingController staticValueController;
final String fieldName;

const _PayloadParameterItem({
Key? key,
required this.param,
required this.allApiFieldNames,
required this.onUpdate,
required this.onToggleUserInput,
required this.onRemove,
required this.keyController,
required this.staticValueController,
required this.fieldName,
}) : super(key: key);

@override
__PayloadParameterItemState createState() => __PayloadParameterItemState();
}

class __PayloadParameterItemState extends State<_PayloadParameterItem> {
Timer? _debounceTimer;

@override
void initState() {
super.initState();
widget.keyController.addListener(_onKeyChanged);
widget.staticValueController.addListener(_onStaticValueChanged);
}

void _onKeyChanged() {
if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
_debounceTimer = Timer(const Duration(milliseconds: 300), () {
if (widget.keyController.text != (widget.param['key']?.toString() ?? '')) {
widget.onUpdate({'property_name': 'key', 'property_value': widget.keyController.text});
}
});
}

void _onStaticValueChanged() {
if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
_debounceTimer = Timer(const Duration(milliseconds: 300), () {
if (widget.staticValueController.text != (widget.param['value']?.toString() ?? '')) {
widget.onUpdate({'property_name': 'value', 'property_value': widget.staticValueController.text});
}
});
}

@override
void dispose() {
_debounceTimer?.cancel();
widget.keyController.removeListener(_onKeyChanged);
widget.staticValueController.removeListener(_onStaticValueChanged);
super.dispose();
}

@override
Widget build(BuildContext context) {
final String valueType = widget.param['value_type']?.toString() ?? 'dynamic';
final bool isUserInput = widget.param['is_user_input'] ?? false;

return Padding(
padding: const EdgeInsets.symmetric(vertical: 8.0),
child: Column(
children: [
Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(
flex: 1,
child: TextField(
controller: widget.keyController,
style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
decoration: InputDecoration(
labelText: 'Key',
labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
),
),
),
const SizedBox(width: 8),
Expanded(
flex: 2,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
DropdownButtonFormField<String>(
decoration: InputDecoration(
labelText: 'Value Type',
labelStyle: GoogleFonts.poppins(),
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
),
value: valueType,
items: const [
DropdownMenuItem(value: 'static', child: Text('Static')),
DropdownMenuItem(value: 'dynamic', child: Text('Dynamic (Map to Field)')),
]
    .map((item) => DropdownMenuItem<String>(
value: item.value,
child: Text(item.child.toString(), style: GoogleFonts.poppins()),
))
    .toList(),
onChanged: (String? newValue) {
if (newValue != null) {
widget.onUpdate({
'property_name': 'value_type',
'property_value': newValue,
});
widget.onUpdate({
'property_name': 'value',
'property_value': '',
});
}
},
),
if (valueType == 'static')
Padding(
padding: const EdgeInsets.only(top: 8.0),
child: TextField(
controller: widget.staticValueController,
style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
decoration: InputDecoration(
labelText: 'Literal Value',
labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
),
),
)
else if (valueType == 'dynamic')
Padding(
padding: const EdgeInsets.only(top: 8.0),
child: Autocomplete<String>(
initialValue: TextEditingValue(text: widget.param['value']?.toString() ?? ''),
optionsBuilder: (TextEditingValue textEditingValue) {
if (textEditingValue.text.isEmpty) {
return const Iterable<String>.empty();
}
return widget.allApiFieldNames.where((String option) {
return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
}).toList();
},
onSelected: (String selection) {
FocusScope.of(context).unfocus();
widget.onUpdate({
'property_name': 'value',
'property_value': selection,
});
_debounceTimer?.cancel();
},
fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
if (!focusNode.hasFocus && controller.text != (widget.param['value']?.toString() ?? '')) {
controller.text = widget.param['value']?.toString() ?? '';
controller.selection = TextSelection.fromPosition(
TextPosition(offset: controller.text.length),
);
}
return TextField(
controller: controller,
focusNode: focusNode,
style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
decoration: InputDecoration(
labelText: 'Select Field',
labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
filled: true,
fillColor: Colors.white.withOpacity(0.9),
border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
),
onChanged: (value) {
if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
_debounceTimer = Timer(const Duration(milliseconds: 300), () {
widget.onUpdate({
'property_name': 'value',
'property_value': value,
});
});
},
);
},
optionsViewBuilder: (context, onSelected, options) {
final renderBox = context.findRenderObject() as RenderBox?;
final width = renderBox?.size.width ?? MediaQuery.of(context).size.width * 0.4;
return Align(
alignment: Alignment.topLeft,
child: Material(
elevation: 4.0,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
child: SizedBox(
width: width,
child: ListView.builder(
padding: EdgeInsets.zero,
shrinkWrap: true,
itemCount: options.length,
itemBuilder: (context, index) {
final option = options.elementAt(index);
return ListTile(
title: Text(option, style: GoogleFonts.poppins()),
onTap: () {
onSelected(option);
},
);
},
),
),
),
);
},
),
),
],
),
),
IconButton(
icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
onPressed: widget.onRemove,
),
],
),
CheckboxListTile(
title: Text(
'User Input Field (Only one per API call)',
style: GoogleFonts.poppins(fontSize: 14),
),
value: isUserInput,
onChanged: (value) {
widget.onToggleUserInput(value!);
},
controlAffinity: ListTileControlAffinity.leading,
contentPadding: EdgeInsets.zero,
activeColor: Colors.blueAccent,
),
const SizedBox(height: 8),
],
),
);
}
}
