import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math; // Import for math functions like log and pow

// Assuming AppBarWidget is defined elsewhere and correctly implemented.
import '../../../ReportUtils/Appbar.dart';

class GraphView extends StatefulWidget {
final String graphTitle;
final String graphType;
final String xAxisField;
final String yAxisField;
final List<Map<String, dynamic>> reportData;

const GraphView({
super.key,
required this.graphTitle,
required this.graphType,
required this.xAxisField,
required this.yAxisField,
required this.reportData,
});

@override
State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView> {
int? touchedIndex;
String? selectedPieCategory;
List<Map<String, dynamic>> filteredDataForPie = [];

final List<Color> _chartColors = const [
Color(0xFF42A5F5), // Blue
Color(0xFFFF7043), // Orange
Color(0xFF66BB6A), // Green
Color(0xFFAB47BC), // Purple
Color(0xFF26C6DA), // Cyan
Color(0xFFFFCA28), // Amber
Color(0xFF78909C), // Blue Grey
Color(0xFFEF5350), // Red
Color(0xFF8D6E63), // Brown
Color(0xFF9CCC65), // Light Green
Color(0xFF5C6BC0), // Indigo
Color(0xFFFFD54F), // Yellow
];

@override
void initState() {
super.initState();
debugPrint('[GraphView] initState: Initializing for ${widget.graphType}...');
debugPrint('[GraphView] initState: xAxisField: "${widget.xAxisField}", yAxisField: "${widget.yAxisField}"');
debugPrint('[GraphView] initState: reportData size: ${widget.reportData.length}');
if (widget.reportData.isNotEmpty) {
debugPrint('[GraphView] initState: Sample data point (first): ${widget.reportData.first}');
debugPrint('[GraphView] initState: Sample X-value (first): ${widget.reportData.first[widget.xAxisField]}');
debugPrint('[GraphView] initState: Sample Y-value (first): ${widget.reportData.first[widget.yAxisField]}');
}
}

// Helper function to format numbers for axis labels and tooltips
String _formatNumber(double number) {
if (number.isNaN || number.isInfinite) {
debugPrint('[GraphView] _formatNumber: WARNING: Encountered NaN or Infinite number: $number. Returning "N/A".');
return 'N/A';
}
// Adjust formatting for large numbers for better readability
if (number >= 1000000) {
return '${(number / 1000000).toStringAsFixed(1)}M'; // Millions
} else if (number >= 1000) {
return '${(number / 1000).toStringAsFixed(1)}K'; // Thousands
}
// For smaller numbers, use compact format or direct representation
// If the number has no fractional part, display as integer
if (number == number.toInt().toDouble()) {
return number.toInt().toString();
}
return NumberFormat.compact().format(number); // Uses K, M for large numbers automatically
}

@override
Widget build(BuildContext context) {
debugPrint('[GraphView] build: Starting build method.');
Widget chartWidget;

if (widget.reportData.isEmpty) {
debugPrint('[GraphView] build: No report data found. Displaying message.');
chartWidget = Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.bar_chart_rounded, size: 80, color: Colors.grey[400]),
const SizedBox(height: 16),
Text(
"No data available to build the graph.",
style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
textAlign: TextAlign.center,
),
Text(
"Please check your report filters or data source.",
style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
textAlign: TextAlign.center,
),
],
),
);
} else {
debugPrint('[GraphView] build: Report data found. Selecting chart type...');
switch (widget.graphType) {
case 'Line Chart':
debugPrint('[GraphView] build: Matched "Line Chart".');
chartWidget = _buildLineChart();
break;
case 'Bar Chart':
debugPrint('[GraphView] build: Matched "Bar Chart".');
chartWidget = _buildBarChart();
break;
case 'Pie Chart':
debugPrint('[GraphView] build: Matched "Pie Chart".');
chartWidget = _buildPieChartWithFilter();
break;
default:
debugPrint('[GraphView] build: Matched "default".');
chartWidget = Center(
child: Text(
'Unsupported graph type: ${widget.graphType}',
style: GoogleFonts.poppins(color: Colors.red, fontSize: 16),
textAlign: TextAlign.center,
),
);
}
}

