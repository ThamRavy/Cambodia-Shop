import 'package:mongo_dart/mongo_dart.dart';

class ProductService {
  final Db db;

  ProductService(this.db);

  Future<List<Map<String, dynamic>>> list({String? category}) async {
    final selector = where.eq('active', true);
    if (category != null && category.isNotEmpty) {
      selector.eq('category', category);
    }
    final products = await db
        .collection('products')
        .find(selector.sortBy('createdAt', descending: true))
        .toList();
    return products.map(_publicProduct).toList();
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    if (!_isObjectId(id)) return null;
    final product = await db.collection('products').findOne({
      '_id': ObjectId.fromHexString(id),
      'active': true,
    });
    if (product == null) return null;
    final result = _publicProduct(product)..remove('active');
    return result;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final name = (body['name'] ?? '').toString().trim();
    final slug = (body['slug'] ?? '').toString().trim().toLowerCase();
    final price = body['priceCents'];
    final stock = body['stock'];
    if (name.length < 2 ||
        !RegExp(r'^[a-z0-9-]{2,100}$').hasMatch(slug) ||
        price is! int ||
        price < 0 ||
        stock is! int ||
        stock < 0) {
      throw FormatException(
        'name, slug, non-negative integer priceCents and stock are required',
      );
    }

    final id = ObjectId();
    final now = DateTime.now().toUtc();
    await db.collection('products').insertOne({
      '_id': id,
      'name': name,
      'slug': slug,
      'description': (body['description'] ?? '').toString(),
      'category': (body['category'] ?? 'general').toString(),
      'imageUrl': body['imageUrl'],
      'priceCents': price,
      'currency': 'USD',
      'stock': stock,
      'active': true,
      'createdAt': now,
      'updatedAt': now,
    });
    final created = await db.collection('products').findOne({'_id': id});
    return _publicProduct(created!);
  }

  bool _isObjectId(String id) => RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id);

  Map<String, dynamic> _publicProduct(Map<String, dynamic> product) => {
        'id': (product['_id'] is ObjectId)
            ? (product['_id'] as ObjectId).oid
            : product['_id'],
        'name': product['name'],
        'slug': product['slug'],
        'description': product['description'],
        'category': product['category'],
        'imageUrl': product['imageUrl'],
        'priceCents': product['priceCents'],
        'currency': product['currency'] ?? 'USD',
        'stock': product['stock'],
        'active': product['active'],
      };
}
