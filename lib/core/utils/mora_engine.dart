import '../models/installment_model.dart';

class PaymentCascadeResult {
  final double remainingPayment;
  final double totalAppliedToMora;
  final double totalAppliedToInterest;
  final double totalAppliedToPrincipal;
  final List<InstallmentModel> updatedInstallments;
  final List<int> affectedInstallmentNumbers;

  /// Distribución individual por cuota afectada.
  /// Clave: número de cuota como String (ej: "1", "2").
  /// Valor: mapa con claves 'mora', 'interes', 'capital'.
  final Map<String, Map<String, double>> installmentBreakdowns;

  PaymentCascadeResult({
    required this.remainingPayment,
    required this.totalAppliedToMora,
    required this.totalAppliedToInterest,
    required this.totalAppliedToPrincipal,
    required this.updatedInstallments,
    required this.affectedInstallmentNumbers,
    required this.installmentBreakdowns,
  });
}

class MoraEngine {
  static List<InstallmentModel> updateMoraAndConsolidations({
    required List<InstallmentModel> installments,
    required double dailyMoraRate,
    required DateTime targetDate,
  }) {
    final list = installments.map((e) => _cloneInstallment(e)).toList();
    list.sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));

    final targetNormalized = DateTime(targetDate.year, targetDate.month, targetDate.day);

    for (int i = 0; i < list.length; i++) {
      final inst = list[i];
      if (inst.status == InstallmentStatus.paid || inst.remainingAmount <= 0) {
        continue;
      }

      if (inst.isMoraExempt) {
        final instDueNormalized = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
        final InstallmentStatus targetStatus = instDueNormalized.isBefore(targetNormalized)
            ? InstallmentStatus.overdue
            : (inst.paidAmount > 0 ? InstallmentStatus.partial : InstallmentStatus.pending);

        list[i] = _cloneWith(
          inst,
          accumulatedMora: inst.moraPaid,
          isMoraActive: false,
          status: targetStatus,
          moraBase: inst.remainingAmount,
        );
        continue;
      }

      final DateTime start = inst.moraStartDate ?? inst.dueDate;
      final DateTime startNormalized = DateTime(start.year, start.month, start.day);
      final instDueNormalized = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);

      double newAccMora = inst.accumulatedMora;
      bool isMoraActive = inst.isMoraActive;
      InstallmentStatus status = inst.status;
      final double base = inst.remainingAmount;

      if (targetNormalized.isAfter(instDueNormalized)) {
        status = InstallmentStatus.overdue;
        if (targetNormalized.isAfter(startNormalized)) {
          final int days = targetNormalized.difference(startNormalized).inDays;
          if (days > 0) {
            final double additionalMora = base * dailyMoraRate * days;
            newAccMora = start.isAfter(inst.dueDate)
                ? inst.moraPaid + additionalMora
                : additionalMora;
            isMoraActive = true;
          }
        }
      } else {
        status = inst.paidAmount > 0 ? InstallmentStatus.partial : InstallmentStatus.pending;
        newAccMora = inst.moraPaid;
        isMoraActive = false;
      }

      list[i] = _cloneWith(
        inst,
        moraBase: base,
        accumulatedMora: newAccMora,
        isMoraActive: isMoraActive,
        status: status,
      );
    }

    return list;
  }

  /// Aplica un abono recibido en cascada sobre las cuotas del préstamo
  static PaymentCascadeResult applyPaymentCascade({
    required List<InstallmentModel> currentInstallments,
    required double paymentAmount,
    required DateTime paymentDate,
  }) {
    // Clonar y ordenar cuotas
    final list = currentInstallments.map((e) => _cloneInstallment(e)).toList();
    list.sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));

    double remainingPayment = paymentAmount;
    double totalAppliedToMora = 0.0;
    double totalAppliedToInterest = 0.0;
    double totalAppliedToPrincipal = 0.0;
    final List<int> affectedInstallmentNumbers = [];
    final Map<String, Map<String, double>> installmentBreakdowns = {};

    final Map<int, double> appliedMoraMap = {};
    final Map<int, double> appliedInterestMap = {};
    final Map<int, double> appliedPrincipalMap = {};

    final paymentNormalized = DateTime(paymentDate.year, paymentDate.month, paymentDate.day);

    // ── PASO 1: Saldar la Mora Acumulada de TODAS las cuotas primero ──
    for (int i = 0; i < list.length; i++) {
      final inst = list[i];
      if (inst.status == InstallmentStatus.paid || inst.remainingAmount <= 0) {
        continue;
      }

      if (inst.isMoraExempt) {
        list[i] = _cloneWith(
          inst,
          accumulatedMora: inst.moraPaid,
          isMoraActive: false,
        );
        continue;
      }

      final double unpaidMora = (inst.accumulatedMora - inst.moraPaid).clamp(0.0, double.infinity);
      if (unpaidMora > 0 && remainingPayment > 0) {
        final double appliedMora = remainingPayment >= unpaidMora ? unpaidMora : remainingPayment;
        remainingPayment -= appliedMora;
        totalAppliedToMora += appliedMora;
        appliedMoraMap[inst.installmentNumber] = appliedMora;

        // Actualizar en memoria para el siguiente paso
        list[i] = _cloneWith(inst, moraPaid: inst.moraPaid + appliedMora);
      }
    }

    // ── PASO 2: Distribución Proporcional de Capital e Interés ──
    for (int i = 0; i < list.length; i++) {
      final inst = list[i];
      if (inst.status == InstallmentStatus.paid || inst.remainingAmount <= 0) {
        continue;
      }

      if (remainingPayment <= 0) break;

      final double capRatio = inst.scheduledAmount > 0 ? inst.principalPortion / inst.scheduledAmount : 0.0;
      final double intRatio = inst.scheduledAmount > 0 ? inst.interestPortion / inst.scheduledAmount : 0.0;

      final double interestPaidSoFar = inst.paidAmount * intRatio;
      final double principalPaidSoFar = inst.paidAmount * capRatio;

      final double unpaidInterest = (inst.interestPortion - interestPaidSoFar).clamp(0.0, double.infinity);
      final double unpaidPrincipal = (inst.principalPortion - principalPaidSoFar).clamp(0.0, double.infinity);

      final double totalUnpaidCapInt = unpaidInterest + unpaidPrincipal;
      if (totalUnpaidCapInt > 0) {
        double appliedInterest = 0.0;
        double appliedPrincipal = 0.0;

        if (remainingPayment >= totalUnpaidCapInt) {
          appliedInterest = unpaidInterest;
          appliedPrincipal = unpaidPrincipal;
          remainingPayment -= totalUnpaidCapInt;
        } else {
          double targetPrincipal = remainingPayment * capRatio;
          double targetInterest = remainingPayment * intRatio;

          if (targetPrincipal > unpaidPrincipal) {
            appliedPrincipal = unpaidPrincipal;
            appliedInterest = remainingPayment - unpaidPrincipal;
          } else if (targetInterest > unpaidInterest) {
            appliedInterest = unpaidInterest;
            appliedPrincipal = remainingPayment - unpaidInterest;
          } else {
            appliedPrincipal = targetPrincipal;
            appliedInterest = targetInterest;
          }
          remainingPayment = 0.0;
        }

        totalAppliedToInterest += appliedInterest;
        totalAppliedToPrincipal += appliedPrincipal;
        appliedInterestMap[inst.installmentNumber] = appliedInterest;
        appliedPrincipalMap[inst.installmentNumber] = appliedPrincipal;

        list[i] = _cloneWith(
          inst,
          paidAmount: inst.paidAmount + appliedInterest + appliedPrincipal,
          remainingAmount: inst.scheduledAmount - (inst.paidAmount + appliedInterest + appliedPrincipal),
          moraBase: inst.scheduledAmount - (inst.paidAmount + appliedInterest + appliedPrincipal),
        );
      }
    }

    // ── PASO 3: Consolidar estados, auditoría y fechas de mora ──
    for (int i = 0; i < list.length; i++) {
      final inst = list[i];
      final int num = inst.installmentNumber;
      final double appliedMora = appliedMoraMap[num] ?? 0.0;
      final double appliedInterest = appliedInterestMap[num] ?? 0.0;
      final double appliedPrincipal = appliedPrincipalMap[num] ?? 0.0;

      if (appliedMora > 0 || appliedInterest > 0 || appliedPrincipal > 0) {
        affectedInstallmentNumbers.add(num);
        installmentBreakdowns['$num'] = {
          'mora': appliedMora,
          'interes': appliedInterest,
          'capital': appliedPrincipal,
        };

        InstallmentStatus newStatus = inst.status;
        if (inst.remainingAmount <= 0 && inst.moraPaid >= inst.accumulatedMora) {
          newStatus = InstallmentStatus.paid;
        } else {
          final instDueNormalized = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);

          if (instDueNormalized.isBefore(paymentNormalized)) {
            newStatus = InstallmentStatus.overdue;
          } else {
            newStatus = InstallmentStatus.partial;
          }
        }

        final bool modifiedCapInt = (appliedInterest + appliedPrincipal) > 0;

        list[i] = _cloneWith(
          inst,
          status: newStatus,
          updatedAt: paymentDate,
          moraStartDate: modifiedCapInt ? paymentDate : inst.moraStartDate,
        );
      }
    }

    return PaymentCascadeResult(
      remainingPayment: remainingPayment,
      totalAppliedToMora: totalAppliedToMora,
      totalAppliedToInterest: totalAppliedToInterest,
      totalAppliedToPrincipal: totalAppliedToPrincipal,
      updatedInstallments: list,
      affectedInstallmentNumbers: affectedInstallmentNumbers,
      installmentBreakdowns: installmentBreakdowns,
    );
  }

  // Métodos helper para clonar sin mutar
  static InstallmentModel _cloneInstallment(InstallmentModel inst) {
    return InstallmentModel(
      installmentId: inst.installmentId,
      installmentNumber: inst.installmentNumber,
      dueDate: inst.dueDate,
      principalPortion: inst.principalPortion,
      interestPortion: inst.interestPortion,
      scheduledAmount: inst.scheduledAmount,
      status: inst.status,
      paidAmount: inst.paidAmount,
      remainingAmount: inst.remainingAmount,
      isMoraActive: inst.isMoraActive,
      moraStartDate: inst.moraStartDate,
      dailyMoraRate: inst.dailyMoraRate,
      moraBase: inst.moraBase,
      accumulatedMora: inst.accumulatedMora,
      moraPaid: inst.moraPaid,
      isConsolidated: inst.isConsolidated,
      consolidatedIntoInstallment: inst.consolidatedIntoInstallment,
      consolidationDate: inst.consolidationDate,
      createdAt: inst.createdAt,
      updatedAt: inst.updatedAt,
      alarmHour: inst.alarmHour,
      alarmMinute: inst.alarmMinute,
      isAlarmEnabled: inst.isAlarmEnabled,
      isAlarmSilent: inst.isAlarmSilent,
      isMoraExempt: inst.isMoraExempt,
    );
  }

  static InstallmentModel _cloneWith(
    InstallmentModel inst, {
    double? accumulatedMora,
    bool? isMoraActive,
    DateTime? moraStartDate,
    DateTime? updatedAt,
    InstallmentStatus? status,
    bool? isConsolidated,
    int? consolidatedIntoInstallment,
    DateTime? consolidationDate,
    double? moraBase,
    double? moraPaid,
    double? paidAmount,
    double? remainingAmount,
    int? alarmHour,
    int? alarmMinute,
    bool? isAlarmEnabled,
    bool? isAlarmSilent,
    bool? isMoraExempt,
  }) {
    return InstallmentModel(
      installmentId: inst.installmentId,
      installmentNumber: inst.installmentNumber,
      dueDate: inst.dueDate,
      principalPortion: inst.principalPortion,
      interestPortion: inst.interestPortion,
      scheduledAmount: inst.scheduledAmount,
      status: status ?? inst.status,
      paidAmount: paidAmount ?? inst.paidAmount,
      remainingAmount: remainingAmount ?? inst.remainingAmount,
      isMoraActive: isMoraActive ?? inst.isMoraActive,
      moraStartDate: moraStartDate ?? inst.moraStartDate,
      dailyMoraRate: inst.dailyMoraRate,
      moraBase: moraBase ?? inst.moraBase,
      accumulatedMora: accumulatedMora ?? inst.accumulatedMora,
      moraPaid: moraPaid ?? inst.moraPaid,
      isConsolidated: isConsolidated ?? inst.isConsolidated,
      consolidatedIntoInstallment: consolidatedIntoInstallment ?? inst.consolidatedIntoInstallment,
      consolidationDate: consolidationDate ?? inst.consolidationDate,
      createdAt: inst.createdAt,
      updatedAt: updatedAt ?? inst.updatedAt,
      alarmHour: alarmHour ?? inst.alarmHour,
      alarmMinute: alarmMinute ?? inst.alarmMinute,
      isAlarmEnabled: isAlarmEnabled ?? inst.isAlarmEnabled,
      isAlarmSilent: isAlarmSilent ?? inst.isAlarmSilent,
      isMoraExempt: isMoraExempt ?? inst.isMoraExempt,
    );
  }
}
