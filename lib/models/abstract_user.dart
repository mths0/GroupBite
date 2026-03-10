
enum UserRole { customer, driver ,restaurant}

abstract class User {
  User({
    required this.id,
    required this.name,
    required this.phone,
    //! we only need phone to login
    // required this.passwordHash,
  });
  final String id;
  final String name;
  final String phone;
  // final String passwordHash;

  UserRole get role;
  Function login();
  Function logout();
  Function updateProfile();

  Map<String, dynamic> toJson();
}
