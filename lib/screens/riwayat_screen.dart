import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/pin.dart';
import '../data/repo.dart';
import '../theme.dart';
import 'receipt_screen.dart';

const _methodLabel = {'CASH': 'Tunai', 'QRIS': 'QRIS', 'TRANSFER': 'Transfer'};
const _methodIcon = {
  'CASH': Icons.payments_outlined,
  'QRIS': Icons.qr_code_2,
  'TRANSFER': Icons.account_balance_outlined,
};

String _two(int n) => n.toString().padLeft(2, '0');
String _time(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
String _date(DateTime t) => '${_two(t.day)}/${_two(t.month)}/${t.year}';

/// Riwayat transaksi per tanggal (acuan Stitch: riwayat_transaksi_kasir_trx_09).
class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key, required this.repo});
  final Repo repo;

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  String? _status; // null = semua, 'DONE', 'VOID'

  Future<void> _openDetail(int saleId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SaleDetailScreen(repo: widget.repo, saleId: saleId)),
    );
    setState(() {}); // status bisa berubah karena void
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: widget.repo.sales(),
        builder: (context, snap) {
          final all = snap.data ?? const [];
          if (all.isEmpty && snap.connectionState == ConnectionState.done) {
            return const Center(child: Text('Belum ada transaksi'));
          }
          final done = all.where((s) => s['status'] == 'DONE').toList();
          final sales = _status == null ? all : all.where((s) => s['status'] == _status).toList();
          final rows = <Widget>[];
          String? lastDay;
          for (final s in sales) {
            final t = DateTime.fromMillisecondsSinceEpoch(s['created_at'] as int);
            final day = _date(t);
            if (day != lastDay) {
              rows.add(Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SectionLabel(day),
              ));
              lastDay = day;
            }
            rows..add(_card(s, t))..add(const SizedBox(height: 8));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _summary(done),
              const SizedBox(height: 12),
              Row(children: [
                for (final (value, label) in [
                  (null, 'Semua (${all.length})'),
                  ('DONE', 'Lunas (${done.length})'),
                  ('VOID', 'Void (${all.length - done.length})'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _status == value,
                      onSelected: (_) => setState(() => _status = value),
                    ),
                  ),
              ]),
              ...rows,
            ],
          );
        },
      ),
    );
  }

  Widget _summary(List<Map<String, Object?>> done) {
    final total = done.fold(0, (s, e) => s + (e['total'] as int));
    final byMethod = <String, int>{};
    for (final s in done) {
      byMethod.update(s['method'] as String, (v) => v + (s['total'] as int),
          ifAbsent: () => s['total'] as int);
    }
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionLabel('Omzet transaksi tercatat'),
        Money(total, size: 28, color: kPrimaryDark),
        Text('${done.length} transaksi lunas', style: const TextStyle(fontSize: 12, color: kInkSoft)),
        const SizedBox(height: 12),
        Row(children: [
          for (final m in ['CASH', 'QRIS', 'TRANSFER']) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: kSurfaceLow, borderRadius: BorderRadius.circular(4)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(_methodIcon[m], size: 14, color: kInkSoft),
                    const SizedBox(width: 4),
                    Text(_methodLabel[m]!, style: const TextStyle(fontSize: 11, color: kInkSoft)),
                  ]),
                  const SizedBox(height: 2),
                  FittedBox(child: Money(byMethod[m] ?? 0, size: 12)),
                ]),
              ),
            ),
            if (m != 'TRANSFER') const SizedBox(width: 6),
          ],
        ]),
      ]),
    );
  }

  Widget _card(Map<String, Object?> s, DateTime t) {
    final isVoid = s['status'] == 'VOID';
    final method = s['method'] as String;
    return Panel(
      onTap: () => _openDetail(s['id'] as int),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${s['number']}',
                style: mono(13, weight: FontWeight.w700).copyWith(
                    decoration: isVoid ? TextDecoration.lineThrough : null)),
          ),
          isVoid
              ? pill('Void', fg: const Color(0xFF93000A), bg: kRedSoft, icon: Icons.block)
              : pill('Lunas', fg: kOnMintSoft, bg: kMintSoft),
        ]),
        const SizedBox(height: 2),
        Row(children: [
          Text(_time(t), style: mono(11, color: kInkSoft)),
          const SizedBox(width: 8),
          Icon(_methodIcon[method], size: 14, color: kInkSoft),
          const SizedBox(width: 4),
          Text(_methodLabel[method] ?? method,
              style: const TextStyle(fontSize: 12, color: kInkSoft)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isVoid ? 'Nominal batal' : 'Total belanja',
                  style: const TextStyle(fontSize: 11, color: kInkSoft)),
              Opacity(
                opacity: isVoid ? .5 : 1,
                child: Money(s['total'] as int, size: 22, color: isVoid ? kInkSoft : kInk),
              ),
            ]),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ReceiptScreen(repo: widget.repo, saleId: s['id'] as int)),
            ),
            icon: const Icon(Icons.receipt_outlined, size: 18),
            label: const Text('Struk'),
            style: OutlinedButton.styleFrom(
                backgroundColor: kSurfaceLow, side: BorderSide.none),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: kOutline),
        ]),
      ]),
    );
  }
}

