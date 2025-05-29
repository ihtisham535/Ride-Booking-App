class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'user' or 'rider'
  final String? vehicleType;
  final String? licensePlate;
  final double? rating;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.vehicleType,
    this.licensePlate,
    this.rating,
  });
}