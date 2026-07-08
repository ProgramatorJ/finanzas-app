import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/client_model.dart';
import '../models/credit_model.dart';
import '../models/installment_model.dart';
import '../models/payment_model.dart';
import '../models/appointment_model.dart';
import '../models/expense_model.dart';
import '../models/treasury_model.dart';
import '../models/investment_model.dart';
import '../models/investor_payment_model.dart';
import '../models/cash_adjustment_model.dart';
import '../constants/app_constants.dart';
import '../utils/mora_engine.dart';
import '../utils/commercial_calendar.dart';

/// Servicio principal de acceso a Firestore.
/// Contiene los métodos CRUD para todas las colecciones de la app.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── USUARIOS ────────────────────────────────────────────────────────────

  /// Crea o sobreescribe el documento de un usuario en Firestore.
  Future<void> setUser(UserModel user) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(user.toMap());
  }

  /// Obtiene el documento de un usuario por su UID.
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  /// Stream de todos los usuarios (solo admin debería usar esto).
  Stream<List<UserModel>> getAllUsersStream() {
    return _db
        .collection(AppConstants.usersCollection)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream de todos los cobradores activos (para asignar a clientes).
  Stream<List<UserModel>> getCollectorsStream() {
    return _db
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: 'cobrador')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ─── CLIENTES ────────────────────────────────────────────────────────────

  /// Crea un nuevo cliente en Firestore. Devuelve el ID generado.
  Future<String> createClient(ClientModel client) async {
    final docRef = await _db
        .collection(AppConstants.clientsCollection)
        .add(client.toMap());
    return docRef.id;
  }

  /// Actualiza campos específicos de un cliente.
  Future<void> updateClient(String clientId, Map<String, dynamic> data) async {
    await _db
        .collection(AppConstants.clientsCollection)
        .doc(clientId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Stream de todos los clientes (para admin).
  Stream<List<ClientModel>> getAllClientsStream() {
    return _db
        .collection(AppConstants.clientsCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ClientModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream de clientes asignados a un cobrador específico.
  Stream<List<ClientModel>> getAssignedClientsStream(String collectorUid) {
    return _db
        .collection(AppConstants.clientsCollection)
        .where('assignedCollectorIds', arrayContains: collectorUid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ClientModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ─── CRÉDITOS ────────────────────────────────────────────────────────────

  /// Crea un nuevo crédito. Devuelve el ID generado.
  /// Crea un nuevo crédito. Devuelve el ID generado con formato YYMMDDXX.
  Future<String> createCredit(CreditModel credit) async {
    final date = credit.disbursementDate;
    final yy = date.year.toString().substring(2);
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final query = await _db
        .collection(AppConstants.creditsCollection)
        .where('disbursementDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('disbursementDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    int seq = query.docs.length + 1;
    String proposedId = '';
    bool exists = true;
    while (exists) {
      proposedId = '$yy$mm$dd${seq.toString().padLeft(2, '0')}';
      final doc = await _db.collection(AppConstants.creditsCollection).doc(proposedId).get();
      if (!doc.exists) {
        exists = false;
      } else {
        seq++;
      }
    }

    final creditMap = credit.toMap();
    final batch = _db.batch();
    final docRef = _db.collection(AppConstants.creditsCollection).doc(proposedId);
    batch.set(docRef, creditMap);

    // Actualizar tesorería: El desembolso sale de la caja
    batch.set(
      _db.collection('treasury').doc('main'),
      {
        'currentBalance': FieldValue.increment(-credit.principalAmount),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
        
    return proposedId;
  }

  /// Actualiza campos específicos de un crédito.
  Future<void> updateCredit(String creditId, Map<String, dynamic> data) async {
    await _db
        .collection(AppConstants.creditsCollection)
        .doc(creditId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Stream de todos los créditos de un cliente específico.
  Stream<List<CreditModel>> getClientCreditsStream(String clientId) {
    return _db
        .collection(AppConstants.creditsCollection)
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CreditModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream de todos los créditos del sistema (para listado general).
  Stream<List<CreditModel>> getAllCreditsStream() {
    return _db
        .collection(AppConstants.creditsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CreditModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ─── CUOTAS (Subcolección de Crédito) ────────────────────────────────────
  
  /// Escanea todos los créditos activos y actualiza su estado y mora si tienen cuotas vencidas.
  Future<void> autoScanMora() async {
    debugPrint('[AutoScan] Iniciando escáner de mora...');
    try {
      final creditsSnap = await _db
          .collection(AppConstants.creditsCollection)
          .where('status', isEqualTo: CreditStatus.active.name)
          .get();

      for (final doc in creditsSnap.docs) {
        final credit = CreditModel.fromMap(doc.data(), doc.id);
        
        // Buscar las cuotas pendientes del crédito
        final instSnap = await _db
            .collection(AppConstants.creditsCollection)
            .doc(credit.creditId)
            .collection(AppConstants.installmentsSubCollection)
            .where('status', isEqualTo: InstallmentStatus.pending.name)
            .get();

        bool needsRecalculation = false;
        final now = DateTime.now();
        for (final iDoc in instSnap.docs) {
          final inst = InstallmentModel.fromMap(iDoc.data(), iDoc.id, creditId: credit.creditId);
          // Verificar si la fecha de vencimiento ya pasó (inicio del día)
          final dueDate = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
          final today = DateTime(now.year, now.month, now.day);
          if (today.isAfter(dueDate)) {
            needsRecalculation = true;
            break; // Si hay al menos una cuota vencida, se recalcula todo el crédito
          }
        }

        if (needsRecalculation) {
          debugPrint('[AutoScan] Crédito ${credit.creditId} necesita recálculo de mora.');
          await recalculateCreditHistory(credit.creditId);
        }
      }
      debugPrint('[AutoScan] ✅ Escáner de mora finalizado.');
    } catch (e) {
      debugPrint('[AutoScan] Error al escanear mora: $e');
    }
  }

  // ─── CUOTAS (Subcolección de Crédito) ────────────────────────────────────

  /// Crea todas las cuotas de un crédito de forma atómica (batch write).
  Future<void> createInstallments(
      String creditId, List<InstallmentModel> installments) async {
    final batch = _db.batch();
    for (final installment in installments) {
      final docRef = _db
          .collection(AppConstants.creditsCollection)
          .doc(creditId)
          .collection(AppConstants.installmentsSubCollection)
          .doc();
      batch.set(docRef, installment.toMap());
    }
    await batch.commit();
  }

  /// Stream de todas las cuotas de un crédito, ordenadas por número (en memoria).
  /// NOTA: No se usa orderBy() en Firestore porque requiere un índice compuesto
  /// para subcolecciones en Flutter Web, lo que causa fallos silenciosos.
  Stream<List<InstallmentModel>> getInstallmentsStream(String creditId) {
    return _db
        .collection(AppConstants.creditsCollection)
        .doc(creditId)
        .collection(AppConstants.installmentsSubCollection)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => InstallmentModel.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));
          return list;
        });
  }

  /// Actualiza campos de una cuota específica.
  Future<void> updateInstallment(
      String creditId, String installmentId, Map<String, dynamic> data) async {
    await _db
        .collection(AppConstants.creditsCollection)
        .doc(creditId)
        .collection(AppConstants.installmentsSubCollection)
        .doc(installmentId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Stream de todas las cuotas de todos los créditos en el sistema (usando collectionGroup).
  Stream<List<InstallmentModel>> getAllInstallmentsStream() {
    return _db
        .collectionGroup(AppConstants.installmentsSubCollection)
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) {
            final parentCreditId = doc.reference.parent.parent!.id;
            return InstallmentModel.fromMap(
              doc.data(),
              doc.id,
              creditId: parentCreditId,
            );
          }).toList();
        });
  }

  // ─── PAGOS (Subcolección de Crédito) ─────────────────────────────────────

  /// Registra un nuevo pago. Devuelve el ID generado.
  Future<String> registerPayment(String creditId, PaymentModel payment) async {
    final docRef = await _db
        .collection(AppConstants.creditsCollection)
        .doc(creditId)
        .collection(AppConstants.paymentsSubCollection)
        .add(payment.toMap());
    return docRef.id;
  }
  /// Registra un abono en cascada de forma atómica usando batch write.
  /// Se usa batch en lugar de transacción porque las transacciones de Firestore
  /// en Flutter Web (compilación release) pueden silenciar errores internos
  /// cuando combinan queries externas con escrituras dentro de la transacción.
  Future<void> registerPaymentTransaction({
    required String creditId,
    required PaymentModel payment,
    required double dailyMoraRate,
  }) async {
    debugPrint('[PaymentTx] Iniciando registro de abono para crédito: $creditId');
    debugPrint('[PaymentTx] Monto: ${payment.amountReceived}, Fecha: ${payment.paymentDate}');

    final creditRef = _db.collection(AppConstants.creditsCollection).doc(creditId);
    final installmentsRef = creditRef.collection(AppConstants.installmentsSubCollection);

    // 1. Leer crédito
    debugPrint('[PaymentTx] Leyendo documento de crédito...');
    final creditDoc = await creditRef.get();
    if (!creditDoc.exists || creditDoc.data() == null) {
      throw Exception('El crédito no existe (ID: $creditId).');
    }
    final credit = CreditModel.fromMap(creditDoc.data()!, creditDoc.id);
    debugPrint('[PaymentTx] Crédito leído. Balance actual: ${credit.outstandingBalance}');

    // 2. Leer cuotas (sin orderBy para evitar requerir índice compuesto)
    debugPrint('[PaymentTx] Leyendo cuotas...');
    final installmentsSnapshot = await installmentsRef.get();
    debugPrint('[PaymentTx] Cuotas encontradas: ${installmentsSnapshot.docs.length}');

    final List<InstallmentModel> installments = installmentsSnapshot.docs
        .map((doc) => InstallmentModel.fromMap(doc.data(), doc.id))
        .toList();

    // Ordenar en memoria
    installments.sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));

    final normalizedPaymentDate = DateTime(
      payment.paymentDate.year,
      payment.paymentDate.month,
      payment.paymentDate.day,
    );

    // 3. Calcular mora al día del pago (en memoria)
    debugPrint('[PaymentTx] Calculando mora proyectada...');
    final installmentsWithMora = MoraEngine.updateMoraAndConsolidations(
      installments: installments,
      dailyMoraRate: dailyMoraRate,
      targetDate: normalizedPaymentDate,
    );

    // 4. Aplicar cascada de pago (en memoria)
    debugPrint('[PaymentTx] Aplicando cascada de pago...');
    final cascadeResult = MoraEngine.applyPaymentCascade(
      currentInstallments: installmentsWithMora,
      paymentAmount: payment.amountReceived,
      paymentDate: normalizedPaymentDate,
    );
    debugPrint('[PaymentTx] Cascada aplicada. Mora: ${cascadeResult.totalAppliedToMora}, '
        'Interés: ${cascadeResult.totalAppliedToInterest}, Capital: ${cascadeResult.totalAppliedToPrincipal}, '
        'Cuotas afectadas: ${cascadeResult.affectedInstallmentNumbers}');

    // 5. Construir el PaymentModel final con valores reales de la cascada
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

    // 6. Calcular nuevos acumulados del crédito
    final double newTotalPaid = credit.totalPaid + actualApplied;
    final double newTotalPaidPrincipal = credit.totalPaidPrincipal + cascadeResult.totalAppliedToPrincipal;
    final double newTotalPaidInterest = credit.totalPaidInterest + cascadeResult.totalAppliedToInterest;
    final double newTotalPaidMora = credit.totalPaidMora + cascadeResult.totalAppliedToMora;
    final double newOutstandingBalance =
        (credit.totalAmount - newTotalPaidPrincipal - newTotalPaidInterest).clamp(0.0, double.infinity);

    final int newPaidInstallmentsCount = cascadeResult.updatedInstallments
        .where((inst) => inst.status == InstallmentStatus.paid)
        .length;

    CreditStatus newStatus = credit.status;
    if (newOutstandingBalance <= 0) {
      newStatus = CreditStatus.completed;
    } else if (cascadeResult.updatedInstallments
        .any((inst) => inst.status == InstallmentStatus.overdue)) {
      newStatus = CreditStatus.defaulted;
    } else {
      newStatus = CreditStatus.active;
    }

    debugPrint('[PaymentTx] Nuevos valores del crédito: totalPaid=$newTotalPaid, balance=$newOutstandingBalance, status=${newStatus.name}');

    // 7. Escribir todo atómicamente con WriteBatch
    debugPrint('[PaymentTx] Iniciando batch write...');
    final batch = _db.batch();

    // a) Agregar documento de pago
    final paymentDocRef = creditRef.collection(AppConstants.paymentsSubCollection).doc();
    batch.set(paymentDocRef, finalPayment.toMap());
    debugPrint('[PaymentTx] Pago añadido al batch con ID: ${paymentDocRef.id}');

    // b) Actualizar cuotas afectadas
    for (final updatedInst in cascadeResult.updatedInstallments) {
      final originalDoc = installmentsSnapshot.docs.firstWhere(
        (doc) => doc.data()['installmentNumber'] == updatedInst.installmentNumber,
        orElse: () => throw Exception(
            'Cuota #${updatedInst.installmentNumber} no encontrada en Firestore.'),
      );
      final instDocRef = installmentsRef.doc(originalDoc.id);
      batch.set(instDocRef, updatedInst.toMap());
      debugPrint('[PaymentTx] Cuota #${updatedInst.installmentNumber} actualizada en batch.');
    }

    final double finalAccumulatedMora = cascadeResult.updatedInstallments.fold<double>(0.0, (sum, inst) => sum + inst.accumulatedMora);

    // c) Actualizar el crédito
    batch.update(creditRef, {
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
    debugPrint('[PaymentTx] Crédito actualizado en batch.');

    // d) Actualizar Tesorería
    batch.set(
      _db.collection('treasury').doc('main'),
      {
        'currentBalance': FieldValue.increment(actualApplied),
        'totalInterestsEarned': FieldValue.increment(cascadeResult.totalAppliedToInterest),
        'totalMoraEarned': FieldValue.increment(cascadeResult.totalAppliedToMora),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // e) Confirmar batch
    await batch.commit();
    debugPrint('[PaymentTx] ✅ Batch commit exitoso. Abono registrado correctamente.');
  }

  /// Stream de todos los pagos de un crédito, ordenados por fecha (en memoria).
  /// NOTA: No se usa orderBy() en Firestore para evitar índices compuestos en subcolecciones.
  Stream<List<PaymentModel>> getPaymentsStream(String creditId) {
    return _db
        .collection(AppConstants.creditsCollection)
        .doc(creditId)
        .collection(AppConstants.paymentsSubCollection)
        .snapshots()
        .map((snap) {
          final payments = snap.docs
              .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
              .toList();
          payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
          return payments;
        });
  }

  /// Stream de todos los pagos registrados por un cobrador (filtrado en memoria)
  Stream<List<PaymentModel>> getCollectorPaymentsStream(String collectorUid) {
    return _db
        .collectionGroup(AppConstants.paymentsSubCollection)
        .snapshots()
        .map((snap) {
          final payments = snap.docs
              .map((doc) {
                final parentCreditId = doc.reference.parent.parent!.id;
                return PaymentModel.fromMap(
                  doc.data(),
                  doc.id,
                  creditId: parentCreditId,
                );
              })
              .where((p) => p.registeredByUid == collectorUid)
              .toList();
          payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
          return payments;
        });
  }

  /// Stream de todos los pagos registrados en el sistema (ordenado en memoria)
  Stream<List<PaymentModel>> getAllPaymentsStream() {
    return _db
        .collectionGroup(AppConstants.paymentsSubCollection)
        .snapshots()
        .map((snap) {
          final payments = snap.docs
              .map((doc) {
                final parentCreditId = doc.reference.parent.parent!.id;
                return PaymentModel.fromMap(
                  doc.data(),
                  doc.id,
                  creditId: parentCreditId,
                );
              })
              .toList();
          payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
          return payments;
        });
  }

  // ─── TESORERÍA Y GASTOS (NUEVO) ─────────────────────────────────────────

  /// Registra un nuevo gasto operativo y actualiza la tesorería de forma atómica.
  Future<String> registerExpenseTransaction(ExpenseModel expense) async {
    final docRef = _db.collection('expenses').doc();
    final newExpense = ExpenseModel(
      expenseId: docRef.id,
      amount: expense.amount,
      category: expense.category,
      description: expense.description,
      date: expense.date,
      createdBy: expense.createdBy,
    );
    
    final batch = _db.batch();
    batch.set(docRef, newExpense.toMap());
    
    batch.set(
      _db.collection('treasury').doc('main'), 
      {
        'currentBalance': FieldValue.increment(-expense.amount),
        'totalExpenses': FieldValue.increment(expense.amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, 
      SetOptions(merge: true),
    );

    await batch.commit();
    return docRef.id;
  }

  /// Actualiza un gasto existente y ajusta la tesorería de forma atómica.
  Future<void> updateExpense(ExpenseModel oldExp, ExpenseModel newExp) async {
    final batch = _db.batch();
    final double diff = newExp.amount - oldExp.amount;

    batch.set(_db.collection('expenses').doc(oldExp.expenseId), newExp.toMap());

    if (diff != 0) {
      batch.set(
        _db.collection('treasury').doc('main'),
        {
          'currentBalance': FieldValue.increment(-diff),
          'totalExpenses': FieldValue.increment(diff),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Elimina un gasto existente y revierte los cambios en la tesorería de forma atómica.
  Future<void> deleteExpense(String expenseId, double amount) async {
    final batch = _db.batch();
    batch.delete(_db.collection('expenses').doc(expenseId));

    batch.set(
      _db.collection('treasury').doc('main'),
      {
        'currentBalance': FieldValue.increment(amount),
        'totalExpenses': FieldValue.increment(-amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// Stream del documento principal de tesorería
  Stream<TreasuryModel> getTreasuryStream() {
    return _db
        .collection('treasury')
        .doc('main')
        .snapshots()
        .map((snap) {
          if (!snap.exists || snap.data() == null) {
            return TreasuryModel.empty();
          }
          return TreasuryModel.fromMap(snap.data()!);
        });
  }

  /// Stream de los gastos operativos
  Stream<List<ExpenseModel>> getExpensesStream() {
    return _db
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ─── INVERSIONES Y FONDEADORES ──────────────────────────────────────────

  /// Registra una nueva inversión y actualiza la tesorería de forma atómica.
  Future<String> registerInvestmentTransaction(InvestmentModel investment) async {
    final docRef = _db.collection('investments').doc();
    final newInvestment = InvestmentModel(
      investmentId: docRef.id,
      investorName: investment.investorName,
      amount: investment.amount,
      monthlyInterestRate: investment.monthlyInterestRate,
      totalInterestPaid: 0.0,
      totalPrincipalReturned: 0.0,
      outstandingBalance: investment.amount,
      status: InvestmentStatus.active,
      notes: investment.notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(docRef, newInvestment.toMap());

    // Incrementar la caja con el dinero del inversor
    batch.set(
      _db.collection('treasury').doc('main'),
      {
        'currentBalance': FieldValue.increment(investment.amount),
        'totalInvestmentsReceived': FieldValue.increment(investment.amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    return docRef.id;
  }

  /// Actualiza una inversión existente y ajusta la tesorería si el monto cambia.
  Future<void> updateInvestment(InvestmentModel oldInv, InvestmentModel newInv) async {
    final batch = _db.batch();
    final double diff = newInv.amount - oldInv.amount;

    batch.set(_db.collection('investments').doc(oldInv.investmentId), newInv.toMap());

    if (diff != 0) {
      batch.set(
        _db.collection('treasury').doc('main'),
        {
          'currentBalance': FieldValue.increment(diff),
          'totalInvestmentsReceived': FieldValue.increment(diff),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Elimina una inversión y todos sus pagos asociados, revirtiendo el impacto en tesorería de forma atómica.
  Future<void> deleteInvestment(String investmentId, double amount) async {
    final batch = _db.batch();

    // 1. Eliminar documento principal de la inversión
    batch.delete(_db.collection('investments').doc(investmentId));

    // 2. Ajustar el saldo de tesorería restando el capital principal de la inversión
    batch.set(
      _db.collection('treasury').doc('main'),
      {
        'currentBalance': FieldValue.increment(-amount),
        'totalInvestmentsReceived': FieldValue.increment(-amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // 3. Obtener y eliminar pagos de inversores (devolución y/o intereses) asociados
    final paymentsSnap = await _db.collection('investments').doc(investmentId).collection('investor_payments').get();
    for (var doc in paymentsSnap.docs) {
      batch.delete(doc.reference);
      final data = doc.data();
      final concept = data['concept'];
      final payAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      if (concept == 'interestPayment') {
        batch.set(
          _db.collection('treasury').doc('main'),
          {
            'currentBalance': FieldValue.increment(payAmount),
            'totalInterestPaidToInvestors': FieldValue.increment(-payAmount),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        // principalReturn
        batch.set(
          _db.collection('treasury').doc('main'),
          {
            'currentBalance': FieldValue.increment(payAmount),
            'totalReturnedToInvestors': FieldValue.increment(-payAmount),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }

    await batch.commit();
  }

  /// Registra un pago a un inversor (interés o devolución de capital) y actualiza todo atómicamente.
  Future<void> registerInvestorPaymentTransaction({
    required String investmentId,
    required InvestorPaymentModel payment,
  }) async {
    final payDocRef = _db.collection('investments').doc(investmentId).collection('investor_payments').doc();

    final newPayment = InvestorPaymentModel(
      paymentId: payDocRef.id,
      investmentId: investmentId,
      amount: payment.amount,
      concept: payment.concept,
      notes: payment.notes,
      paymentDate: payment.paymentDate,
      createdAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(payDocRef, newPayment.toMap());

    // Actualizar la inversión según el concepto
    final investmentRef = _db.collection('investments').doc(investmentId);
    if (payment.concept == InvestorPaymentConcept.interestPayment) {
      batch.update(investmentRef, {
        'totalInterestPaid': FieldValue.increment(payment.amount),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      // Actualizar tesorería: sale dinero de la caja para intereses
      batch.set(
        _db.collection('treasury').doc('main'),
        {
          'currentBalance': FieldValue.increment(-payment.amount),
          'totalInterestPaidToInvestors': FieldValue.increment(payment.amount),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } else {
      // Devolución de capital
      batch.update(investmentRef, {
        'totalPrincipalReturned': FieldValue.increment(payment.amount),
        'outstandingBalance': FieldValue.increment(-payment.amount),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      batch.set(
        _db.collection('treasury').doc('main'),
        {
          'currentBalance': FieldValue.increment(-payment.amount),
          'totalReturnedToInvestors': FieldValue.increment(payment.amount),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Elimina un pago de inversor revirtiendo los efectos financieros en la inversión y tesorería.
  Future<void> deleteInvestorPaymentTransaction({
    required String investmentId,
    required InvestorPaymentModel payment,
  }) async {
    final payDocRef = _db
        .collection('investments')
        .doc(investmentId)
        .collection('payments')
        .doc(payment.paymentId);

    final batch = _db.batch();
    batch.delete(payDocRef);

    final investmentRef = _db.collection('investments').doc(investmentId);
    if (payment.concept == InvestorPaymentConcept.interestPayment) {
      batch.update(investmentRef, {
        'totalInterestPaid': FieldValue.increment(-payment.amount),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      batch.set(
        _db.collection('treasury').doc('main'),
        {
          'currentBalance': FieldValue.increment(payment.amount),
          'totalInterestPaidToInvestors': FieldValue.increment(-payment.amount),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } else {
      batch.update(investmentRef, {
        'totalPrincipalReturned': FieldValue.increment(-payment.amount),
        'outstandingBalance': FieldValue.increment(payment.amount),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      batch.set(
        _db.collection('treasury').doc('main'),
        {
          'currentBalance': FieldValue.increment(payment.amount),
          'totalReturnedToInvestors': FieldValue.increment(-payment.amount),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Actualiza un pago de inversor revirtiendo el antiguo y aplicando el nuevo.
  Future<void> updateInvestorPaymentTransaction({
    required String investmentId,
    required InvestorPaymentModel oldPayment,
    required InvestorPaymentModel newPayment,
  }) async {
    final payDocRef = _db
        .collection('investments')
        .doc(investmentId)
        .collection('payments')
        .doc(oldPayment.paymentId);

    final batch = _db.batch();
    batch.update(payDocRef, newPayment.toMap());

    final investmentRef = _db.collection('investments').doc(investmentId);
    final treasuryRef = _db.collection('treasury').doc('main');

    // 1. Revertir oldPayment
    if (oldPayment.concept == InvestorPaymentConcept.interestPayment) {
      batch.update(investmentRef, {
        'totalInterestPaid': FieldValue.increment(-oldPayment.amount),
      });
      batch.set(
        treasuryRef,
        {
          'currentBalance': FieldValue.increment(oldPayment.amount),
          'totalInterestPaidToInvestors': FieldValue.increment(-oldPayment.amount),
        },
        SetOptions(merge: true),
      );
    } else {
      batch.update(investmentRef, {
        'totalPrincipalReturned': FieldValue.increment(-oldPayment.amount),
        'outstandingBalance': FieldValue.increment(oldPayment.amount),
      });
      batch.set(
        treasuryRef,
        {
          'currentBalance': FieldValue.increment(oldPayment.amount),
          'totalReturnedToInvestors': FieldValue.increment(-oldPayment.amount),
        },
        SetOptions(merge: true),
      );
    }

    // 2. Aplicar newPayment
    if (newPayment.concept == InvestorPaymentConcept.interestPayment) {
      batch.update(investmentRef, {
        'totalInterestPaid': FieldValue.increment(newPayment.amount),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      batch.set(
        treasuryRef,
        {
          'currentBalance': FieldValue.increment(-newPayment.amount),
          'totalInterestPaidToInvestors': FieldValue.increment(newPayment.amount),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } else {
      batch.update(investmentRef, {
        'totalPrincipalReturned': FieldValue.increment(newPayment.amount),
        'outstandingBalance': FieldValue.increment(-newPayment.amount),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      batch.set(
        treasuryRef,
        {
          'currentBalance': FieldValue.increment(-newPayment.amount),
          'totalReturnedToInvestors': FieldValue.increment(newPayment.amount),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Marca una inversión como completada (todo el capital fue devuelto).
  Future<void> completeInvestment(String investmentId) async {
    await _db.collection('investments').doc(investmentId).update({
      'status': 'completed',
      'outstandingBalance': 0.0,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Stream de todas las inversiones.
  Stream<List<InvestmentModel>> getInvestmentsStream() {
    return _db
        .collection('investments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => InvestmentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream de los pagos realizados a un inversor específico.
  Stream<List<InvestorPaymentModel>> getInvestorPaymentsStream(String investmentId) {
    return _db
        .collection('investments')
        .doc(investmentId)
        .collection('investor_payments')
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => InvestorPaymentModel.fromMap(doc.data(), doc.id, investmentId: investmentId))
            .toList());
  }

  /// Stream de todos los pagos realizados a inversores en el sistema (Collection Group).
  Stream<List<InvestorPaymentModel>> getAllInvestorPaymentsStream() {
    return _db
        .collectionGroup('investor_payments')
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => InvestorPaymentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ─── CRUD Y OPERACIONES DE BORRADO/EDICIÓN DE ADMINISTRADOR ───────────────────

  /// Elimina un cliente y todos sus créditos asociados (con sus cuotas y pagos).
  Future<void> deleteClient(String clientId) async {
    final batch = _db.batch();
    
    // 1. Obtener todos los créditos de este cliente
    final creditsSnap = await _db
        .collection(AppConstants.creditsCollection)
        .where('clientId', isEqualTo: clientId)
        .get();
        
    for (final creditDoc in creditsSnap.docs) {
      final creditId = creditDoc.id;
      final creditRef = _db.collection(AppConstants.creditsCollection).doc(creditId);
      
      // Eliminar cuotas
      final instSnap = await creditRef.collection(AppConstants.installmentsSubCollection).get();
      for (final doc in instSnap.docs) {
        batch.delete(doc.reference);
      }
      
      // Eliminar pagos
      final paySnap = await creditRef.collection(AppConstants.paymentsSubCollection).get();
      for (final doc in paySnap.docs) {
        batch.delete(doc.reference);
      }
      
      // Eliminar crédito
      batch.delete(creditRef);
    }
    
    // 2. Eliminar cliente
    final clientRef = _db.collection(AppConstants.clientsCollection).doc(clientId);
    batch.delete(clientRef);
    
    await batch.commit();
  }

  /// Elimina un crédito y todas sus cuotas y pagos de forma atómica.
  Future<void> deleteCredit(String creditId) async {
    final batch = _db.batch();
    final creditRef = _db.collection(AppConstants.creditsCollection).doc(creditId);
    
    // Eliminar cuotas
    final instSnap = await creditRef.collection(AppConstants.installmentsSubCollection).get();
    for (final doc in instSnap.docs) {
      batch.delete(doc.reference);
    }
    
    // Eliminar pagos
    final paySnap = await creditRef.collection(AppConstants.paymentsSubCollection).get();
    for (final doc in paySnap.docs) {
      batch.delete(doc.reference);
    }
    
    // Eliminar crédito
    batch.delete(creditRef);
    
    await batch.commit();
  }

  /// Actualiza campos de un crédito específico.
  Future<void> updateCreditFields(String creditId, Map<String, dynamic> data) async {
    await _db
        .collection(AppConstants.creditsCollection)
        .doc(creditId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Actualiza campos de una cuota específica.
  Future<void> updateInstallmentFields(String creditId, String installmentId, Map<String, dynamic> data) async {
    await _db
        .collection(AppConstants.creditsCollection)
        .doc(creditId)
        .collection(AppConstants.installmentsSubCollection)
        .doc(installmentId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Elimina una cuota de un crédito específico.
  Future<void> deleteInstallment(String creditId, String installmentId) async {
    await _db
        .collection(AppConstants.creditsCollection)
        .doc(creditId)
        .collection(AppConstants.installmentsSubCollection)
        .doc(installmentId)
        .delete();
  }

  /// Elimina un abono (pago) y gatilla el recálculo histórico de saldos.
  Future<void> deletePayment(String creditId, String paymentId) async {
    // 1. Eliminar de Firestore
    await _db
        .collection(AppConstants.creditsCollection)
        .doc(creditId)
        .collection(AppConstants.paymentsSubCollection)
        .doc(paymentId)
        .delete();
        
    // 2. Recalcular el historial completo del crédito para consistencia
    await recalculateCreditHistory(creditId);
  }

  /// Actualiza un abono (pago) y gatilla el recálculo histórico de saldos.
  Future<void> updatePaymentFields(String creditId, String paymentId, Map<String, dynamic> data, {bool triggerRecalculate = false}) async {
    await _db
        .collection(AppConstants.creditsCollection)
        .doc(creditId)
        .collection(AppConstants.paymentsSubCollection)
        .doc(paymentId)
        .update(data);
        
    if (triggerRecalculate) {
      await recalculateCreditHistory(creditId);
    }
  }

  /// Restablece todas las cuotas al estado original del crédito y re-aplica todos
  /// los abonos vigentes en orden cronológico.
  Future<void> recalculateCreditHistory(String creditId) async {
    debugPrint('[Recalculate] Iniciando recálculo del crédito: $creditId');
    final creditRef = _db.collection(AppConstants.creditsCollection).doc(creditId);
    final installmentsRef = creditRef.collection(AppConstants.installmentsSubCollection);
    final paymentsRef = creditRef.collection(AppConstants.paymentsSubCollection);

    // 1. Leer el crédito
    final creditDoc = await creditRef.get();
    if (!creditDoc.exists || creditDoc.data() == null) return;
    final credit = CreditModel.fromMap(creditDoc.data()!, creditDoc.id);

    final batch = _db.batch();

    // 2. Leer todas las cuotas actuales
    final instSnap = await installmentsRef.get();
    final List<InstallmentModel> dbInstallments = instSnap.docs
        .map((doc) => InstallmentModel.fromMap(doc.data(), doc.id))
        .toList();

    // Ajustar cantidad de cuotas si cambió en el crédito
    final int diff = credit.numberOfInstallments - dbInstallments.length;
    if (diff > 0) {
      for (int i = 0; i < diff; i++) {
        final newDocRef = installmentsRef.doc();
        final newNumber = dbInstallments.length + 1;
        final newInst = InstallmentModel(
          installmentId: newDocRef.id,
          installmentNumber: newNumber,
          dueDate: credit.firstInstallmentDate,
          principalPortion: 0.0,
          interestPortion: 0.0,
          scheduledAmount: 0.0,
          status: InstallmentStatus.pending,
          paidAmount: 0.0,
          remainingAmount: 0.0,
          isMoraActive: false,
          moraStartDate: credit.firstInstallmentDate,
          dailyMoraRate: credit.dailyMoraRate,
          moraBase: 0.0,
          accumulatedMora: 0.0,
          moraPaid: 0.0,
          isConsolidated: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        dbInstallments.add(newInst);
      }
    } else if (diff < 0) {
      dbInstallments.sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));
      final int excessCount = diff.abs();
      for (int i = 0; i < excessCount; i++) {
        final instToDelete = dbInstallments.removeLast();
        batch.delete(installmentsRef.doc(instToDelete.installmentId));
      }
    }

    dbInstallments.sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));

    // Generar nuevas fechas de vencimiento
    final List<DateTime> newDueDates = CommercialCalendar.generateInstallmentDates(
      firstInstallmentDate: credit.firstInstallmentDate,
      numberOfInstallments: dbInstallments.length,
      frequency: credit.paymentFrequency.name,
    );

    // Calcular porciones recalculadas
    final double stdInstallmentAmount = credit.installmentAmount;
    final double stdPrincipalPortion = dbInstallments.isNotEmpty
        ? (credit.principalAmount / dbInstallments.length).ceilToDouble()
        : 0.0;
    final double stdInterestPortion = stdInstallmentAmount - stdPrincipalPortion;

    double accumulatedPrincipal = 0.0;
    double accumulatedInterest = 0.0;

    // 3. Restablecer cada cuota a su estado original (saldo completo, sin pagos, sin mora activa)
    final List<InstallmentModel> resetInstallments = [];
    for (int i = 0; i < dbInstallments.length; i++) {
      final inst = dbInstallments[i];
      final isLast = (i == dbInstallments.length - 1);
      
      double currentPrincipal;
      double currentInterest;
      double currentScheduled;

      if (isLast) {
        currentPrincipal = (credit.principalAmount - accumulatedPrincipal).clamp(0.0, double.infinity);
        currentInterest = (credit.totalAmount - credit.principalAmount - accumulatedInterest).clamp(0.0, double.infinity);
        currentScheduled = currentPrincipal + currentInterest;
      } else {
        currentPrincipal = stdPrincipalPortion;
        currentInterest = stdInterestPortion;
        currentScheduled = stdInstallmentAmount;

        accumulatedPrincipal += currentPrincipal;
        accumulatedInterest += currentInterest;
      }

      final DateTime newDueDate = i < newDueDates.length ? newDueDates[i] : inst.dueDate;

      resetInstallments.add(InstallmentModel(
        installmentId: inst.installmentId,
        installmentNumber: inst.installmentNumber,
        dueDate: newDueDate,
        principalPortion: currentPrincipal,
        interestPortion: currentInterest,
        scheduledAmount: currentScheduled,
        status: InstallmentStatus.pending,
        paidAmount: 0.0,
        remainingAmount: currentScheduled,
        isMoraActive: false,
        moraStartDate: newDueDate,
        dailyMoraRate: credit.dailyMoraRate,
        moraBase: currentScheduled,
        accumulatedMora: 0.0,
        moraPaid: 0.0,
        isConsolidated: false,
        consolidatedIntoInstallment: null,
        consolidationDate: null,
        createdAt: inst.createdAt,
        updatedAt: credit.disbursementDate,
        isMoraExempt: inst.isMoraExempt,
      ));
    }

    // 4. Leer todos los pagos vigentes del crédito, ordenados cronológicamente
    final paymentsSnap = await paymentsRef.get();
    final List<PaymentModel> paymentsList = paymentsSnap.docs
        .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
        .toList();
    paymentsList.sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

    // 5. Re-aplicar cascada de cada pago cronológicamente en memoria
    List<InstallmentModel> currentList = resetInstallments;
    double totalPaid = 0.0;
    double totalPaidPrincipal = 0.0;
    double totalPaidInterest = 0.0;
    double totalPaidMora = 0.0;

    for (final payment in paymentsList) {
      // Proyectar mora hasta la fecha de este pago
      final installmentsWithMora = MoraEngine.updateMoraAndConsolidations(
        installments: currentList,
        dailyMoraRate: credit.dailyMoraRate,
        targetDate: payment.paymentDate,
      );

      // Aplicar el pago en cascada
      final cascadeResult = MoraEngine.applyPaymentCascade(
        currentInstallments: installmentsWithMora,
        paymentAmount: payment.amountReceived,
        paymentDate: payment.paymentDate,
      );

      currentList = cascadeResult.updatedInstallments;

      // Actualizar el documento del abono en Firestore con los nuevos breakdowns del recálculo
      final double actualApplied = payment.amountReceived - cascadeResult.remainingPayment;
      final updatedPayment = PaymentModel(
        paymentId: payment.paymentId,
        registeredByUid: payment.registeredByUid,
        paymentDate: payment.paymentDate,
        amountReceived: payment.amountReceived,
        appliedToMora: cascadeResult.totalAppliedToMora,
        appliedToInterest: cascadeResult.totalAppliedToInterest,
        appliedToPrincipal: cascadeResult.totalAppliedToPrincipal,
        affectedInstallmentNumbers: cascadeResult.affectedInstallmentNumbers,
        installmentBreakdowns: cascadeResult.installmentBreakdowns,
        paymentMethod: payment.paymentMethod,
        receiptNumber: payment.receiptNumber,
        notes: payment.notes,
        createdAt: payment.createdAt,
      );
      
      batch.set(paymentsRef.doc(payment.paymentId), updatedPayment.toMap());

      totalPaid += actualApplied;
      totalPaidPrincipal += cascadeResult.totalAppliedToPrincipal;
      totalPaidInterest += cascadeResult.totalAppliedToInterest;
      totalPaidMora += cascadeResult.totalAppliedToMora;
    }

    // Proyectar mora final hasta hoy para las cuotas restantes
    final finalInstallments = MoraEngine.updateMoraAndConsolidations(
      installments: currentList,
      dailyMoraRate: credit.dailyMoraRate,
      targetDate: DateTime.now(),
    );

    // Guardar todas las cuotas recalculadas en el batch
    for (final inst in finalInstallments) {
      final docRef = installmentsRef.doc(inst.installmentId);
      batch.set(docRef, inst.toMap());
    }

    // Actualizar el balance general del crédito
    final double outstandingBalance = (credit.totalAmount - totalPaidPrincipal - totalPaidInterest).clamp(0.0, double.infinity);
    final int paidInstallmentsCount = finalInstallments.where((i) => i.status == InstallmentStatus.paid).length;

    CreditStatus newStatus = credit.status;
    if (outstandingBalance <= 0) {
      newStatus = CreditStatus.completed;
    } else if (finalInstallments.any((i) => i.status == InstallmentStatus.overdue)) {
      newStatus = CreditStatus.defaulted;
    } else {
      newStatus = CreditStatus.active;
    }

    final double finalAccumulatedMora = finalInstallments.fold<double>(0.0, (sum, inst) => sum + inst.accumulatedMora);

    batch.update(creditRef, {
      'totalPaid': totalPaid,
      'totalPaidPrincipal': totalPaidPrincipal,
      'totalPaidInterest': totalPaidInterest,
      'totalPaidMora': totalPaidMora,
      'outstandingBalance': outstandingBalance,
      'paidInstallments': paidInstallmentsCount,
      'status': newStatus.name,
      'accumulatedMora': finalAccumulatedMora,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 6. Confirmar batch
    await batch.commit();
    debugPrint('[Recalculate] ✅ Recálculo de historial de crédito completado.');
  }

  // ─── CITAS (Agenda / Recordatorios de Visita) ───────────────────────────

  /// Crea una nueva cita en Firestore. Devuelve el ID generado.
  Future<String> createAppointment(AppointmentModel appointment) async {
    final docRef = await _db
        .collection(AppConstants.appointmentsCollection)
        .add(appointment.toMap());
    return docRef.id;
  }

  /// Actualiza el estado de completación de una cita.
  Future<void> updateAppointmentStatus(String appointmentId, bool isCompleted) async {
    await _db
        .collection(AppConstants.appointmentsCollection)
        .doc(appointmentId)
        .update({
          'isCompleted': isCompleted,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Elimina una cita de Firestore.
  Future<void> deleteAppointment(String appointmentId) async {
    await _db
        .collection(AppConstants.appointmentsCollection)
        .doc(appointmentId)
        .delete();
  }

  /// Stream de todas las citas en el sistema (para el admin).
  Stream<List<AppointmentModel>> getAllAppointmentsStream() {
    return _db
        .collection(AppConstants.appointmentsCollection)
        .orderBy('scheduledTime', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream de las citas de un cobrador específico.
  Stream<List<AppointmentModel>> getCollectorAppointmentsStream(String collectorUid) {
    return _db
        .collection(AppConstants.appointmentsCollection)
        .where('collectorUid', isEqualTo: collectorUid)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
          return list;
        });
  }

  // ─── AJUSTES MANUALES DE CAJA ────────────────────────────────────────────

  /// Registra un ajuste manual de caja y actualiza el saldo atómicamente.
  Future<String> registerCashAdjustment(CashAdjustmentModel adjustment) async {
    final docRef = _db.collection('cash_adjustments').doc();
    final newAdj = CashAdjustmentModel(
      adjustmentId: docRef.id,
      amount: adjustment.amount,
      description: adjustment.description,
      date: adjustment.date,
      createdBy: adjustment.createdBy,
      createdAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(docRef, newAdj.toMap());

    batch.set(
      _db.collection('treasury').doc('main'),
      {
        'currentBalance': FieldValue.increment(adjustment.amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    return docRef.id;
  }

  /// Stream de todos los ajustes manuales de caja, ordenados por fecha descendente.
  Stream<List<CashAdjustmentModel>> getCashAdjustmentsStream() {
    return _db
        .collection('cash_adjustments')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CashAdjustmentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Elimina un ajuste manual de caja y revierte el saldo atómicamente.
  Future<void> deleteCashAdjustment(String adjustmentId, double amount) async {
    final docRef = _db.collection('cash_adjustments').doc(adjustmentId);
    final batch = _db.batch();
    batch.delete(docRef);

    batch.set(
      _db.collection('treasury').doc('main'),
      {
        'currentBalance': FieldValue.increment(-amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}

// ─── Provider de Riverpod ─────────────────────────────────────────────────

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());
