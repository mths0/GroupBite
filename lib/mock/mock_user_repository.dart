import 'package:food_delivery_platform/models/abstract_user.dart';
import 'mock_users.dart';

//? who can login?
class MockUserRepository {
  static User? findByPhone(String phone) {
    for (final user in mockUsers) {
      if (user.phone == phone) {
        return user;
      }
    }
    return null;
  }
}