import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/services/price_catalog.dart';
import 'package:hefarmer/services/price_fetcher.dart';
import 'package:hefarmer/services/price_parser.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _commodity = Commodity(
  id: 'caphe',
  name: 'Cà phê',
  icon: '☕',
  unit: 'đ/kg',
  sources: [
    PriceSource(
      name: 'nguồn hỏng',
      url: 'https://a.test/',
      parse: (t) => parseProvincePrices(t, coffeeProvinces, 40000, 200000),
    ),
    PriceSource(
      name: 'nguồn đổi giao diện',
      url: 'https://b.test/',
      parse: (t) => parseProvincePrices(t, coffeeProvinces, 40000, 200000),
    ),
    PriceSource(
      name: 'nguồn tốt',
      url: 'https://c.test/',
      parse: (t) => parseProvincePrices(t, coffeeProvinces, 40000, 200000),
    ),
  ],
);

void main() {
  test('nguồn 1 lỗi, nguồn 2 không bóc được -> tự chuyển sang nguồn 3', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      switch (req.url.host) {
        case 'a.test':
          return http.Response('loi', 503);
        case 'b.test':
          return http.Response.bytes(
              utf8.encode('<p>Trang mới, không có bảng giá</p>'), 200);
        default:
          return http.Response.bytes(
              utf8.encode('<table><tr><td>Đắk Lắk</td><td>98.500</td></tr>'
                  '<tr><td>Lâm Đồng</td><td>97.800</td></tr></table>'),
              200);
      }
    });
    final f = await PriceFetcher(client: client).fetchCommodity(_commodity);
    expect(f.ok, isTrue);
    expect(f.sourceName, 'nguồn tốt');
    expect(f.rows.map((r) => r.buy), [98500, 97800]);
    expect(f.attempts.map((a) => a.ok), [false, false, true]);
    expect(f.attempts.first.error, contains('503'));
    expect(calls, 3);

    final s = summarizeRows(_commodity, f.rows);
    expect(s.avgBuy, 98150);
  });

  test('mọi nguồn đều lỗi -> không ném lỗi, có thông báo rõ', () async {
    final client = MockClient((_) async => http.Response('', 500));
    final f = await PriceFetcher(client: client).fetchCommodity(_commodity);
    expect(f.ok, isFalse);
    expect(f.error, contains('đã thử'));
    expect(f.attempts, hasLength(3));
  });

  test('cùng một trang chỉ tải 1 lần trong một lượt', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('x', 200);
    });
    final fetcher = PriceFetcher(client: client);
    await Future.wait([
      fetcher.fetchText('https://c.test/'),
      fetcher.fetchText('https://c.test/'),
    ]);
    expect(calls, 1);
  });
}
