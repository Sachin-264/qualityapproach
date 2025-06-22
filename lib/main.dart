import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // <--- NEW: Import the provider package

// Your existing Bloc imports
import 'CustomerRetail/RetailBloc.dart';
import 'EditSparePart/editsparebloc.dart';
import 'NEWREPORT/EDIT/filterreportbloc.dart';
import 'NEWREPORT/ReportEdit/edit_bloc.dart';
import 'NEWREPORT/report_bloc.dart';
import 'QualtyChecks/qualityFilterbloc.dart';
import 'ReportDashboard/DashboardBloc/dashboard_builder_bloc.dart';
import 'ReportDynamic/ReportAPIService.dart';
import 'ReportDynamic/ReportAdmin/ReportAdminBloc.dart';
import 'ReportDynamic/ReportGenerator/Reportbloc.dart';
import 'ReportDynamic/ReportMakeEdit/EditDetailMakerBloc.dart';
import 'ReportDynamic/ReportMakeEdit/EditReportMaker.dart';
import 'ReportDynamic/Report_MakeBLoc.dart';
import 'SaleVsTarget/sale_TargetBloc.dart';
import 'SparePart/spare_bloc.dart';


import 'complaint_page.dart';

void main() {
  // Create a single instance of ReportAPIService to be shared across BLoCs AND widgets
  final ReportAPIService apiService = ReportAPIService();

  runApp(
    // NEW: Provide ReportAPIService using a Provider
    Provider<ReportAPIService>.value( // Use .value to provide an existing instance
      value: apiService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<BranchBloc>(create: (context) => BranchBloc()),
          BlocProvider<RetailCustomerBloc>(create: (context) => RetailCustomerBloc()),
          BlocProvider<ReportBloc>(create: (context) => ReportBloc()),
          BlocProvider<FilterBloc>(create: (context) => FilterBloc()),
          BlocProvider<EditBloc>(create: (context) => EditBloc()),
          BlocProvider<SparePartBloc>(create: (context) => SparePartBloc()),
          BlocProvider<EditSpareBloc>(create: (context) => EditSpareBloc()),
          BlocProvider<SaleTargetBloc>(create: (context) => SaleTargetBloc()),

          // DashboardBuilderBloc now correctly receives the apiService instance
          BlocProvider<DashboardBuilderBloc>(create: (context) => DashboardBuilderBloc(apiService)),

          // Ensure other BLoCs that need ReportAPIService are updated
          BlocProvider<ReportMakerBloc>(
            create: (context) => ReportMakerBloc(apiService),
          ),
          BlocProvider<ReportBlocGenerate>(create: (context) => ReportBlocGenerate(apiService)),
          BlocProvider<ReportAdminBloc>(create: (context) => ReportAdminBloc(apiService)),
          BlocProvider<EditDetailMakerBloc>(create: (context) => EditDetailMakerBloc(apiService)),
          BlocProvider<EditReportMakerBloc>(create: (context) => EditReportMakerBloc(apiService)),
        ],
        child: const MyApp(),
      ),
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
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      home: ComplaintPage(),
    );
  }
}