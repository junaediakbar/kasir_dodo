import 'dart:io';

import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../theme.dart';

/// App bar tab utama ala Stitch: nama toko + pil "Data lokal" + judul halaman.
AppBar shopAppBar(Repo repo, String page, {List<Widget> actions = const []}) => AppBar(
      toolbarHeight: 64,
      titleSpacing: 16,
      title: FutureBuilder<Map<String, Object?>?>(
        future: repo.store(),
        builder: (context, snap) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(snap.data?['name'] as String? ?? 'Kasir Dodo',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Text(page, style: mono(10, weight: FontWeight.w600, color: kInkSoft)),
              const SizedBox(width: 8),
              pill('Data lokal', fg: Colors.white, bg: kPrimary, icon: Icons.offline_bolt),
            ]),
          ],
        ),
      ),
      actions: [...actions, const SizedBox(width: 8)],
    );

/// Thumbnail produk 48px: foto jika ada, selain itu inisial nama.
Widget productThumb(Map<String, Object?> p, {double size = 48}) {
  final path = p['photo_path'] as String?;
  final name = (p['name'] as String).trim();
  final initials = name.split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase();
  return ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: SizedBox.square(
      dimension: size,
      child: path != null && File(path).existsSync()
          ? Image.file(File(path), fit: BoxFit.cover, cacheWidth: (size * 3).round())
          : ColoredBox(
              color: kSurfaceMid,
              child: Center(
                child: Text(initials,
                    style: mono(size * .3, weight: FontWeight.w700, color: kPrimaryDark)),
              ),
            ),
    ),
  );
}
