import 'package:finanzas_app/core/enums/user_role.dart';
enum UserRole {
  admin,
  cobrador;

  static UserRole fromString(String role) {
    return UserRole.values.firstWhere(
      (e) => e.name == role.toLowerCase(),
      orElse: () => UserRole.cobrador,
    );
  }
}
