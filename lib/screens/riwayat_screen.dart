import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/repo.dart';
import '../core/pin.dart';
import '../theme.dart';
import 'receipt_screen.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key, required this.repo});
  final Repo repo;

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat transaksi')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: widget.repo.sales(),
        builder: (context, snap) {
          final sales = snap.data ?? const [];
          if (sales.isEmpty && snap.connectionState == ConnectionState.done) {
            return const Center(child: Text('Belum ada transaksi'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sales.length,
            itemBuilder: (_, i) {
              final s = sales[i];
              final isVoid = s['status'] == 'VOID';
              final t = DateTime.fromMillisecondsSinceEpoch(s['created_at'] as int);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${s['number']}'),
                  subtitle: Text(
                      '${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} · ${s['method']}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(rp(s['total'] as int),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              decoration: isVoid ? TextDecoration.lineThrough : null)),
                      if (isVoid)
                        const Text('VOID', style: TextStyle(color: kRed, fontSize: 11)),
                    ],
                  ),
                  onTap: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SaleDetailScreen(
                            repo: widget.repo, saleId: s['id'] as int),
                      ),
                    );
                    if (changed == true) setState(() {});
                  },
                ),
              );
            },
          );
        },
      ),
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
  bool _voided = false;

  /// Void butuh PIN owner (PRD TRX-10).
  Future<bool> _checkPin() async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Void transaksi'),
          content: TextField(
            controller: c,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'PIN owner'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Void')),
          ],
        );
      },
    );
    if (pin == null) return false;
    final store = await widget.repo.store();
    if (store == null) return false;
    return hashPin(pin, store['pin_salt'] as String) == store['pin_hash'];
  }

  Future<void> _void() async {
    final ok = await _checkPin();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PIN salah. Transaksi tidak dibatalkan.')));
      return;
    }
    await widget.repo.voidSale(widget.saleId);
    if (!mounted) return;
    setState(() => _voided = true);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Transaksi dibatalkan, stok dikembalikan')));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _voided) Navigator.of(context).pop(true);
      },
      child: FutureBuilder<List<Object>>(
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
          final isVoid = sale['status'] == 'VOID' || _voided;
          return Scaffold(
            appBar: AppBar(title: Text('${sale['number']}')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Status: ${isVoid ? 'VOID' : 'Selesai'}',
                    style: TextStyle(color: isVoid ? kRed : kPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                for (final it in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(it['name_snapshot'] as String),
                    subtitle: Text('${it['qty']} x ${rp(it['price'] as int)}'),
                    trailing: Text(rp((it['qty'] as int) * (it['price'] as int))),
                  ),
                const Divider(),
                Row(children: [
                  const Expanded(child: Text('Total')),
                  Text(rp(sale['total'] as int), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ReceiptScreen(repo: widget.repo, saleId: widget.saleId)),
                  ),
                  child: const Text('Lihat struk'),
                ),
                if (!isVoid) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: kRed,
                    ),
                    onPressed: _void,
                    child: const Text('Void transaksi (PIN owner)'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
