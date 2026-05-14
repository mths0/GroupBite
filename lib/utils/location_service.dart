import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied.',
      );
    }

    return await Geolocator.getCurrentPosition();
  }

  static double distanceInKm({
    required firestore.GeoPoint from,
    required firestore.GeoPoint to,
  }) {
    // const kmPerLatDegree = 111.0;

    // final latDiff = from.latitude - to.latitude;
    // final lngDiff = from.longitude - to.longitude;

    final distanceInMeters = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    return distanceInMeters / 1000; // convert to kilometers
  }

  static bool isWithinDistanceKm({
    required firestore.GeoPoint? from,
    required firestore.GeoPoint? to,
    required double maxDistanceKm,
  }) {
    if (from == null || to == null) return false;

    return distanceInKm(from: from, to: to) <= maxDistanceKm;
  }

  static Stream<Position> getLiveLocationStream() {
  const settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // update every 10 meters
  );

  return Geolocator.getPositionStream(locationSettings: settings);
}
}
