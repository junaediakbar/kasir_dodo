import 'package:flutter/material.dart';

import '../core/cart.dart';
import '../core/money.dart';
import '../data/repo.dart';
import 'receipt_screen.dart';

/// Pembayaran. Tunai: hitung kembalian. Transfer/QRIS: dicatat manual, nominal = total.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.repo, required this.lines});
  final Repo repo;
  final List<CartLine> lines;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _method = 'CASH';
  final _paid = TextEditingController();
  bool _saving = false;

  int get _total => widget.lines.fold(0, (s, l) => s + l.subtotal);

  int get _paidAmount => _method == 'CASH' ? parseRupiah(_paid.text) : _total;

  bool get _canPay =>
      !_saving && _paidAmount >= _total && widget.lines.isNotEmpty;

  @override
  void dispose() {
    _paid.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      final saleId = await widget.repo.checkout(
        lines: widget.lines,
        method: _method,
        paid: _paidAmount,
      );
      if (!mounted) return;
      // Struk langsung tampil; hasil true dikembalikan ke Kasir untuk mengosongkan keranjang.
      Navigator.pushReplacement<void, bool>(
        context,
        MaterialPageRoute(builder: (_) => ReceiptScreen(repo: widget.repo, saleId: saleId)),
        result: true,
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final change = _paidAmount >= _total ? _paidAmount - _total : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Total tagihan', style: Theme.of(context).textTheme.titleMedium),
          Text(rp(_total),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'CASH', label: Text('Tunai')),
              ButtonSegment(value: 'TRANSFER', label: Text('Transfer')),
              ButtonSegment(value: 'QRIS', label: Text('QRIS')),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() {
              _method = s.first;
              if (_method != 'CASH') _paid.clear();
            }),
          ),
          const SizedBox(height: 16),
          if (_method == 'CASH') ...[
            TextField(
              controller: _paid,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Uang diterima (Rp)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ActionChip(
                label: const Text('Uang Pas'),
                onPressed: () => setState(() => _paid.text = '$_total'),
              ),
              for (final n in [20000, 50000, 100000])
                ActionChip(
                  label: Text(rp(n)),
                  onPressed: () => setState(() => _paid.text = '$n'),
                ),
            ]),
            const SizedBox(height: 16),
            Text('Kembalian ${rp(change)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ] else
            const Text('Pencatatan manual. Pastikan pembayaran sudah diterima.'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _canPay ? _confirm : null,
            child: const Text('Selesaikan'),
          ),
        ],
      ),
    );
  }
}
