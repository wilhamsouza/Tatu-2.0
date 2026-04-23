import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../../../../core/auth/domain/entities/user_session.dart';
import '../../../../../../core/database/app_database.dart';
import '../../../../../../core/database/local_database_executor.dart';
import '../../../../../../core/sync/domain/entities/sync_record_status.dart';
import '../../../../cart/domain/entities/cart_item.dart';
import '../../../../cash_register/data/datasources/local/cash_register_local_datasource.dart';
import '../../../../cash_register/domain/entities/cash_movement_type.dart';
import '../../../../payments/domain/entities/payment_method.dart';
import '../../../../payments/domain/entities/payment_term.dart';
import '../../../../quick_customer/data/datasources/local/quick_customer_local_datasource.dart';
import '../../../../quick_customer/domain/entities/quick_customer.dart';
import '../../../../receipts/data/datasources/local/receipt_local_datasource.dart';
import '../../../../receipts/domain/entities/receipt.dart';
import '../../../application/dtos/checkout_request.dart';
import '../../../application/dtos/checkout_result.dart';
import '../../../domain/entities/local_payment.dart';
import '../../../domain/entities/local_sale.dart';
import '../../../domain/entities/local_sale_item.dart';

class CheckoutLocalDatasource {
  CheckoutLocalDatasource({
    required AppDatabase database,
    required QuickCustomerLocalDatasource quickCustomerLocalDatasource,
    required CashRegisterLocalDatasource cashRegisterLocalDatasource,
    required ReceiptLocalDatasource receiptLocalDatasource,
    Uuid? uuid,
  }) : _database = database,
       _quickCustomerLocalDatasource = quickCustomerLocalDatasource,
       _cashRegisterLocalDatasource = cashRegisterLocalDatasource,
       _receiptLocalDatasource = receiptLocalDatasource,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final QuickCustomerLocalDatasource _quickCustomerLocalDatasource;
  final CashRegisterLocalDatasource _cashRegisterLocalDatasource;
  final ReceiptLocalDatasource _receiptLocalDatasource;
  final Uuid _uuid;