class SaleDetailScreen extends StatefulWidget {
  const SaleDetailScreen({super.key, required this.repo, required this.saleId});
  final Repo repo;
  final int saleId;

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  /// Void butuh PIN owner (acuan Stitch: modal_void_nota_otorisasi_pin_owner_trx_10).
  Future<bool> _checkPin(Map<String, Object?> sale) async {
    final c = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: iconTile(Icons.gpp_maybe_outlined, fg: kRed, bg: kRedSoft, size: 48),
        title: const Text('Void Nota'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${sale['number']}', style: mono(12, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Transaksi dibatalkan dan stok dikembalikan. Masukkan PIN owner.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: kInkSoft)),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: mono(24, weight: FontWeight.w700).copyWith(letterSpacing: 8),
            decoration: const InputDecoration(hintText: 'PIN owner', counterText: ''),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: kRed, minimumSize: const Size(100, 48)),
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    // Controller tidak di-dispose di sini: dialog masih beranimasi keluar.
    if (pin == null) return false;
    final store = await widget.repo.store();
    if (store == null) return false;
    return hashPin(pin, store['pin_salt'] as String) == store['pin_hash'];
  }

  Future<void> _void(Map<String, Object?> sale) async {
    final ok = await _checkPin(sale);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN salah. Transaksi tidak dibatalkan.')));
      return;
    }
    await widget.repo.voidSale(widget.saleId);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi dibatalkan, stok dikembalikan')));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>([
        widget.repo.saleById(widget.saleId).then((v) => v!),
        widget.repo.saleItems(widget.saleId),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final sale = snap.data![0] as Map<String, Object?>;
        final items = snap.data![1] as List<Map<String, Object?>>;
        final isVoid = sale['status'] == 'VOID';
        final t = DateTime.fromMillisecondsSinceEpoch(sale['created_at'] as int);
        final method = sale['method'] as String;
        return Scaffold(
          appBar: AppBar(title: const Text('Detail Transaksi')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Panel(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text('${sale['number']}', style: mono(14, weight: FontWeight.w700)),
                    ),
                    isVoid
                        ? pill('Dibatalkan', fg: const Color(0xFF93000A), bg: kRedSoft)
                        : pill('Lunas', fg: kOnMintSoft, bg: kMintSoft),
                  ]),
                  Text('${_date(t)} ${_time(t)} · ${_methodLabel[method] ?? method}',
                      style: mono(11, color: kInkSoft)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: kSurfaceLow, borderRadius: BorderRadius.circular(4)),
                    child: Column(children: [
                      for (final it in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Expanded(
                              child: Text('${it['qty']}x ${it['name_snapshot']}',
                                  style: TextStyle(
                                      decoration: isVoid ? TextDecoration.lineThrough : null)),
                            ),
                            Text(rp((it['qty'] as int) * (it['price'] as int)),
                                style: mono(12, weight: FontWeight.w600)),
                          ]),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Expanded(
                        child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700))),
                    Money(sale['total'] as int, size: 22, color: isVoid ? kInkSoft : kInk),
                  ]),
                  if (isVoid) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: kRedSoft, borderRadius: BorderRadius.circular(4)),
                      child: const Row(children: [
                        Icon(Icons.inventory_outlined, size: 16, color: kRed),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text('Dibatalkan dengan PIN owner. Stok sudah dikembalikan.',
                              style: TextStyle(fontSize: 12, color: kRed)),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
              if (!isVoid) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: kRed,
                      side: const BorderSide(color: kRed),
                    ),
                    onPressed: () => _void(sale),
                    icon: const Icon(Icons.block),
                    label: const Text('Void'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ReceiptScreen(repo: widget.repo, saleId: widget.saleId)),
                  ),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Lihat struk'),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
