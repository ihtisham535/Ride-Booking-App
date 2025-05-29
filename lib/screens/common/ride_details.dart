import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/ride.dart';
import '../../utils/colors.dart';
import '../../utils/styles.dart';
import '../../utils/extensions.dart';
import 'rating_dialog.dart';

class RideDetailsScreen extends StatefulWidget {
  final Ride ride;
  final String riderName;
  final double riderRating;
  final String riderVehicle;
  final String riderPlate;

  const RideDetailsScreen({
    super.key,
    required this.ride,
    required this.riderName,
    required this.riderRating,
    required this.riderVehicle,
    required this.riderPlate,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.riderName == 'You' ? AppColors.secondaryColor : AppColors.primaryColor;
    final themeColorLight = Color.lerp(themeColor, Colors.white, 0.85);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeColor,
                Color.lerp(themeColor, Colors.black87, 0.3) ?? themeColor,
              ],
            ),
          ),
        ),
        title: Text(
          'Ride Details',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        shadowColor: themeColor.withOpacity(0.4),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              themeColorLight ?? Colors.white,
              Colors.white,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLocationCard(themeColor),
                const SizedBox(height: 16),
                _buildRideInfoCard(themeColor),
                const SizedBox(height: 16),
                _buildRiderInfoCard(themeColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard(Color themeColor) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.1),
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
              _buildLocationRow(
                icon: Icons.location_on_rounded,
                label: 'Pickup Location',
                value: widget.ride.pickupLocation,
                themeColor: themeColor,
              ),
              const SizedBox(height: 16),
              _buildLocationRow(
                icon: Icons.flag_rounded,
                label: 'Destination',
                value: widget.ride.destination,
                themeColor: themeColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRideInfoCard(Color themeColor) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.1),
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
              Text(
                'Ride Information',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: themeColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Status', widget.ride.status.capitalize(), themeColor),
              const Divider(height: 24, thickness: 1),
              _buildDetailRow(
                'Request Time',
                widget.ride.requestTime.toLocal().toString().split(' ')[1].substring(0, 5),
                themeColor,
              ),
              if (widget.ride.startTime != null) ...[
                const Divider(height: 24, thickness: 1),
                _buildDetailRow(
                  'Start Time',
                  widget.ride.startTime!.toLocal().toString().split(' ')[1].substring(0, 5),
                  themeColor,
                ),
              ],
              if (widget.ride.endTime != null) ...[
                const Divider(height: 24, thickness: 1),
                _buildDetailRow(
                  'End Time',
                  widget.ride.endTime!.toLocal().toString().split(' ')[1].substring(0, 5),
                  themeColor,
                ),
              ],
              if (widget.ride.fare != null) ...[
                const Divider(height: 24, thickness: 1),
                _buildDetailRow(
                  'Fare',
                  '\$${widget.ride.fare!.toStringAsFixed(2)}',
                  themeColor,
                ),
              ],
              if (widget.ride.rating != null) ...[
                const Divider(height: 24, thickness: 1),
                _buildDetailRow(
                  'Your Rating',
                  widget.ride.rating!.toStringAsFixed(1),
                  themeColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiderInfoCard(Color themeColor) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.1),
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
              Text(
                widget.riderName == 'You' ? 'Your Information' : 'Rider Information',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: themeColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Name', widget.riderName, themeColor),
              const Divider(height: 24, thickness: 1),
              _buildDetailRow('Rating', widget.riderRating.toStringAsFixed(1), themeColor),
              const Divider(height: 24, thickness: 1),
              _buildDetailRow('Vehicle', widget.riderVehicle, themeColor),
              const Divider(height: 24, thickness: 1),
              _buildDetailRow('License Plate', widget.riderPlate, themeColor),
              if (widget.ride.status == 'accepted') ...[
                const SizedBox(height: 24),
                _buildActionButton(
                  label: 'Complete Ride',
                  onTap: _completeRide,
                  themeColor: themeColor,
                ),
              ],
              if (widget.ride.status == 'completed' && widget.ride.rating == null && widget.riderName != 'You') ...[
                const SizedBox(height: 24),
                _buildActionButton(
                  label: 'Rate Rider',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return RatingDialog(
                          onRatingSubmitted: (rating) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Thanks for your rating!',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                backgroundColor: Colors.green.shade600,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  },
                  themeColor: themeColor,
                  isOutlined: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required String label,
    required String value,
    required Color themeColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: themeColor,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, Color themeColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: themeColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    required Color themeColor,
    bool isOutlined = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: isOutlined
            ? null
            : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeColor,
            Color.lerp(themeColor, Colors.black87, 0.3) ?? themeColor,
          ],
        ),
        border: isOutlined ? Border.all(color: themeColor, width: 2) : null,
        color: isOutlined ? Colors.white : null,
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isOutlined ? themeColor : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _completeRide() async {
    try {
      final updatedRide = Ride(
        id: widget.ride.id,
        userId: widget.ride.userId,
        riderId: widget.ride.riderId,
        pickupLocation: widget.ride.pickupLocation,
        destination: widget.ride.destination,
        requestTime: widget.ride.requestTime,
        status: 'completed',
        startTime: widget.ride.startTime ?? DateTime.now(),
        endTime: DateTime.now(),
        fare: 15.0, // Replace with your fare calculation logic
        rating: widget.ride.rating,
      );

      await FirebaseFirestore.instance.collection('rides').doc(widget.ride.id).update({
        'status': updatedRide.status,
        'startTime': updatedRide.startTime!.toIso8601String(),
        'endTime': updatedRide.endTime!.toIso8601String(),
        'fare': updatedRide.fare,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ride completed successfully!',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error completing ride: $e',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}