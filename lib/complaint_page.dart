import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Import your project's existing screens and blocs
// (Ensure all paths are correct for your project structure)
import 'APIgenerator/api_generator.dart';
import 'ReportDashboard/DashboardBloc/dashboard_builder_bloc.dart';
import 'ReportDashboard/DashboardScreen/dashboard_builder_screen.dart';
import 'ReportDashboard/DashboardScreen/dashboard_listing_screen.dart';
import 'ReportDynamic/ReportAPIService.dart';
import 'ReportDynamic/ReportAdmin/ReportAdminBloc.dart';
import 'ReportDynamic/ReportAdmin/ReportAdminUI.dart';
import 'ReportDynamic/ReportGenerator/ReportUI.dart';
import 'ReportDynamic/ReportGenerator/Reportbloc.dart';
import 'ReportDynamic/Report_Make.dart';
import 'ReportDynamic/Report_MakeBLoc.dart';
import 'SetupScreen/setup_bloc.dart';
import 'SetupScreen/setup_screen.dart';

// Data model for dashboard items for cleaner code
class DashboardItem {
  final String title;
  final IconData icon;
  final Function(BuildContext) onTap;

  DashboardItem({required this.title, required this.icon, required this.onTap});
}

class ComplaintPage extends StatefulWidget {
  const ComplaintPage({super.key});

  @override
  State<ComplaintPage> createState() => _ComplaintPageState();
}

class _ComplaintPageState extends State<ComplaintPage> with TickerProviderStateMixin {
  int _selectedIndex = 0; // Tracks the selected horizontal tab
  late AnimationController _pageAnimationController;
  late Animation<double> _fadeAnimation;

  final List<String> _sectionTitles = ['Dashboard', 'Reporting', 'System'];

