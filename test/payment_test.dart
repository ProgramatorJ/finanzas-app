import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_app/core/models/installment_model.dart';
import 'package:finanzas_app/core/utils/mora_engine.dart';

void main() {
  group('Pruebas del Motor de Mora y Consolidación (Días Reales)', () {
    test('Cálculo de mora simple (1 cuota vencida, sin consolidación)', () {
      final dueDate = DateTime(2026, 5, 1);
      final targetDate = DateTime(2026, 5, 11); // 10 días de retraso real

      final installments = [
        InstallmentModel(
          installmentId: 'inst1',
          installmentNumber: 1,
          dueDate: dueDate,
          principalPortion: 90000.0,
          interestPortion: 10000.0,
          scheduledAmount: 100000.0,
          status: InstallmentStatus.pending,
          paidAmount: 0.0,
          remainingAmount: 100000.0,
          isMoraActive: false,
          moraStartDate: null,
          dailyMoraRate: 0.007,
          moraBase: 100000.0,
          accumulatedMora: 0.0,
          moraPaid: 0.0,
          isConsolidated: false,
          consolidatedIntoInstallment: null,
          consolidationDate: null,
          createdAt: dueDate.subtract(const Duration(days: 30)),
          updatedAt: dueDate.subtract(const Duration(days: 30)), // updatedAt inicial
        )
      ];

      final updated = MoraEngine.updateMoraAndConsolidations(
        installments: installments,
        dailyMoraRate: 0.007,
        targetDate: targetDate,
      );

      expect(updated.length, 1);
      final inst = updated.first;

      // 10 días de diferencia real (5/1 a 5/11)
      // mora = 100,000 * 0.007 * 10 = 7,000
      expect(inst.accumulatedMora, closeTo(7000.0, 0.01));
      expect(inst.isMoraActive, true);
      expect(inst.status, InstallmentStatus.overdue);
    });

    test('Cálculo de mora individual independiente (2 cuotas vencidas, sin consolidación)', () {
      final dueDate1 = DateTime(2026, 5, 1);
      final dueDate2 = DateTime(2026, 6, 1);
      final targetDate = DateTime(2026, 6, 5); // 35 días después de la cuota 1, 4 días después de la cuota 2

      final installments = [
        InstallmentModel(
          installmentId: 'inst1',
          installmentNumber: 1,
          dueDate: dueDate1,
          principalPortion: 180000.0,
          interestPortion: 20000.0,
          scheduledAmount: 200000.0,
          status: InstallmentStatus.pending,
          paidAmount: 0.0,
          remainingAmount: 200000.0,
          isMoraActive: false,
          dailyMoraRate: 0.007,
          moraBase: 200000.0,
          accumulatedMora: 0.0,
          moraPaid: 0.0,
          isConsolidated: false,
          createdAt: dueDate1.subtract(const Duration(days: 30)),
          updatedAt: dueDate1.subtract(const Duration(days: 30)),
        ),
        InstallmentModel(
          installmentId: 'inst2',
          installmentNumber: 2,
          dueDate: dueDate2,
          principalPortion: 180000.0,
          interestPortion: 20000.0,
          scheduledAmount: 200000.0,
          status: InstallmentStatus.pending,
          paidAmount: 0.0,
          remainingAmount: 200000.0,
          isMoraActive: false,
          dailyMoraRate: 0.007,
          moraBase: 200000.0,
          accumulatedMora: 0.0,
          moraPaid: 0.0,
          isConsolidated: false,
          createdAt: dueDate1.subtract(const Duration(days: 30)),
          updatedAt: dueDate1.subtract(const Duration(days: 30)),
        ),
      ];

      final updated = MoraEngine.updateMoraAndConsolidations(
        installments: installments,
        dailyMoraRate: 0.007,
        targetDate: targetDate,
      );

      final inst1 = updated.firstWhere((i) => i.installmentNumber == 1);
      final inst2 = updated.firstWhere((i) => i.installmentNumber == 2);

      // Verificaciones Cuota 1:
      // Debe estar vencida, NO consolidada
      expect(inst1.isConsolidated, false);
      expect(inst1.status, InstallmentStatus.overdue);
      // Mora acumulada hasta el 5 de junio (35 días de retraso)
      // 200,000 * 0.007 * 35 = 49,000
      expect(inst1.accumulatedMora, closeTo(49000.0, 0.01));

      // Verificaciones Cuota 2:
      // Debe estar vencida, NO consolidada, base de mora es la suya propia (200k)
      expect(inst2.isConsolidated, false);
      expect(inst2.moraBase, closeTo(200000.0, 0.01));
      // Mora acumulada del 1 de junio al 5 de junio (4 días de retraso)
      // 200,000 * 0.007 * 4 = 5,600
      expect(inst2.accumulatedMora, closeTo(5600.0, 0.01));
      expect(inst2.isMoraActive, true);
      expect(inst2.status, InstallmentStatus.overdue);
    });

    test('Cascada de abonos a cuotas futuras: abono fluye hacia cuotas posteriores a la fecha del pago', () {
      final dueDate1 = DateTime(2026, 5, 1);
      final dueDate2 = DateTime(2026, 5, 16);
      final paymentDate = DateTime(2026, 5, 5); // Entre la cuota 1 y la 2

      final installments = [
        InstallmentModel(
          installmentId: 'inst1',
          installmentNumber: 1,
          dueDate: dueDate1,
          principalPortion: 180000.0,
          interestPortion: 20000.0,
          scheduledAmount: 200000.0,
          status: InstallmentStatus.overdue,
          paidAmount: 0.0,
          remainingAmount: 200000.0,
          isMoraActive: true,
          moraStartDate: dueDate1,
          dailyMoraRate: 0.007,
          moraBase: 200000.0,
          accumulatedMora: 5600.0, // 4 días de retraso al 5 de mayo (200k * 0.007 * 4 = 5.6k)
          moraPaid: 0.0,
          isConsolidated: false,
          createdAt: dueDate1.subtract(const Duration(days: 30)),
          updatedAt: dueDate1,
        ),
        InstallmentModel(
          installmentId: 'inst2',
          installmentNumber: 2,
          dueDate: dueDate2,
          principalPortion: 180000.0,
          interestPortion: 20000.0,
          scheduledAmount: 200000.0,
          status: InstallmentStatus.pending,
          paidAmount: 0.0,
          remainingAmount: 200000.0,
          isMoraActive: false,
          dailyMoraRate: 0.007,
          moraBase: 0.0,
          accumulatedMora: 0.0,
          moraPaid: 0.0,
          isConsolidated: false,
          createdAt: dueDate1.subtract(const Duration(days: 30)),
          updatedAt: dueDate1.subtract(const Duration(days: 30)),
        ),
      ];

      // Pago de $300,000 el 5 de mayo
      // 1. Paga mora cuota 1 ($5,600)
      // 2. Proporcional a capital e interés de cuota 1 (se cancela completa: $180k cap, $20k int = $200k total)
      // 3. Sobran $94,400 de capital/interés sobre la cuota 1. Estos fluyen hacia la cuota 2.
      //    Se distribuye de forma proporcional en la cuota 2 (90% capital, 10% interés):
      //    - Capital cuota 2 = 94,400 * 0.9 = $84,960
      //    - Interés cuota 2 = 94,400 * 0.1 = $9,440
      final res = MoraEngine.applyPaymentCascade(
        currentInstallments: installments,
        paymentAmount: 300000.0,
        paymentDate: paymentDate,
      );

      // Verificación de montos aplicados
      expect(res.totalAppliedToMora, 5600.0);
      expect(res.totalAppliedToInterest, closeTo(20000.0 + 9440.0, 0.01)); // Se paga interés cuota 1 + parte de cuota 2
      expect(res.totalAppliedToPrincipal, closeTo(180000.0 + 84960.0, 0.01)); // Se paga capital cuota 1 + parte de cuota 2
      // El excedente fue totalmente consumido
      expect(res.remainingPayment, 0.0);

      final inst1 = res.updatedInstallments.firstWhere((i) => i.installmentNumber == 1);
      final inst2 = res.updatedInstallments.firstWhere((i) => i.installmentNumber == 2);

      // Cuota 1 debe estar pagada
      expect(inst1.status, InstallmentStatus.paid);
      expect(inst1.remainingAmount, 0.0);

      // Cuota 2 debe estar pagada parcialmente
      expect(inst2.status, InstallmentStatus.partial);
      expect(inst2.paidAmount, 94400.0);
      expect(inst2.remainingAmount, 200000.0 - 94400.0);
    });
  });

  group('Pruebas de la Cascada de Pagos', () {
    test('Distribución en cascada exacta sobre mora, interés y capital', () {
      final dueDate = DateTime(2026, 5, 1);
      final paymentDate = DateTime(2026, 5, 11);

      // Establecer cuota con mora calculada de antemano
      final installments = [
        InstallmentModel(
          installmentId: 'inst1',
          installmentNumber: 1,
          dueDate: dueDate,
          principalPortion: 180000.0,
          interestPortion: 20000.0,
          scheduledAmount: 200000.0,
          status: InstallmentStatus.overdue,
          paidAmount: 0.0,
          remainingAmount: 200000.0,
          isMoraActive: true,
          moraStartDate: dueDate.add(const Duration(days: 1)),
          dailyMoraRate: 0.007,
          moraBase: 200000.0,
          accumulatedMora: 43400.0, // Mora ya calculada de antemano
          moraPaid: 0.0,
          isConsolidated: false,
          createdAt: dueDate.subtract(const Duration(days: 30)),
          updatedAt: paymentDate,
        )
      ];

      // Caso A: Pago parcial de $50,000
      // 1. Paga toda la mora de la cuota 1 ($43,400)
      // 2. Sobran $6,600 que van a interés
      // 3. No alcanza para capital
      final resA = MoraEngine.applyPaymentCascade(
        currentInstallments: installments,
        paymentAmount: 50000.0,
        paymentDate: paymentDate,
      );

      expect(resA.totalAppliedToMora, 43400.0);
      expect(resA.totalAppliedToInterest, 660.0);
      expect(resA.totalAppliedToPrincipal, 5940.0);
      expect(resA.remainingPayment, 0.0);

      final updatedInstA = resA.updatedInstallments.first;
      expect(updatedInstA.moraPaid, 43400.0);
      expect(updatedInstA.paidAmount, 6600.0);
      expect(updatedInstA.remainingAmount, 193400.0); // 200,000 - 6,600
      expect(updatedInstA.status, InstallmentStatus.overdue); // Aún no está pagada totalmente

      // Caso B: Pago de $250,000 (excedente)
      // 1. Paga mora ($43,400)
      // 2. Paga interés ($20,000)
      // 3. Paga capital ($180,000)
      // Sobran $6,600
      final resB = MoraEngine.applyPaymentCascade(
        currentInstallments: installments,
        paymentAmount: 250000.0,
        paymentDate: paymentDate,
      );

      expect(resB.totalAppliedToMora, 43400.0);
      expect(resB.totalAppliedToInterest, 20000.0);
      expect(resB.totalAppliedToPrincipal, 180000.0);
      expect(resB.remainingPayment, 6600.0); // Devuelve el excedente
      expect(resB.updatedInstallments.first.status, InstallmentStatus.paid);
    });

    test('Simulación de Pago Histórico: Rewind y exención de mora', () {
      final dueDate1 = DateTime(2026, 2, 14);
      final dueDate2 = DateTime(2026, 3, 14);

      final installments = <InstallmentModel>[
        InstallmentModel(
          installmentId: 'inst1',
          installmentNumber: 1,
          dueDate: dueDate1,
          principalPortion: 180000.0,
          interestPortion: 20000.0,
          scheduledAmount: 200000.0,
          status: InstallmentStatus.pending,
          paidAmount: 0.0,
          remainingAmount: 200000.0,
          isMoraActive: false,
          dailyMoraRate: 0.007,
          moraBase: 200000.0,
          accumulatedMora: 0.0,
          moraPaid: 0.0,
          isConsolidated: false,
          isMoraExempt: false,
          createdAt: dueDate1.subtract(const Duration(days: 30)),
          updatedAt: dueDate1.subtract(const Duration(days: 30)),
        ),
        InstallmentModel(
          installmentId: 'inst2',
          installmentNumber: 2,
          dueDate: dueDate2,
          principalPortion: 180000.0,
          interestPortion: 20000.0,
          scheduledAmount: 200000.0,
          status: InstallmentStatus.pending,
          paidAmount: 0.0,
          remainingAmount: 200000.0,
          isMoraActive: false,
          dailyMoraRate: 0.007,
          moraBase: 200000.0,
          accumulatedMora: 0.0,
          moraPaid: 0.0,
          isConsolidated: false,
          isMoraExempt: false,
          createdAt: dueDate1.subtract(const Duration(days: 30)),
          updatedAt: dueDate1.subtract(const Duration(days: 30)),
        ),
      ];

      // Caso A: Proyección al 14 de Febrero (Fecha de vencimiento cuota 1, antes de vencimiento cuota 2)
      // No debería haber mora en ninguna de las dos cuotas
      final projectedFeb14 = MoraEngine.updateMoraAndConsolidations(
        installments: installments,
        dailyMoraRate: 0.007,
        targetDate: DateTime(2026, 2, 14),
      );

      expect(projectedFeb14[0].accumulatedMora, 0.0);
      expect(projectedFeb14[0].isMoraActive, false);
      expect(projectedFeb14[1].accumulatedMora, 0.0);
      expect(projectedFeb14[1].isMoraActive, false);

      // Caso B: Proyección al 7 de Marzo (Cuota 1 vencida por 21 días, Cuota 2 no vencida)
      // Cuota 1 debe tener mora, Cuota 2 debe tener 0 mora
      final projectedMar7 = MoraEngine.updateMoraAndConsolidations(
        installments: installments,
        dailyMoraRate: 0.007,
        targetDate: DateTime(2026, 3, 7),
      );

      // 21 días de mora: 200,000 * 0.007 * 21 = 29,400
      expect(projectedMar7[0].accumulatedMora, closeTo(29400.0, 0.01));
      expect(projectedMar7[0].isMoraActive, true);
      expect(projectedMar7[1].accumulatedMora, 0.0);
      expect(projectedMar7[1].isMoraActive, false);

      // Caso C: Cuota 1 tiene isMoraExempt = true, proyección al 7 de Marzo
      // Cuota 1 debe tener 0 mora, Cuota 2 debe tener 0 mora
      final installmentsExempt = <InstallmentModel>[
        projectedMar7[0].copyWith(isMoraExempt: true),
        projectedMar7[1],
      ];
      final projectedExempt = MoraEngine.updateMoraAndConsolidations(
        installments: installmentsExempt,
        dailyMoraRate: 0.007,
        targetDate: DateTime(2026, 3, 7),
      );

      expect(projectedExempt[0].accumulatedMora, 0.0);
      expect(projectedExempt[0].isMoraActive, false);
      expect(projectedExempt[1].accumulatedMora, 0.0);
      expect(projectedExempt[1].isMoraActive, false);
    });
  });
}
