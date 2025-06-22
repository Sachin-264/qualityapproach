import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'APIgenerator/api_generator.dart';
import 'ReportDashboard/DashboardBloc/dashboard_builder_bloc.dart';
import 'ReportDashboard/DashboardScreen/dashboard_listing_screen.dart';
import 'ReportDynamic/ReportAPIService.dart';
import 'ReportUtils/Appbar.dart'; // Assuming your custom AppBar is here

// Existing Bloc imports (check your exact paths for these!)
import 'CustomerRetail/RetailBloc.dart';
import 'CustomerRetail/RetailFilter.dart';
import 'EditSparePart/editsparebloc.dart';
import 'EditSparePart/editspareui.dart';
import 'NEWREPORT/EDIT/filterreport.dart';
import 'NEWREPORT/EDIT/filterreportbloc.dart';
import 'NEWREPORT/ReportEdit/edit_bloc.dart';
// import 'NEWREPORT/ReportEdit/editReport_bloc.dart'; // Not in provided code
import 'NEWREPORT/ReportEdit/edit_ui.dart';
import 'NEWREPORT/report.dart';
import 'NEWREPORT/report_bloc.dart';
import 'QualtyChecks/qualityFilter.dart';
import 'QualtyChecks/qualityFilterbloc.dart';
import 'ReportDynamic/ReportAdmin/ReportAdminBloc.dart';
import 'ReportDynamic/ReportAdmin/ReportAdminUI.dart';
import 'ReportDynamic/ReportGenerator/ReportUI.dart';
import 'ReportDynamic/ReportGenerator/Reportbloc.dart';
import 'ReportDynamic/Report_Make.dart';
import 'ReportDynamic/Report_MakeBLoc.dart';
import 'SaleVsTarget/sale_TargetBloc.dart';
import 'SaleVsTarget/sale_targetUI.dart';
import 'SparePart/spare_UI.dart';
import 'SparePart/spare_bloc.dart';




class ComplaintPage extends StatelessWidget {
  ComplaintPage({super.key}); // Add super.key for consistency

  ListTile _createDrawerItem({
    required IconData icon,
    required String text,
    required GestureTapCallback onTap,
  }) {
    return ListTile(
      title: Row(
        children: <Widget>[
          Icon(icon),
          Padding(
            padding: const EdgeInsets.only(left: 8.0), // Use const for padding
            child: Text(text),
          )
        ],
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        title: const Text(
        "Complaint Entry List",
        style: TextStyle(
        color: Colors.white,
    ),
    ),
    backgroundColor: Colors.blue,
    leading: Builder(
    builder: (context) {
    return IconButton(
    icon: const Icon(Icons.menu, color: Colors.white),
    onPressed: () {
    Scaffold.of(context).openDrawer();
    },
    );
    },
    ),
    ),
    drawer: Drawer(
    child: Container(
    color: Colors.blue[50],
    child: ListView(
    padding: EdgeInsets.zero,
    children: [
    DrawerHeader(
    decoration: BoxDecoration(
    color: Colors.blue,
    borderRadius: const BorderRadius.only(
    bottomLeft: Radius.circular(20),
    bottomRight: Radius.circular(20),
    ),
    ),
    child: Center(
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: const [ // Use const for column children if possible
    Icon(Icons.dashboard, size: 50, color: Colors.white),
    SizedBox(height: 10),
    Text(
    'Complaint Management',
    style: TextStyle(
    fontSize: 20,
    color: Colors.white,
    fontWeight: FontWeight.bold,
    ),
    ),
    ],
    ),
    ),
    ),
    _createDrawerItem(
    icon: Icons.home,
    text: 'Complaint Page',
    onTap: () {
    Navigator.pop(context);
    },
    ),
    _createDrawerItem(
    icon: Icons.search,
    text: 'Customer Report',
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => BlocProvider.value(
    value: context.read<RetailCustomerBloc>(),
    child: RetailCustomerPage(),
    ),
    ),
    );
    },
    ),
    _createDrawerItem(
    icon: Icons.high_quality,
    text: 'Quality Checks',
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => BlocProvider.value(
    value: context.read<BranchBloc>(),
    child: QualityFilterPage(),
    ),
    ),
    );
    },
    ),
    _createDrawerItem(
    icon: Icons.edit,
    text: 'Edit Report',
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => BlocProvider.value(
    value: context.read<FilterBloc>(),
    child: FilterUI(),
    ),
    ),
    );
    },
    ),
    _createDrawerItem(
    icon: Icons.repeat_on,
    text: 'Report check',
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => BlocProvider.value(
    value: context.read<ReportBloc>(),
    child: ReportPage(),
    ),
    ),
    );
    },
    ),
    _createDrawerItem(
    icon: Icons.edit,
    text: 'Real Edit Report',
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => BlocProvider.value(
    value: context.read<EditBloc>(),
    child: EditPage(),
    ),
    ),
    );
    },
    ),
    _createDrawerItem(
    icon: Icons.edit,
    text: 'SparePart',
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => BlocProvider.value(
    value: context.read<SparePartBloc>(),
    child: SparePartScreen(),
    ),
    ),
    );
    },
    ),
    _createDrawerItem(
    icon: Icons.edit,
    text: 'EditSparePart',
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => BlocProvider.value(
    value: context.read<EditSpareBloc>(),
    child: EditSpareScreen(),
    ),
    ),
    );
    },
    ),
    // NEW Dashboard Menu Item
    _createDrawerItem(
    icon: Icons.dashboard, // Using dashboard icon
    text: 'Dashboard Builder', // Clear text for builder
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => BlocProvider.value(
    // IMPORTANT: Provide the DashboardBuilderBloc
    value: context.read<DashboardBuilderBloc>(),
    child: DashboardListingScreen(
    apiService:
    context.read<ReportAPIService>()), // Pass API service
    ),
    ),
    );
    },
    ),
    _createDrawerItem(
    icon: Icons.satellite_alt_outlined,
    text: 'SaleVsTarget',
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => BlocProvider.value(
    value: context.read<SaleTargetBloc>(),
    child: SaleTargetUI(),
    ),
    ),
    );
    },
    ),
    _createDrawerItem(
    icon: Icons.dynamic_feed,
    text: 'API Generator',
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => const ApiGeneratorPage(),
    ),
    );
    },
    ),
    _createDrawerItem(
    icon: Icons.satellite_alt_outlined,
    text: 'dynamic Report Builder ',
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => BlocProvider.value(
    value: context.read<ReportMakerBloc>(),
    child: ReportMakerUI(),
    ),
    ),
    );
    },
    ),
    _createDrawerItem(
    icon: Icons.access_time,
    text: 'dynamic Report generator ',
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => BlocProvider.value(
    value: context.read<ReportBlocGenerate>(),
    child: ReportUI(),
    ),
    ),
    );
    },
    ),
    _createDrawerItem(
    icon: Icons.search,
    text: 'Report Admin',
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => BlocProvider.value(
    value: context.read<ReportAdminBloc>(),
    child: ReportAdminUI(),
    ),
    ),
    );
    },
    ),
    const Divider(), // Use const for Divider
    _createDrawerItem(
    icon: Icons.settings,
    text: 'Settings',
    onTap: () {
    Navigator.pop(context);
    },
    ),
    ],
    ),
    ),),
    body: const Center( // Use const for simple Text widget
    child: Text('Complaint Page'),
    ));
  }
}