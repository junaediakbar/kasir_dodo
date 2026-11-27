import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dodo/data/ai_scan.dart';

void main() {
  const valid = {1, 2, 3, 4};

  test('JSON bersih: urut keyakinan, maksimal 3, id tak dikenal dibuang', () {
    final m = parseMatches(
      '{"matches":[{"product_id":2,"confidence":0.6},{"product_id":9,"confidence":0.99},'
      '{"product_id":1,"confidence":0.9},{"product_id":3,"confidence":0.4},{"product_id":4,"confidence":0.5}]}',
      valid,
    );
    expect(m.map((e) => e.productId), [1, 2, 4]);
    expect(m.first.confidence, 0.9);
  });

  test('JSON dibungkus teks lain tetap terbaca', () {
    final m = parseMatches(
        'Hasilnya: {"matches":[{"product_id":3,"confidence":0.7}]} semoga membantu',
        valid);
    expect(m.single.productId, 3);
  });

  test('isi kosong, rusak, atau tanpa matches menghasilkan daftar kosong', () {
    expect(parseMatches(null, valid), isEmpty);
    expect(parseMatches('   ', valid), isEmpty);
    expect(parseMatches('bukan json', valid), isEmpty);
    expect(parseMatches('{"hasil": 1}', valid), isEmpty);
    expect(parseMatches('{"matches": [{"product_id": "x"}]}', valid), isEmpty);
  });

  test('confidence di luar 0..1 dijepit', () {
    final m = parseMatches('{"matches":[{"product_id":1,"confidence":1.7}]}', valid);
    expect(m.single.confidence, 1.0);
  });

  test('aturan tindakan sesuai PRD (ambang 0,85)', () {
    AiMatch c(double v) => AiMatch(1, v);
    expect(actionFor([c(0.9)], 0.85), ScanAction.autoAdd);
    expect(actionFor([c(0.85)], 0.85), ScanAction.autoAdd);
    expect(actionFor([c(0.7)], 0.85), ScanAction.suggest);
    expect(actionFor([c(0.5)], 0.85), ScanAction.suggest);
    expect(actionFor([c(0.49)], 0.85), ScanAction.unknown);
    expect(actionFor(const [], 0.85), ScanAction.unknown);
  });
}
