import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qualityapproach/CustomerRetail/RetailBloc.dart';
import 'package:qualityapproach/NEWREPORT/report_bloc.dart';
import 'package:qualityapproach/QualtyChecks/qualityFilterbloc.dart';

import 'package:qualityapproach/complaint_page.dart';
import 'package:universal_html/js.dart';

void main() {
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<BranchBloc>(create: (context) => BranchBloc()),
        BlocProvider<RetailCustomerBloc>(create: (context) => RetailCustomerBloc()),
        BlocProvider<ReportBloc>(create: (context) => ReportBloc()),
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