debugPrint('[GraphView] build: Returning Scaffold.');
return Scaffold(
appBar: AppBarWidget(
title: widget.graphTitle,
onBackPress: () {
debugPrint('[GraphView] AppBarWidget: Back button pressed.');
Navigator.pop(context);
},
),
body: Padding(
padding: const EdgeInsets.all(8.0),
child: Card(
elevation: 8,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
color: Colors.white,
child: Padding(
padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
child: Column(
children: [
Expanded(
child: chartWidget,
),
],
),
),
),
),
);
}

// --- Chart Building Functions ---

Widget _buildLineChart() {
debugPrint('[GraphView] _buildLineChart: Building Line Chart...');
final spots = <FlSpot>[];
double maxY = 0;
for (int i = 0; i < widget.reportData.length; i++) {
final row = widget.reportData[i];
final yValueRaw = row[widget.yAxisField];
final double y = double.tryParse(yValueRaw?.toString() ?? '0') ?? 0;

if (y.isNaN || y.isInfinite) {
debugPrint('[GraphView] _buildLineChart: WARNING: Invalid Y-value for index $i ("$yValueRaw"). Setting to 0.0.');
spots.add(FlSpot(i.toDouble(), 0.0));
} else {
spots.add(FlSpot(i.toDouble(), y));
if (y > maxY) maxY = y;
}
debugPrint('[GraphView] _buildLineChart: Added spot $i: (x: ${i.toDouble()}, y: $yValueRaw -> $y)');
}
debugPrint('[GraphView] _buildLineChart: Processed ${spots.length} spots.');

if (spots.isEmpty) {
debugPrint('[GraphView] _buildLineChart: No valid data points to draw Line Chart.');
return Center(child: Text('No valid data available for Line Chart.', style: GoogleFonts.poppins(color: Colors.grey[600])));
}

// Calculate dynamic width for horizontal scrolling
final double minChartWidth = MediaQuery.of(context).size.width - (2 * 24) - (16 + 24); // Screen width minus page padding and inner card padding
// Increased pixels per data point to allow more space for X-axis labels, especially when rotated.
final double calculatedChartWidth = widget.reportData.length * 120.0; // Ample space per data point for labels
final double finalChartWidth = math.max(minChartWidth, calculatedChartWidth); // Ensure it's at least screen width

return SingleChildScrollView(
scrollDirection: Axis.horizontal,
child: SizedBox(
width: finalChartWidth,
// Removed fixed height here, allowing Expanded parent to control vertical space
child: LineChart(
LineChartData(
lineTouchData: LineTouchData(
handleBuiltInTouches: true,
touchTooltipData: LineTouchTooltipData(
fitInsideHorizontally: true,
fitInsideVertically: true,
getTooltipColor: (spot) => Colors.blueGrey.withOpacity(0.9),
tooltipPadding: const EdgeInsets.all(8),
getTooltipItems: (touchedSpots) {
return touchedSpots.map((spot) {
final index = spot.x.toInt();
if (index < 0 || index >= widget.reportData.length) return null;
final xLabel = widget.reportData[index][widget.xAxisField]?.toString() ?? 'N/A';
final yLabel = _formatNumber(spot.y);
debugPrint('[GraphView] LineChart Touch: Tooltip for index $index (X: "$xLabel", Y: "$yLabel")');
return LineTooltipItem(
'${widget.xAxisField}: $xLabel\n${widget.yAxisField}: $yLabel',
const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
);
}).whereType<LineTooltipItem>().toList();
},
),
),
gridData: FlGridData(
show: true,
drawVerticalLine: true,
drawHorizontalLine: true,
getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
horizontalInterval: _calculateOptimalInterval(spots.map((s) => s.y).toList()),
),
titlesData: _buildAxisTitles(maxY: maxY, dataLength: widget.reportData.length),
borderData: FlBorderData(
show: true,
border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
),
lineBarsData: [
LineChartBarData(
spots: spots,
isCurved: true,
gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF66BB6A)]),
barWidth: 3,
isStrokeCapRound: true,
dotData: FlDotData(
show: true,
getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
radius: 4,
color: Colors.blueAccent,
strokeColor: Colors.white,
strokeWidth: 2,
),
),
belowBarData: BarAreaData(
show: true,
gradient: LinearGradient(
colors: [Color(0xFF42A5F5).withOpacity(0.3), Color(0xFF66BB6A).withOpacity(0)],
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
),
),
),
],
minY: 0,
maxY: maxY * 1.15, // Add a bit of padding above max Y
),
duration: const Duration(milliseconds: 800),
curve: Curves.easeOut,
),
),
);
}

