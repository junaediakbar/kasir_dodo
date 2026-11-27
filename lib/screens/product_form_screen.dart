import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/repo.dart';
import '../theme.dart';

/// Tambah atau ubah produk. Stok awal hanya saat tambah; ubah stok di tab Stok.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, required this.repo, this.productId});
  final Repo repo;
  final int? productId;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sell = TextEditingController();
  final _cost = TextEditingController();
  final _unit = TextEditingController(text: 'pcs');
  final _stock = TextEditingController(text: '0');
  final _minStock = TextEditingController(text: '5');
  final _barcode = TextEditingController();
  int? _categoryId;
  bool _loaded = false;
  bool _saving = false;
  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final p = await widget.repo.product(widget.productId!);
    if (p == null || !mounted) return;
    setState(() {
      _name.text = p['name'] as String;
      _sell.text = '${p['sell_price']}';
      _cost.text = '${p['cost_price']}';
      _unit.text = p['unit'] as String;
      _stock.text = '${p['stock']}';
      _minStock.text = '${p['min_stock']}';
      _barcode.text = (p['barcode'] as String?) ?? '';
      _categoryId = p['category_id'] as int?;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _sell, _cost, _unit, _stock, _minStock, _barcode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kategori baru'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama kategori'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    try {
      final id = await widget.repo.addCategory(name);
      setState(() => _categoryId = id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kategori sudah ada')));
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final name = _name.text.trim();
    final sell = parseRupiah(_sell.text);
    final cost = parseRupiah(_cost.text);
    final minStock = int.tryParse(_minStock.text) ?? 5;
    final barcode = _barcode.text.trim().isEmpty ? null : _barcode.text.trim();
    if (_isEdit) {
      await widget.repo.updateProduct(widget.productId!, {
        'name': name,
        'category_id': _categoryId,
        'sell_price': sell,
        'cost_price': cost,
        'unit': _unit.text.trim(),
        'min_stock': minStock,
        'barcode': barcode,
      });
    } else {
      await widget.repo.addProduct(
        name: name,
        categoryId: _categoryId,
        sellPrice: sell,
        costPrice: cost,
        unit: _unit.text.trim(),
        stock: int.tryParse(_stock.text) ?? 0,
        minStock: minStock,
        barcode: barcode,
      );
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _archive() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Arsipkan produk?'),
        content: const Text('Produk disembunyikan dari kasir. Riwayat transaksi tetap ada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Arsipkan')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.repo.archiveProduct(widget.productId!);
    if (mounted) Navigator.pop(context, true);
  }

  String? _required(String? v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null;

  Widget _section(IconData icon, String title, List<Widget> children) => Panel(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            iconTile(icon, size: 32),
            const SizedBox(width: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 14),
          for (final (i, c) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            c,
          ],
        ]),
      );

  Widget _margin() {
    final sell = parseRupiah(_sell.text), cost = parseRupiah(_cost.text);
    if (sell <= 0) return const SizedBox.shrink();
    final profit = sell - cost;
    final pct = (profit * 100 / sell).round();
    final ok = profit > 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: ok ? const Color(0xFFE6F7EF) : kRedSoft,
          borderRadius: BorderRadius.circular(4)),
      child: Row(children: [
        Icon(ok ? Icons.trending_up : Icons.trending_down,
            size: 18, color: ok ? kPrimaryDark : kRed),
        const SizedBox(width: 8),
        Expanded(
          child: Text(ok ? 'Laba per ${_unit.text.trim().isEmpty ? 'unit' : _unit.text.trim()}' : 'Harga jual di bawah modal',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: ok ? kPrimaryDark : kRed)),
        ),
        Money(profit, size: 13, color: ok ? kPrimaryDark : kRed),
        const SizedBox(width: 6),
        pill('$pct%', fg: ok ? kOnMintSoft : kRed, bg: ok ? kMintSoft : Colors.white),
      ]),
    );
  }

  InputDecoration _dec(String label, {String? hint, String? prefix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        prefixStyle: mono(14, color: kInkSoft),
      );

  @override
  Widget build(BuildContext context) {
    if (_isEdit && !_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final money = mono(15, weight: FontWeight.w700);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah Produk' : 'Tambah Produk Baru'),
        actions: [
          if (_isEdit)
            TextButton.icon(
              onPressed: _archive,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Arsipkan'),
              style: TextButton.styleFrom(foregroundColor: kRed),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(Icons.inventory_2_outlined, 'Informasi Dasar Produk', [
              TextFormField(
                controller: _name,
                decoration: _dec('Nama produk', hint: 'mis. Indomie Goreng Spesial'),
                validator: _required,
              ),
              FutureBuilder<List<Map<String, Object?>>>(
                future: widget.repo.categories(),
                builder: (context, snap) {
                  final cats = snap.data ?? const [];
                  return Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue:
                            cats.any((c) => c['id'] == _categoryId) ? _categoryId : null,
                        decoration: _dec('Kategori'),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('Tanpa kategori')),
                          for (final c in cats)
                            DropdownMenuItem<int?>(
                                value: c['id'] as int, child: Text(c['name'] as String)),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox.square(
                      dimension: 52,
                      child: OutlinedButton(
                        onPressed: _addCategory,
                        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Icon(Icons.add, semanticLabel: 'Kategori baru'),
                      ),
                    ),
                  ]);
                },
              ),
              TextFormField(
                controller: _barcode,
                style: mono(14),
                decoration: _dec('Barcode EAN/UPC (opsional)').copyWith(
                    prefixIcon: const Icon(Icons.qr_code_scanner)),
              ),
            ]),
            const SizedBox(height: 12),
            _section(Icons.sell_outlined, 'Harga & Margin', [
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _cost,
                    keyboardType: TextInputType.number,
                    style: money,
                    decoration: _dec('Modal (HPP)', prefix: 'Rp '),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sell,
                    keyboardType: TextInputType.number,
                    style: money,
                    decoration: _dec('Harga jual', prefix: 'Rp '),
                    validator: _required,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
              TextFormField(
                controller: _unit,
                decoration: _dec('Satuan jual', hint: 'pcs, bks, kg, botol'),
                validator: _required,
                onChanged: (_) => setState(() {}),
              ),
              _margin(),
            ]),
            const SizedBox(height: 12),
            _section(Icons.warehouse_outlined, 'Inventaris & Pengingat Restok', [
              Row(children: [
                if (!_isEdit) ...[
                  Expanded(
                    child: TextFormField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      style: money,
                      decoration: _dec('Stok awal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: TextFormField(
                    controller: _minStock,
                    keyboardType: TextInputType.number,
                    style: money,
                    decoration: _dec('Batas stok minimum'),
                  ),
                ),
              ]),
              Row(children: [
                const Icon(Icons.notifications_active_outlined, size: 16, color: kAmberDark),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isEdit
                        ? 'Ubah jumlah stok lewat tab Stok agar tercatat di kartu stok.'
                        : 'Produk masuk Pengingat Stok saat stok ≤ batas minimum.',
                    style: const TextStyle(fontSize: 12, color: kInkSoft),
                  ),
                ),
              ]),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Simpan'),
        ),
      ),
    );
  }
}
