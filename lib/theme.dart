import 'package:flutter/material.dart';

const kPrimary = Color(0xFF047857);
const kMint = Color(0xFF10B981);
const kAmber = Color(0xFFF59E0B);
const kRed = Color(0xFFDC2626);
const kBg = Color(0xFFF4F4F5);
const kBorder = Color(0xFFE4E4E7);
const kDark = Color(0xFF18181B);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kPrimary, primary: kPrimary);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: kBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimary,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFD4D4D8), width: 1.5),
      ),
    ),
  );
}

/// Badge stok: Habis (merah) atau Menipis (amber). null jika aman.
Widget? stockBadge(int stock, int minStock) {
  if (stock <= 0) return _badge('Habis', kRed, const Color(0xFFFEE2E2));
  if (minStock > 0 && stock <= minStock) {
    return _badge('Menipis', const Color(0xFFB45309), const Color(0xFFFEF3C7));
  }
  return null;
}

Widget _badge(String text, Color fg, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
