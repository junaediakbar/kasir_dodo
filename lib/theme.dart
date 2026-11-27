import 'package:flutter/material.dart';

import 'core/money.dart';

// Token warna dari stitch_minimalist_retail_pos_cashier (tailwind.config di code.html).
const kPrimary = Color(0xFF047857); // primary-container: tombol utama
const kPrimaryDark = Color(0xFF005D42); // primary: kartu hero, ikon aktif
const kMint = Color(0xFF10B981);
const kMintSoft = Color(0xFF6CF8BB); // secondary-container
const kOnMintSoft = Color(0xFF00714D);
const kMintFixed = Color(0xFF6FFBBE); // secondary-fixed: aksen di atas hijau tua
const kAmber = Color(0xFFF59E0B);
const kAmberDark = Color(0xFF734700); // tertiary
const kAmberSoft = Color(0xFFFFDDB8); // tertiary-fixed
const kRed = Color(0xFFBA1A1A); // error
const kRedSoft = Color(0xFFFFDAD6); // error-container
const kBg = Color(0xFFFBF8FF); // surface
const kSurfaceLow = Color(0xFFF4F2FD);
const kSurfaceMid = Color(0xFFEEEDF7);
const kSurfaceHigh = Color(0xFFE8E7F1);
const kBorder = Color(0xFFE4E4E7);
const kOutline = Color(0xFF6E7A73);
const kOutlineSoft = Color(0xFFBDC9C1);
const kInk = Color(0xFF1A1B22); // on-surface
const kInkSoft = Color(0xFF3E4943); // on-surface-variant
const kDark = Color(0xFF2F3038); // inverse-surface

const kSans = 'HankenGrotesk';
const kMono = 'JetBrainsMono';

/// Gaya JetBrains Mono untuk angka, SKU, label status, dan waktu.
TextStyle mono(double size, {FontWeight weight = FontWeight.w500, Color? color}) =>
    TextStyle(fontFamily: kMono, fontSize: size, fontWeight: weight, color: color);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kPrimary).copyWith(
    primary: kPrimary,
    onPrimary: Colors.white,
    primaryContainer: kPrimary,
    onPrimaryContainer: Colors.white,
    secondary: const Color(0xFF006C49),
    secondaryContainer: kMintSoft,
    onSecondaryContainer: kOnMintSoft,
    tertiary: kAmberDark,
    tertiaryContainer: kAmberSoft,
    error: kRed,
    errorContainer: kRedSoft,
    surface: kBg,
    onSurface: kInk,
    onSurfaceVariant: kInkSoft,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: kSurfaceLow,
    surfaceContainer: kSurfaceMid,
    surfaceContainerHigh: kSurfaceHigh,
    outline: kOutline,
    outlineVariant: kOutlineSoft,
    surfaceTint: Colors.transparent,
  );
  const r4 = BorderRadius.all(Radius.circular(4));
  const r8 = BorderRadius.all(Radius.circular(8));
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: kSans);
  TextStyle sans(double s, FontWeight w, [Color c = kInk]) =>
      TextStyle(fontFamily: kSans, fontSize: s, fontWeight: w, color: c);
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    textTheme: base.textTheme.copyWith(
      headlineSmall: sans(22, FontWeight.w700),
      titleLarge: sans(18, FontWeight.w700),
      titleMedium: sans(16, FontWeight.w700),
      titleSmall: sans(14, FontWeight.w600),
      bodyLarge: sans(16, FontWeight.w500),
      bodyMedium: sans(14, FontWeight.w400),
      bodySmall: sans(12, FontWeight.w400, kInkSoft),
      labelSmall: mono(10, color: kInkSoft),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kBg,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: const Color(0x14000000),
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: sans(18, FontWeight.w700),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: kBg,
      elevation: 3,
      shadowColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => mono(10,
          weight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? kPrimaryDark : kInkSoft)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          size: 24, color: s.contains(WidgetState.selected) ? kPrimaryDark : kInkSoft)),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: r8, side: BorderSide(color: kBorder)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(borderRadius: r4),
        textStyle: sans(16, FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kInk,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: kOutlineSoft),
        shape: const RoundedRectangleBorder(borderRadius: r4),
        textStyle: sans(14, FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPrimaryDark,
        shape: const RoundedRectangleBorder(borderRadius: r4),
        textStyle: sans(14, FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kPrimaryDark,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: r8),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: r4, borderSide: BorderSide(color: Color(0xFFD4D4D8), width: 1.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: r4, borderSide: BorderSide(color: Color(0xFFD4D4D8), width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: r4, borderSide: BorderSide(color: kPrimary, width: 2)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kSurfaceMid,
      selectedColor: kDark,
      side: BorderSide.none,
      showCheckmark: false,
      shape: const RoundedRectangleBorder(borderRadius: r4),
      labelStyle: mono(12, weight: FontWeight.w600, color: kInk),
      secondaryLabelStyle: mono(12, weight: FontWeight.w600, color: Colors.white),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: r8),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kDark,
      shape: RoundedRectangleBorder(borderRadius: r4),
    ),
    dividerTheme: const DividerThemeData(color: kBorder, space: 1),
  );
}

/// Nominal Rupiah: "Rp" 75% dan reguler, angka JetBrains Mono tebal (DESIGN.md).
class Money extends StatelessWidget {
  const Money(this.amount,
      {super.key, this.size = 14, this.color, this.weight = FontWeight.w700});
  final int amount;
  final double size;
  final Color? color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? kInk;
    final text = rp(amount);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'Rp ', style: mono(size * .75, weight: FontWeight.w400, color: c)),
        TextSpan(text: text.substring(3), style: mono(size, weight: weight, color: c)),
      ]),
      semanticsLabel: text,
      maxLines: 1,
    );
  }
}

/// Judul bagian kecil kapital, mis. "METODE PEMBAYARAN".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: mono(11, weight: FontWeight.w700, color: kInkSoft)
                    .copyWith(letterSpacing: .6)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Pil status kecil kapital, mis. HABIS / LUNAS / VOID.
Widget pill(String text, {Color fg = kInk, Color bg = kSurfaceHigh, IconData? icon}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 11, color: fg), const SizedBox(width: 3)],
        Text(text.toUpperCase(),
            style: mono(10, weight: FontWeight.w700, color: fg).copyWith(letterSpacing: .5)),
      ]),
    );

/// Badge stok: Habis (merah) atau Menipis (amber). null jika aman.
Widget? stockBadge(int stock, int minStock) {
  if (stock <= 0) return pill('Habis', fg: const Color(0xFF93000A), bg: kRedSoft);
  if (minStock > 0 && stock <= minStock) {
    return pill('Menipis', fg: const Color(0xFF653E00), bg: kAmberSoft);
  }
  return null;
}

/// Kartu putih ber-border radius 8 (Level 1 DESIGN.md), bisa diketuk.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color = Colors.white,
    this.borderColor = kBorder,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), side: BorderSide(color: borderColor)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

/// Kotak ikon persegi berwarna lembut, dipakai di daftar dan kartu.
Widget iconTile(IconData icon,
        {Color fg = kPrimaryDark, Color bg = kSurfaceMid, double size = 40}) =>
    Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Icon(icon, color: fg, size: size * .5),
    );
