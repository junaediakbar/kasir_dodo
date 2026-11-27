import 'package:flutter/material.dart';

import '../core/pin.dart';
import '../data/repo.dart';
import 'home_shell.dart';

/// Menentukan layar awal: setup (belum ada toko), kunci PIN, atau aplikasi.
class Gate extends StatefulWidget {
  const Gate({super.key, required this.repo});
  final Repo repo;

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> with WidgetsBindingObserver {
  static const _idleLimit = Duration(minutes: 5);
  Map<String, Object?>? _store;
  bool _loading = true;
  bool _unlocked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    final store = await widget.repo.store();
    if (!mounted) return;
    setState(() {
      _store = store;
      _loading = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _pausedAt != null) {
      if (DateTime.now().difference(_pausedAt!) > _idleLimit) {
        setState(() => _unlocked = false);
        _load(); // ambil PIN terbaru (bisa sudah diganti di Pengaturan)
      }
      _pausedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_store == null) {
      return SetupScreen(repo: widget.repo, onDone: _load);
    }
    if (!_unlocked) {
      return LockScreen(
        store: _store!,
        onUnlock: () => setState(() => _unlocked = true),
      );
    }
    return HomeShell(repo: widget.repo);
  }
}

/// Layar setup owner: nama toko, nama owner, PIN 6 digit.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.repo, required this.onDone});
  final Repo repo;
  final VoidCallback onDone;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _form = GlobalKey<FormState>();
  final _store = TextEditingController();
  final _owner = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_store, _owner, _pin, _pin2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final salt = newSalt();
    await widget.repo.createStore(
      name: _store.text.trim(),
      owner: _owner.text.trim(),
      pinSalt: salt,
      pinHash: hashPin(_pin.text, salt),
    );
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selamat datang di Kasir Dodo')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Isi data toko dan buat PIN owner. PIN dipakai untuk membuka aplikasi.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _store,
              decoration: const InputDecoration(labelText: 'Nama toko'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _owner,
              decoration: const InputDecoration(labelText: 'Nama owner'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'PIN 6 digit'),
              validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '') ? null : 'PIN harus 6 digit',
            ),
            TextFormField(
              controller: _pin2,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Ulangi PIN'),
              validator: (v) => v == _pin.text ? null : 'PIN tidak sama',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Mulai'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kunci PIN. 5 kali salah → terkunci 1 menit.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.store, required this.onUnlock});
  final Map<String, Object?> store;
  final VoidCallback onUnlock;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pin = TextEditingController();
  int _fails = 0;
  DateTime? _lockedUntil;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    final now = DateTime.now();
    if (_lockedUntil != null && now.isBefore(_lockedUntil!)) {
      final secs = _lockedUntil!.difference(now).inSeconds + 1;
      setState(() => _error = 'Terkunci. Coba lagi dalam $secs detik');
      return;
    }
    final ok = hashPin(_pin.text, widget.store['pin_salt'] as String) ==
        widget.store['pin_hash'];
    if (ok) {
      widget.onUnlock();
      return;
    }
    _pin.clear();
    _fails++;
    setState(() {
      if (_fails >= 5) {
        _fails = 0;
        _lockedUntil = now.add(const Duration(minutes: 1));
        _error = 'Terlalu banyak salah. Terkunci 1 menit';
      } else {
        _error = 'PIN salah (${5 - _fails} percobaan tersisa)';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.store['name'] as String,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _pin,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'PIN'),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: 220,
                child: FilledButton(onPressed: _submit, child: const Text('Buka')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
