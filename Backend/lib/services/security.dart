import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../config/env.dart';

class Principal {
  final String id;
  final String role;
  final String email;
  const Principal(this.id, this.role, this.email);
}

Principal? principalFrom(RequestContext context) {
  final h = context.request.headers['authorization'];
  if (h == null || !h.startsWith('Bearer ')) return null;
  try {
    final jwt = JWT.verify(h.substring(7), SecretKey(Env.jwtSecret),
        issuer: Env.jwtIssuer);
    return Principal(
        jwt.payload['sub'] as String,
        (jwt.payload['role'] ?? 'customer') as String,
        jwt.payload['email'] as String);
  } catch (_) {
    return null;
  }
}
