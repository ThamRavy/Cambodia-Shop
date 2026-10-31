import 'package:mongo_dart/mongo_dart.dart';
import 'package:uuid/uuid.dart';

import 'aba_payway_service.dart';

class PaymentService {
  final Db db;
  final AbaPayWayService payWay;

  PaymentService(this.db, {AbaPayWayService? payWay})
      : payWay = payWay ?? AbaPayWayService();

  Future<Map<String, dynamic>> createCheckout({
    required String orderId,
    required String userId,
    required String paymentOption,
    Map<String, String>? returnDeeplink,
  }) async {
    if (!_isObjectId(orderId)) {
      throw FormatException('Valid orderId is required');
    }
    final order = await db.collection('orders').findOne({
      '_id': ObjectId.fromHexString(orderId),
      'userId': userId,
      'paymentStatus': 'unpaid',
    });
    if (order == null) {
      throw StateError('order_not_found_or_already_paid');
    }
    final user = await db
        .collection('users')
        .findOne({'_id': ObjectId.fromHexString(userId)});
    if (user == null) throw StateError('unauthorized');

    final name = ('${user['name'] ?? 'Customer'}').trim().split(RegExp(r'\s+'));
    final firstName = name.first;
    final lastName = name.length > 1 ? name.skip(1).join(' ') : 'Customer';
    final tranId = const Uuid().v4().replaceAll('-', '').substring(0, 20);
    final checkout = await payWay.createCheckout(
      tranId: tranId,
      amountCents: order['totalCents'] as int,
      shippingCents: order['shippingCents'] as int,
      currency: order['currency'] as String,
      paymentOption: paymentOption,
      firstName: firstName,
      lastName: lastName,
      email: user['email'] as String,
      phone: '${(order['shippingAddress'] as Map)['phone'] ?? ''}',
      returnDeeplink: returnDeeplink,
      items: (order['items'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
    await db.collection('payments').insertOne({
      '_id': ObjectId(),
      'provider': 'aba_payway',
      'tranId': tranId,
      'orderId': orderId,
      'userId': userId,
      'amountCents': order['totalCents'],
      'currency': order['currency'],
      'paymentOption': paymentOption,
      'status': 'pending',
      'createdAt': DateTime.now().toUtc(),
    });
    return checkout;
  }

  Future<bool> hasTransaction(String transactionId) async =>
      await db.collection('payments').findOne({'tranId': transactionId}) !=
      null;

  Future<Map<String, dynamic>> verifyTransaction({
    required String transactionId,
    required String userId,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9]{1,20}$').hasMatch(transactionId)) {
      throw FormatException('Invalid transaction ID');
    }
    final payments = db.collection('payments');
    final payment = await payments.findOne({
      'tranId': transactionId,
      'userId': userId,
      'provider': 'aba_payway',
    });
    if (payment == null) throw StateError('payment_not_found');

    const terminalStatuses = {
      'approved',
      'pre_auth',
      'declined',
      'refunded',
      'cancelled',
    };
    final existingStatus = payment['status'];
    if (terminalStatuses.contains(existingStatus)) {
      return {
        'tranId': transactionId,
        'status': existingStatus,
        'providerStatus': payment['providerStatus'],
        'paymentStatusCode': payment['paymentStatusCode'],
        'amount': payment['providerAmount'],
        'currency': payment['providerCurrency'],
        'checkedAt': (payment['lastCheckedAt'] as DateTime?)?.toIso8601String(),
      };
    }

    final result = await payWay.checkTransaction(transactionId);
    final providerStatus = '${result['payment_status'] ?? ''}'.toUpperCase();
    final statusCode = result['payment_status_code'];
    final paymentStatus = switch (providerStatus) {
      'APPROVED' when statusCode == 0 => 'approved',
      'PRE-AUTH' => 'pre_auth',
      'PENDING' => 'pending',
      'DECLINED' => 'declined',
      'REFUNDED' => 'refunded',
      'CANCELLED' => 'cancelled',
      _ => throw StateError('ABA PayWay returned an unknown payment status'),
    };

    if (paymentStatus == 'approved') {
      final totalAmount = result['total_amount'];
      final paymentCurrency = result['payment_currency'];
      final expectedAmountCents = payment['amountCents'];
      if (totalAmount is! num ||
          expectedAmountCents is! int ||
          (totalAmount * 100).round() != expectedAmountCents ||
          paymentCurrency != payment['currency']) {
        throw StateError(
          'PayWay payment amount or currency does not match the order',
        );
      }
    }

    final now = DateTime.now().toUtc();
    final orderId = payment['orderId'] as String;
    if (paymentStatus == 'approved') {
      final orderUpdate = await db.collection('orders').updateOne(
        {
          '_id': ObjectId.fromHexString(orderId),
          'userId': userId,
          'paymentStatus': {
            '\$in': ['unpaid', 'paid']
          },
        },
        {
          '\$set': {
            'paymentStatus': 'paid',
            'status': 'paid',
            'updatedAt': now,
          },
        },
      );
      if (orderUpdate.nMatched != 1) {
        throw StateError('The order for this payment could not be updated');
      }
    }
    await payments.updateOne(
      {'_id': payment['_id']},
      {
        '\$set': {
          'status': paymentStatus,
          'providerStatus': providerStatus,
          'paymentStatusCode': statusCode,
          'providerAmount': result['total_amount'],
          'providerCurrency': result['payment_currency'],
          'providerApprovalCode': result['apv'],
          'providerTransactionDate': result['transaction_date'],
          'lastCheckedAt': now,
        },
      },
    );

    return {
      'tranId': transactionId,
      'status': paymentStatus,
      'providerStatus': providerStatus,
      'paymentStatusCode': statusCode,
      'amount': result['total_amount'],
      'currency': result['payment_currency'],
      'checkedAt': now.toIso8601String(),
    };
  }

  bool _isObjectId(String id) => RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id);
}
