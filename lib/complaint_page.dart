import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:excel/excel.dart'; // For Excel export
import 'package:pdf/pdf.dart'; // For PDF export
import 'package:pdf/widgets.dart' as pw; // For PDF export
import 'package:path_provider/path_provider.dart'; // For file storage
import 'dart:io'; // For file operations
import 'package:file_picker/file_picker.dart'; // For file picking
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qualityapproach/CustomerRetail/RetailBloc.dart';
import 'package:qualityapproach/Dashboard/Dashboard.bloc.dart';
import 'package:qualityapproach/Dashboard/Dashboard.dart';
import 'package:qualityapproach/EditSparePart/editsparebloc.dart';
import 'package:qualityapproach/EditSparePart/editspareui.dart';
import 'package:qualityapproach/NEWREPORT/EDIT/filterreport.dart';
import 'package:qualityapproach/NEWREPORT/ReportEdit/edit_bloc.dart';
import 'package:qualityapproach/NEWREPORT/ReportEdit/edit_ui.dart';
import 'package:qualityapproach/NEWREPORT/report.dart';
import 'package:qualityapproach/NEWREPORT/report_bloc.dart';
import 'package:qualityapproach/QualtyChecks/qualityFilter.dart';
import 'package:qualityapproach/QualtyChecks/qualityFilterbloc.dart';
import 'package:qualityapproach/SaleVsTarget/sale_TargetBloc.dart';
import 'package:qualityapproach/SaleVsTarget/sale_targetUI.dart';
import 'package:qualityapproach/SparePart/spare_UI.dart';
import 'package:qualityapproach/SparePart/spare_bloc.dart';
// ignore: depend_on_referenced_packages
import 'package:universal_html/html.dart' as html;

import 'CustomerRetail/RetailFilter.dart';
import 'NEWREPORT/EDIT/filterreportbloc.dart';

class ComplaintPage extends StatelessWidget {
  ComplaintPage();

  ListTile _createDrawerItem(
      {required IconData icon,
      required String text,
      required GestureTapCallback onTap}) {
    return ListTile(
      title: Row(
        children: <Widget>[
          Icon(icon),
          Padding(
            padding: EdgeInsets.only(left: 8.0),
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
          title: Text(
            "Complaint Entry List",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.blue,
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: Icon(Icons.menu, color: Colors.white),
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
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                      )
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
                            child:EditPage(),
                          ),
                        )
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
                            child:SparePartScreen(),
                          ),
                        )
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
                            child:EditSpareScreen()
                          ),
                        )
                    );
                  },
                ),
                _createDrawerItem(
                  icon: Icons.edit,
                  text: 'Dashboard',
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BlocProvider.value(
                              value: context.read<DashboardBloc>(),
                              child:DashboardPage()
                          ),
                        )
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
                              child:SaleTargetUI(),
                          ),
                        )
                    );
                  },
                ),
                Divider(),
                _createDrawerItem(
                  icon: Icons.settings,
                  text: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
        body: Center(
          child: Text('Complaint Page'),
        ));
  }
}
