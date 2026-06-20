import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_app/core/utils/commercial_calendar.dart';

void main() {
  group('CommercialCalendar (Año Comercial 360)', () {
    test('addCommercialDays añade días correctamente en meses comerciales de 30 días', () {
      final start = DateTime(2026, 1, 15);
      
      // Sumar 15 días a la quincena de enero -> debería ser 30 de enero
      final target1 = CommercialCalendar.addCommercialDays(start, 15);
      expect(target1.year, 2026);
      expect(target1.month, 1);
      expect(target1.day, 30);

      // Sumar 30 días (1 mes comercial) -> debería ser 15 de febrero
      final target2 = CommercialCalendar.addCommercialDays(start, 30);
      expect(target2.year, 2026);
      expect(target2.month, 2);
      expect(target2.day, 15);
    });

    test('commercialDaysBetween calcula la diferencia de días correctamente', () {
      final from = DateTime(2026, 1, 10);
      final to = DateTime(2026, 2, 10);

      // Un mes comercial exacto = 30 días
      final days = CommercialCalendar.commercialDaysBetween(from, to);
      expect(days, 30);
    });

    test('calculateNumberOfInstallments calcula número de cuotas según frecuencia', () {
      // 3 meses plazo
      expect(CommercialCalendar.calculateNumberOfInstallments(termInMonths: 3, frequency: 'weekly'), 12);
      expect(CommercialCalendar.calculateNumberOfInstallments(termInMonths: 3, frequency: 'biweekly'), 6);
      expect(CommercialCalendar.calculateNumberOfInstallments(termInMonths: 3, frequency: 'monthly'), 3);
    });
  });

  group('Motor de Proyección y Reconciliación de Créditos', () {
    test('Cálculo de cuotas con redondeo hacia arriba (ceil) y ajuste en la última cuota', () {
      final double principal = 1000000;
      final double monthlyInterestRate = 0.10; // 10%
      final int termInMonths = 3;
      final String frequency = 'biweekly'; // Quincenal -> 6 cuotas

      final totalInterest = principal * monthlyInterestRate * termInMonths;
      final totalAmount = principal + totalInterest;

      final numInstallments = CommercialCalendar.calculateNumberOfInstallments(
        termInMonths: termInMonths,
        frequency: frequency,
      );

      expect(totalInterest, 300000);
      expect(totalAmount, 1300000);
      expect(numInstallments, 6);

      // Proyección estándar redondeando al entero superior más cercano (ceil)
      final stdInstallmentAmount = (totalAmount / numInstallments).ceilToDouble();
      final stdPrincipalPortion = (principal / numInstallments).ceilToDouble();
      final stdInterestPortion = stdInstallmentAmount - stdPrincipalPortion;

      expect(stdInstallmentAmount, 216667); // ceil(1300000 / 6) = 216667
      expect(stdPrincipalPortion, 166667);  // ceil(1000000 / 6) = 166667
      expect(stdInterestPortion, 50000);    // 216667 - 166667 = 50000

      // Reconciliación en la última cuota
      double accumulatedPrincipal = 0.0;
      double accumulatedInterest = 0.0;

      double finalPrincipal = 0.0;
      double finalInterest = 0.0;
      double finalScheduled = 0.0;

      for (int i = 0; i < numInstallments; i++) {
        final isLast = (i == numInstallments - 1);
        if (isLast) {
          finalPrincipal = principal - accumulatedPrincipal;
          finalInterest = totalInterest - accumulatedInterest;
          finalScheduled = finalPrincipal + finalInterest;
        } else {
          accumulatedPrincipal += stdPrincipalPortion;
          accumulatedInterest += stdInterestPortion;
        }
      }

      // Verificaciones de la última cuota reconciliada
      expect(finalPrincipal, 166665); // 1000000 - (166667 * 5) = 166665
      expect(finalInterest, 50000);   // 300000 - (50000 * 5) = 50000
      expect(finalScheduled, 216665); // 166665 + 50000 = 216665

      // Verificación de que la suma de todas las cuotas es exactamente el total esperado
      final double totalCalculatedPrincipal = (stdPrincipalPortion * (numInstallments - 1)) + finalPrincipal;
      final double totalCalculatedInterest = (stdInterestPortion * (numInstallments - 1)) + finalInterest;
      final double totalCalculatedAmount = (stdInstallmentAmount * (numInstallments - 1)) + finalScheduled;

      expect(totalCalculatedPrincipal, principal);
      expect(totalCalculatedInterest, totalInterest);
      expect(totalCalculatedAmount, totalAmount);
    });
  });
}
