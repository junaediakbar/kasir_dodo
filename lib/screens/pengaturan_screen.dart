import 'package:flutter/material.dart';

import '../core/pin.dart';
import '../data/ai_key.dart';
import '../data/repo.dart';
import '../theme.dart';

/// Profil toko (F-16) dan pengaturan Scan AI (F-17).
class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key, required this.repo});
  final Repo repo;

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _footer = TextEditingController();
  final _model = TextEditingController();
  double _threshold = .85;
  final _apiKey = TextEditingController();
  bool _aiEnabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await widget.repo.store();
    final key = await readAiKey();
    if (!mounted || s == null) return;
    setState(() {
      _name.text = s['name'] as String;
      _address.text = s['address'] as String;
      _phone.text = s['phone'] as String;
      _footer.text = s['receipt_footer'] as String;
      _model.text = s['ai_model'] as String;
      _threshold = (s['ai_threshold'] as num).toDouble();
      _aiEnabled = s['ai_enabled'] == 1;
      _apiKey.text = key ?? '';
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _footer, _model, _apiKey]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _confirmPrivacy() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Scan AI'),
        content: const Text(
            'Foto produk akan dikirim ke DeepSeek untuk dikenali. '
            'Foto tidak disimpan oleh aplikasi. Scan AI butuh internet.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mengerti')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _toggleAi(bool v) async {
    if (v && !await _confirmPrivacy()) return;
    setState(() => _aiEnabled = v);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _snack('Nama toko wajib diisi');
      return;
    }
    await widget.repo.updateStore({
      'name': _name.text.trim(),
      'address': _address.text.trim(),
      'phone': _phone.text.trim(),
      'receipt_footer': _footer.text.trim(),
      'ai_model': _model.text.trim(),
      'ai_threshold': _threshold,
      'ai_enabled': _aiEnabled ? 1 : 0,
    });
    if (_apiKey.text.trim().isNotEmpty) {
      await writeAiKey(_apiKey.text.trim());
    }
    if (!mounted) return;
    _snack('Pengaturan disimpan');
    Navigator.pop(context);
  }

  /// Ganti PIN owner: cek PIN lama, simpan hash PIN baru dengan salt baru.
  Future<void> _changePin() async {
    final old = TextEditingController();
    final pin = TextEditingController();
    final pin2 = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti PIN'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (c, label) in [
                (old, 'PIN lama'),
                (pin, 'PIN baru (6 digit)'),
                (pin2, 'Ulangi PIN baru'),
              ])
                TextFormField(
                  controller: c,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(labelText: label),
                  validator: (v) {
                    if (!RegExp(r'^\d{6}$').hasMatch(v ?? '')) return 'PIN harus 6 digit';
                    if (c == pin2 && v != pin.text) return 'PIN tidak sama';
                    return null;
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    // Controller tidak di-dispose di sini: dialog masih beranimasi keluar.
    final oldPin = old.text, newPin = pin.text;
    if (ok != true) return;
    final s = await widget.repo.store();
    if (!mounted) return;
    if (s == null || hashPin(oldPin, s['pin_salt'] as String) != s['pin_hash']) {
      _snack('PIN lama salah. PIN tidak diganti.');
      return;
    }
    final salt = newSalt();
    await widget.repo.updateStore({'pin_salt': salt, 'pin_hash': hashPin(newPin, salt)});
    if (!mounted) return;
    _snack('PIN berhasil diganti');
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _section(IconData icon, String title, String hint, List<Widget> children) => Panel(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            iconTile(icon, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(hint, style: const TextStyle(fontSize: 12, color: kInkSoft)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          for (final (i, c) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            c,
          ],
        ]),
      );

  /// Pratinjau kepala dan kaki struk dari isian profil toko.
  Widget _receiptPreview() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSurfaceLow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kBorder),
        ),
        child: DefaultTextStyle(
          style: mono(11, color: kInk),
          textAlign: TextAlign.center,
          child: Column(children: [
            Text('PRATINJAU STRUK 58MM', style: mono(9, weight: FontWeight.w700, color: kOutline)),
            const SizedBox(height: 6),
            Text(_name.text.trim().isEmpty ? 'Nama toko' : _name.text.trim().toUpperCase(),
                style: const TextStyle(fontFamily: kSans, fontSize: 14, fontWeight: FontWeight.w800)),
            if (_address.text.trim().isNotEmpty) Text(_address.text.trim()),
            if (_phone.text.trim().isNotEmpty) Text('Telp: ${_phone.text.trim()}'),
            const Text('- - - - - - - - - - - - - -', style: TextStyle(color: kOutline)),
            Text(_footer.text.trim(), style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    void redraw(String _) => setState(() {});
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(Icons.storefront_outlined, 'Profil Toko', 'Tampil di kepala dan kaki struk', [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nama toko'),
                onChanged: redraw),
            TextField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Alamat'),
                onChanged: redraw),
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                style: mono(14),
                decoration: const InputDecoration(labelText: 'Telepon'),
                onChanged: redraw),
            TextField(
                controller: _footer,
                decoration: const InputDecoration(labelText: 'Teks footer struk'),
                onChanged: redraw),
            _receiptPreview(),
          ]),
          const SizedBox(height: 12),
          _section(Icons.lock_outline, 'Keamanan', 'PIN owner untuk membuka app dan void', [
            OutlinedButton.icon(
              onPressed: _changePin,
              icon: const Icon(Icons.lock_reset),
              label: const Text('Ganti PIN'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ]),
          const SizedBox(height: 12),
          _section(Icons.auto_awesome, 'Scan AI (DeepSeek)', 'Kenali produk dari foto', [
            Container(
              decoration: BoxDecoration(
                  color: kSurfaceLow, borderRadius: BorderRadius.circular(4)),
              child: SwitchListTile(
                title: const Text('Aktifkan Scan AI',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Perlu internet. Foto dikirim ke DeepSeek.',
                    style: TextStyle(fontSize: 12)),
                value: _aiEnabled,
                onChanged: _toggleAi,
              ),
            ),
            TextField(
              controller: _apiKey,
              obscureText: true,
              style: mono(14),
              decoration: const InputDecoration(
                labelText: 'API key DeepSeek',
                helperText: 'Disimpan terenkripsi di HP. Tidak ikut di APK.',
              ),
            ),
            TextField(
              controller: _model,
              style: mono(14),
              decoration: const InputDecoration(
                labelText: 'Model ID',
                helperText: 'Bisa diganti tanpa build ulang, mis. deepseek-flash',
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              decoration: BoxDecoration(
                  color: kSurfaceLow, borderRadius: BorderRadius.circular(4)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(
                    child: Text('Ambang masuk keranjang otomatis',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text('${(_threshold * 100).round()}%',
                      style: mono(18, weight: FontWeight.w700, color: kPrimaryDark)),
                ]),
                Slider(
                  value: _threshold,
                  min: .5,
                  max: 1,
                  divisions: 10,
                  label: '${(_threshold * 100).round()}%',
                  onChanged: (v) => setState(() => _threshold = v),
                ),
                Row(children: [
                  Text('50% longgar', style: mono(10, color: kInkSoft)),
                  const Spacer(),
                  Text('100% ketat', style: mono(10, color: kInkSoft)),
                ]),
                const SizedBox(height: 6),
                const Text(
                    'Di bawah ambang, kasir memilih dari saran produk mirip.',
                    style: TextStyle(fontSize: 12, color: kInkSoft)),
                const SizedBox(height: 6),
              ]),
            ),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Simpan Pengaturan'),
        ),
      ),
    );
  }
}