  Future<CheckoutResult> completeCheckout({
    required CheckoutRequest request,
    required UserSession session,
  }) async {
    if (request.cart.isEmpty) {
      throw const CheckoutException(
        'Adicione itens ao carrinho antes de concluir.',
      );
    }

    final openCashSession = await _cashRegisterLocalDatasource
        .loadOpenSessionSummary();
    if (openCashSession == null) {
      throw const CheckoutException(
        'Abra o caixa antes de registrar uma venda.',
      );
    }

    final now = DateTime.now().toUtc();
    final saleLocalId = _uuid.v4();
    final subtotalInCents = request.cart.subtotalInCents;
    final discountInCents = request.cart.discountInCents;
    final totalInCents = request.cart.totalInCents;

    if (request.paymentMethod == PaymentMethod.cash &&
        request.amountReceivedInCents < totalInCents) {
      throw const CheckoutException(
        'Valor recebido em dinheiro nao pode ser menor que o total da venda.',
      );
    }

    if (request.paymentMethod == PaymentMethod.pix &&
        !request.pixConfirmedManually) {
      throw const CheckoutException(
        'Confirme manualmente o pagamento Pix antes de concluir.',
      );
    }

    final normalizedCustomerName = request.customerName?.trim();
    final normalizedCustomerPhone = request.customerPhone?.trim();
    final hasCustomerDraft =
        normalizedCustomerName != null &&
        normalizedCustomerName.isNotEmpty &&
        normalizedCustomerPhone != null &&
        normalizedCustomerPhone.isNotEmpty;

    if (request.paymentMethod == PaymentMethod.note &&
        request.noteDueDate == null) {
      throw const CheckoutException(
        'Pagamento em nota exige definicao de vencimento.',
      );
    }

    if (request.paymentMethod == PaymentMethod.note && !hasCustomerDraft) {
      throw const CheckoutException(
        'Pagamento em nota exige cliente identificado nesta fase do projeto.',
      );
    }

    final paymentStatus = request.paymentMethod == PaymentMethod.note
        ? 'pending'
        : 'paid';
    final changeInCents = request.paymentMethod == PaymentMethod.cash
        ? request.amountReceivedInCents - totalInCents
        : 0;
    final cashMovementType = switch (request.paymentMethod) {
      PaymentMethod.cash => CashMovementType.saleCash,
      PaymentMethod.pix => CashMovementType.salePix,
      PaymentMethod.note => CashMovementType.saleNote,
    };

    final receipt = await _generateReceipt(
      saleLocalId: saleLocalId,
      session: session,
      request: request,
      createdAt: now,
      subtotalInCents: subtotalInCents,
      discountInCents: discountInCents,
      totalInCents: totalInCents,
      changeInCents: changeInCents,
    );

    final db = await _database.database;
    late final LocalSale sale;
    late final List<LocalSaleItem> saleItems;
    late final LocalPayment payment;
    PaymentTerm? paymentTerm;
    QuickCustomer? quickCustomer;

    await db.transaction((txn) async {
      if (hasCustomerDraft) {
        final upsertResult = await _quickCustomerLocalDatasource
            .upsertInTransaction(
              executor: txn,
              name: normalizedCustomerName,
              phone: normalizedCustomerPhone,
            );
        quickCustomer = upsertResult.customer;

        if (upsertResult.created) {
          await _insertOutbox(
            executor: txn,
            operationType: 'quick_customer',
            entityLocalId: quickCustomer!.localId,
            companyId: session.companyContext.companyId,
            deviceId: session.deviceRegistration.deviceId,
            payload: <String, Object?>{
              'localId': quickCustomer!.localId,
              'name': quickCustomer!.name,
              'phone': quickCustomer!.phone,
              'createdAt': quickCustomer!.createdAt.toIso8601String(),
            },
          );
        }
      }

      sale = LocalSale(
        localId: saleLocalId,
        companyId: session.companyContext.companyId,
        userId: session.user.userId,
        customerLocalId: quickCustomer?.localId,
        customerRemoteId: quickCustomer?.remoteId,
        cashSessionLocalId: openCashSession.session.localId,
        subtotalInCents: subtotalInCents,
        discountInCents: discountInCents,
        totalInCents: totalInCents,
        status: 'completed',
        createdAt: now,
        updatedAt: now,
      );

      await txn.insert('sales', <String, Object?>{
        'local_id': sale.localId,
        'remote_id': sale.remoteId,
        'company_id': sale.companyId,
        'user_id': sale.userId,
        'customer_local_id': sale.customerLocalId,
        'customer_remote_id': sale.customerRemoteId,
        'cash_session_local_id': sale.cashSessionLocalId,
        'subtotal_cents': sale.subtotalInCents,
        'discount_cents': sale.discountInCents,
        'total_cents': sale.totalInCents,
        'status': sale.status,
        'created_at': sale.createdAt.toIso8601String(),
        'updated_at': sale.updatedAt.toIso8601String(),
        'synced_at': null,
      });

      saleItems = request.cart.items.map((item) {
        return _buildSaleItem(
          saleLocalId: saleLocalId,
          item: item,
          createdAt: now,
        );
      }).toList();

      for (final item in saleItems) {
        await txn.insert('sale_items', <String, Object?>{
          'local_id': item.localId,
          'sale_local_id': item.saleLocalId,
          'variant_local_id': item.variantLocalId,
          'variant_remote_id': item.variantRemoteId,
          'display_name': item.displayName,
          'quantity': item.quantity,
          'unit_price_cents': item.unitPriceInCents,
          'total_price_cents': item.totalPriceInCents,
          'discount_cents': item.discountInCents,
          'created_at': item.createdAt.toIso8601String(),
        });
      }

      payment = LocalPayment(
        localId: _uuid.v4(),
        saleLocalId: saleLocalId,
        method: request.paymentMethod,
        amountInCents: totalInCents,
        changeInCents: changeInCents,
        status: paymentStatus,
        createdAt: now,
        updatedAt: now,
      );

      await txn.insert('payments', <String, Object?>{
        'local_id': payment.localId,
        'sale_local_id': payment.saleLocalId,
        'method': payment.method.wireValue,
        'amount_cents': payment.amountInCents,
        'change_cents': payment.changeInCents,
        'status': payment.status,
        'created_at': payment.createdAt.toIso8601String(),
        'updated_at': payment.updatedAt.toIso8601String(),
      });

      if (request.paymentMethod == PaymentMethod.note) {
        paymentTerm = PaymentTerm.createNote(
          localId: _uuid.v4(),
          saleLocalId: saleLocalId,
          customerLocalId: quickCustomer?.localId,
          customerRemoteId: quickCustomer?.remoteId,
          originalAmountInCents: totalInCents,
          dueDate: request.noteDueDate!,
          notes: request.noteDescription,
          now: now,
        );

        await txn.insert('payment_terms', <String, Object?>{
          'local_id': paymentTerm!.localId,
          'sale_local_id': paymentTerm!.saleLocalId,
          'remote_id': paymentTerm!.remoteId,
          'customer_local_id': paymentTerm!.customerLocalId,
          'customer_remote_id': paymentTerm!.customerRemoteId,
          'payment_method': paymentTerm!.paymentMethod.wireValue,
          'original_amount_cents': paymentTerm!.originalAmountInCents,
          'paid_amount_cents': paymentTerm!.paidAmountInCents,
          'outstanding_amount_cents': paymentTerm!.outstandingAmountInCents,
          'due_date': paymentTerm!.dueDate.toIso8601String(),
          'payment_status': paymentTerm!.paymentStatus.wireValue,
          'notes': paymentTerm!.notes,
          'sync_status': paymentTerm!.syncStatus.wireValue,
          'created_at': paymentTerm!.createdAt.toIso8601String(),
          'updated_at': paymentTerm!.updatedAt.toIso8601String(),
        });
      }

      await txn.insert('receipts', <String, Object?>{
        'local_id': receipt.localId,
        'sale_local_id': receipt.saleLocalId,
        'pdf_path': receipt.pdfPath,
        'shared_at': receipt.sharedAt?.toIso8601String(),
        'created_at': receipt.createdAt.toIso8601String(),
      });

      await _cashRegisterLocalDatasource.insertSaleMovementInTransaction(
        executor: txn,
        companyId: session.companyContext.companyId,
        deviceId: session.deviceRegistration.deviceId,
        cashSessionLocalId: openCashSession.session.localId,
        type: cashMovementType,
        amountInCents: totalInCents,
        saleLocalId: saleLocalId,
      );

      await _insertOutbox(
        executor: txn,
        operationType: 'sale',
        entityLocalId: saleLocalId,
        companyId: session.companyContext.companyId,
        deviceId: session.deviceRegistration.deviceId,
        payload: <String, Object?>{
          'localId': sale.localId,
          'companyId': sale.companyId,
          'userId': sale.userId,
          'customerLocalId': sale.customerLocalId,
          'cashSessionLocalId': sale.cashSessionLocalId,
          'subtotalInCents': sale.subtotalInCents,
          'discountInCents': sale.discountInCents,
          'totalInCents': sale.totalInCents,
          'status': sale.status,
          'createdAt': sale.createdAt.toIso8601String(),
          'items': saleItems.map(_saleItemPayload).toList(),
          'payments': <Map<String, Object?>>[
            _salePaymentPayload(
              payment: payment,
              dueDate: request.noteDueDate,
              notes: request.noteDescription,
            ),
          ],
        },
      );

      if (paymentTerm != null) {
        await _insertOutbox(
          executor: txn,
          operationType: 'receivable_note',
          entityLocalId: paymentTerm!.localId,
          companyId: session.companyContext.companyId,
          deviceId: session.deviceRegistration.deviceId,
          payload: <String, Object?>{
            'saleLocalId': sale.localId,
            'paymentTermLocalId': paymentTerm!.localId,
            'customerLocalId': paymentTerm!.customerLocalId,
            'originalAmountInCents': paymentTerm!.originalAmountInCents,
            'outstandingAmountInCents': paymentTerm!.outstandingAmountInCents,
            'dueDate': paymentTerm!.dueDate.toIso8601String(),
            'paymentStatus': paymentTerm!.paymentStatus.wireValue,
            'notes': paymentTerm!.notes,
          },
        );
      }
    });

    return CheckoutResult(
      sale: sale,
      items: saleItems,
      payment: payment,
      paymentTerm: paymentTerm,
      quickCustomer: quickCustomer,
      receipt: receipt,
      cashMovementType: cashMovementType,
    );
  }

