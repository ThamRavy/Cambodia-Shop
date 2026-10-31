import 'package:mongo_dart/mongo_dart.dart';
import '../config/env.dart';

class Database {
  static Db? _db;
  static Future<Db>? _connecting;
  static Future<Db> connect() async {
    final existingConnection = _connecting;
    if (existingConnection != null) return existingConnection;

    final connection = _connect();
    _connecting = connection;
    try {
      return await connection;
    } catch (_) {
      _connecting = null;
      rethrow;
    }
  }

  static Future<Db> _connect() async {
    final mongoUri = Uri.parse(Env.mongoUri).replace(
      path: '/${Env.databaseName}',
    );
    final db = await Db.create(mongoUri.toString());
    await db.open();
    _db = db;
    await db.collection('users').createIndex(keys: {'email': 1}, unique: true);
    await db
        .collection('products')
        .createIndex(keys: {'slug': 1}, unique: true);
    await db
        .collection('products')
        .createIndex(keys: {'active': 1, 'category': 1});
    await db
        .collection('orders')
        .createIndex(keys: {'orderNumber': 1}, unique: true);
    await db
        .collection('orders')
        .createIndex(keys: {'userId': 1, 'createdAt': -1});
    await db
        .collection('payments')
        .createIndex(keys: {'tranId': 1}, unique: true);
    await db
        .collection('payments')
        .createIndex(keys: {'orderId': 1, 'status': 1});
    return db;
  }

  static Db get db => _db ?? (throw StateError('Database is not initialized'));
}
