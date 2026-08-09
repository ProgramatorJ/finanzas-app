import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_app/core/models/installment_model.dart';
import 'package:finanzas_app/core/utils/mora_engine.dart';

void main() {
  group('MoraEngine Tests', () {
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
        dailyMoraRate: 0.01, // 1% diario para matemáticas fáciles
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

    test('updateMoraAndConsolidations aplica mora exacta por 5 días de retraso', () {
      final installments = [
        createInstallment(1, 100.0, baseDate), // Vence el 1 de Enero
      ];

      // Pago 5 días tarde (6 de Enero)
      final targetDate = baseDate.add(const Duration(days: 5));
      
      final updated = MoraEngine.updateMoraAndConsolidations(
        installments: installments,
        dailyMoraRate: 0.01,
        targetDate: targetDate,
      );

      // Base: 100, Rate: 0.01 (1%), Days: 5 => Mora esperada: 5.0
      expect(updated.first.accumulatedMora, 5.0);
      expect(updated.first.status, InstallmentStatus.overdue);
    });

    test('applyPaymentCascade lanza ArgumentError si el pago supera la deuda', () {
      final installments = [
        createInstallment(1, 100.0, baseDate),
      ];

      // No hay mora, la deuda total es 100.
      expect(
        () => MoraEngine.applyPaymentCascade(
          currentInstallments: installments,
          paymentAmount: 101.0, 
          paymentDate: baseDate,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('applyPaymentCascade distribuye correctamente pago de capital y mora', () {
      var installments = [
        createInstallment(1, 100.0, baseDate), // Vence 1 de Enero
      ];

      // 5 días tarde, mora = 5.0. Deuda total = 105.0.
      final targetDate = baseDate.add(const Duration(days: 5));
      installments = MoraEngine.updateMoraAndConsolidations(
        installments: installments,
        dailyMoraRate: 0.01,
        targetDate: targetDate,
      );

      // Abono parcial de 55.0 (debería pagar los 5.0 de mora y 50.0 a la cuota)
      final result = MoraEngine.applyPaymentCascade(
        currentInstallments: installments,
        paymentAmount: 55.0,
        paymentDate: targetDate,
      );

      expect(result.totalAppliedToMora, 5.0);
      expect(result.remainingPayment, 0.0);
      
      final updatedInst = result.updatedInstallments.first;
      expect(updatedInst.moraPaid, 5.0);
      expect(updatedInst.paidAmount, 50.0);
      expect(updatedInst.status, InstallmentStatus.overdue);
    });
  });
}
