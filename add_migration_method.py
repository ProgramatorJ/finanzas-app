import re

file_path = r'c:\dev\finanzas-app\lib\core\repositories\payments_repository.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

method_content = """
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
          installments: installments,
          payment: p,
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
        newStatus = CreditStatus.paid;
      } else if (installments.any((inst) => inst.status == InstallmentStatus.overdue)) {
        newStatus = CreditStatus.overdue;
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
"""

content = content.replace(
    "Future<void> deletePayment(String creditId, String paymentId) async {",
    method_content + "\n\n  Future<void> deletePayment(String creditId, String paymentId) async {"
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Added forceRebuildAndMigrateCredit")
