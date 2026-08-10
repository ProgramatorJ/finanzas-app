import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_app/core/models/installment_model.dart';
import 'package:finanzas_app/core/utils/mora_engine.dart';

void main() {
  final DateTime baseDate = DateTime(2026, 1, 1);
  InstallmentModel createInstallment(int id, double amount, DateTime due) {
    return InstallmentModel(
      installmentId: id.toString(),
      installmentNumber: id,
      dueDate: due,
      principalPortion: amount * 0.8,
      interestPortion: amount * 0.2,
      scheduledAmount: amount,
      status: InstallmentStatus.pending,
      paidAmount: 0,
      remainingAmount: amount,
      isMoraActive: false,
      dailyMoraRate: 0.01,
      moraBase: amount,
      accumulatedMora: 0,
      moraPaid: 0,
      isConsolidated: false,
      createdAt: baseDate,
      updatedAt: baseDate,
      alarmHour: 8,
      alarmMinute: 0,
      isAlarmEnabled: false,
      isAlarmSilent: false,
      isMoraExempt: false,
    );
  }

  test('MoraEngine double counting bug reproduction', () {
    var installments = [
      createInstallment(1, 100.0, baseDate), // Due Jan 1
    ];

    // Day 9: update mora
    final targetDate1 = baseDate.add(const Duration(days: 9)); // Jan 10
    installments = MoraEngine.updateMoraAndConsolidations(
      installments: installments,
      dailyMoraRate: 0.01,
      targetDate: targetDate1,
    );
    expect(installments.first.accumulatedMora, 9.0);

    // Apply 0 payment at Day 9 (to simulate a payment on another installment that didn't reach this one)
    final cascadeResult = MoraEngine.applyPaymentCascade(
      currentInstallments: installments,
      paymentAmount: 0.0,
      paymentDate: targetDate1,
    );
    installments = cascadeResult.updatedInstallments;

    // Day 14: update mora again
    final targetDate2 = baseDate.add(const Duration(days: 14)); // Jan 15
    installments = MoraEngine.updateMoraAndConsolidations(
      installments: installments,
      dailyMoraRate: 0.01,
      targetDate: targetDate2,
    );
    
    // Expected mora for 14 days is 14.0. But due to double counting, it will be 9 + 14 = 23!
    print("Accumulated Mora is: ${installments.first.accumulatedMora}");
    expect(installments.first.accumulatedMora, 14.0, reason: "Should be exactly 14 days of mora");
  });
}
