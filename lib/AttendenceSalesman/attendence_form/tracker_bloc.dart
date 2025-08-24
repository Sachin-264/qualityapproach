import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // CORRECT
import 'package:qualityapproach/AttendenceSalesman/attendence_form/trackingapiservice.dart';


// -- DATA MODEL --
class Checkpoint extends Equatable {
  final String title;
  final String address;
  final DateTime timestamp;
  final LatLng location;

  const Checkpoint({
    required this.title,
    this.address = "",
    required this.timestamp,
    required this.location,
  });

  Checkpoint copyWith({String? address}) {
    return Checkpoint(
      title: title,
      address: address ?? this.address,
      timestamp: timestamp,
      location: location,
    );
  }

  @override
  List<Object> get props => [title, address, timestamp, location];
}

// -- EVENTS --
abstract class TrackerEvent extends Equatable {
  const TrackerEvent();
  @override
  List<Object> get props => [];
}

class StartTracking extends TrackerEvent {
  final String salesmanName;
  final String imagePath;
  const StartTracking({required this.salesmanName, required this.imagePath});
}

class _LocationUpdated extends TrackerEvent {
  final Position position;
  const _LocationUpdated(this.position);
}

class _CheckpointAddressUpdated extends TrackerEvent {
  final DateTime timestamp;
  final String newAddress;
  const _CheckpointAddressUpdated(this.timestamp, this.newAddress);
}

class AddCheckpoint extends TrackerEvent {
  final String title;
  const AddCheckpoint({required this.title});
}

class StopTracking extends TrackerEvent {}


// -- STATE --
abstract class TrackerState extends Equatable {
  const TrackerState();
  @override
  List<Object?> get props => [];
}

class TrackerInitial extends TrackerState {}
class TrackerLoading extends TrackerState {}

class TrackerInProgress extends TrackerState {
  final int recNo;
  final String salesmanName;
  final String imagePath;
  final LatLng? currentLocation;
  final List<LatLng> routePoints;
  final double totalDistance;
  final List<Checkpoint> checkpoints;

  const TrackerInProgress({
    required this.recNo,
    required this.salesmanName,
    required this.imagePath,
    this.currentLocation,
    this.routePoints = const [],
    this.totalDistance = 0.0,
    this.checkpoints = const [],
  });

  TrackerInProgress copyWith({
    int? recNo,
    LatLng? currentLocation,
    List<LatLng>? routePoints,
    double? totalDistance,
    List<Checkpoint>? checkpoints,
  }) {
    return TrackerInProgress(
      recNo: recNo ?? this.recNo,
      salesmanName: salesmanName,
      imagePath: imagePath,
      currentLocation: currentLocation ?? this.currentLocation,
      routePoints: routePoints ?? this.routePoints,
      totalDistance: totalDistance ?? this.totalDistance,
      checkpoints: checkpoints ?? this.checkpoints,
    );
  }

  @override
  List<Object?> get props => [recNo, salesmanName, imagePath, currentLocation, routePoints, totalDistance, checkpoints];
}

class TrackerFailure extends TrackerState {
  final String error;
  const TrackerFailure(this.error);
}


// -- BLOC --
class TrackerBloc extends Bloc<TrackerEvent, TrackerState> {
  StreamSubscription<Position>? _locationSubscription;
  final TrackingApiService _apiService;

  static const double _DISTANCE_THRESHOLD = 10.0; // meters
  static const double _ACCURACY_THRESHOLD = 20.0; // meters

  // Hardcoded values as per your example. In a real app, these would come from a login service.
  static const String _USER_ID = '101';
  static const String _GROUP_CODE = '5';
  static const String _BRANCH_CODE = 'B001'; // Example branch code

  TrackerBloc()
      : _apiService = TrackingApiService(),
        super(TrackerInitial()) {
    on<StartTracking>(_onStartTracking);
    on<_LocationUpdated>(_onLocationUpdated);
    on<AddCheckpoint>(_onAddCheckpoint);
    on<_CheckpointAddressUpdated>(_onCheckpointAddressUpdated);
    on<StopTracking>(_onStopTracking);
  }

