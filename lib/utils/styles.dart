import 'package:flutter/material.dart';
import 'colors.dart';

class AppStyles {
  // Heading styles with bold weights and modern sizing
  static const TextStyle headline1 = TextStyle(
    fontFamily: 'Poppins', // Modern font for a fresh look
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.darkGray,
  );

  static const TextStyle headline2 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 20, // Adjusted for better hierarchy
    fontWeight: FontWeight.w600,
    color: AppColors.darkGray,
  );

  static const TextStyle headline3 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textColor,
  );

  // Body text styles with readability focus
  static const TextStyle bodyText1 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.darkGray,
  );

  static const TextStyle bodyText2 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.lightGray,
  );

  // Button text style for clear call-to-actions
  static const TextStyle buttonText = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w600, // Slightly bolder for emphasis
    color: Colors.white,
  );

  // Additional styles for flexibility
  static const TextStyle captionText = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.lightGray,
  );

  static const TextStyle subtitleText = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.darkGray,
  );
  static const TextStyle headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    fontFamily: 'Roboto',
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    fontFamily: 'Roboto',
  );


  static final ButtonStyle elevatedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.secondaryColor,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    textStyle: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    elevation: 2,
  );

  static final ButtonStyle outlinedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.errorColor,
    side: const BorderSide(color: AppColors.errorColor, width: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    textStyle: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.errorColor,
    ),
    elevation: 0,
  );
}