import 'package:flutter/material.dart';

import '../data/ai_key.dart';
import '../data/repo.dart';

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
  final _threshold = TextEditingController();
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
      _threshold.text = '${s['ai_threshold']}';
      _aiEnabled = s['ai_enabled'] == 1;
      _apiKey.text = key ?? '';
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _footer, _model, _threshold, _apiKey]) {
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
    final threshold = double.tryParse(_threshold.text.replaceAll(',', '.'));
    if (threshold == null || threshold < 0.5 || threshold > 1) {
      _snack('Ambang harus antara 0,5 dan 1');
      return;
    }
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
      'ai_threshold': threshold,
      'ai_enabled': _aiEnabled ? 1 : 0,
    });
    if (_apiKey.text.trim().isNotEmpty) {
      await writeAiKey(_apiKey.text.trim());
    }
    if (!mounted) return;
    _snack('Pengaturan disimpan');
    Navigator.pop(context);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Profil toko', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama toko')),
          const SizedBox(height: 8),
          TextField(controller: _address, decoration: const InputDecoration(labelText: 'Alamat')),
          const SizedBox(height: 8),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Telepon')),
          const SizedBox(height: 8),
          TextField(controller: _footer, decoration: const InputDecoration(labelText: 'Teks footer struk')),
          const Divider(height: 32),
          Text('Scan AI (DeepSeek)', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aktifkan Scan AI'),
            subtitle: const Text('Perlu internet. Foto dikirim ke DeepSeek.'),
            value: _aiEnabled,
            onChanged: _toggleAi,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKey,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API key DeepSeek',
              helperText: 'Disimpan terenkripsi di HP. Tidak ikut di APK.',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: 'Model ID',
              helperText: 'Bisa diganti tanpa build ulang, mis. deepseek-flash',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _threshold,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Ambang masuk keranjang otomatis (0,5 – 1)',
            ),
          ),
        ],
      ),
    );
  }
}