Widget _buildBarChart() {
debugPrint('[GraphView] _buildBarChart: Building Bar Chart...');
final barGroups = <BarChartGroupData>[];
double maxY = 0;
final double barWidth = 20; // Fixed width for each bar for calculation

for (int i = 0; i < widget.reportData.length; i++) {
final row = widget.reportData[i];
final yValueRaw = row[widget.yAxisField];
final double y = double.tryParse(yValueRaw?.toString() ?? '0') ?? 0;

if (y.isNaN || y.isInfinite) {
debugPrint('[GraphView] _buildBarChart: WARNING: Invalid Y-value for index $i ("$yValueRaw"). Setting to 0.0.');
barGroups.add(BarChartGroupData(
x: i,
barRods: [
BarChartRodData(
toY: 0.0,
color: _chartColors[i % _chartColors.length],
width: barWidth,
borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
borderSide: const BorderSide(color: Colors.white, width: 1.5),
)
],
));
} else {
barGroups.add(BarChartGroupData(
x: i,
barRods: [
BarChartRodData(
toY: y,
gradient: _barsGradient,
width: barWidth,
borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
borderSide: const BorderSide(color: Colors.white, width: 1.5),
)
],
));
if (y > maxY) maxY = y;
}
debugPrint('[GraphView] _buildBarChart: Added bar group $i: (x: $i, y: $yValueRaw -> $y)');
}
debugPrint('[GraphView] _buildBarChart: Processed ${barGroups.length} groups.');

if (barGroups.isEmpty) {
debugPrint('[GraphView] _buildBarChart: No valid bar groups to draw Bar Chart.');
return Center(child: Text('No valid data available for Bar Chart.', style: GoogleFonts.poppins(color: Colors.grey[600])));
}

// Calculate dynamic width for horizontal scrolling
final double minChartWidth = MediaQuery.of(context).size.width - (2 * 24) - (16 + 24); // Screen width minus page padding and inner card padding
// Calculate width based on number of bars + spacing. Increased spacing for rotated labels.
final double calculatedChartWidth = (widget.reportData.length * (barWidth + 60.0)); // Bar width + 60px spacing for labels
final double finalChartWidth = math.max(minChartWidth, calculatedChartWidth);

return SingleChildScrollView(
scrollDirection: Axis.horizontal,
child: SizedBox(
width: finalChartWidth,
// Removed fixed height here, allowing Expanded parent to control vertical space
child: BarChart(
BarChartData(
barTouchData: BarTouchData(
touchTooltipData: BarTouchTooltipData(
fitInsideHorizontally: true,
fitInsideVertically: true,
getTooltipColor: (group) => Colors.grey[800]!,
tooltipPadding: const EdgeInsets.all(8),
getTooltipItem: (group, groupIndex, rod, rodIndex) {
final xLabel = widget.reportData[group.x.toInt()][widget.xAxisField]?.toString() ?? 'N/A';
final yLabel = _formatNumber(rod.toY);
debugPrint('[GraphView] BarChart Touch: Tooltip for group $groupIndex (X: "$xLabel", Y: "$yLabel")');
return BarTooltipItem(
'${widget.xAxisField}: $xLabel\n${widget.yAxisField}: $yLabel',
const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
);
},
),
),
titlesData: _buildAxisTitles(maxY: maxY, dataLength: widget.reportData.length),
borderData: FlBorderData(
show: true,
border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
),
barGroups: barGroups,
gridData: FlGridData(
show: true,
drawVerticalLine: true,
drawHorizontalLine: true,
getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
horizontalInterval: _calculateOptimalInterval(barGroups.expand((g) => g.barRods.map((r) => r.toY)).toList()),
),
minY: 0,
maxY: maxY * 1.15,
),
duration: const Duration(milliseconds: 800),
curve: Curves.easeOut,
),
),
);
}

