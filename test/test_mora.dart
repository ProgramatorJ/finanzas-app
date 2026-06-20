import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_app/core/models/installment_model.dart';
import 'package:finanzas_app/core/utils/mora_engine.dart';

void main() {
  test('Mora Engine Test', () {
    print("Starting Mora Engine Test...");

    final List<InstallmentModel> installments = [
      InstallmentModel(
        installmentId: "1",
        installmentNumber: 1,
        dueDate: DateTime.utc(2026, 2, 20),
        principalPortion: 50000.0,
        interestPortion: 25000.0,
        scheduledAmount: 75000.0,
        status: InstallmentStatus.pending,
        paidAmount: 0.0,
        remainingAmount: 75000.0,
        isMoraActive: false,
        dailyMoraRate: 0.007,
        moraBase: 0.0,
        accumulatedMora: 0.0,
        moraPaid: 0.0,
        isConsolidated: false,
        createdAt: DateTime.utc(2026, 5, 24, 18, 9, 10),
        updatedAt: DateTime.utc(2026, 5, 24, 18, 9, 10),
      ),
      InstallmentModel(
        installmentId: "2",
        installmentNumber: 2,
        dueDate: DateTime.utc(2026, 3, 5),
        principalPortion: 50000.0,
        interestPortion: 25000.0,
        scheduledAmount: 75000.0,
        status: InstallmentStatus.pending,
        paidAmount: 0.0,
        remainingAmount: 75000.0,
        isMoraActive: false,
        dailyMoraRate: 0.007,
        moraBase: 0.0,
        accumulatedMora: 0.0,
        moraPaid: 0.0,
        isConsolidated: false,
        createdAt: DateTime.utc(2026, 5, 24, 18, 9, 10),
        updatedAt: DateTime.utc(2026, 5, 24, 18, 9, 10),
      ),
    ];

    try {
      print("Running updateMoraAndConsolidations...");
      final result = MoraEngine.updateMoraAndConsolidations(
        installments: installments,
        dailyMoraRate: 0.007,
        targetDate: DateTime.utc(2026, 5, 24, 18, 14, 51),
      );
      
      print("Success! Result length: ${result.length}");
      for (var inst in result) {
        print("Cuota ${inst.installmentNumber}: status=${inst.status.name}, remaining=${inst.remainingAmount}, accumulatedMora=${inst.accumulatedMora}, updatedAt=${inst.updatedAt}");
      }
    } catch (e, stack) {
      print("Error during updateMoraAndConsolidations: $e");
      print(stack);
      fail("MoraEngine failed with exception: $e");
    }
  });
}
