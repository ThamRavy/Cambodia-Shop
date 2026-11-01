import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../config/env.dart';
import 'email_service.dart';

class AuthConflictException implements Exception {
  const AuthConflictException(this.message);

  final String message;
}

class AuthRateLimitException implements Exception {
  const AuthRateLimitException(this.message);

  final String message;
}

class EmailNotVerifiedException implements Exception {
  const EmailNotVerifiedException();
}

class AuthService {
  final Db db;
  final ResendEmailService emailService;

  AuthService(this.db, {ResendEmailService? emailService})
      : emailService = emailService ?? ResendEmailService();

  Future<void> register(String email, String password, String name) async {
    final normalized = email.trim().toLowerCase();
    if (!_isValidEmail(normalized)) {
      throw FormatException('A valid email is required');
    }
    if (password.length < 6) {
      throw FormatException('Password must be at least 6 characters');
    }
    if (name.trim().length < 2) {
      throw FormatException('Name must be at least 2 characters');
    }
    final users = db.collection('users');
    if (await users.findOne({'email': normalized}) != null) {
      throw const AuthConflictException('Email is already registered.');
    }

    await _sendVerificationCode(
      normalized,
      name: name.trim(),
      passwordHash: BCrypt.hashpw(password, BCrypt.gensalt()),
    );
  }

  Future<Map<String, dynamic>> verifyEmail(String email, String code) async {
    final normalized = email.trim().toLowerCase();
    if (!_isValidEmail(normalized) || !RegExp(r'^\d{6}$').hasMatch(code)) {
      throw FormatException('A valid email and six-digit code are required');
    }
    final verifications = db.collection('email_verifications');
    final pending = await verifications.findOne({'email': normalized});
    if (pending == null) {
      throw const AuthConflictException(
        'No pending signup was found. Create your account again.',
      );
    }
    final now = DateTime.now().toUtc();
    final expiresAt = pending['expiresAt'];
    if (expiresAt is! DateTime || !expiresAt.isAfter(now)) {
      await verifications.deleteOne({'email': normalized});
      throw FormatException(
        'This verification code has expired. Request a new one.',
      );
    }
    if ((pending['attempts'] as int? ?? 0) >= 5) {
      throw const AuthRateLimitException(
        'Too many incorrect codes. Request a new verification email.',
      );
    }

    final expectedHash = pending['codeHash'] as String;
    final suppliedHash = _verificationHash(normalized, code);
    if (!_constantTimeBytesEquality(
      utf8.encode(expectedHash),
      utf8.encode(suppliedHash),
    )) {
      await verifications.updateOne(
        {
          'email': normalized,
          'codeHash': expectedHash,
          'attempts': {r'$lt': 5},
        },
        {
          r'$inc': {'attempts': 1}
        },
      );
      throw FormatException('The verification code is incorrect.');
    }
    final claimed = await verifications.updateOne(
      {
        'email': normalized,
        'codeHash': expectedHash,
        'expiresAt': {r'$gt': now},
        'attempts': {r'$lt': 5},
        'consumed': {r'$ne': true},
      },
      {
        r'$set': {'consumed': true},
      },
    );
    if (claimed.nModified != 1) {
      throw const AuthConflictException(
        'This verification code has already been used. Request a new one.',
      );
    }

    final users = db.collection('users');
    final existingUserId = pending['userId'];
    late final ObjectId id;
    late final String userName;
    late final String role;
    if (existingUserId is ObjectId) {
      id = existingUserId;
      userName = pending['name'] as String;
      final result = await users.updateOne(
        {
          '_id': id,
          'email': normalized,
          'emailVerified': {r'$ne': true},
        },
        {
          r'$set': {
            'emailVerified': true,
            'emailVerifiedAt': now,
          },
        },
      );
      if (result.nModified != 1) {
        throw const AuthConflictException(
          'This account changed while being verified. Sign in again.',
        );
      }
      final user = await users.findOne({'_id': id});
      if (user == null) {
        throw StateError('Verified user disappeared during verification');
      }
      role = (user['role'] ?? 'customer') as String;
    } else {
      if (await users.findOne({'email': normalized}) != null) {
        await verifications.deleteOne({'email': normalized});
        throw const AuthConflictException('Email is already registered.');
      }
      id = ObjectId();
      userName = pending['name'] as String;
      role = 'customer';
      await users.insertOne({
        '_id': id,
        'email': normalized,
        'name': userName,
        'passwordHash': pending['passwordHash'],
        'role': role,
        'emailVerified': true,
        'emailVerifiedAt': now,
        'createdAt': now,
      });
    }
    await verifications
        .deleteOne({'email': normalized, 'codeHash': expectedHash});
    return {
      'user': {
        'id': id.oid,
        'email': normalized,
        'name': userName,
        'role': role,
      },
      'token': _token(id.oid, normalized, role),
    };
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    if (!_isValidEmail(normalized) || password.isEmpty) {
      throw FormatException('Invalid email or password');
    }
    final user = await db.collection('users').findOne({'email': normalized});
    if (user == null ||
        !BCrypt.checkpw(password, user['passwordHash'] as String)) {
      throw FormatException('Invalid email or password');
    }
    if (user['emailVerified'] != true) {
      await _sendVerificationCode(
        normalized,
        name: '${user['name'] ?? 'Customer'}',
        passwordHash: user['passwordHash'] as String,
        userId: user['_id'] as ObjectId,
      );
      throw const EmailNotVerifiedException();
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

  String _generateVerificationCode() =>
      List.generate(6, (_) => Random.secure().nextInt(10)).join();

  String _verificationHash(String email, String code) => Hmac(
        sha256,
        utf8.encode(Env.jwtSecret),
      ).convert(utf8.encode('$email:$code')).toString();

  Future<void> _sendVerificationCode(
    String email, {
    required String name,
    required String passwordHash,
    ObjectId? userId,
  }) async {
    final verifications = db.collection('email_verifications');
    final existing = await verifications.findOne({'email': email});
    final now = DateTime.now().toUtc();
    final lastSentAt = existing?['lastSentAt'];
    if (lastSentAt is DateTime && now.difference(lastSentAt).inSeconds < 60) {
      throw const AuthRateLimitException(
        'A verification email was just sent. Please wait a minute before trying again.',
      );
    }

    final code = _generateVerificationCode();
    final update = <String, dynamic>{
      'email': email,
      'name': name,
      'passwordHash': passwordHash,
      'codeHash': _verificationHash(email, code),
      'attempts': 0,
      'lastSentAt': now,
      'expiresAt': now.add(const Duration(minutes: 10)),
    };
    if (userId != null) update['userId'] = userId;
    await verifications.updateOne(
      {'email': email},
      {
        r'$set': update,
        if (userId == null) r'$unset': {'userId': ''},
      },
      upsert: true,
    );
    await emailService.sendVerificationCode(email, code);
  }

  bool _constantTimeBytesEquality(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
}
