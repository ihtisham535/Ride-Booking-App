class Ride {
  final String id;
  final String userId;
  final String riderId;
  final String pickupLocation;
  final String destination;
  final DateTime requestTime;
  final DateTime? startTime;
  final DateTime? endTime;
  final String status; // 'requested', 'accepted', 'started', 'completed', 'cancelled'
  final double? fare;
  final double? rating;

  Ride({
    required this.id,
    required this.userId,
    required this.riderId,
    required this.pickupLocation,
    required this.destination,
    required this.requestTime,
    this.startTime,
    this.endTime,
    required this.status,
    this.fare,
    this.rating,
  });
}