import 'package:flutter/material.dart';

class Brand {
  final String name;
  final String url;
  final Color color; // brand accent for the logo chip

  const Brand(this.name, this.url, this.color);
}

// Admin-managed on the backend later; static for now.
const mockBrands = [
  Brand('SHEIN', 'https://shein.com', Color(0xFF111111)),
  Brand('Amazon', 'https://amazon.com', Color(0xFFFF9900)),
  Brand('AliExpress', 'https://aliexpress.com', Color(0xFFE62E04)),
  Brand('adidas', 'https://adidas.com', Color(0xFF111111)),
  Brand('Temu', 'https://temu.com', Color(0xFFFB7701)),
];
