import 'dart:async';
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
    context.read<DashboardBuilderBloc>().add(const FetchDashboardList());
  }

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
      context.read<DashboardBuilderBloc>().add(DeleteDashboardEvent(dashboardId));
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // UPDATED: This function now shows the improved dialog and displays a SnackBar based on the result.
  Future<void> _handleTransferDashboard(Dashboard dashboard) async {
    final bool? transferSuccess = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (dialogContext) {
        return _DashboardTransferDialog( // Using the new, improved dialog widget
          apiService: widget.apiService,
          dashboard: dashboard,
        );
      },
    );

    // After the dialog closes, show a final confirmation on the main screen.
    if (transferSuccess == true) {
      _showSnackBar('Dashboard "${dashboard.dashboardName}" transferred successfully!');
    } else if (transferSuccess == false) {
      _showSnackBar('Dashboard transfer failed. Please check the details and try again.', isError: true);
    }
    // If null, the user cancelled the operation.
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
                            icon: const Icon(Icons.send, color: Colors.teal),
                            tooltip: 'Send to Client',
                            onPressed: () => _handleTransferDashboard(dashboard),
                          ),
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
                            onPressed: () => _confirmAndDeleteDashboard(dashboard.dashboardId, dashboard.dashboardName),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DashboardViewScreen(
                              dashboardId: dashboard.dashboardId,
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

// =========================================================================
// == NEW, IMPROVED DIALOG WIDGET FOR DASHBOARD TRANSFER
// =========================================================================

enum _TransferStatus { form, loading, success, error }

class _DashboardTransferDialog extends StatefulWidget {
  final ReportAPIService apiService;
  final Dashboard dashboard;

  const _DashboardTransferDialog({
    required this.apiService,
    required this.dashboard,
  });

  @override
  _DashboardTransferDialogState createState() => _DashboardTransferDialogState();
}

class _DashboardTransferDialogState extends State<_DashboardTransferDialog> {
  // State for the entire dialog flow
  _TransferStatus _status = _TransferStatus.form;
  String _feedbackMessage = '';

  // State for the form
  bool _isLoadingApis = true;
  List<Map<String, dynamic>> _availableApis = [];
  Map<String, dynamic>? _selectedApi;
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isFetchingDatabases = false;
  List<String> _databaseList = [];
  String? _selectedDatabase;

  @override
  void initState() {
    super.initState();
    _loadApiConnections();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadApiConnections() async {
    try {
      final allApiNames = await widget.apiService.getAvailableApis();
      final List<Map<String, dynamic>> fullDetails = [];
      for (var name in allApiNames) {
        final details = await widget.apiService.getApiDetails(name);
        details['APIName'] = name;
        fullDetails.add(details);
      }
      if (mounted) setState(() { _availableApis = fullDetails; _isLoadingApis = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _isLoadingApis = false; _status = _TransferStatus.error; _feedbackMessage = "Failed to load connections: $e"; });
      }
    }
  }

  Future<void> _fetchDatabases() async {
    if (_serverController.text.isEmpty || _userController.text.isEmpty) {
      setState(() { _feedbackMessage = "Server IP and User Name are required."; });
      return;
    }
    setState(() { _isFetchingDatabases = true; _databaseList = []; _selectedDatabase = null; _feedbackMessage = ''; });
    try {
      final databases = await widget.apiService.fetchDatabases(
        serverIP: _serverController.text, userName: _userController.text, password: _passwordController.text,
      );
      if (mounted) setState(() { _databaseList = databases; _isFetchingDatabases = false; });
    } catch (e) {
      if (mounted) { setState(() { _isFetchingDatabases = false; _feedbackMessage = "Error fetching databases: $e"; }); }
    }
  }

  Future<void> _startTransfer() async {
    setState(() { _status = _TransferStatus.loading; _feedbackMessage = ''; });
    try {
      final result = await widget.apiService.transferFullDashboard(
        dashboardData: widget.dashboard.toJson(),
        clientServerIP: _serverController.text,
        clientUserName: _userController.text,
        clientPassword: _passwordController.text,
        clientDatabaseName: _selectedDatabase!,
      );

      if (!mounted) return;

      if (result['status'] == 'success') {
        setState(() {
          _status = _TransferStatus.success;
          _feedbackMessage = result['message'] ?? 'Dashboard transferred successfully!';
        });
      } else {
        setState(() {
          _status = _TransferStatus.error;
          _feedbackMessage = result['message'] ?? 'An unknown error occurred during transfer.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _TransferStatus.error;
          _feedbackMessage = 'A critical error occurred: $e';
        });
      }
    }
  }

  Widget _buildSectionTitle(String number, String title) { /* ... (Same as before) ... */
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar( radius: 14, backgroundColor: Colors.teal, child: Text(number, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildModernTextField({ /* ... (Same as before) ... */
    required TextEditingController controller, required String label, required IconData icon, bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller, obscureText: obscureText, style: GoogleFonts.poppins(fontSize: 15),
        decoration: InputDecoration(
          labelText: label, labelStyle: GoogleFonts.poppins(), prefixIcon: Icon(icon, color: Colors.grey[700], size: 20),
          filled: true, fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.teal, width: 2)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Transfer Dashboard', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 450,
        child: _buildContent(),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    switch (_status) {
      case _TransferStatus.loading:
        return _TransferStatusIndicator(
          icon: Icons.sync,
          color: Colors.blue,
          message: 'Transferring dashboard and reports...\nThis may take a moment.',
          isLoading: true,
        );
      case _TransferStatus.success:
        return _TransferStatusIndicator(
          icon: Icons.check_circle,
          color: Colors.green,
          message: _feedbackMessage,
        );
      case _TransferStatus.error:
        return _TransferStatusIndicator(
          icon: Icons.error,
          color: Colors.red,
          message: _feedbackMessage,
        );
      case _TransferStatus.form:
      default:
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('1', 'Select a Destination Connection'),
                if (_isLoadingApis) const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                else DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedApi, hint: Text('Select a saved connection...', style: GoogleFonts.poppins()), isExpanded: true,
                  items: _availableApis.map((api) => DropdownMenuItem(value: api, child: Text(api['APIName'] ?? 'Unknown', overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedApi = value; _serverController.text = value?['serverIP'] ?? '';
                      _userController.text = value?['userName'] ?? ''; _passwordController.text = value?['password'] ?? '';
                      _databaseList = []; _selectedDatabase = null; _feedbackMessage = '';
                    });
                  },
                  decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const Divider(height: 32),
                _buildSectionTitle('2', 'Verify Credentials & Fetch Databases'),
                _buildModernTextField(controller: _serverController, label: "Server IP", icon: Icons.dns_outlined),
                _buildModernTextField(controller: _userController, label: "User Name", icon: Icons.person_outline),
                _buildModernTextField(controller: _passwordController, label: "Password", icon: Icons.password_outlined, obscureText: true),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isFetchingDatabases ? null : _fetchDatabases,
                    icon: _isFetchingDatabases ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_sync_outlined),
                    label: Text("Fetch Databases", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const Divider(height: 32),
                _buildSectionTitle('3', 'Select Target Database'),
                if (_isFetchingDatabases) const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Fetching...")))
                else if (_databaseList.isEmpty) const Center(child: Text("No databases found.", style: TextStyle(color: Colors.grey)))
                else DropdownButtonFormField<String>(
                    value: _selectedDatabase, hint: Text('Select target database...', style: GoogleFonts.poppins()), isExpanded: true,
                    items: _databaseList.map((db) => DropdownMenuItem(value: db, child: Text(db, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (value) => setState(() => _selectedDatabase = value),
                    decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  ),
                if (_feedbackMessage.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [ const Icon(Icons.error_outline, color: Colors.red), const SizedBox(width: 10), Expanded(child: Text(_feedbackMessage, style: const TextStyle(color: Colors.red, fontSize: 13))) ],),
                  ),
              ],
            ),
          ),
        );
    }
  }

  List<Widget> _buildActions() {
    bool isForm = _status == _TransferStatus.form;
    bool isLoading = _status == _TransferStatus.loading;

    if (_status == _TransferStatus.success) {
      return [ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: Text("Close", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)))];
    }

    if (_status == _TransferStatus.error) {
      return [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("Close", style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
        ElevatedButton(onPressed: () => setState(() => _status = _TransferStatus.form), child: Text("Retry", style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
      ];
    }

    return [
      TextButton(onPressed: isLoading ? null : () => Navigator.of(context).pop(null), child: Text("Cancel", style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        icon: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
        label: Text(isLoading ? 'Transferring...' : 'Confirm Transfer', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        onPressed: (isForm && _selectedDatabase != null) ? _startTransfer : null,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ];
  }
}

// NEW WIDGET: A reusable indicator for loading, success, and error states inside the dialog.
class _TransferStatusIndicator extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final bool isLoading;

  const _TransferStatusIndicator({
    required this.icon,
    required this.color,
    required this.message,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        if (isLoading)
          const CircularProgressIndicator()
        else
          Icon(icon, color: color, size: 60),
        const SizedBox(height: 20),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}