  @override
  void initState() {
    super.initState();
    _pageAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pageAnimationController, curve: Curves.easeIn),
    );
    _pageAnimationController.forward();
  }

  @override
  void dispose() {
    _pageAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildImprovedAppBar(),
      drawer: _buildModernDrawer(context),
      body: Container(
        color: Colors.grey[50],
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // --- Horizontal Tile Navigator ---
              _buildHorizontalTabs(),

              // Animated content area that switches based on selection
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.97, end: 1.0).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    key: ValueKey<int>(_selectedIndex), // Crucial for detecting change
                    child: _buildSelectedGrid(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Building Methods ---

  AppBar _buildImprovedAppBar() {
    return AppBar(
      title: const Text("Aquare-Report Builder", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
      iconTheme: const IconThemeData(color: Colors.white),
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade400],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
      ),
    );
  }

  Widget _buildHorizontalTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _sectionTitles.asMap().entries.map((entry) {
          int index = entry.key;
          String title = entry.value;
          bool isSelected = _selectedIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                transform: isSelected ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: isSelected ? null : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Center(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedGrid() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardGrid(context, _getDashboardItems(context));
      case 1:
        return _buildDashboardGrid(context, _getReportItems(context));
      case 2:
        return _buildDashboardGrid(context, _getUtilityItems(context));
      default:
        return Container();
    }
  }

  Widget _buildDashboardGrid(BuildContext context, List<DashboardItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(context),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildDashboardCard(
          icon: item.icon,
          title: item.title,
          onTap: () => item.onTap(context),
        );
      },
    );
  }

  Widget _buildDashboardCard({required IconData icon, required String title, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shadowColor: Colors.blue.withOpacity(0.2),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 38, color: Colors.white.withOpacity(0.95)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DRAWER IMPLEMENTATION (FULLY RESTORED) ---
  Drawer _buildModernDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text('Aquare-Report Builder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: const Text('Your central reporting hub'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.analytics, size: 40, color: Colors.blue),
              ),
              decoration: const BoxDecoration(color: Colors.blue),
            ),
            _createDrawerItem(
              icon: Icons.dashboard_outlined, text: 'Dashboard Viewer',
              onTap: () => _navigateToPage(context, BlocProvider.value(
                value: context.read<DashboardBuilderBloc>(),
                child: DashboardListingScreen(apiService: context.read<ReportAPIService>()),
              )),
            ),
            _createDrawerItem(
              icon: Icons.add_chart_outlined, text: 'Create New Dashboard',
              onTap: () => _navigateToPage(context, BlocProvider.value(
                value: context.read<DashboardBuilderBloc>(),
                child: DashboardBuilderScreen(apiService: context.read<ReportAPIService>(), dashboardToEdit: null),
              )),
            ),
            const Divider(),
            _createDrawerItem(
              icon: Icons.design_services_outlined, text: 'Report Designer',
              onTap: () => _navigateToPage(context, BlocProvider.value(value: context.read<ReportMakerBloc>(), child: ReportMakerUI())),
            ),
            _createDrawerItem(
              icon: Icons.pie_chart_outline, text: 'Report Generator',
              onTap: () => _navigateToPage(context, BlocProvider.value(value: context.read<ReportBlocGenerate>(), child: ReportUI())),
            ),
            _createDrawerItem(
              icon: Icons.build_circle_outlined, text: 'Report Setup',
              onTap: () => _navigateToPage(context, BlocProvider.value(value: context.read<ReportAdminBloc>(), child: ReportAdminUI())),
            ),
            const Divider(),
            _createDrawerItem(
              icon: Icons.api_outlined, text: 'API Generator',
              onTap: () => _navigateToPage(context, const ApiGeneratorPage()),
            ),
            _createDrawerItem(
              icon: Icons.settings_input_component_outlined, text: 'Database Setup',
              onTap: () => _navigateToPage(context, BlocProvider.value(value: context.read<SetupBloc>(), child: const SetupScreen())),
            ),
          ],
        ),
      ),
    );
  }

  ListTile _createDrawerItem({required IconData icon, required String text, required GestureTapCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[800]),
      title: Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 16)),
      onTap: onTap,
    );
  }

  // --- HELPER & DATA METHODS ---

  int _getCrossAxisCount(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 5;
    if (screenWidth > 900) return 4;
    if (screenWidth > 600) return 3;
    return 2;
  }

  void _navigateToPage(BuildContext context, Widget screen) {
    Navigator.pop(context); // Close the drawer first
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _navigateToCard(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // --- Data source for the grid items ---
  List<DashboardItem> _getDashboardItems(BuildContext context) {
    return [
      DashboardItem(
        title: 'Dashboard Viewer', icon: Icons.dashboard_rounded,
        onTap: (ctx) => _navigateToCard(ctx, BlocProvider.value(
          value: ctx.read<DashboardBuilderBloc>(),
          child: DashboardListingScreen(apiService: ctx.read<ReportAPIService>()),
        )),
      ),
      DashboardItem(
        title: 'Create Dashboard', icon: Icons.add_chart_sharp,
        onTap: (ctx) => _navigateToCard(ctx, BlocProvider.value(
          value: ctx.read<DashboardBuilderBloc>(),
          child: DashboardBuilderScreen(apiService: ctx.read<ReportAPIService>(), dashboardToEdit: null),
        )),
      ),
    ];
  }

  List<DashboardItem> _getReportItems(BuildContext context) {
    return [
      DashboardItem(
        title: 'Report Designer', icon: Icons.design_services_rounded,
        onTap: (ctx) => _navigateToCard(ctx, BlocProvider.value(value: ctx.read<ReportMakerBloc>(), child: ReportMakerUI())),
      ),
      DashboardItem(
        title: 'Report Generator', icon: Icons.pie_chart_rounded,
        onTap: (ctx) => _navigateToCard(ctx, BlocProvider.value(value: ctx.read<ReportBlocGenerate>(), child: ReportUI())),
      ),
      DashboardItem(
        title: 'Report Setup', icon: Icons.build_circle_rounded,
        onTap: (ctx) => _navigateToCard(ctx, BlocProvider.value(value: ctx.read<ReportAdminBloc>(), child: ReportAdminUI())),
      ),
    ];
  }

  List<DashboardItem> _getUtilityItems(BuildContext context) {
    return [
      DashboardItem(
        title: 'Database Setup', icon: Icons.storage_rounded,
        onTap: (ctx) => _navigateToCard(ctx, BlocProvider.value(value: ctx.read<SetupBloc>(), child: const SetupScreen())),
      ),
      DashboardItem(
        title: 'API Generator', icon: Icons.api_rounded,
        onTap: (ctx) => _navigateToCard(ctx, const ApiGeneratorPage()),
      ),
    ];
  }
}