  Future<Receipt> _generateReceipt({
    required String saleLocalId,
    required UserSession session,
    required CheckoutRequest request,
    required DateTime createdAt,
    required int subtotalInCents,
    required int discountInCents,
    required int totalInCents,
    required int changeInCents,
  }) {
    return _receiptLocalDatasource.generateSaleReceipt(
      saleLocalId: saleLocalId,
      companyName: session.companyContext.companyName,
      operatorName: session.user.name,
      customerName: request.customerName,
      customerPhone: request.customerPhone,
      items: request.cart.items
          .map(
            (item) => ReceiptLineItem(
              description: item.variant.displayName,
              quantity: item.quantity,
              totalInCents: item.totalPriceInCents,
            ),
          )
          .toList(),
      paymentMethodLabel: switch (request.paymentMethod) {
        PaymentMethod.cash => 'Dinheiro',
        PaymentMethod.pix => 'Pix manual',
        PaymentMethod.note => 'Nota',
      },
      dueDate: request.noteDueDate,
      subtotalInCents: subtotalInCents,
      discountInCents: discountInCents,
      totalInCents: totalInCents,
      changeInCents: changeInCents,
      createdAt: createdAt,
    );
  }

  LocalSaleItem _buildSaleItem({
    required String saleLocalId,
    required CartItem item,
    required DateTime createdAt,
  }) {
    return LocalSaleItem(
      localId: _uuid.v4(),
      saleLocalId: saleLocalId,
      variantLocalId: item.variant.localId,
      variantRemoteId: item.variant.remoteId,
      displayName: item.variant.displayName,
      quantity: item.quantity,
      unitPriceInCents: item.unitPriceInCents,
      totalPriceInCents: item.totalPriceInCents,
      discountInCents: 0,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> _saleItemPayload(LocalSaleItem item) {
    return <String, Object?>{
      'localId': item.localId,
      'variantLocalId': item.variantLocalId,
      'variantRemoteId': item.variantRemoteId,
      'displayName': item.displayName,
      'quantity': item.quantity,
      'unitPriceInCents': item.unitPriceInCents,
      'totalPriceInCents': item.totalPriceInCents,
    };
  }

  Map<String, Object?> _salePaymentPayload({
    required LocalPayment payment,
    DateTime? dueDate,
    String? notes,
  }) {
    return <String, Object?>{
      'localId': payment.localId,
      'method': payment.method.wireValue,
      'amountInCents': payment.amountInCents,
      'changeInCents': payment.changeInCents,
      'status': payment.status,
      'dueDate': dueDate?.toUtc().toIso8601String(),
      'notes': notes,
    };
  }

  Future<void> _insertOutbox({
    required LocalDatabaseExecutor executor,
    required String operationType,
    required String entityLocalId,
    required String companyId,
    required String deviceId,
    required Map<String, Object?> payload,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await executor.insert('sync_outbox', <String, Object?>{
      'operation_id': _uuid.v4(),
      'device_id': deviceId,
      'company_id': companyId,
      'type': operationType,
      'entity_local_id': entityLocalId,
      'payload_json': jsonEncode(payload),
      'status': SyncRecordStatus.pending.wireValue,
      'retries': 0,
      'last_error': null,
      'created_at': now,
      'updated_at': now,
    });
  }
}

class CheckoutException implements Exception {
  const CheckoutException(this.message);

  final String message;

  @override
  String toString() => message;
}
