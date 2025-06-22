import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../ReportDynamic/ReportAPIService.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../DashboardBloc/dashboard_builder_bloc.dart';
import '../DashboardModel/dashboard_model.dart';
import 'dashboard_view_screen.dart';
import 'dashboard_builder_screen.dart';

class DashboardListingScreen extends StatefulWidget {
  final ReportAPIService apiService;

  const DashboardListingScreen({
    Key? key,
    required this.apiService,
  }) : super(key: key);

  @override
  State<DashboardListingScreen> createState() => _DashboardListingScreenState();
}

class _DashboardListingScreenState extends State<DashboardListingScreen> {
  @override
  void initState() {
    super.initState();
    _loadDashboards();
  }

  void _loadDashboards() {
    context.read<DashboardBuilderBloc>().add(const LoadDashboardBuilderData());
  }

  // *** FIX: Expect a String for dashboardId ***
  Future<void> _confirmAndDeleteDashboard(String dashboardId, String dashboardName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Dashboard', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete dashboard "$dashboardName"? This action cannot be undone.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // *** FIX: Pass the String ID to the DeleteDashboardEvent ***
      context.read<DashboardBuilderBloc>().add(DeleteDashboardEvent(dashboardId));
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: 'My Dashboards',
        onBackPress: () => Navigator.pop(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create New Dashboard',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider.value(
                    value: context.read<DashboardBuilderBloc>(),
                    child: DashboardBuilderScreen(
                      apiService: widget.apiService,
                      dashboardToEdit: null,
                    ),
                  ),
                ),
              );
              if (result == true) {
                _loadDashboards();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Dashboards',
            onPressed: _loadDashboards,
          ),
        ],
      ),
      body: BlocConsumer<DashboardBuilderBloc, DashboardBuilderState>(
        listener: (context, state) {
          if (state is DashboardBuilderLoaded) {
            if (state.message != null) {
              _showSnackBar(state.message!);
            } else if (state.error != null) {
              _showSnackBar(state.error!, isError: true);
            }
          } else if (state is DashboardBuilderErrorState) {
            _showSnackBar(state.message, isError: true);
          }
        },
        builder: (context, state) {
          if (state is DashboardBuilderLoading) {
            return const Center(child: SubtleLoader());
          } else if (state is DashboardBuilderLoaded) {
            final List<Dashboard> dashboards = state.existingDashboards;

            if (dashboards.isEmpty) {
              return Center(
                child: Text(
                  'No dashboards found. Click "+" to create one!',
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            } else {
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: dashboards.length,
                itemBuilder: (context, index) {
                  final dashboard = dashboards[index];
                  return Card(
                    elevation: 2.0,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      leading: CircleAvatar(
                        backgroundColor: dashboard.templateConfig.accentColor?.withOpacity(0.1) ?? Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Icon(Icons.dashboard, color: dashboard.templateConfig.accentColor ?? Theme.of(context).primaryColor),
                      ),
                      title: Text(
                        dashboard.dashboardName,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Text(
                        dashboard.dashboardDescription ?? 'No description',
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Edit Dashboard',
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BlocProvider.value(
                                    value: context.read<DashboardBuilderBloc>(),
                                    child: DashboardBuilderScreen(
                                      apiService: widget.apiService,
                                      dashboardToEdit: dashboard,
                                    ),
                                  ),
                                ),
                              );
                              if (result == true) {
                                _loadDashboards();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete Dashboard',
                            // *** FIX: Pass the String ID from the dashboard object ***
                            onPressed: () => _confirmAndDeleteDashboard(dashboard.dashboardId, dashboard.dashboardName),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            // Assuming DashboardViewScreen also expects a String ID now.
                            // If not, you will need to update it as well.
                            builder: (context) => DashboardViewScreen(
                              dashboardId: dashboard.dashboardId, // *** FIX: Pass the String ID ***
                              apiService: widget.apiService,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            }
          } else {
            return const Center(child: Text("Loading...")); // Fallback for other states
          }
        },
      ),
    );
  }
}