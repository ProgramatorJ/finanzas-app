import 'package:finanzas_app/core/repositories/payments_repository.dart';
import 'package:finanzas_app/core/enums/credit_status.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment_model.dart';
import '../models/credit_model.dart';
import '../models/installment_model.dart';
import '../constants/app_constants.dart';
import '../utils/mora_engine.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(FirebaseFirestore.instance);
});

class PaymentsRepository {
  final FirebaseFirestore _db;

  PaymentsRepository(this._db);

  /// Transacción atómica de pagos extraída de firestore_service.dart
  Future<void> registerPaymentTransaction({
    required String creditId,
    required PaymentModel payment,
    required double dailyMoraRate,
  }) async {
    debugPrint('[PaymentTx] Iniciando registro de abono para crédito: $creditId');

    final creditRef = _db.collection(AppConstants.creditsCollection).doc(creditId);
    final installmentsRef = creditRef.collection(AppConstants.installmentsSubCollection);

    // Obtener las referencias de las cuotas fuera de la transacción (Firestore Web seguro)
    final installmentsQuery = await installmentsRef.get();
    final List<DocumentReference> instRefs = installmentsQuery.docs.map((d) => d.reference).toList();

    await _db.runTransaction((transaction) async {
      // 1. Leer crédito con bloqueo
      final creditDoc = await transaction.get(creditRef);
      if (!creditDoc.exists || creditDoc.data() == null) {
        throw Exception('El crédito no existe (ID: $creditId).');
      }
      final credit = CreditModel.fromMap(creditDoc.data()!, creditDoc.id);

      // 2. Leer cuotas con bloqueo
      final instDocs = await Future.wait(instRefs.map((ref) => transaction.get(ref)));
      final List<InstallmentModel> installments = instDocs
          .where((doc) => doc.exists && doc.data() != null)
          .map((doc) => InstallmentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      installments.sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));

      // 3. Proyectar mora a la fecha REAL del pago (la que seleccionó el usuario)
      final normalizedPaymentDate = DateTime(
        payment.paymentDate.year,
        payment.paymentDate.month,
        payment.paymentDate.day,
      );

      // 3. Proyectar mora
      final installmentsWithMora = MoraEngine.updateMoraAndConsolidations(
        installments: installments,
        dailyMoraRate: dailyMoraRate,
        targetDate: normalizedPaymentDate,
      );

      // 4. Aplicar cascada
      final cascadeResult = MoraEngine.applyPaymentCascade(
        currentInstallments: installmentsWithMora,
        paymentAmount: payment.amountReceived,
        paymentDate: normalizedPaymentDate,
      );

      // 5. Preparar documentos
      final double actualApplied = payment.amountReceived - cascadeResult.remainingPayment;
      final finalPayment = PaymentModel(
        paymentId: '',
        registeredByUid: payment.registeredByUid,
        paymentDate: normalizedPaymentDate,
        amountReceived: payment.amountReceived,
        appliedToMora: cascadeResult.totalAppliedToMora,
        appliedToInterest: cascadeResult.totalAppliedToInterest,
        appliedToPrincipal: cascadeResult.totalAppliedToPrincipal,
        affectedInstallmentNumbers: cascadeResult.affectedInstallmentNumbers,
        installmentBreakdowns: cascadeResult.installmentBreakdowns,
        paymentMethod: payment.paymentMethod,
        receiptNumber: payment.receiptNumber,
        notes: payment.notes,
        createdAt: DateTime.now(),
      );

      final paymentMap = finalPayment.toMap();
      // Guardar la fecha elegida por el usuario (no sobreescribir con serverTimestamp)
      paymentMap['paymentDate'] = Timestamp.fromDate(normalizedPaymentDate);
      paymentMap['createdAt'] = FieldValue.serverTimestamp();

      final double newTotalPaid = credit.totalPaid + actualApplied;
      final double newTotalPaidPrincipal = credit.totalPaidPrincipal + cascadeResult.totalAppliedToPrincipal;
      final double newTotalPaidInterest = credit.totalPaidInterest + cascadeResult.totalAppliedToInterest;
      final double newTotalPaidMora = credit.totalPaidMora + cascadeResult.totalAppliedToMora;
      final double newOutstandingBalance = (credit.totalAmount - newTotalPaidPrincipal - newTotalPaidInterest).clamp(0.0, double.infinity);

      final int newPaidInstallmentsCount = cascadeResult.updatedInstallments.where((inst) => inst.status == InstallmentStatus.paid).length;

      CreditStatus newStatus = credit.status;
      if (newOutstandingBalance <= 0) {
        newStatus = CreditStatus.completed;
      } else if (cascadeResult.updatedInstallments.any((inst) => inst.status == InstallmentStatus.overdue)) {
        newStatus = CreditStatus.defaulted;
      } else {
        newStatus = CreditStatus.active;
      }

      final double finalAccumulatedMora = cascadeResult.updatedInstallments.fold<double>(0.0, (sum, inst) => sum + inst.accumulatedMora);

      // 6. Escribir
      final paymentDocRef = creditRef.collection(AppConstants.paymentsSubCollection).doc();
      transaction.set(paymentDocRef, paymentMap);

      for (final updatedInst in cascadeResult.updatedInstallments) {
        final originalDoc = instDocs.firstWhere((doc) => (doc.data() as Map<String, dynamic>)['installmentNumber'] == updatedInst.installmentNumber);
        transaction.set(originalDoc.reference, updatedInst.toMap());
      }

      transaction.update(creditRef, {
        'totalPaid': newTotalPaid,
        'totalPaidPrincipal': newTotalPaidPrincipal,
        'totalPaidInterest': newTotalPaidInterest,
        'totalPaidMora': newTotalPaidMora,
        'outstandingBalance': newOutstandingBalance,
        'paidInstallments': newPaidInstallmentsCount,
        'status': newStatus.name,
        'accumulatedMora': finalAccumulatedMora,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        _db.collection('treasury').doc('main'),
        {
          'currentBalance': FieldValue.increment(actualApplied),
          'totalInterestsEarned': FieldValue.increment(cascadeResult.totalAppliedToInterest),
          'totalMoraEarned': FieldValue.increment(cascadeResult.totalAppliedToMora),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    debugPrint('[PaymentTx] ✅ Transacción atómica exitosa. Abono registrado correctamente.');
  }

  Stream<List<PaymentModel>> getPaymentsStream(String creditId) {
    return _db
        .collection(AppConstants.creditsCollection)
        .doc(creditId)
        .collection(AppConstants.paymentsSubCollection)
        .snapshots()
        .map((snap) {
      final payments = snap.docs.map((doc) => PaymentModel.fromMap(doc.data(), doc.id)).toList();
      payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      return payments;
    });
  }

  Stream<List<PaymentModel>> getAllPaymentsStream({int limit = 10000}) {
    return _db
        .collectionGroup(AppConstants.paymentsSubCollection)
        .orderBy('paymentDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => PaymentModel.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<PaymentModel>> getCollectorPaymentsStream(String collectorUid, {int limit = 10000}) {
    return _db
        .collectionGroup(AppConstants.paymentsSubCollection)
        .where('registeredByUid', isEqualTo: collectorUid)
        .orderBy('paymentDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => PaymentModel.fromMap(doc.data(), doc.id)).toList());
  }

  
  Future<void> forceRebuildAndMigrateCredit(String creditId) async {
    debugPrint('[PaymentTx] Iniciando migracion forzada de esquema para credito: $creditId');

    final creditRef = _db.collection(AppConstants.creditsCollection).doc(creditId);
    final installmentsRef = creditRef.collection(AppConstants.installmentsSubCollection);

    // Obtener las referencias de las cuotas fuera de la transaccion
    final installmentsQuery = await installmentsRef.get();
    final List<DocumentReference> instRefs = installmentsQuery.docs.map((d) => d.reference).toList();
    
    // Obtener todos los pagos restantes fuera de la transaccion
    final paymentsQuery = await creditRef.collection(AppConstants.paymentsSubCollection).get();

    await _db.runTransaction((transaction) async {
      // 1. Leer credito con bloqueo
      final creditDoc = await transaction.get(creditRef);
      if (!creditDoc.exists || creditDoc.data() == null) {
        throw Exception('El credito no existe (ID: $creditId).');
      }
      final credit = CreditModel.fromMap(creditDoc.data()!, creditDoc.id);

      // Si ya esta en la version actual, no hacemos nada
      if (credit.schemaVersion == AppConstants.currentMathSchemaVersion) {
        return;
      }

      // 2. Reconstruir el estado base de TODAS las cuotas
      final instDocs = await Future.wait(instRefs.map((ref) => transaction.get(ref)));
      List<InstallmentModel> installments = instDocs
          .where((doc) => doc.exists && doc.data() != null)
          .map((doc) => InstallmentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      // Resetear cuotas a su estado original
      installments = installments.map((inst) => InstallmentModel(
        installmentId: inst.installmentId,
        creditId: inst.creditId,
        installmentNumber: inst.installmentNumber,
        dueDate: inst.dueDate,
        principalPortion: inst.principalPortion,
        interestPortion: inst.interestPortion,
        scheduledAmount: inst.scheduledAmount,
        status: InstallmentStatus.pending,
        paidAmount: 0.0,
        remainingAmount: inst.scheduledAmount,
        isMoraActive: false,
        moraStartDate: null,
        dailyMoraRate: inst.dailyMoraRate,
        moraBase: inst.scheduledAmount,
        accumulatedMora: 0.0,
        moraPaid: 0.0,
        isConsolidated: inst.isConsolidated,
        consolidatedIntoInstallment: inst.consolidatedIntoInstallment,
        consolidationDate: inst.consolidationDate,
        createdAt: inst.createdAt,
        updatedAt: DateTime.now(), // Se actualizara a medida que se procesen los pagos
      )).toList();

      // Resetear contadores del credito a estado original
      double newTotalPaid = 0.0;
      double newTotalPaidPrincipal = 0.0;
      double newTotalPaidInterest = 0.0;
      double newTotalPaidMora = 0.0;
      int newPaidInstallmentsCount = 0;
      
      // 3. Obtener los pagos ordenados cronologicamente
      final remainingPayments = paymentsQuery.docs
          .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
          .toList();
      remainingPayments.sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

      // Reaplicar cada pago restante en orden
      for (final p in remainingPayments) {
        final normalizedDate = DateTime(p.paymentDate.year, p.paymentDate.month, p.paymentDate.day);
        installments = MoraEngine.updateMoraAndConsolidations(
          installments: installments,
          dailyMoraRate: credit.dailyMoraRate,
          targetDate: normalizedDate,
        );
        
        final cascadeResult = MoraEngine.applyPaymentCascade(
          currentInstallments: installments,
          paymentAmount: p.amountReceived,
          paymentDate: normalizedDate,
        );
        installments = cascadeResult.updatedInstallments;

        newTotalPaid += p.amountReceived;
        newTotalPaidPrincipal += p.appliedToPrincipal;
        newTotalPaidInterest += p.appliedToInterest;
        newTotalPaidMora += p.appliedToMora;
      }

      // 4. Calcular estado final del credito
      final double newOutstandingBalance = (credit.totalAmount - newTotalPaidPrincipal - newTotalPaidInterest).clamp(0.0, double.infinity);
      double finalAccumulatedMora = installments.fold(0.0, (sum, inst) => sum + inst.accumulatedMora);
      newPaidInstallmentsCount = installments.where((inst) => inst.status == InstallmentStatus.paid).length;
      
      CreditStatus newStatus = credit.status;
      if (newOutstandingBalance <= 0.0 && finalAccumulatedMora <= newTotalPaidMora) {
        newStatus = CreditStatus.completed;
      } else if (installments.any((inst) => inst.status == InstallmentStatus.overdue)) {
        newStatus = CreditStatus.defaulted;
      } else {
        newStatus = CreditStatus.active;
      }

      // 5. Escribir actualizaciones
      for (final updatedInst in installments) {
        final originalDoc = instDocs.firstWhere((doc) => (doc.data() as Map<String, dynamic>)['installmentNumber'] == updatedInst.installmentNumber);
        transaction.set(originalDoc.reference, updatedInst.toMap());
      }

      transaction.update(creditRef, {
        'totalPaid': newTotalPaid,
        'totalPaidPrincipal': newTotalPaidPrincipal,
        'totalPaidInterest': newTotalPaidInterest,
        'totalPaidMora': newTotalPaidMora,
        'outstandingBalance': newOutstandingBalance,
        'paidInstallments': newPaidInstallmentsCount,
        'status': newStatus.name,
        'accumulatedMora': finalAccumulatedMora,
        'schemaVersion': AppConstants.currentMathSchemaVersion, // ACTUALIZACION DE SCHEMA
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    
    debugPrint('[PaymentTx] Migracion de esquema finalizada exitosamente para credito: $creditId');
  }


  Future<void> deletePayment(String creditId, String paymentId) async {
    debugPrint('[PaymentTx] Iniciando reversión de abono $paymentId para crédito: $creditId');

    final creditRef = _db.collection(AppConstants.creditsCollection).doc(creditId);
    final paymentRef = creditRef.collection(AppConstants.paymentsSubCollection).doc(paymentId);

    final installmentsRef = creditRef.collection(AppConstants.installmentsSubCollection);

    // Obtener las referencias de las cuotas fuera de la transacción
    final installmentsQuery = await installmentsRef.get();
    final List<DocumentReference> instRefs = installmentsQuery.docs.map((d) => d.reference).toList();
    
    // Obtener todos los pagos restantes fuera de la transacción
    final paymentsQuery = await creditRef.collection(AppConstants.paymentsSubCollection).get();

    await _db.runTransaction((transaction) async {
      // 1. Leer el pago a eliminar
      final paymentDoc = await transaction.get(paymentRef);
      if (!paymentDoc.exists || paymentDoc.data() == null) {
        throw Exception('El abono no existe (ID: $paymentId).');
      }
      final paymentToDelete = PaymentModel.fromMap(paymentDoc.data()!, paymentDoc.id);

      // 2. Leer crédito con bloqueo
      final creditDoc = await transaction.get(creditRef);
      if (!creditDoc.exists || creditDoc.data() == null) {
        throw Exception('El crédito no existe (ID: $creditId).');
      }
      final credit = CreditModel.fromMap(creditDoc.data()!, creditDoc.id);

      // 3. Revertir los contadores del crédito
      final double newTotalPaid = (credit.totalPaid - paymentToDelete.amountReceived).clamp(0.0, double.infinity);
      final double newTotalPaidPrincipal = (credit.totalPaidPrincipal - paymentToDelete.appliedToPrincipal).clamp(0.0, double.infinity);
      final double newTotalPaidInterest = (credit.totalPaidInterest - paymentToDelete.appliedToInterest).clamp(0.0, double.infinity);
      final double newTotalPaidMora = (credit.totalPaidMora - paymentToDelete.appliedToMora).clamp(0.0, double.infinity);
      final double newOutstandingBalance = (credit.totalAmount - newTotalPaidPrincipal - newTotalPaidInterest).clamp(0.0, double.infinity);

      // 4. Reconstruir el estado base de TODAS las cuotas
      final instDocs = await Future.wait(instRefs.map((ref) => transaction.get(ref)));
      List<InstallmentModel> installments = instDocs
          .where((doc) => doc.exists && doc.data() != null)
          .map((doc) => InstallmentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      // Resetear cuotas a su estado original
      installments = installments.map((inst) => InstallmentModel(
        installmentId: inst.installmentId,
        creditId: inst.creditId,
        installmentNumber: inst.installmentNumber,
        dueDate: inst.dueDate,
        principalPortion: inst.principalPortion,
        interestPortion: inst.interestPortion,
        scheduledAmount: inst.scheduledAmount,
        status: InstallmentStatus.pending,
        paidAmount: 0.0,
        remainingAmount: inst.scheduledAmount,
        isMoraActive: false,
        moraStartDate: null,
        dailyMoraRate: inst.dailyMoraRate,
        moraBase: inst.scheduledAmount,
        accumulatedMora: 0.0,
        moraPaid: 0.0,
        isConsolidated: inst.isConsolidated,
        consolidatedIntoInstallment: inst.consolidatedIntoInstallment,
        consolidationDate: inst.consolidationDate,
        createdAt: inst.createdAt,
        updatedAt: DateTime.now(),
        alarmHour: inst.alarmHour,
        alarmMinute: inst.alarmMinute,
        isAlarmEnabled: inst.isAlarmEnabled,
        isAlarmSilent: inst.isAlarmSilent,
        isMoraExempt: inst.isMoraExempt,
      )).toList();
      
      // Ordenar cronológicamente los pagos RESTANTES
      final remainingPayments = paymentsQuery.docs
          .where((doc) => doc.id != paymentId)
          .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
          .toList();
      remainingPayments.sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

      // Reaplicar cada pago restante en orden
      for (final p in remainingPayments) {
        final normalizedDate = DateTime(p.paymentDate.year, p.paymentDate.month, p.paymentDate.day);
        installments = MoraEngine.updateMoraAndConsolidations(
          installments: installments,
          dailyMoraRate: credit.dailyMoraRate,
          targetDate: normalizedDate,
        );
        final cascade = MoraEngine.applyPaymentCascade(
          currentInstallments: installments,
          paymentAmount: p.amountReceived,
          paymentDate: normalizedDate,
        );
        installments = cascade.updatedInstallments;
      }
      
      // Proyectar al día de hoy para actualizar estados de mora finales
      final now = DateTime.now();
      final todayNormalized = DateTime(now.year, now.month, now.day);
      installments = MoraEngine.updateMoraAndConsolidations(
          installments: installments,
          dailyMoraRate: credit.dailyMoraRate,
          targetDate: todayNormalized,
      );

      final int newPaidInstallmentsCount = installments.where((inst) => inst.status == InstallmentStatus.paid).length;
      final double finalAccumulatedMora = installments.fold<double>(0.0, (sum, inst) => sum + inst.accumulatedMora);

      CreditStatus newStatus = credit.status;
      if (newOutstandingBalance <= 0) {
        newStatus = CreditStatus.completed;
      } else if (installments.any((inst) => inst.status == InstallmentStatus.overdue)) {
        newStatus = CreditStatus.defaulted;
      } else {
        newStatus = CreditStatus.active;
      }

      // 5. Escribir actualizaciones
      for (final updatedInst in installments) {
        final originalDoc = instDocs.firstWhere((doc) => (doc.data() as Map<String, dynamic>)['installmentNumber'] == updatedInst.installmentNumber);
        transaction.set(originalDoc.reference, updatedInst.toMap());
      }

      transaction.update(creditRef, {
        'totalPaid': newTotalPaid,
        'totalPaidPrincipal': newTotalPaidPrincipal,
        'totalPaidInterest': newTotalPaidInterest,
        'totalPaidMora': newTotalPaidMora,
        'outstandingBalance': newOutstandingBalance,
        'paidInstallments': newPaidInstallmentsCount,
        'status': newStatus.name,
        'accumulatedMora': finalAccumulatedMora,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        _db.collection('treasury').doc('main'),
        {
          'currentBalance': FieldValue.increment(-paymentToDelete.amountReceived),
          'totalInterestsEarned': FieldValue.increment(-paymentToDelete.appliedToInterest),
          'totalMoraEarned': FieldValue.increment(-paymentToDelete.appliedToMora),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Borrar el pago
      transaction.delete(paymentRef);
    });

    debugPrint('[PaymentTx] ✅ Transacción de reversión exitosa.');
  }

  Future<void> updatePaymentFields(String creditId, String paymentId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db
        .collection(AppConstants.creditsCollection)
        .doc(creditId)
        .collection(AppConstants.paymentsSubCollection)
        .doc(paymentId)
        .update(data);
  }
}
