import 'package:flutter/material.dart';

// Brand colors, taken from the web app's _variables.scss so the app matches the site.
class AppPalette {
  AppPalette._();

  static const primary = Color(0xFFB85450); // coral, used for delivery/CTAs
  static const primaryPressed = Color(0xFFA4433F);
  static const navy = Color(0xFF0D1536); // brand navy — text, trips, banner
  static const deepNavy = Color(0xFF0D1536); // trip cards
  static const grey = Color(0xFFADADAD);

  static const verified = Color(0xFF35D17F); // verified-user check
  static const confirmGreen = Color(0xFF2BA84A); // "confirm agreement" CTA
  static const localAccent = Color(0xFF2BB673); // "local" mode
  static const intlAccent = Color(0xFF3480FF); // "international" mode (plane)

  // soft periwinkle used on the secondary "Next" button in the mobile mockups
  static const softAccent = Color(0xFFC7D2F4);

  // card fills
  static const requestCard = primary;
  static const tripCard = deepNavy;
}
