import 'package:flutter/material.dart';

import '../core/pin.dart';
import '../data/repo.dart';
import '../theme.dart';
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

/// Layar setup owner (acuan Stitch: setup_toko_akun_owner_auth_01).
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

  Widget _section(String title, Widget badge, List<Widget> children) => Panel(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            badge,
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pinMatch = _pin.text.length == 6 && _pin.text == _pin2.text;
    final pinStyle = mono(
      20,
      weight: FontWeight.w700,
    ).copyWith(letterSpacing: 8);
    return Scaffold(
      appBar: AppBar(title: const Text('Selamat datang di Kasir Dodo')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: pill(
                'Data tersimpan di HP ini',
                fg: Colors.white,
                bg: kPrimary,
                icon: Icons.offline_bolt,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Daftarkan Toko & Akun Pemilik',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text(
              'Isi data toko dan buat PIN owner. PIN dipakai untuk membuka aplikasi.',
              style: TextStyle(color: kInkSoft),
            ),
            const SizedBox(height: 16),
            _section('1. Profil Usaha', pill('Wajib diisi'), [
              TextFormField(
                controller: _store,
                decoration: const InputDecoration(
                  labelText: 'Nama toko / usaha',
                  helperText: 'Tampil di struk',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _owner,
                decoration: const InputDecoration(
                  labelText: 'Nama lengkap pemilik',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
              ),
            ]),
            const SizedBox(height: 12),
            _section(
              '2. Kunci Keamanan Owner',
              pill(
                'Otoritas penuh',
                fg: const Color(0xFF653E00),
                bg: kAmberSoft,
              ),
              [
                TextFormField(
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  style: pinStyle,
                  decoration: const InputDecoration(
                    labelText: 'Buat PIN owner (6 digit)',
                  ),
                  validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                      ? null
                      : 'PIN harus 6 digit',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _pin2,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  style: pinStyle,
                  decoration: InputDecoration(
                    labelText: 'Ulangi PIN owner',
                    suffixIcon: _pin2.text.isEmpty
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Center(
                              widthFactor: 1,
                              child: pinMatch
                                  ? pill(
                                      'Cocok',
                                      fg: kOnMintSoft,
                                      bg: kMintSoft,
                                    )
                                  : pill('Belum cocok'),
                            ),
                          ),
                  ),
                  validator: (v) => v == _pin.text ? null : 'PIN tidak sama',
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Mulai'),
        ),
      ),
    );
  }
}

/// Kunci PIN dengan keypad (acuan Stitch: kunci_pin_ganti_pengguna_auth_02_auth_07).
/// 5 kali salah → terkunci 1 menit.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.store, required this.onUnlock});
  final Map<String, Object?> store;
  final VoidCallback onUnlock;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  int _fails = 0;
  DateTime? _lockedUntil;
  String? _error;

  void _press(String d) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 6) _submit();
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submit() {
    final now = DateTime.now();
    if (_lockedUntil != null && now.isBefore(_lockedUntil!)) {
      final secs = _lockedUntil!.difference(now).inSeconds + 1;
      setState(() {
        _pin = '';
        _error = 'Terkunci. Coba lagi dalam $secs detik';
      });
      return;
    }
    final ok =
        hashPin(_pin, widget.store['pin_salt'] as String) ==
        widget.store['pin_hash'];
    if (ok) {
      widget.onUnlock();
      return;
    }
    _fails++;
    setState(() {
      _pin = '';
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
    final owner = widget.store['owner_name'] as String? ?? 'Owner';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  iconTile(
                    Icons.storefront,
                    fg: Colors.white,
                    bg: kPrimaryDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.store['name'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'Aplikasi terkunci',
                          style: mono(11, color: kInkSoft),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.lock_outline, color: kInkSoft),
                ],
              ),
              const SizedBox(height: 20),
              Panel(
                color: kPrimary,
                borderColor: kPrimary,
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Text(
                        owner.isEmpty ? '?' : owner[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            owner,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Owner (utama)',
                            style: mono(11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle, color: kMintFixed),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Masukkan PIN 6 digit',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 6; i++)
                    Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length
                            ? kPrimaryDark
                            : Colors.transparent,
                        border: Border.all(
                          color: _error != null ? kRed : kOutline,
                          width: 2,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: 32,
                child: Center(
                  child: _error == null
                      ? null
                      : Text(
                          _error!,
                          style: const TextStyle(
                            color: kRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const Spacer(),
              _keypad(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _keypad() {
    const letters = [
      '',
      'ABC',
      'DEF',
      'GHI',
      'JKL',
      'MNO',
      'PQRS',
      'TUV',
      'WXYZ',
    ];
    Widget key(
      Widget child,
      VoidCallback onTap, {
      Color bg = Colors.white,
      String? tip,
    }) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Tooltip(
          message: tip ?? '',
          excludeFromSemantics: tip == null,
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: kBorder),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: SizedBox(height: 64, child: Center(child: child)),
            ),
          ),
        ),
      ),
    );
    Widget digit(int n) => key(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$n', style: mono(24, weight: FontWeight.w600)),
          if (n > 0 && letters[n - 1].isNotEmpty)
            Text(letters[n - 1], style: mono(9, color: kInkSoft)),
        ],
      ),
      () => _press('$n'),
    );
    return Column(
      children: [
        for (final row in [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ])
          Row(children: [for (final n in row) digit(n)]),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            digit(0),
            key(
              const Icon(Icons.backspace_outlined),
              _backspace,
              bg: kSurfaceMid,
              tip: 'Hapus',
            ),
          ],
        ),
      ],
    );
  }
}