// Gradient for Bar Chart rods
LinearGradient get _barsGradient => const LinearGradient(
colors: [Color(0xFFAB47BC), Color(0xFF42A5F5)],
begin: Alignment.bottomCenter,
end: Alignment.topCenter,
);

// Calculates an optimal interval for axis labels based on data values
double _calculateOptimalInterval(List<double> values) {
if (values.isEmpty) return 1.0;
final double maxVal = values.reduce((a, b) => a > b ? a : b);
if (maxVal == 0) return 1.0;

// Aims for about 5-10 intervals
double interval = maxVal / 5;
if (interval == 0) return 1.0;

// Find a 'nice' step value (1, 2, 5, 10, 20, 50, etc.)
double step = math.pow(10, (math.log(interval) / math.log(10)).floorToDouble()).toDouble();
if (interval / step < 2) {
interval = step;
} else if (interval / step < 5) {
interval = 2 * step;
} else {
interval = 5 * step;
}
return interval;
}

Widget _buildPieChartWithFilter() {
debugPrint('[GraphView] _buildPieChart: Aggregating data...');
final Map<String, double> aggregatedData = {};
for (final row in widget.reportData) {
final category = row[widget.xAxisField]?.toString() ?? 'Unknown';
final valueRaw = row[widget.yAxisField];
final double value = double.tryParse(valueRaw?.toString() ?? '0.0') ?? 0.0;

if (value.isNaN || value.isInfinite) {
debugPrint('[GraphView] _buildPieChart: WARNING: Invalid value for Pie Chart for category "$category" ("$valueRaw"). Skipping this data point.');
continue;
}
aggregatedData[category] = (aggregatedData[category] ?? 0) + value;
debugPrint('[GraphView] _buildPieChart: Aggregating for category "$category", added value: $value, current total: ${aggregatedData[category]}');
}
debugPrint('[GraphView] _buildPieChart: Aggregated data: $aggregatedData');

if (aggregatedData.isEmpty) {
debugPrint('[GraphView] _buildPieChart: Aggregated data is empty. Displaying message.');
return Center(
child: Text(
"No data to aggregate for Pie Chart.",
style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
textAlign: TextAlign.center,
),
);
}

return Column(
children: [
Expanded(
// Adjust flex based on whether the table is shown
flex: selectedPieCategory == null ? 2 : 1,
child: Row(
children: <Widget>[
Expanded(
child: PieChart(
PieChartData(
pieTouchData: PieTouchData(
touchCallback: (FlTouchEvent event, pieTouchResponse) {
setState(() {
if (!event.isInterestedForInteractions ||
pieTouchResponse == null ||
pieTouchResponse.touchedSection == null) {
touchedIndex = -1;
selectedPieCategory = null;
filteredDataForPie = [];
debugPrint('[GraphView] Pie touch: Resetting selection (no interaction or no touched section).');
return;
}
touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
selectedPieCategory = aggregatedData.keys.elementAt(touchedIndex!);
filteredDataForPie = widget.reportData
    .where((row) => row[widget.xAxisField]?.toString() == selectedPieCategory)
    .toList();
debugPrint('[GraphView] Pie slice selected: "$selectedPieCategory", found ${filteredDataForPie.length} rows for filtering.');
});
},
),
borderData: FlBorderData(show: false),
sectionsSpace: 4,
centerSpaceRadius: 60, // Slightly smaller to give more space to slices
sections: _buildPieChartSections(aggregatedData),
),
duration: const Duration(milliseconds: 800),
curve: Curves.easeOut,
),
),
const SizedBox(width: 28),
_buildLegend(aggregatedData.keys.toList()),
],
),
),
if (selectedPieCategory != null)
Expanded(
flex: 1, // Allocate space for the filtered table
child: Column(
children: [
Padding(
padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0), // Padding adjusted
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
'Data for "$selectedPieCategory"',
style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
),
TextButton.icon(
onPressed: () {
setState(() {
selectedPieCategory = null;
filteredDataForPie = [];
touchedIndex = -1;
debugPrint('[GraphView] Pie selection cleared by button.');
});
},
icon: const Icon(Icons.clear_all, size: 20),
label: Text('Clear Selection', style: GoogleFonts.poppins(fontSize: 14)),
style: TextButton.styleFrom(
foregroundColor: Colors.blueGrey[700],
),
),
],
),
),
Expanded(
child: _buildFilteredDataTable(),
),
],
),
),
],
);
}

