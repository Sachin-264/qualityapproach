import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qualityapproach/CustomerRetail/RetailBloc.dart';
import 'package:qualityapproach/Dashboard/Dashboard.bloc.dart';
import 'package:qualityapproach/Dashboard/detailDashBloc.dart';
import 'package:qualityapproach/EditSparePart/editsparebloc.dart';
import 'package:qualityapproach/EditSparePart/editspareui.dart';
import 'package:qualityapproach/NEWREPORT/EDIT/filterreportbloc.dart';
import 'package:qualityapproach/NEWREPORT/ReportEdit/editReport_bloc.dart';
import 'package:qualityapproach/NEWREPORT/ReportEdit/edit_bloc.dart';
import 'package:qualityapproach/NEWREPORT/report_bloc.dart';
import 'package:qualityapproach/QualtyChecks/qualityFilterbloc.dart';
import 'package:qualityapproach/ReportDynamic/ReportAdmin/ReportAdminBloc.dart';
import 'package:qualityapproach/ReportDynamic/ReportGenerator/Reportbloc.dart';
import 'package:qualityapproach/SaleVsTarget/sale_TargetBloc.dart';
import 'package:qualityapproach/SparePart/spare_bloc.dart';
import 'package:qualityapproach/complaint_page.dart';
import 'package:qualityapproach/dynamic/dynamic_all_bloc.dart';
import 'package:universal_html/js.dart';
import 'EditSparePart/editsparedetailbloc.dart';
import 'ReportDynamic/Report_MakeBLoc.dart';
import 'ReportDynamic/ReportAPIService.dart';
import 'dynamic/dynamic_detail.dart';
import 'dynamic/dynamic_detail_bloc.dart';

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
        BlocProvider<SparePartBloc>(create: (context) => SparePartBloc()),
        BlocProvider<EditSpareBloc>(create: (context) => EditSpareBloc()),
        BlocProvider<EditSparePartBloc>(create: (context) => EditSparePartBloc()),
        BlocProvider<SaleTargetBloc>(create: (context) => SaleTargetBloc()),
        BlocProvider<DashboardBloc>(create: (context) => DashboardBloc()),
        BlocProvider<DetailDashBloc>(create: (context) => DetailDashBloc()),
        BlocProvider<DynamicAllBloc>(create: (context) => DynamicAllBloc()),
        BlocProvider<DynamicDetailBloc>(create: (context) => DynamicDetailBloc()),
        BlocProvider<ReportMakerBloc>(
          create: (context) => ReportMakerBloc(ReportAPIService()),
        ),
        BlocProvider<ReportBlocGenerate>(create: (context) => ReportBlocGenerate(ReportAPIService())),
        BlocProvider<ReportAdminBloc>(create: (context) => ReportAdminBloc(ReportAPIService())),
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