  Future<String> _getAddressFromLatLng(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final name = place.name ?? '';
        final locality = place.locality ?? '';
        final thoroughfare = place.thoroughfare ?? '';
        if (thoroughfare.isNotEmpty && locality.isNotEmpty) return "$thoroughfare, $locality";
        return "$name, $locality".replaceAll(RegExp(r'^, | ,$'), '');
      }
      return "Address not available";
    } catch (e) {
      debugPrint("Error fetching address: $e");
      return "Could not fetch address";
    }
  }

  Future<void> _onStartTracking(StartTracking event, Emitter<TrackerState> emit) async {
    emit(TrackerLoading());
    try {
      debugPrint("Step 1: Uploading image...");
      final uniqueFileName = await _apiService.uploadImage(
        imagePath: event.imagePath,
        userId: _USER_ID,
        groupCode: _GROUP_CODE,
      );
      debugPrint("Image uploaded successfully. Filename: $uniqueFileName");

      debugPrint("Step 2: Marking attendance...");
      final recNo = await _apiService.markAttendance(
        userCode: _USER_ID,
        branchCode: _BRANCH_CODE,
        selfiePath: uniqueFileName,
      );
      debugPrint("Attendance marked successfully. RecNo: $recNo");

      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        emit(const TrackerFailure("Location permissions are required."));
        return;
      }

      final Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final startPoint = LatLng(pos.latitude, pos.longitude);

      final initialCheckpoint = Checkpoint(
        title: "Checked In",
        timestamp: DateTime.now(),
        location: startPoint,
        address: "Fetching address...",
      );

      emit(TrackerInProgress(
        recNo: recNo,
        salesmanName: event.salesmanName,
        imagePath: event.imagePath,
        currentLocation: startPoint,
        routePoints: [startPoint],
        checkpoints: [initialCheckpoint],
      ));

      _getAddressFromLatLng(startPoint).then((address) {
        if (!isClosed) add(_CheckpointAddressUpdated(initialCheckpoint.timestamp, address));
      });

      // This call will now work because trackUser expects a Google Maps LatLng
      _apiService.trackUser(recNo: recNo, userCode: _USER_ID, location: startPoint);

      const locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
      _locationSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((position) {
        if (!isClosed) add(_LocationUpdated(position));
      });
    } catch (e) {
      emit(TrackerFailure("Failed to start tracking: ${e.toString()}"));
    }
  }

  void _onLocationUpdated(_LocationUpdated event, Emitter<TrackerState> emit) {
    if (state is! TrackerInProgress) return;
    final currentState = state as TrackerInProgress;

    debugPrint('[GPS LOG] Received update. Accuracy: ${event.position.accuracy.toStringAsFixed(2)}m');
    final newPoint = LatLng(event.position.latitude, event.position.longitude);

    if (event.position.accuracy > _ACCURACY_THRESHOLD) {
      debugPrint('[GPS LOG] -> IGNORED: Accuracy is worse than $_ACCURACY_THRESHOLD m.');
      emit(currentState.copyWith(currentLocation: newPoint));
      return;
    }

    final lastPoint = currentState.routePoints.last;
    final double distance = Geolocator.distanceBetween(
      lastPoint.latitude,
      lastPoint.longitude,
      newPoint.latitude,
      newPoint.longitude,
    );

    if (distance > _DISTANCE_THRESHOLD) {
      debugPrint('[GPS LOG] -> ACCEPTED: Moved ${distance.toStringAsFixed(2)}m. Updating route.');

      debugPrint("⬆️ [API] Sending location to server... RecNo: ${currentState.recNo}, Location: ${newPoint.latitude}, ${newPoint.longitude}");

      // This call will now work because trackUser expects a Google Maps LatLng
      _apiService.trackUser(
          recNo: currentState.recNo,
          userCode: _USER_ID,
          location: newPoint
      ).then((_) {
        debugPrint("✅ [API] Location saved successfully on the server.");
      }).catchError((error) {
        debugPrint("❌ [API] FAILED to save location to the server: $error");
      });

      final newRoutePoints = List<LatLng>.from(currentState.routePoints)..add(newPoint);
      final newTotalDistance = currentState.totalDistance + (distance / 1000.0);
      emit(currentState.copyWith(currentLocation: newPoint, routePoints: newRoutePoints, totalDistance: newTotalDistance));
    } else {
      debugPrint('[GPS LOG] -> IGNORED: Moved ${distance.toStringAsFixed(2)}m, which is less than threshold.');
      emit(currentState.copyWith(currentLocation: newPoint));
    }
  }

  void _onCheckpointAddressUpdated(_CheckpointAddressUpdated event, Emitter<TrackerState> emit) {
    if (state is! TrackerInProgress) return;
    final currentState = state as TrackerInProgress;
    final updatedCheckpoints = currentState.checkpoints.map((cp) {
      return cp.timestamp == event.timestamp ? cp.copyWith(address: event.newAddress) : cp;
    }).toList();
    emit(currentState.copyWith(checkpoints: updatedCheckpoints));
  }

  Future<void> _onAddCheckpoint(AddCheckpoint event, Emitter<TrackerState> emit) async {
    if (state is! TrackerInProgress) return;
    final currentState = state as TrackerInProgress;
    if (currentState.currentLocation == null) return;

    final newLocation = currentState.currentLocation!;
    final newCheckpoint = Checkpoint(
      title: event.title,
      timestamp: DateTime.now(),
      location: newLocation,
      address: "Fetching address...",
    );

    final updatedCheckpoints = [newCheckpoint, ...currentState.checkpoints];
    emit(currentState.copyWith(checkpoints: updatedCheckpoints));

    _getAddressFromLatLng(newLocation).then((address) {
      if (!isClosed) add(_CheckpointAddressUpdated(newCheckpoint.timestamp, address));
    });
  }

  void _onStopTracking(StopTracking event, Emitter<TrackerState> emit) {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    return super.close();
  }
}