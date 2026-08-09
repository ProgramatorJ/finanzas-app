  Future<void> deleteInstallment(String creditId, String installmentId) async {
    await _db
        .collection(AppConstants.creditsCollection)
        .doc(creditId)
        .collection(AppConstants.installmentsSubCollection)
        .doc(installmentId)
        .delete();
  }

  Future<void> autoScanMora() async {
    debugPrint('[AutoScan] Iniciando escáner de mora...');
    try {
      final creditsSnap = await _db
          .collection(AppConstants.creditsCollection)
          .where('status', isEqualTo: CreditStatus.active.name)
          .get();

      for (final doc in creditsSnap.docs) {
        final credit = CreditModel.fromMap(doc.data(), doc.id);
        
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
          final dueDate = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
          final today = DateTime(now.year, now.month, now.day);
          if (today.isAfter(dueDate)) {
            needsRecalculation = true;
            break;
          }
        }

        if (needsRecalculation) {
          debugPrint('[AutoScan] Crédito ${credit.creditId} necesita recálculo de mora.');
          await recalculateCreditHistory(credit.creditId);
        }
      }
      debugPrint('[AutoScan] OK Escáner de mora finalizado.');
    } catch (e) {
      debugPrint('[AutoScan] Error al escanear mora: $e');
    }
  }

  Future<void> recalculateCreditHistory(String creditId) async {
    debugPrint('[Recalculate] Iniciando recálculo del crédito: $creditId');
    try {
      final creditRef = _db.collection(AppConstants.creditsCollection).doc(creditId);
      final installmentsRef = creditRef.collection(AppConstants.installmentsSubCollection);
      final paymentsRef = creditRef.collection(AppConstants.paymentsSubCollection);

      final creditDoc = await creditRef.get();
      if (!creditDoc.exists || creditDoc.data() == null) return;
      final credit = CreditModel.fromMap(creditDoc.data()!, creditDoc.id);

      final instSnap = await installmentsRef.orderBy('installmentNumber').get();
      final installments = instSnap.docs.map((d) => InstallmentModel.fromMap(d.data(), d.id, creditId: creditId)).toList();

      final paySnap = await paymentsRef.orderBy('paymentDate').get();
      final payments = paySnap.docs.map((d) => PaymentModel.fromMap(d.data(), d.id, creditId: creditId)).toList();

      final engine = MoraEngine(
        installments: installments,
        payments: payments,
        creditTotalAmount: credit.totalAmount,
        creditInterestRate: credit.interestRate,
        creditDisbursementDate: credit.disbursementDate,
      );

      final recalculationResult = engine.recalculateAll();
      final finalInstallments = recalculationResult['installments'] as List<InstallmentModel>;
      final finalPayments = recalculationResult['payments'] as List<PaymentModel>;

      final batch = _db.batch();

      for (var inst in finalInstallments) {
        batch.update(installmentsRef.doc(inst.installmentId), inst.toMap());
      }
      for (var pay in finalPayments) {
        batch.update(paymentsRef.doc(pay.paymentId), pay.toMap());
      }

      double totalPaidPrincipal = 0.0;
      double totalPaidInterest = 0.0;
      double totalPaidMora = 0.0;
      double totalPaid = 0.0;

      for (var p in finalPayments) {
        totalPaidPrincipal += p.principalAmount;
        totalPaidInterest += p.interestAmount;
        totalPaidMora += p.moraAmount;
        totalPaid += p.amountReceived;
      }

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

      await batch.commit();
      debugPrint('[Recalculate] Finalizado exitosamente.');
    } catch (e) {
      debugPrint('[Recalculate] Error: $e');
    }
  }
