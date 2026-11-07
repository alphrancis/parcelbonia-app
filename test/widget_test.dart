import 'package:flutter_test/flutter_test.dart';
import 'package:parcelbonia_app/store.dart';

void main() {
  test('sensor formatting matches the website', () {
    expect(sensors[0].format(1), 'Occupied');
    expect(sensors[1].format(1.304), '1.30 kg');
    expect(sensors[2].format(0), 'Closed');
    expect(sensors[3].format(94), '94 %');
    expect(sensors[1].format(null), '—');
  });

  test('duration formatting', () {
    expect(duration(45000), '45s');
    expect(duration(125000), '2m 5s');
    expect(duration(3 * 3600000 + 60000), '3h 1m');
  });
}
