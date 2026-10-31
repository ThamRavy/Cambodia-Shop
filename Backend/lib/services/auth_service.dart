import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../config/env.dart';

class AuthService {
  final Db db;
  AuthService(this.db);
  Future<Map<String, dynamic>> register(
      String email, String password, String name) async {
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      throw FormatException('A valid email is required');
    }
    if (password.length < 12) {
      throw FormatException('Password must be at least 12 characters');
    }
    if (name.trim().length < 2) {
      throw FormatException('Name must be at least 2 characters');
    }
    final id = ObjectId();
    try {
      await db.collection('users').insertOne({
        '_id': id,
        'email': normalized,
        'name': name.trim(),
        'passwordHash': BCrypt.hashpw(password, BCrypt.gensalt()),
        'role': 'customer',
        'createdAt': DateTime.now().toUtc()
      });
    } catch (_) {
      throw StateError('Email is already registered');
    }
    return {
      'user': {
        'id': id.oid,
        'email': normalized,
        'name': name.trim(),
        'role': 'customer'
      },
      'token': _token(id.oid, normalized, 'customer')
    };
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final user = await db
        .collection('users')
        .findOne({'email': email.trim().toLowerCase()});
    if (user == null ||
        !BCrypt.checkpw(password, user['passwordHash'] as String)) {
      throw FormatException('Invalid email or password');
    }
    final id = (user['_id'] as ObjectId).oid;
    return {
      'user': {
        'id': id,
        'email': user['email'],
        'name': user['name'],
        'role': user['role'] ?? 'customer'
      },
      'token': _token(
          id, user['email'] as String, (user['role'] ?? 'customer') as String)
    };
  }

  String _token(String id, String email, String role) =>
      JWT({'sub': id, 'email': email, 'role': role}, issuer: Env.jwtIssuer)
          .sign(SecretKey(Env.jwtSecret), expiresIn: const Duration(hours: 6));
}
