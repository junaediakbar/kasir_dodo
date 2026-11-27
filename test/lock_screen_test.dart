import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dodo/core/pin.dart';
import 'package:kasir_dodo/screens/gate.dart';

void main() {
  const salt = 'garam';
  final store = {
    'name': 'Toko Uji',
    'owner_name': 'Sari',
    'pin_salt': salt,
    'pin_hash': hashPin('123456', salt),
  };

  Future<void> typePin(WidgetTester t, String pin) async {
    for (final d in pin.split('')) {
      await t.tap(find.text(d));
      await t.pump();
    }
  }

  testWidgets('keypad: PIN benar membuka, salah 5x terkunci 1 menit', (t) async {
    var unlocked = 0;
    await t.binding.setSurfaceSize(const Size(400, 900));
    await t.pumpWidget(MaterialApp(
      home: LockScreen(store: store, onUnlock: () => unlocked++),
    ));

    await typePin(t, '000000');
    expect(find.text('PIN salah (4 percobaan tersisa)'), findsOneWidget);
    expect(unlocked, 0);

    for (var i = 0; i < 4; i++) {
      await typePin(t, '000000');
    }
    expect(find.text('Terlalu banyak salah. Terkunci 1 menit'), findsOneWidget);

    // PIN benar pun ditolak selama terkunci.
    await typePin(t, '123456');
    expect(find.textContaining('Terkunci. Coba lagi'), findsOneWidget);
    expect(unlocked, 0);
  });

  testWidgets('keypad: hapus satu digit lalu PIN benar membuka', (t) async {
    var unlocked = 0;
    await t.binding.setSurfaceSize(const Size(400, 900));
    await t.pumpWidget(MaterialApp(
      home: LockScreen(store: store, onUnlock: () => unlocked++),
    ));
    await typePin(t, '12');
    await t.tap(find.byTooltip('Hapus'));
    await t.pump();
    await typePin(t, '23456');
    expect(unlocked, 1);
  });
}
