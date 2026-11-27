import 'package:flutter/material.dart';

import '../core/cart.dart';
import '../data/repo.dart';
import 'beranda_screen.dart';
import 'kasir_screen.dart';
import 'laporan_screen.dart';
import 'products_screen.dart';
import 'stok_screen.dart';

/// Kerangka utama dengan bottom nav. Keranjang dipegang di sini
/// agar tetap ada saat pindah tab.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repo});
  final Repo repo;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 1; // mulai di Kasir
  final _cart = Cart();

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final pages = <Widget>[
      BerandaScreen(repo: repo),
      KasirScreen(repo: repo, cart: _cart, onChanged: () => setState(() {})),
      ProductsScreen(repo: repo),
      StokScreen(repo: repo),
      LaporanScreen(repo: repo),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Kasir'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Produk'),
          NavigationDestination(icon: Icon(Icons.warehouse_outlined), label: 'Stok'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Laporan'),
        ],
      ),
    );
  }
}
