import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'tracker_bloc.dart';

// Main entry point
class TrackerPage extends StatelessWidget {
  final String salesmanName;
  final String imagePath;
  const TrackerPage({super.key, required this.salesmanName, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TrackerBloc()..add(StartTracking(salesmanName: salesmanName, imagePath: imagePath)),
      child: const TrackerView(),
    );
  }
}

// Main UI
class TrackerView extends StatefulWidget {
  const TrackerView({super.key});
  @override
  State<TrackerView> createState() => _TrackerViewState();
}

class _TrackerViewState extends State<TrackerView> {
  GoogleMapController? _mapController;
  bool _isUserInteracting = false;

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double minPanelHeight = screenHeight < 600 ? 170.0 : 210.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50.withOpacity(0.8), Colors.white],
          ),
        ),
        child: BlocBuilder<TrackerBloc, TrackerState>(
          builder: (context, state) {
            if (state is TrackerLoading || state is TrackerInitial) {
              return const _LoadingView();
            }
            if (state is TrackerFailure) {
              return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error: ${state.error}", textAlign: TextAlign.center)));
            }
            if (state is TrackerInProgress) {
              return SlidingUpPanel(
                minHeight: minPanelHeight,
                maxHeight: screenHeight * 0.85,
                parallaxEnabled: true,
                body: _LiveMapWidget(
                  state: state,
                  isUserInteracting: _isUserInteracting,
                  onMapCreated: (controller) {
                    debugPrint("✅ [MAP] Google Map Controller Initialized successfully.");
                    setState(() => _mapController = controller);
                  },
                  onMapInteraction: () {
                    if (!_isUserInteracting) setState(() => _isUserInteracting = true);
                  },
                  onRecenter: () {
                    setState(() => _isUserInteracting = false);
                    if (state.currentLocation != null && _mapController != null) {
                      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(state.currentLocation!, 16.5));
                    }
                  },
                  mapController: _mapController,
                ),
                panelBuilder: (sc) => _buildSlidingPanel(context, sc, state),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
                boxShadow: const [],
                color: Colors.transparent,
              );
            }
            return const Center(child: Text("An unknown error occurred."));
          },
        ),
      ),
    );
  }

  Widget _buildSlidingPanel(BuildContext context, ScrollController sc, TrackerInProgress state) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.60),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.0),
          ),
          child: Column(
            children: [
              Container(width: 48, height: 5, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12))),
              _CollapsedPanelContent(state: state),
              const SizedBox(height: 12),
              Expanded(child: _ExpandedPanelContent(sc: sc, state: state)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGETS ---

class _LoadingView extends StatefulWidget {
  const _LoadingView();
  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView> with SingleTickerProviderStateMixin {
  final List<String> _loadingMessages = ["Loading Map...", "Acquiring GPS Signal...", "Pinpointing Location...", "Almost there..."];
  int _currentMessageIndex = 0;
  Timer? _timer;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() => _currentMessageIndex = (_currentMessageIndex + 1) % _loadingMessages.length);
        _fadeController.forward(from: 0.0);
      }
    });
    _fadeController.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SpinKitChasingDots(
            color: Color(0xFF1976D2),
            size: 60.0,
          ),
          const SizedBox(height: 24),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
              _loadingMessages[_currentMessageIndex],
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMapWidget extends StatelessWidget {
  final TrackerInProgress state;
  final bool isUserInteracting;
  final Function(GoogleMapController) onMapCreated;
  final VoidCallback onMapInteraction;
  final VoidCallback onRecenter;
  final GoogleMapController? mapController;

  const _LiveMapWidget({
    required this.state,
    required this.isUserInteracting,
    required this.onMapCreated,
    required this.onMapInteraction,
    required this.onRecenter,
    this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    final Set<Marker> markers = state.currentLocation != null
        ? {
      Marker(
        markerId: const MarkerId('current_location'),
        position: state.currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
      )
    }
        : {};

    final Set<Polyline> polylines = {
      if (state.routePoints.length > 1)
        Polyline(
          polylineId: const PolylineId('route'),
          points: state.routePoints,
          color: Colors.blue.shade600,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        )
    };

    return BlocListener<TrackerBloc, TrackerState>(
      listener: (context, state) {
        if (state is TrackerInProgress && state.currentLocation != null && !isUserInteracting && mapController != null) {
          debugPrint("🗺️ [MAP] Auto-centering map camera to new location: ${state.currentLocation}");
          mapController!.animateCamera(CameraUpdate.newLatLngZoom(state.currentLocation!, 16.5));
        }
      },
      child: Stack(
        children: [
          GoogleMap(
            onMapCreated: onMapCreated,
            initialCameraPosition: CameraPosition(
              target: state.currentLocation ?? const LatLng(51.5, -0.12),
              zoom: 16.5,
            ),
            mapType: MapType.normal,
            myLocationButtonEnabled: false,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            polylines: polylines,
            markers: markers,
            onCameraMoveStarted: onMapInteraction,
            padding: const EdgeInsets.only(bottom: 210, top: 120),
          ),
          _TopBar(state: state),
          if (isUserInteracting)
            Positioned(
              bottom: 220,
              right: 20,
              child: FloatingActionButton(
                onPressed: onRecenter,
                backgroundColor: Colors.white,
                elevation: 4,
                child: Icon(Icons.my_location_rounded, color: Colors.blue.shade800),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final TrackerInProgress state;
  const _TopBar({required this.state});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12, left: 12, right: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
          child: Container(
            padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 8, 12, 12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(16.0), border: Border.all(color: Colors.white.withOpacity(0.2))),
            child: Row(
              children: [
                CircleAvatar(radius: 22, backgroundImage: FileImage(File(state.imagePath))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.salesmanName, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.greenAccent.shade400, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          const Text("Online", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                StreamBuilder(stream: Stream.periodic(const Duration(seconds: 1)), builder: (context, snapshot) => Text(DateFormat('hh:mm a').format(DateTime.now()), style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedPanelContent extends StatelessWidget {
  final TrackerInProgress state;
  const _CollapsedPanelContent({required this.state});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(child: _StatCard(title: "Time In", value: state.checkpoints.isNotEmpty ? DateFormat('hh:mm a').format(state.checkpoints.first.timestamp) : "--:--", icon: Icons.timer_outlined, gradientColors: [Colors.blue.shade700, Colors.blue.shade400])),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(title: "Distance", value: "${state.totalDistance.toStringAsFixed(2)} km", icon: Icons.route_outlined, gradientColors: [Colors.purple.shade500, Colors.purple.shade300])),
        ],
      ),
    );
  }
}

class _ExpandedPanelContent extends StatelessWidget {
  final ScrollController sc;
  final TrackerInProgress state;
  const _ExpandedPanelContent({required this.sc, required this.state});

  Future<void> _showAddStopDialog(BuildContext parentContext) async {
    final TextEditingController controller = TextEditingController();
    bool includeClientName = false;
    await showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), backgroundColor: Colors.white,
              title: const Text("Add New Stop", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                CheckboxListTile(title: const Text("Include Client Name"), value: includeClientName, onChanged: (value) => setDialogState(() => includeClientName = value ?? false), controlAffinity: ListTileControlAffinity.leading, activeColor: Colors.blue.shade700),
                if (includeClientName) TextField(controller: controller, decoration: InputDecoration(hintText: "Enter client name", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade100)),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                TextButton(
                  onPressed: () {
                    final title = includeClientName && controller.text.isNotEmpty ? controller.text : "Visited New Client";
                    parentContext.read<TrackerBloc>().add(AddCheckpoint(title: title));
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text("Add", style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Live Activity", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87)),
              TextButton.icon(
                style: TextButton.styleFrom(backgroundColor: Colors.blue.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                icon: Icon(Icons.add_location_alt_outlined, size: 18, color: Colors.blue.shade800),
                label: Text("Add Stop", style: TextStyle(color: Colors.blue.shade800, fontSize: 14, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddStopDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: sc,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            itemCount: state.checkpoints.length,
            itemBuilder: (context, index) {
              final checkpoint = state.checkpoints[index];
              return _TimelineTile(
                key: ValueKey(checkpoint.timestamp),
                icon: checkpoint.title == "Checked In" ? Icons.login_rounded : Icons.flag_rounded,
                color: checkpoint.title == "Checked In" ? Colors.green.shade600 : Colors.blue.shade600,
                title: checkpoint.title,
                subtitle: checkpoint.address,
                time: DateFormat('hh:mm a').format(checkpoint.timestamp),
                isFirst: index == 0,
                isLast: index == state.checkpoints.length - 1,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.red.shade500, Colors.red.shade600], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
                onPressed: () {
                  context.read<TrackerBloc>().add(StopTracking());
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.power_settings_new_rounded, size: 22),
                label: const Text("End Shift", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradientColors;

  const _StatCard({required this.title, required this.value, required this.icon, required this.gradientColors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white, width: 1.5)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  final bool isFirst;
  final bool isLast;

  const _TimelineTile({super.key, required this.icon, required this.color, required this.title, required this.subtitle, required this.time, this.isFirst = false, this.isLast = false});

  @override
  State<_TimelineTile> createState() => _TimelineTileState();
}

class _TimelineTileState extends State<_TimelineTile> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _lineAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<Offset> _contentSlideAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _lineAnimation = CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _iconScaleAnimation = CurvedAnimation(parent: _entryController, curve: const Interval(0.4, 1.0, curve: Curves.elasticOut));
    _contentSlideAnimation = Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimelineGutter(context),
          const SizedBox(width: 16),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildTimelineGutter(BuildContext context) {
    return SizedBox(
      width: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              Container(width: 2, height: 10, color: widget.isFirst ? Colors.transparent : Colors.grey.shade300),
              Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.isFirst)
                    ScaleTransition(
                      scale: Tween<double>(begin: 1.0, end: 2.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut)),
                      child: FadeTransition(opacity: Tween<double>(begin: 0.6, end: 0.0).animate(_pulseController), child: Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.4)))),
                    ),
                  ScaleTransition(
                    scale: _iconScaleAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: widget.color.withOpacity(0.3), blurRadius: 8)]),
                      child: Icon(widget.icon, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              AnimatedBuilder(
                animation: _lineAnimation,
                builder: (context, child) {
                  final height = (constraints.maxHeight - 50) * _lineAnimation.value;
                  return Container(width: 2, height: widget.isLast ? 0 : (height > 0 ? height : 0), color: Colors.grey.shade300);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    return Expanded(
      child: FadeTransition(
        opacity: _entryController,
        child: SlideTransition(
          position: _contentSlideAnimation,
          child: Container(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(widget.subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(widget.time, style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}