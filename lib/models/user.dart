enum UserRole { admin, pharmacist, technician }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.pharmacist:
        return 'Pharmacist';
      case UserRole.technician:
        return 'Technician';
    }
  }

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.technician,
    );
  }
}

class AppUser {
  final String id;
  final String name;
  final String username;
  final String passwordHash;
  final UserRole role;

  AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.passwordHash,
    required this.role,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'username': username,
        'passwordHash': passwordHash,
        'role': role.name,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as String,
        name: map['name'] as String,
        username: map['username'] as String,
        passwordHash: map['passwordHash'] as String,
        role: UserRoleX.fromString(map['role'] as String),
      );
}
