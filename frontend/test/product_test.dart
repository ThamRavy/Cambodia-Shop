import 'package:cambodia_shop_app/models/product.dart';
import 'package:cambodia_shop_app/store_state.dart';
import 'package:cambodia_shop_app/api/shop_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Product', () {
    test('parses API product fields', () {
      final product = Product.fromJson({
        'id': 'product-1',
        'name': 'Palm sugar',
        'description': 'Small-batch palm sugar',
        'category': 'Pantry',
        'priceCents': 725,
        'currency': 'USD',
        'stock': 8,
        'imageUrl': 'https://example.com/palm-sugar.png',
      });

      expect(product.id, 'product-1');
      expect(product.name, 'Palm sugar');
      expect(product.priceCents, 725);
      expect(product.stock, 8);
      expect(product.imageUrl, 'https://example.com/palm-sugar.png');
    });

    test('uses safe defaults for optional API values', () {
      final product = Product.fromJson({'id': 'product-2'});

      expect(product.name, 'Untitled product');
      expect(product.priceCents, 0);
      expect(product.stock, 0);
      expect(product.currency, 'USD');
    });
  });

  test('cart tracks quantities and subtotal', () {
    final store = StoreState(ShopApi());
    const product = Product(
      id: 'product-1',
      name: 'Palm sugar',
      description: '',
      category: 'Pantry',
      priceCents: 725,
      stock: 8,
    );
    store.products.add(product);

    store.addToCart(product);
    store.addToCart(product);
    expect(store.cartCount, 2);
    expect(store.cartTotalCents, 1450);

    store.removeFromCart(product);
    expect(store.quantityFor(product), 1);
    store.removeFromCart(product);
    expect(store.cartCount, 0);
  });
}