Widget _buildFilteredDataTable() {
debugPrint('[GraphView] _buildFilteredDataTable: Building table for "$selectedPieCategory" with ${filteredDataForPie.length} rows.');
if (filteredDataForPie.isEmpty) {
return Center(
child: Text(
'No detailed data for "$selectedPieCategory".',
style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
textAlign: TextAlign.center,
),
);
}

return Padding(
padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add horizontal padding for the table
child: SingleChildScrollView(
child: SingleChildScrollView(
// Nested SingleChildScrollView for horizontal scroll within table
scrollDirection: Axis.horizontal,
child: DataTable(
columnSpacing: 20,
dataRowHeight: 48, // Consistent row height
headingRowHeight: 56, // Consistent heading row height
headingRowColor: MaterialStateProperty.all(Colors.grey[100]), // Lighter heading background
columns: [
DataColumn(label: Text(widget.xAxisField, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey[900]))),
DataColumn(label: Text(widget.yAxisField, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey[900])), numeric: true),
],
rows: filteredDataForPie.map((row) {
final xValue = row[widget.xAxisField]?.toString() ?? '';
final yValueRaw = row[widget.yAxisField]?.toString() ?? '0';
final double yValue = double.tryParse(yValueRaw) ?? 0;
debugPrint('[GraphView] Filtered Table Row: X: "$xValue", Y: "$yValueRaw" -> ${yValue}');
return DataRow(
cells: [
DataCell(Text(xValue, style: GoogleFonts.poppins(fontSize: 13))),
DataCell(Text(_formatNumber(yValue), style: GoogleFonts.poppins(fontSize: 13))),
],
);
}).toList(),
),
),
),
);
}

// Builds the sections for the Pie Chart based on aggregated data
List<PieChartSectionData> _buildPieChartSections(Map<String, double> aggregatedData) {
final total = aggregatedData.values.fold(0.0, (sum, item) => sum + item);
List<PieChartSectionData> sections = [];
int i = 0;
debugPrint('[GraphView] _buildPieChartSections: Total aggregated value: $total');
aggregatedData.forEach((key, value) {
final isTouched = i == touchedIndex;
final radius = isTouched ? 70.0 : 60.0;
final fontSize = isTouched ? 18.0 : 16.0; // Enlarge font for touched section
final percentage = total > 0 ? (value / total * 100) : 0;
debugPrint('[GraphView] _buildPieChartSections: Section $i for "$key": value=$value, percentage=${percentage.toStringAsFixed(1)}%, radius=$radius');

sections.add(PieChartSectionData(
color: _chartColors[i % _chartColors.length],
value: value,
title: '${percentage.toStringAsFixed(1)}%',
radius: radius,
titleStyle: GoogleFonts.poppins(
fontSize: fontSize,
fontWeight: FontWeight.bold,
color: Colors.white,
shadows: const [
Shadow(color: Colors.black26, blurRadius: 2)
]),
));
i++;
});
debugPrint('[GraphView] _buildPieChartSections: Generated ${sections.length} sections.');
return sections;
}

