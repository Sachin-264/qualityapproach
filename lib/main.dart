import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qualityapproach/AttendenceSalesman/attendence_form/attendence_bloc.dart';
import 'package:qualityapproach/AttendenceSalesman/attendence_form/attendence_screen.dart';
import 'package:qualityapproach/SetupScreen/setup_bloc.dart';

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

// A global list to hold the available cameras, initialized before the app runs.
List<CameraDescription> cameras = [];

Future<void> main() async {
  try {
    // Ensure that plugin services are initialized so that `availableCameras()` can be called.
    WidgetsFlutterBinding.ensureInitialized();
    // Obtain a list of the available cameras on the device.
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('FATAL ERROR: Could not get available cameras: $e');
  }

  // Your existing setup
  final ReportAPIService apiService = ReportAPIService();

  runApp(
    Provider<ReportAPIService>.value(
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
          BlocProvider<DashboardBuilderBloc>(create: (context) => DashboardBuilderBloc(apiService)),
          BlocProvider<ReportMakerBloc>(create: (context) => ReportMakerBloc(apiService)),
          BlocProvider<ReportBlocGenerate>(create: (context) => ReportBlocGenerate(apiService)),
          BlocProvider<ReportAdminBloc>(create: (context) => ReportAdminBloc(apiService)),
          BlocProvider<EditDetailMakerBloc>(create: (context) => EditDetailMakerBloc(apiService)),
          BlocProvider<EditReportMakerBloc>(create: (context) => EditReportMakerBloc(apiService)),
          BlocProvider<SetupBloc>(create: (context) => SetupBloc(apiService)),
          BlocProvider<AttendanceBloc>(create: (context) => AttendanceBloc()),
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
      // IMPORTANT: Set to AttendanceView for testing the camera fix.
      // Remember to change this back to `ComplaintPage()` when you're done.
      home:  ComplaintPage(),
    );
  }
}