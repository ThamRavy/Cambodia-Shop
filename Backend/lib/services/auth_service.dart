import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../config/env.dart';
import 'firebase_identity_service.dart';

class AuthConflictException implements Exception {
  const AuthConflictException(this.message);

  final String message;
}

class FirebaseEmailNotVerifiedException implements Exception {
  const FirebaseEmailNotVerifiedException();
}

class AuthService {
  AuthService(
    this.db, {
    FirebaseIdentityService? firebaseIdentityService,
  }) : _firebaseIdentityService =
            firebaseIdentityService ?? FirebaseIdentityService();

  final Db db;
  final FirebaseIdentityService _firebaseIdentityService;

  Future<Map<String, dynamic>> loginWithFirebase(String idToken) async {
    final identity = await _firebaseIdentityService.verifyIdToken(idToken);
    if (!identity.emailVerified) {
      throw const FirebaseEmailNotVerifiedException();
    }

    final email = identity.email.trim().toLowerCase();
    if (!_isValidEmail(email)) {
      throw const FormatException('The Firebase account has no valid email.');
    }

    final users = db.collection('users');
    final accountByUid = await users.findOne({'firebaseUid': identity.uid});
    final accountByEmail = await users.findOne({'email': email});
    if (accountByUid != null &&
        accountByEmail != null &&
        accountByUid['_id'] != accountByEmail['_id']) {
      throw const AuthConflictException(
        'This Firebase account is already linked to another shop account.',
      );
    }

    final existing = accountByUid ?? accountByEmail;
    final linkedUid = existing?['firebaseUid'];
    if (linkedUid is String && linkedUid != identity.uid) {
      throw const AuthConflictException(
        'This email is already linked to another Firebase account.',
      );
    }

    final now = DateTime.now().toUtc();
    final id = existing?['_id'] as ObjectId? ?? ObjectId();

    final existingName = existing?['name'] as String?;
    final name = existingName != null && existingName.trim().isNotEmpty
        ? existingName
        : identity.displayName.trim().isNotEmpty
            ? identity.displayName.trim()
            : email.split('@').first;
    final role = (existing?['role'] ?? 'customer') as String;

    if (existing == null) {
      await users.insertOne({
        '_id': id,
        'email': email,
        'name': name,
        'firebaseUid': identity.uid,
        'role': role,
        'emailVerified': true,
        'emailVerifiedAt': now,
        'createdAt': now,
      });
    } else {
      await users.updateOne(
        {'_id': id},
        {
          r'$set': {
            'email': email,
            'name': name,
            'firebaseUid': identity.uid,
            'emailVerified': true,
            'emailVerifiedAt': existing['emailVerifiedAt'] ?? now,
            'updatedAt': now,
          },
        },
      );
    }

    return {
      'user': {
        'id': id.oid,
        'email': email,
        'name': name,
        'role': role,
      },
      'token': _token(id.oid, email, role),
    };
  }

  String _token(String id, String email, String role) =>
      JWT({'sub': id, 'email': email, 'role': role}, issuer: Env.jwtIssuer)
          .sign(SecretKey(Env.jwtSecret), expiresIn: const Duration(hours: 6));

  bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
}
