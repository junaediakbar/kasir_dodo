import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/repo.dart';

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

  @override
  Widget build(BuildContext context) {
    if (_isEdit && !_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah produk' : 'Produk baru'),
        actions: [
          if (_isEdit)
            IconButton(icon: const Icon(Icons.archive_outlined), onPressed: _archive),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama produk'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, Object?>>>(
              future: widget.repo.categories(),
              builder: (context, snap) {
                final cats = snap.data ?? const [];
                return Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: cats.any((c) => c['id'] == _categoryId) ? _categoryId : null,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Tanpa kategori')),
                        for (final c in cats)
                          DropdownMenuItem<int?>(
                              value: c['id'] as int, child: Text(c['name'] as String)),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.add), onPressed: _addCategory),
                ]);
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _sell,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Harga jual (Rp)'),
                  validator: _required,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cost,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Harga modal (Rp)'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _unit,
                  decoration: const InputDecoration(labelText: 'Satuan'),
                  validator: _required,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _minStock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Batas stok min'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            if (!_isEdit)
              TextFormField(
                controller: _stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stok awal'),
              ),
            if (!_isEdit) const SizedBox(height: 12),
            TextFormField(
              controller: _barcode,
              decoration: const InputDecoration(labelText: 'Barcode (opsional)'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