// Builds the legend for the Pie Chart
Widget _buildLegend(List<String> keys) {
debugPrint('[GraphView] _buildLegend: Building legend for ${keys.length} items.');
return Column(
mainAxisAlignment: MainAxisAlignment.center,
crossAxisAlignment: CrossAxisAlignment.start,
children: List.generate(keys.length, (index) {
debugPrint('[GraphView] _buildLegend: Legend item $index: ${keys[index]}');
return Padding(
padding: const EdgeInsets.symmetric(vertical: 4.0),
child: Row(
children: [
Container(width: 16, height: 16, color: _chartColors[index % _chartColors.length]),
const SizedBox(width: 8),
Flexible(child: Text(keys[index], style: GoogleFonts.poppins(fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 2,)),
],
),
);
}),
);
}

// Builds the X and Y axis titles and labels for Line and Bar Charts
FlTitlesData _buildAxisTitles({double maxY = 0, required int dataLength}) {
debugPrint('[GraphView] _buildAxisTitles: Building axis titles. MaxY: $maxY, Data Length: $dataLength');

bool shouldRotateXLabels = false;
double xAxisInterval = 1;

// Heuristic for X-axis label display:
if (dataLength > 6 && dataLength <= 15) { // Rotate for moderate number of points
shouldRotateXLabels = true;
xAxisInterval = 1;
} else if (dataLength > 15) { // Use interval and rotate for many points
shouldRotateXLabels = true;
xAxisInterval = (dataLength / 8).ceilToDouble(); // Show roughly 8-10 labels
if (xAxisInterval == 0) xAxisInterval = 1; // Prevent division by zero
debugPrint('[GraphView] _buildAxisTitles: X-axis: large data, setting interval to $xAxisInterval');
} else {
shouldRotateXLabels = false;
xAxisInterval = 1;
}

final double yAxisInterval = _calculateOptimalInterval([maxY]);

return FlTitlesData(
show: true,
rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
bottomTitles: AxisTitles(
sideTitles: SideTitles(
showTitles: true,
reservedSize: shouldRotateXLabels ? 100 : 60, // More space for rotated labels
interval: xAxisInterval,
getTitlesWidget: (value, meta) {
final index = value.toInt();
if (index < 0 || index >= widget.reportData.length) {
return const SizedBox.shrink();
}

String xLabel = widget.reportData[index][widget.xAxisField]?.toString() ?? '';
// Truncate long labels for horizontal display if not rotating
if (xLabel.length > 15 && !shouldRotateXLabels) {
xLabel = '${xLabel.substring(0, 12)}...';
}
debugPrint('[GraphView] getTitlesWidget (bottom): Index $index, Label: "$xLabel", shouldRotate: $shouldRotateXLabels');

Widget textWidget = Text(
xLabel,
style: GoogleFonts.poppins(color: Colors.grey[700], fontWeight: FontWeight.normal, fontSize: 12),
textAlign: TextAlign.center,
);

if (shouldRotateXLabels) {
return SideTitleWidget(
meta:meta,
space: 10,
child: RotatedBox(
quarterTurns: -1, // Rotate 90 degrees counter-clockwise
child: textWidget,
),
);
}
return SideTitleWidget(
meta:meta,
space: 10,
child: textWidget,
);
},
),
axisNameWidget: Padding(
padding: const EdgeInsets.only(top: 10.0),
child: Text(widget.xAxisField, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey[800])),
),
),
leftTitles: AxisTitles(
sideTitles: SideTitles(
showTitles: true,
reservedSize: 60, // Increased slightly for readability of longer numbers
getTitlesWidget: (value, meta) {
final formattedValue = _formatNumber(value);
debugPrint('[GraphView] getTitlesWidget (left): Raw value: $value, Formatted: "$formattedValue"');
return Text(formattedValue, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]));
},
interval: yAxisInterval,
),
axisNameWidget: Text(widget.yAxisField, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey[800])),
),
);
}
}

// Extension for math functions (already present, good for clarity)
extension on double {
double log() => math.log(this);
double pow(num exponent) => math.pow(this, exponent).toDouble();
}
