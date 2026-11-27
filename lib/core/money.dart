import 'package:intl/intl.dart';

final _idr = NumberFormat.decimalPattern('id_ID');

/// Format Rupiah, mis. 15000 -> "Rp 15.000".
String rp(int amount) => 'Rp ${_idr.format(amount)}';

/// Kembalian. Lempar jika uang diterima kurang dari total.
int changeFor({required int total, required int paid}) {
  if (paid < total) {
    throw ArgumentError('Uang diterima kurang dari total');
  }
  return paid - total;
}

/// Ambil angka rupiah dari teks input, mis. "15.000" -> 15000.
int parseRupiah(String s) =>
    int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
