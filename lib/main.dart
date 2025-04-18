import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qualityapproach/CustomerRetail/RetailBloc.dart';
import 'package:qualityapproach/EditSparePart/editsparebloc.dart';
import 'package:qualityapproach/EditSparePart/editspareui.dart';
import 'package:qualityapproach/NEWREPORT/EDIT/filterreportbloc.dart';
import 'package:qualityapproach/NEWREPORT/ReportEdit/editReport_bloc.dart';
import 'package:qualityapproach/NEWREPORT/ReportEdit/edit_bloc.dart';
import 'package:qualityapproach/NEWREPORT/report_bloc.dart';
import 'package:qualityapproach/QualtyChecks/qualityFilterbloc.dart';
import 'package:qualityapproach/SaleVsTarget/sale_TargetBloc.dart';
import 'package:qualityapproach/SparePart/spare_bloc.dart';

import 'package:qualityapproach/complaint_page.dart';
import 'package:universal_html/js.dart';

import 'EditSparePart/editsparedetailbloc.dart';

void main() {
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<BranchBloc>(create: (context) => BranchBloc()),
        BlocProvider<RetailCustomerBloc>(create: (context) => RetailCustomerBloc()),
        BlocProvider<ReportBloc>(create: (context) => ReportBloc()),
        BlocProvider<FilterBloc>(create: (context) => FilterBloc()),
        BlocProvider<EditBloc>(create: (context) => EditBloc()),
        BlocProvider<EditReportBloc>(create: (context) => EditReportBloc()),
        BlocProvider<SparePartBloc>(create:(context)=>SparePartBloc()),
        BlocProvider<EditSpareBloc>(create: (context) => EditSpareBloc()),
        BlocProvider<EditSparePartBloc>(create: (context) => EditSparePartBloc()),
        BlocProvider<SaleTargetBloc>(create: (context) => SaleTargetBloc()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Complaint Entry App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ComplaintPage(),
    );
  }
}
