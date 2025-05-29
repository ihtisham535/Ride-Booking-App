import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../models/ride.dart';
import '../../utils/colors.dart';
import '../../utils/styles.dart';
import '../common/ride_details.dart';
import '../../services/auth_service.dart';

class RideRequestRepository {
  static Future<void> addRideRequest(Ride ride) async {
    try {
      await FirebaseFirestore.instance.collection('rides').doc(ride.id).set({
        'id': ride.id,
        'userId': ride.userId,
        'riderId': ride.riderId,
        'pickupLocation': ride.pickupLocation,
        'destination': ride.destination,
        'requestTime': ride.requestTime.toIso8601String(),
        'status': ride.status,
        'startTime': ride.startTime?.toIso8601String(),
        'endTime': ride.endTime?.toIso8601String(),
        'fare': ride.fare,
        'rating': ride.rating,
      });
    } catch (e) {
      throw Exception('Failed to add ride request: $e');
    }
  }

  static Future<Map<String, dynamic>?> getRiderDetails(String riderId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('rider').doc(riderId).get();
      if (doc.exists) {
        return doc.data();
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Stream<List<Map<String, dynamic>>> getRideRequestsStream(String riderId) {
    return FirebaseFirestore.instance
        .collection('rides')
        .where('riderId', isEqualTo: riderId)
        .where('status', isEqualTo: 'requested')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> rideRequests = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final ride = Ride(
          id: data['id'] as String,
          userId: data['userId'] as String,
          riderId: data['riderId'] as String,
          pickupLocation: data['pickupLocation'] as String,
          destination: data['destination'] as String,
          requestTime: DateTime.parse(data['requestTime'] as String),
          status: data['status'] as String,
          startTime: data['startTime'] != null ? DateTime.parse(data['startTime'] as String) : null,
          endTime: data['endTime'] != null ? DateTime.parse(data['endTime'] as String) : null,
          fare: data['fare'] as double?,
          rating: data['rating'] as double?,
        );

        final riderDetails = await getRiderDetails(ride.riderId);
        rideRequests.add({
          'ride': ride,
          'riderDetails': riderDetails ?? {
            'name': 'Unknown Rider',
            'vehicle': 'Unknown Vehicle',
            'plate': 'N/A',
          },
        });
      }
      return rideRequests;
    });
  }

  static Future<void> removeRideRequest(String rideId) async {
    try {
      await FirebaseFirestore.instance.collection('rides').doc(rideId).delete();
    } catch (e) {
      throw Exception('Failed to remove ride request: $e');
    }
  }
}

class RideRequestsScreen extends StatefulWidget {
  const RideRequestsScreen({super.key});

  @override
  State<RideRequestsScreen> createState() => _RideRequestsScreenState();
}

