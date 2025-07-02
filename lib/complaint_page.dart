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
import 'SetupScreen/setup_bloc.dart';
import 'SetupScreen/setup_screen.dart';
import 'SparePart/spare_UI.dart';
import 'SparePart/spare_bloc.dart';

// Import the DashboardBuilderScreen
import 'ReportDashboard/DashboardScreen/dashboard_builder_screen.dart';


class ComplaintPage extends StatelessWidget {
  ComplaintPage({super.key});

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
            padding: const EdgeInsets.only(left: 8.0),
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
          "Aquare-Report Builder",
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
                    children: const [
                      Icon(Icons.dashboard, size: 50, color: Colors.white),
                      SizedBox(height: 10),
                      Text(
                        'Aquare-Report Builder',
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
              // Dashboard Listing Menu Item
              _createDrawerItem(
                icon: Icons.dashboard,
                text: 'Dashboard Viewer',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BlocProvider.value(
                        value: context.read<DashboardBuilderBloc>(),
                        child: DashboardListingScreen(
                            apiService:
                            context.read<ReportAPIService>()),
                      ),
                    ),
                  );
                },
              ),
              // NEW: Create Dashboard Menu Item
              _createDrawerItem(
                icon: Icons.add,
                text: 'Create New Dashboard',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BlocProvider.value(
                        value: context.read<DashboardBuilderBloc>(),
                        child: DashboardBuilderScreen(
                          apiService: context
                              .read<ReportAPIService>(),
                          dashboardToEdit:
                          null,
                        ),
                      ),
                    ),
                  );
                },
              ),
              _createDrawerItem(
                icon: Icons.dynamic_feed,
                text: 'API Generator',
                onTap: () {
                  Navigator.pop(context);
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
                text: ' Report Designer',
                onTap: () {
                  Navigator.pop(context);
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
                text: 'Report generator',
                onTap: () {
                  Navigator.pop(context);
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
                text: 'Report Setup',
                onTap: () {
                  Navigator.pop(context);
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
              // --- NEW: Setup Option ---
              const Divider(), // A visual separator
              _createDrawerItem(
                icon: Icons.settings_input_component, // A good icon for setup/configuration
                text: 'Database Setup', // Clear and concise text
                onTap: () {
                  Navigator.pop(context); // Close the drawer first
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BlocProvider.value(
                        // Provide the SetupBloc to the SetupScreen
                        value: context.read<SetupBloc>(),
                        child: const SetupScreen(),
                      ),
                    ),
                  );
                },
              ),
              // --- End NEW Setup Option ---
              // const Divider(),
              // _createDrawerItem(
              //   icon: Icons.settings,
              //   text: 'Settings',
              //   onTap: () {
              //     Navigator.pop(context);
              //   },
              // ),
            ],
          ),
        ),
      ),
      body: const Center(
        child: Text('Aquare-Report Builder'),
      ),
    );
  }
}