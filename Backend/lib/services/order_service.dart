import 'package:mongo_dart/mongo_dart.dart';
import 'package:uuid/uuid.dart';

class OrderService {
  final Db db;

  OrderService(this.db);

  Future<List<Map<String, dynamic>>> listForUser(String userId) async {
    final orders =
        await db.collection('orders').find({'userId': userId}).toList();
    return orders.map(_publicOrder).toList();
  }

  Future<Map<String, dynamic>?> getForUser(String id, String userId) async {
    if (!_isObjectId(id)) return null;
    final order = await db.collection('orders').findOne({
      '_id': ObjectId.fromHexString(id),
      'userId': userId,
    });
    return order == null ? null : _orderDetails(order);
  }

  Future<Map<String, dynamic>> create(
    String userId,
    Map<String, dynamic> body,
  ) async {
    final rawItems = body['items'];
    if (rawItems is! List || rawItems.isEmpty || rawItems.length > 50) {
      throw FormatException('items must contain 1 to 50 products');
    }

    final lineItems = <Map<String, dynamic>>[];
    var total = 0;
    for (final raw in rawItems) {
      if (raw is! Map) throw FormatException('Invalid item');
      final id = '${raw['productId'] ?? ''}';
      final quantity = raw['quantity'];
      if (!_isObjectId(id) ||
          quantity is! int ||
          quantity < 1 ||
          quantity > 100) {
        throw FormatException('Invalid productId or quantity');
      }
      final product = await db.collection('products').findOne({
        '_id': ObjectId.fromHexString(id),
        'active': true,
      });
      if (product == null) throw FormatException('Product unavailable');
      if ((product['stock'] as int) < quantity) {
        throw FormatException('Insufficient stock for ${product['name']}');
      }
      final unitPrice = product['priceCents'] as int;
      total += unitPrice * quantity;
      lineItems.add({
        'productId': id,
        'name': product['name'],
        'quantity': quantity,
        'unitPriceCents': unitPrice,
        'lineTotalCents': unitPrice * quantity,
      });
    }

    final address = body['shippingAddress'];
    if (address is! Map ||
        '${address['addressLine'] ?? ''}'.trim().isEmpty ||
        '${address['city'] ?? ''}'.trim().isEmpty) {
      throw FormatException(
        'shippingAddress.addressLine and city are required',
      );
    }
    final latitude = address['latitude'];
    final longitude = address['longitude'];
    if (latitude != null &&
        (latitude is! num || latitude < -90 || latitude > 90)) {
      throw FormatException('Invalid latitude');
    }
    if (longitude != null &&
        (longitude is! num || longitude < -180 || longitude > 180)) {
      throw FormatException('Invalid longitude');
    }

    for (final item in lineItems) {
      final result = await db.collection('products').updateOne(
        {
          '_id': ObjectId.fromHexString(item['productId'] as String),
          'stock': {r'$gte': item['quantity']},
        },
        {
          r'$inc': {'stock': -(item['quantity'] as int)},
          r'$set': {'updatedAt': DateTime.now().toUtc()},
        },
      );
      if (result.nModified != 1) {
        throw StateError('Stock changed during checkout; retry the order');
      }
    }

    final orderNumber =
        'CS${DateTime.now().toUtc().millisecondsSinceEpoch}${const Uuid().v4().substring(0, 4).toUpperCase()}';
    final id = ObjectId();
    final now = DateTime.now().toUtc();
    final order = {
      '_id': id,
      'orderNumber': orderNumber,
      'userId': userId,
      'items': lineItems,
      'subtotalCents': total,
      'shippingCents': 0,
      'totalCents': total,
      'currency': 'USD',
      'status': 'pending_payment',
      'paymentStatus': 'unpaid',
      'shippingAddress': address,
      'createdAt': now,
      'updatedAt': now,
    };
    await db.collection('orders').insertOne(order);
    return _publicOrder(order);
  }

  bool _isObjectId(String id) => RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id);

  Map<String, dynamic> _publicOrder(Map<String, dynamic> order) => {
        'id': (order['_id'] is ObjectId)
            ? (order['_id'] as ObjectId).oid
            : order['_id'],
        'orderNumber': order['orderNumber'],
        'items': order['items'],
        'subtotalCents': order['subtotalCents'],
        'shippingCents': order['shippingCents'],
        'totalCents': order['totalCents'],
        'currency': order['currency'],
        'status': order['status'],
        'paymentStatus': order['paymentStatus'],
        'shippingAddress': order['shippingAddress'],
        'createdAt': order['createdAt']?.toString(),
      };

  Map<String, dynamic> _orderDetails(Map<String, dynamic> order) => {
        'id': (order['_id'] as ObjectId).oid,
        'orderNumber': order['orderNumber'],
        'items': order['items'],
        'totalCents': order['totalCents'],
        'currency': order['currency'],
        'status': order['status'],
        'paymentStatus': order['paymentStatus'],
        'shippingAddress': order['shippingAddress'],
        'createdAt': order['createdAt']?.toString(),
      };
}