class _RideRequestsScreenState extends State<RideRequestsScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  String? _riderId;
  bool _isLoadingAccept = false;
  bool _isLoadingReject = false;

  @override
  void initState() {
    super.initState();
    _loadRiderId();
  }

  Future<void> _loadRiderId() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        setState(() {
          _riderId = user.uid;
        });
      } else {
        print('DEBUG: No authenticated user found at ${DateTime.now().toIso8601String()}');
      }
    } catch (e) {
      print('DEBUG: Error loading riderId: $e at ${DateTime.now().toIso8601String()}');
    }
  }

  Future<void> _acceptRide(Ride ride) async {
    if (_isLoadingAccept || _isLoadingReject) return;
    setState(() {
      _isLoadingAccept = true;
    });
    try {
      if (_riderId == null) {
        _showSnackBar('Error: User not authenticated', isError: true);
        return;
      }

      final updatedRide = Ride(
        id: ride.id,
        userId: ride.userId,
        riderId: ride.riderId,
        pickupLocation: ride.pickupLocation,
        destination: ride.destination,
        requestTime: ride.requestTime,
        status: 'accepted',
        startTime: DateTime.now(),
        endTime: null,
        fare: null,
        rating: null,
      );

      await FirebaseFirestore.instance.collection('rides').doc(ride.id).update({
        'userId': updatedRide.userId,
        'status': updatedRide.status,
        'startTime': updatedRide.startTime!.toIso8601String(),
        'endTime': updatedRide.endTime?.toIso8601String(),
        'fare': updatedRide.fare,
        'rating': updatedRide.rating,
      });

      final updatedDoc = await FirebaseFirestore.instance.collection('rides').doc(ride.id).get();
      if (!updatedDoc.exists) {
        throw Exception('Ride document not found after update');
      }

      if (mounted) {
        final riderDetails = await RideRequestRepository.getRiderDetails(ride.riderId);
        HapticFeedback.mediumImpact();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RideDetailsScreen(
              ride: updatedRide,
              riderName: riderDetails?['name'] ?? 'Unknown Rider',
              riderRating: (riderDetails?['rating'] as num?)?.toDouble() ?? 4.8,
              riderVehicle: riderDetails?['vehicle'] ?? 'Unknown Vehicle',
              riderPlate: riderDetails?['plate'] ?? 'N/A',
            ),
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error accepting ride ${ride.id}: $e at ${DateTime.now().toIso8601String()}');
      if (mounted) {
        _showSnackBar('Error accepting ride: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAccept = false;
        });
      }
    }
  }

  Future<void> _rejectRide(Ride ride) async {
    if (_isLoadingAccept || _isLoadingReject) return;
    setState(() {
      _isLoadingReject = true;
    });
    try {
      await FirebaseFirestore.instance.collection('rides').doc(ride.id).update({
        'status': 'rejected',
      });

      if (mounted) {
        HapticFeedback.mediumImpact();
        _showSnackBar('Ride request from ${ride.pickupLocation} rejected', isError: true);
      }
    } catch (e) {
      print('DEBUG: Error rejecting ride ${ride.id}: $e at ${DateTime.now().toIso8601String()}');
      if (mounted) {
        _showSnackBar('Error rejecting ride: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingReject = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppStyles.bodyText2.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? AppColors.errorColor : AppColors.secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        duration: const Duration(seconds: 3),
        elevation: 6,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text('Ride Requests', style: AppStyles.headline1.copyWith(fontSize: 24, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryColor.withOpacity(0.1), AppColors.cardBackground],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            color: AppColors.cardBackground,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label: 'Ride Requests Header',
                    child: Text(
                      'Available Rides',
                      style: AppStyles.headline1.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _riderId == null
                        ? _buildLoadingState()
                        : RefreshIndicator(
                      color: AppColors.primaryColor,
                      backgroundColor: AppColors.cardBackground,
                      onRefresh: () async {
                        HapticFeedback.lightImpact();
                        setState(() {});
                      },
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: RideRequestRepository.getRideRequestsStream(_riderId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return _buildLoadingState();
                          }
                          if (snapshot.hasError) {
                            print('DEBUG: StreamBuilder error: ${snapshot.error} at ${DateTime.now().toIso8601String()}');
                            return Center(
                              child: Semantics(
                                label: 'Error loading ride requests',
                                child: Text(
                                  'Error loading ride requests',
                                  style: AppStyles.bodyText2.copyWith(
                                    color: AppColors.errorColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }
                          final rideRequests = snapshot.data ?? [];
                          print('DEBUG: Fetched ${rideRequests.length} ride requests for riderId: $_riderId at ${DateTime.now().toIso8601String()}');
                          if (rideRequests.isEmpty) {
                            return _buildEmptyState();
                          }
                          return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: rideRequests.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final rideData = rideRequests[index];
                              final ride = rideData['ride'] as Ride;
                              final riderDetails = rideData['riderDetails'] as Map<String, dynamic>;
                              return _buildRideCard(ride, riderDetails);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRideCard(Ride ride, Map<String, dynamic> riderDetails) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Transform.scale(
              scale: 0.95 + (0.05 * value),
              child: child,
            ),
          ),
        );
      },
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                AppColors.cardBackground,
                AppColors.cardBackground.withAlpha(220),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primaryColor.withOpacity(0.15),
                          child: Icon(
                            Icons.person,
                            color: AppColors.primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Semantics(
                          label: 'Rider name: ${riderDetails['name']}',
                          child: Text(
                            riderDetails['name'],
                            style: AppStyles.headline3.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Semantics(
                      label: 'Request time: ${ride.requestTime.toLocal().toString().split(' ')[1].substring(0, 5)}',
                      child: Text(
                        ride.requestTime.toLocal().toString().split(' ')[1].substring(0, 5),
                        style: AppStyles.bodyText2.copyWith(
                          fontSize: 16,
                          color: AppColors.textSecondary.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.directions_car,
                      color: AppColors.primaryColor.withOpacity(0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Semantics(
                            label: 'Vehicle label',
                            child: Text(
                              'Vehicle:',
                              style: AppStyles.bodyText1.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Semantics(
                            label: 'Vehicle: ${riderDetails['vehicle']}',
                            child: Text(
                              riderDetails['vehicle'],
                              style: AppStyles.bodyText1.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.local_offer,
                      color: AppColors.primaryColor.withOpacity(0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Semantics(
                            label: 'Plate label',
                            child: Text(
                              'Plate:',
                              style: AppStyles.bodyText1.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Semantics(
                            label: 'License plate: ${riderDetails['plate']}',
                            child: Text(
                              riderDetails['plate'],
                              style: AppStyles.bodyText1.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  color: AppColors.dividerColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppColors.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        label: 'Pickup location: ${ride.pickupLocation}',
                        child: Text(
                          ride.pickupLocation,
                          style: AppStyles.bodyText1.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.flag,
                      color: AppColors.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        label: 'Destination: ${ride.destination}',
                        child: Text(
                          ride.destination,
                          style: AppStyles.bodyText1.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isLoadingReject || _isLoadingAccept ? null : () => _rejectRide(ride),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.errorColor,
                              width: 2,
                            ),
                            color: _isLoadingReject || _isLoadingAccept
                                ? AppColors.errorColor.withOpacity(0.3)
                                : Colors.transparent,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: _isLoadingReject
                                ? SizedBox(
                              height: 20,
                              width: 20,
                              child: SpinKitFadingCircle(
                                color: AppColors.errorColor,
                                size: 20,
                              ),
                            )
                                : Text(
                              'Reject',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.errorColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isLoadingAccept || _isLoadingReject ? null : () => _acceptRide(ride),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: _isLoadingAccept || _isLoadingReject
                                ? AppColors.primaryColor.withOpacity(0.5)
                                : AppColors.primaryColor,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: _isLoadingAccept
                                ? SizedBox(
                              height: 20,
                              width: 20,
                              child: SpinKitFadingCircle(
                                color: Colors.white,
                                size: 20,
                              ),
                            )
                                : Text(
                              'Accept',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitChasingDots(
            color: AppColors.primaryColor,
            size: 50,
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'Loading ride requests',
            child: Text(
              'Loading Ride Requests...',
              style: AppStyles.bodyText2.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: 'No ride requests icon',
            child: Icon(
              Icons.directions_car_filled,
              size: 80,
              color: Color.fromRGBO(
                AppColors.textSecondary.red,
                AppColors.textSecondary.green,
                AppColors.textSecondary.blue,
                0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'No ride requests available',
            child: Text(
              'No Ride Requests',
              style: AppStyles.headline2.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Pull to refresh or check back later to see new ride requests',
            child: Text(
              'Pull to refresh or check back later.',
              style: AppStyles.bodyText2.copyWith(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: AppStyles.elevatedButtonStyle.copyWith(
              backgroundColor: WidgetStateProperty.all(AppColors.primaryColor),
              foregroundColor: WidgetStateProperty.all(Colors.white),
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {});
            },
            icon: const Icon(Icons.refresh, size: 20),
            label: Text(
              'Refresh Now',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
    bool isBold = false,
    String? semanticsLabel,
  }) {
    return Row(
      children: [
        Semantics(
          label: semanticsLabel != null ? 'Icon for $semanticsLabel' : null,
          child: Icon(
            icon,
            color: AppColors.primaryColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            label: semanticsLabel,
            child: Text(
              text,
              style: AppStyles.bodyText1.copyWith(
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                fontSize: isBold ? 16 : 14,
                color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}