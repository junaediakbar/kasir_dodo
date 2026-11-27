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
          appBar: AppBar(title: const Text('Struk')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: RepaintBoundary(
                  key: _cardKey,
                  child: _ReceiptCard(d),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _share(d.sale),
                icon: const Icon(Icons.share),
                label: const Text('Bagikan struk'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: kPrimary,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Selesai'),
              ),
            ],
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

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard(this.d);
  final _ReceiptData d;

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black);
    final when = DateTime.fromMillisecondsSinceEpoch(d.sale['created_at'] as int);
    final method = d.sale['method'] as String;
    final total = d.sale['total'] as int;
    final paid = d.sale['paid'] as int;
    final change = d.sale['change'] as int;
    final isVoid = d.sale['status'] == 'VOID';
    return Container(
      width: 300,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: DefaultTextStyle(
        style: mono,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(d.store['name'] as String,
                  style: mono.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            if ((d.store['address'] as String).isNotEmpty)
              Center(child: Text(d.store['address'] as String, textAlign: TextAlign.center)),
            if ((d.store['phone'] as String).isNotEmpty)
              Center(child: Text(d.store['phone'] as String)),
            const Divider(),
            Text(d.sale['number'] as String),
            Text('${when.day}/${when.month}/${when.year} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}'),
            if (isVoid)
              Text('*** DIBATALKAN ***', style: mono.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            for (final it in d.items) ...[
              Text(it['name_snapshot'] as String),
              Row(children: [
                Expanded(child: Text('  ${it['qty']} x ${rp(it['price'] as int)}')),
                Text(rp((it['qty'] as int) * (it['price'] as int))),
              ]),
            ],
            const Divider(),
            _line('TOTAL', rp(total)),
            _line('Metode', method),
            _line('Bayar', rp(paid)),
            _line('Kembali', rp(change)),
            const Divider(),
            Center(child: Text(d.store['receipt_footer'] as String, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }

  Widget _line(String a, String b) => Row(children: [
        Expanded(child: Text(a)),
        Text(b),
      ]);
}
