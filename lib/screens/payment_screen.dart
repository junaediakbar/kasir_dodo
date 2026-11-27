import 'package:flutter/material.dart';

import '../core/cart.dart';
import '../core/money.dart';
import '../data/repo.dart';
import '../theme.dart';
import 'receipt_screen.dart';

/// Pembayaran (acuan Stitch: pembayaran_kasir_hitung_kembalian).
/// Tunai: hitung kembalian. Transfer/QRIS: dicatat manual, nominal = total.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.repo, required this.lines});
  final Repo repo;
  final List<CartLine> lines;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

/// Saran uang diterima: pembulatan ke atas ke pecahan umum, maksimal 3, di atas total.
List<int> quickCash(int total) {
  final out = <int>{};
  for (final step in [5000, 10000, 20000, 50000, 100000]) {
    final v = ((total + step - 1) ~/ step) * step;
    if (v > total) out.add(v);
  }
  return (out.toList()..sort()).take(3).toList();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _method = 'CASH';
  final _paid = TextEditingController();
  bool _saving = false;

  int get _total => widget.lines.fold(0, (s, l) => s + l.subtotal);
  int get _items => widget.lines.fold(0, (s, l) => s + l.qty);
  int get _paidAmount => _method == 'CASH' ? parseRupiah(_paid.text) : _total;
  bool get _canPay => !_saving && _paidAmount >= _total && widget.lines.isNotEmpty;

  @override
  void dispose() {
    _paid.dispose();
    super.dispose();
  }

  void _setPaid(int v) => setState(() => _paid.text = '$v');

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = _paidAmount;
    final enough = paid >= _total;
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _totalCard(),
          const SizedBox(height: 16),
          const SectionLabel('Metode pembayaran'),
          _methods(),
          const SizedBox(height: 16),
          if (_method == 'CASH') ...[
            SectionLabel('Uang diterima dari pembeli',
                trailing: enough && paid > 0
                    ? pill('Lunas', fg: kOnMintSoft, bg: kMintSoft)
                    : null),
            TextField(
              controller: _paid,
              keyboardType: TextInputType.number,
              style: mono(26, weight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '0',
                prefixText: 'Rp ',
                prefixStyle: mono(20, weight: FontWeight.w400, color: kInkSoft),
                fillColor: kSurfaceLow,
                suffixIcon: IconButton(
                  tooltip: 'Hapus nominal',
                  icon: const Icon(Icons.backspace_outlined),
                  onPressed: () => setState(_paid.clear),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _cashGrid(),
            const SizedBox(height: 16),
            _changeCard(enough ? paid - _total : 0, enough),
          ] else
            Panel(
              color: kSurfaceLow,
              child: Row(children: [
                const Icon(Icons.info_outline, color: kInkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'Pencatatan manual. Pastikan ${_method == 'QRIS' ? 'QRIS' : 'transfer'} '
                      'sebesar ${rp(_total)} sudah masuk.'),
                ),
              ]),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: _canPay ? _confirm : null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
          child: Row(children: [
            const Icon(Icons.check_circle_outline),
            const SizedBox(width: 12),
            const Expanded(child: Text('Selesaikan')),
            if (_saving)
              const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else
              const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }

  Widget _totalCard() => Panel(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Total tagihan belanja'),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Money(_total, size: 32)),
            Text('$_items barang', style: mono(12, color: kInkSoft)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final l in widget.lines)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                    color: kSurfaceLow, borderRadius: BorderRadius.circular(4)),
                child: Text('${l.name} (${l.qty}x)', style: mono(11, color: kInkSoft)),
              ),
          ]),
        ]),
      );

  Widget _methods() {
    const options = [
      ('CASH', 'Tunai', 'Uang fisik', Icons.payments_outlined),
      ('QRIS', 'QRIS', 'Dicatat manual', Icons.qr_code_2),
      ('TRANSFER', 'Transfer', 'Dicatat manual', Icons.account_balance_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: kSurfaceMid, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        for (final (value, label, hint, icon) in options)
          Expanded(
            child: Material(
              color: _method == value ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              elevation: _method == value ? 1 : 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => setState(() {
                  _method = value;
                  if (value != 'CASH') _paid.clear();
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(children: [
                    Icon(icon, color: _method == value ? kPrimaryDark : kInkSoft),
                    const SizedBox(height: 2),
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _method == value ? kPrimaryDark : kInk)),
                    Text(hint, style: mono(9, color: kInkSoft)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _cashGrid() {
    final options = [('Uang pas', _total), for (final v in quickCash(_total)) ('Pecahan', v)];
    final paid = parseRupiah(_paid.text);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.9,
      children: [
        for (final (label, value) in options)
          Material(
            color: paid == value ? kPrimary : kSurfaceLow,
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => _setPaid(value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(label.toUpperCase(),
                            style: mono(10,
                                weight: FontWeight.w600,
                                color: paid == value ? Colors.white70 : kInkSoft)),
                        Money(value, size: 14, color: paid == value ? Colors.white : kInk),
                      ],
                    ),
                  ),
                  Icon(paid == value ? Icons.check_circle_outline : Icons.add_circle_outline,
                      size: 20, color: paid == value ? Colors.white : kInkSoft),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _changeCard(int change, bool enough) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: enough ? kPrimaryDark : kSurfaceHigh,
            borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.currency_exchange,
                size: 16, color: enough ? kMintFixed : kInkSoft),
            const SizedBox(width: 6),
            Text(enough ? 'SERAHKAN KE PEMBELI' : 'UANG BELUM CUKUP',
                style: mono(11,
                    weight: FontWeight.w700, color: enough ? kMintFixed : kInkSoft)),
          ]),
          const SizedBox(height: 6),
          Text('Kembalian ${rp(change)}',
              style: mono(30, weight: FontWeight.w700, color: enough ? Colors.white : kInk)),
          if (!enough)
            Text('Kurang ${rp(_total - _paidAmount)}',
                style: mono(12, weight: FontWeight.w600, color: kRed)),
        ]),
      );
}
