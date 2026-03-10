import 'package:food_delivery_platform/models/driver.dart';

class MockDriverRepository {
  static final List<Driver> _pendingDrivers = [];
  static final List<Driver> _drivers = [];

  // Save before OTP (temporary)
  static void addPending(Driver driver) {
    _pendingDrivers.add(driver);
  }

  // Commit after OTP success
  static void confirmDriver(String driverId) {
    final driver = _pendingDrivers.firstWhere(
      (d) => d.id == driverId,
    );
    _pendingDrivers.remove(driver);
    _drivers.add(driver);
  }

  static List<Driver> get allDrivers => _drivers;
}
