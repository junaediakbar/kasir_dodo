import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/money.dart';
import '../data/repo.dart';
import '../theme.dart';

/// Struk 58 mm di layar. Bagikan sebagai gambar (WhatsApp, dll).
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.repo, required this.saleId});
  final Repo repo;
  final int saleId;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _cardKey = GlobalKey();

  Future<_ReceiptData> _load() async {
    final store = (await widget.repo.store())!;
    final sale = (await widget.repo.saleById(widget.saleId))!;
    final items = await widget.repo.saleItems(widget.saleId);
    return _ReceiptData(store, sale, items);
  }

  Future<void> _share(Map<String, Object?> sale) async {
    final boundary =
        _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'struk_${sale['number']}.png'));
    await file.writeAsBytes(data!.buffer.asUint8List());
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text: 'Struk ${sale['number']}',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReceiptData>(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final d = snap.data!;
        return Scaffold(
          backgroundColor: kSurfaceMid,
          appBar: AppBar(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Struk Penjualan'),
              Text(d.sale['number'] as String, style: mono(11, color: kInkSoft)),
            ]),
            actions: [
              IconButton(
                tooltip: 'Bagikan',
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _share(d.sale),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Center(
                child: RepaintBoundary(key: _cardKey, child: _ReceiptCard(d)),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FilledButton.icon(
                onPressed: () => _share(d.sale),
                icon: const Icon(Icons.share),
                label: const Text('Bagikan struk'),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.point_of_sale),
                label: const Text('Selesai'),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _ReceiptData {
  _ReceiptData(this.store, this.sale, this.items);
  final Map<String, Object?> store;
  final Map<String, Object?> sale;
  final List<Map<String, Object?>> items;
}

/// Kertas struk 58 mm: font mono hitam, garis putus-putus, tepi bawah bergerigi.
class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard(this.d);
  final _ReceiptData d;

  static const _methods = {'CASH': 'Tunai', 'QRIS': 'QRIS', 'TRANSFER': 'Transfer'};

  @override
  Widget build(BuildContext context) {
    final base = mono(11, color: Colors.black);
    final when = DateTime.fromMillisecondsSinceEpoch(d.sale['created_at'] as int);
    String two(int n) => n.toString().padLeft(2, '0');
    final method = d.sale['method'] as String;
    final isVoid = d.sale['status'] == 'VOID';
    final address = d.store['address'] as String;
    final phone = d.store['phone'] as String;
    final count = d.items.fold(0, (s, it) => s + (it['qty'] as int));
    return ClipPath(
      clipper: const _ZigzagClipper(),
      child: Container(
        width: 300,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        child: DefaultTextStyle(
          style: base,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.black, borderRadius: BorderRadius.circular(4)),
                  child: const Icon(Icons.storefront, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              Text((d.store['name'] as String).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: kSans, fontSize: 16, fontWeight: FontWeight.w800,
                      color: Colors.black)),
              if (address.isNotEmpty) Text(address, textAlign: TextAlign.center),
              if (phone.isNotEmpty) Text('Telp: $phone', textAlign: TextAlign.center),
              const _Dashed(),
              _line('NO. NOTA', d.sale['number'] as String),
              _line('WAKTU',
                  '${two(when.day)}/${two(when.month)}/${when.year} ${two(when.hour)}:${two(when.minute)}'),
              if (isVoid)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('*** DIBATALKAN ***',
                      textAlign: TextAlign.center,
                      style: base.copyWith(fontWeight: FontWeight.w700)),
                ),
              const _Dashed(),
              for (final it in d.items) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(it['name_snapshot'] as String)),
                  Text(rp((it['qty'] as int) * (it['price'] as int))),
                ]),
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 6),
                  child: Text('${it['qty']}x @ ${rp(it['price'] as int)}',
                      style: base.copyWith(color: Colors.black54, fontSize: 10)),
                ),
              ],
              const _Dashed(),
              _line('Subtotal ($count item)', rp(d.sale['total'] as int)),
              const SizedBox(height: 6),
              Container(
                color: const Color(0xFFEFEFEF),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(children: [
                  Text('TOTAL',
                      style: TextStyle(
                          fontFamily: kSans, fontSize: 15, fontWeight: FontWeight.w800,
                          color: Colors.black)),
                  const Spacer(),
                  Text(rp(d.sale['total'] as int),
                      style: base.copyWith(fontSize: 20, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 6),
              _line('Metode bayar', _methods[method] ?? method),
              _line('Diterima', rp(d.sale['paid'] as int)),
              _line('KEMBALIAN', rp(d.sale['change'] as int), bold: true),
              const _Dashed(),
              Text(d.store['receipt_footer'] as String,
                  textAlign: TextAlign.center,
                  style: base.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('*** Kasir Dodo ***',
                  textAlign: TextAlign.center,
                  style: base.copyWith(fontSize: 9, color: Colors.black45)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: [
          Expanded(
              child: Text(a,
                  style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null)),
          Text(b, style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
        ]),
      );
}

class _Dashed extends StatelessWidget {
  const _Dashed();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(
          builder: (_, c) => Row(
            children: List.generate(
              (c.maxWidth / 6).floor(),
              (_) => Container(
                  width: 3, height: 1, margin: const EdgeInsets.only(right: 3),
                  color: Colors.black38),
            ),
          ),
        ),
      );
}

class _ZigzagClipper extends CustomClipper<Path> {
  const _ZigzagClipper();

  @override
  Path getClip(Size s) {
    const t = 8.0; // lebar gigi
    final path = Path()..lineTo(s.width, 0)..lineTo(s.width, s.height - t / 2);
    var x = s.width;
    var down = true;
    while (x > 0) {
      x -= t / 2;
      path.lineTo(x.clamp(0, s.width), down ? s.height : s.height - t / 2);
      down = !down;
    }
    return path..close();
  }

  @override
  bool shouldReclip(_ZigzagClipper old) => false;
}
