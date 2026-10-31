import 'dart:convert';

import 'package:cambodia_shop_app/api/shop_api.dart';
import 'package:cambodia_shop_app/main.dart';
import 'package:cambodia_shop_app/store_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('cart quantity and totals update immediately', (tester) async {
    final api = ShopApi(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/products')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'product-1',
                  'name': 'Classic White Cotton T-Shirt',
                  'description': 'Cotton t-shirt',
                  'category': 'clothing',
                  'priceCents': 1299,
                  'currency': 'USD',
                  'stock': 10,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      }),
    );
    final store = StoreState(api);

    await tester.pumpWidget(MaterialApp(home: StoreHome(store: store)));
    await tester.pumpAndSettle();

    store.addToCart(store.products.single);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();

    expect(_cartQuantity(tester).data, '1');
    expect(_cartSubtotal(tester).data, r'$12.99');

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(_cartQuantity(tester).data, '2');
    expect(_cartSubtotal(tester).data, r'$25.98');

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    expect(_cartQuantity(tester).data, '1');
    expect(_cartSubtotal(tester).data, r'$12.99');
  });
}

Text _cartQuantity(WidgetTester tester) =>
    tester.widget(find.byKey(const ValueKey('cart-quantity-product-1')));

Text _cartSubtotal(WidgetTester tester) =>
    tester.widget(find.byKey(const ValueKey('cart-subtotal')));
