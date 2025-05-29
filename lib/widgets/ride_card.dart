import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/styles.dart';

class RideCard extends StatelessWidget {
  final String name;
  final String vehicle;
  final String plate;
  final double rating;
  final double distance;
  final VoidCallback onTap;

  const RideCard({
    super.key,
    required this.name,
    required this.vehicle,
    required this.plate,
    required this.rating,
    required this.distance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primaryColor,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppStyles.headline2),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: AppStyles.bodyText1,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  const Icon(Icons.directions_car, color: AppColors.darkGray),
                  const SizedBox(width: 10),
                  Text('$vehicle ($plate)'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_pin, color: AppColors.darkGray),
                  const SizedBox(width: 10),
                  Text('${distance.toStringAsFixed(1)} km away'),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                  ),
                  onPressed: onTap,
                  child: const Text('Select'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}