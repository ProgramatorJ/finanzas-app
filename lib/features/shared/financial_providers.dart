import 'package:finanzas_app/core/repositories/treasury_repository.dart';
/// ═══════════════════════════════════════════════════════════════════════════
/// financial_providers.dart
/// ═══════════════════════════════════════════════════════════════════════════
/// Fuente centralizada de todos los providers financieros.
/// Tanto la pestaña Tesorería como Informes importan este archivo,
/// eliminando duplicación y garantizando consistencia de datos.
/// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/treasury_model.dart';
import '../../core/models/expense_model.dart';
import '../../core/models/investment_model.dart';
import '../../core/models/investor_payment_model.dart';
import '../../core/models/cash_adjustment_model.dart';
import '../../core/models/credit_model.dart';
import '../../core/models/payment_model.dart';
import '../../core/services/firestore_service.dart';
import '../calendar/calendar_providers.dart'; // Para allPaymentsProvider
import '../credits/credit_list_screen.dart'; // Para allCreditsStreamProvider

// ─── Providers de Tesorería ──────────────────────────────────────────────

/// Stream del documento principal de tesorería (resumen)
final treasuryStreamProvider = StreamProvider<TreasuryModel>((ref) {
  return ref.watch(treasuryRepositoryProvider).getTreasuryStream();
});

/// Stream de todos los gastos operativos
final expensesStreamProvider = StreamProvider<List<ExpenseModel>>((ref) {
  return ref.watch(treasuryRepositoryProvider).getExpensesStream();
});

/// Stream de todas las inversiones
final investmentsStreamProvider = StreamProvider<List<InvestmentModel>>((ref) {
  return ref.watch(treasuryRepositoryProvider).getInvestmentsStream();
});

/// Stream de todos los ajustes manuales de caja
final cashAdjustmentsStreamProvider = StreamProvider<List<CashAdjustmentModel>>((ref) {
  return ref.watch(treasuryRepositoryProvider).getCashAdjustmentsStream();
});

/// Stream consolidado de TODOS los pagos a inversores.
/// Escucha la sub-colección de cada inversión y emite una lista fusionada.
final allInvestorPaymentsStreamProvider = StreamProvider<List<InvestorPaymentModel>>((ref) {
  final investmentsAsync = ref.watch(investmentsStreamProvider);
  return investmentsAsync.maybeWhen(
    data: (investments) {
      if (investments.isEmpty) {
        return Stream.value(<InvestorPaymentModel>[]);
      }

      final controller = StreamController<List<InvestorPaymentModel>>();
      final Map<String, List<InvestorPaymentModel>> paymentsByInvestment = {};
      final List<StreamSubscription> subscriptions = [];

      void emitMerged() {
        final allPayments = paymentsByInvestment.values.expand((x) => x).toList();
        allPayments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
        if (!controller.isClosed) {
          controller.add(allPayments);
        }
      }

      for (var inv in investments) {
        final sub = ref.read(firestoreServiceProvider)
            .getInvestorPaymentsStream(inv.investmentId)
            .listen((payments) {
          paymentsByInvestment[inv.investmentId] = payments;
          emitMerged();
        }, onError: (e) {
          debugPrint('Error loading payments for ${inv.investmentId}: $e');
        });
        subscriptions.add(sub);
      }

      ref.onDispose(() {
        for (var sub in subscriptions) {
          sub.cancel();
        }
        controller.close();
      });

      return controller.stream;
    },
    orElse: () => Stream.value(<InvestorPaymentModel>[]),
  );
});

// ─── Calculador Central Financiero (SSOT) ──────────────────────────────────

// ─── Calculador Central Financiero (SSOT) ──────────────────────────────────

class FinancialMetrics {
  final double cajaActual;
  final double carteraActivaCapital;
  final double interesesPorCobrar;
  final double moraAcumulada;
  final double deudaInversores;
  final double patrimonioNeto;
  final double utilidadNeta;

  FinancialMetrics({
    required this.cajaActual,
    required this.carteraActivaCapital,
    required this.interesesPorCobrar,
    required this.moraAcumulada,
    required this.deudaInversores,
    required this.patrimonioNeto,
    required this.utilidadNeta,
  });

  factory FinancialMetrics.calculate({
    required List<CreditModel> credits,
    required List<PaymentModel> payments,
    required List<ExpenseModel> expenses,
    required List<InvestmentModel> investments,
    required List<InvestorPaymentModel> investorPayments,
    required List<CashAdjustmentModel> adjustments,
    DateTime? dateLimit,
  }) {
    final DateTime cutoffDate = DateTime(2026, 7, 1);

    // 1. Calcular Caja Actual (con restricción cutoff 01/07/2026 y dateLimit)
    double recSubs = 0;
    for (var p in payments) {
      if (!p.paymentDate.isBefore(cutoffDate)) {
        if (dateLimit == null || p.paymentDate.isBefore(dateLimit) || p.paymentDate.isAtSameMomentAs(dateLimit)) {
          recSubs += p.amountReceived;
        }
      }
    }

    double invSubs = 0;
    for (var inv in investments) {
      if (!inv.createdAt.isBefore(cutoffDate)) {
        if (dateLimit == null || inv.createdAt.isBefore(dateLimit) || inv.createdAt.isAtSameMomentAs(dateLimit)) {
          invSubs += inv.amount;
        }
      }
    }

    double credSubs = 0;
    for (var c in credits) {
      if (!c.disbursementDate.isBefore(cutoffDate)) {
        if (dateLimit == null || c.disbursementDate.isBefore(dateLimit) || c.disbursementDate.isAtSameMomentAs(dateLimit)) {
          credSubs += c.principalAmount;
        }
      }
    }

    double expSubs = 0;
    for (var e in expenses) {
      if (!e.date.isBefore(cutoffDate)) {
        if (dateLimit == null || e.date.isBefore(dateLimit) || e.date.isAtSameMomentAs(dateLimit)) {
          expSubs += e.amount;
        }
      }
    }

    double ipSubs = 0;
    for (var ip in investorPayments) {
      if (!ip.paymentDate.isBefore(cutoffDate)) {
        if (dateLimit == null || ip.paymentDate.isBefore(dateLimit) || ip.paymentDate.isAtSameMomentAs(dateLimit)) {
          ipSubs += ip.amount;
        }
      }
    }

    double adjSubs = 0;
    for (var adj in adjustments) {
      if (!adj.date.isBefore(cutoffDate)) {
        if (dateLimit == null || adj.date.isBefore(dateLimit) || adj.date.isAtSameMomentAs(dateLimit)) {
          adjSubs += adj.amount;
        }
      }
    }

    final double cajaActual = recSubs + invSubs - credSubs - expSubs - ipSubs + adjSubs;

    // 2. Calcular Cartera Activa de Capital, Intereses por Cobrar y Mora Acumulada (Sin restricción de fecha)
    double carteraActivaCapital = 0;
    double interesesPorCobrar = 0;
    double moraAcumulada = 0;

    for (var c in credits) {
      if (dateLimit != null && c.disbursementDate.isAfter(dateLimit)) {
        continue;
      }

      double capitalPaid = 0;
      double interestPaid = 0;
      double moraPaid = 0;
      double totalMoraPaidAllTime = 0;

      for (var p in payments) {
        if (p.creditId == c.creditId) {
          totalMoraPaidAllTime += p.appliedToMora;
          if (dateLimit == null || p.paymentDate.isBefore(dateLimit) || p.paymentDate.isAtSameMomentAs(dateLimit)) {
            capitalPaid += p.appliedToPrincipal;
            interestPaid += p.appliedToInterest;
            moraPaid += p.appliedToMora;
          }
        }
      }

      if (capitalPaid < c.principalAmount) {
        carteraActivaCapital += (c.principalAmount - capitalPaid).clamp(0.0, double.infinity);
        interesesPorCobrar += (c.totalInterest - interestPaid).clamp(0.0, double.infinity);
        double moraRem = (c.accumulatedMora - totalMoraPaidAllTime + moraPaid).clamp(0.0, double.infinity);
        moraAcumulada += moraRem;
      }
    }

    // 3. Deuda con Inversores (Pasivos) - Sin restricción de fecha
    double deudaInversores = 0;
    for (var inv in investments) {
      if (dateLimit != null && inv.createdAt.isAfter(dateLimit)) {
        continue;
      }
      double returned = 0;
      for (var ip in investorPayments) {
        if (ip.investmentId == inv.investmentId && ip.concept == InvestorPaymentConcept.principalReturn) {
          if (dateLimit == null || ip.paymentDate.isBefore(dateLimit) || ip.paymentDate.isAtSameMomentAs(dateLimit)) {
            returned += ip.amount;
          }
        }
      }
      double outstanding = inv.amount - returned;
      if (outstanding > 0) {
        deudaInversores += outstanding;
      }
    }

    // 4. Calcular Patrimonio Neto
    final double totalActivos = cajaActual + carteraActivaCapital + interesesPorCobrar + moraAcumulada;
    final double patrimonioNeto = totalActivos - deudaInversores;

    // 5. Calcular Utilidad Neta (Desde Julio 2026+)
    double totalIntereses = 0;
    double totalMora = 0;
    for (var p in payments) {
      if (!p.paymentDate.isBefore(cutoffDate)) {
        if (dateLimit == null || p.paymentDate.isBefore(dateLimit) || p.paymentDate.isAtSameMomentAs(dateLimit)) {
          totalIntereses += p.appliedToInterest;
          totalMora += p.appliedToMora;
        }
      }
    }

    double totalExpenses = 0;
    for (var e in expenses) {
      if (!e.date.isBefore(cutoffDate)) {
        if (dateLimit == null || e.date.isBefore(dateLimit) || e.date.isAtSameMomentAs(dateLimit)) {
          totalExpenses += e.amount;
        }
      }
    }

    double totalInterestPaidToInvestors = 0;
    for (var ip in investorPayments) {
      if (ip.concept != InvestorPaymentConcept.principalReturn) {
        if (!ip.paymentDate.isBefore(cutoffDate)) {
          if (dateLimit == null || ip.paymentDate.isBefore(dateLimit) || ip.paymentDate.isAtSameMomentAs(dateLimit)) {
            totalInterestPaidToInvestors += ip.amount;
          }
        }
      }
    }

    final double utilidadNeta = (totalIntereses + totalMora) - totalExpenses - totalInterestPaidToInvestors;

    return FinancialMetrics(
      cajaActual: cajaActual,
      carteraActivaCapital: carteraActivaCapital,
      interesesPorCobrar: interesesPorCobrar,
      moraAcumulada: moraAcumulada,
      deudaInversores: deudaInversores,
      patrimonioNeto: patrimonioNeto,
      utilidadNeta: utilidadNeta,
    );
  }
}

/// Provider central que realiza los cálculos financieros unificados.
final financialMetricsProvider = Provider<AsyncValue<FinancialMetrics>>((ref) {
  final creditsAsync = ref.watch(allCreditsStreamProvider);
  final paymentsAsync = ref.watch(allPaymentsProvider);
  final expensesAsync = ref.watch(expensesStreamProvider);
  final investmentsAsync = ref.watch(investmentsStreamProvider);
  final investorPaymentsAsync = ref.watch(allInvestorPaymentsStreamProvider);
  final adjustmentsAsync = ref.watch(cashAdjustmentsStreamProvider);

  if (creditsAsync.isLoading ||
      paymentsAsync.isLoading ||
      expensesAsync.isLoading ||
      investmentsAsync.isLoading ||
      investorPaymentsAsync.isLoading ||
      adjustmentsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (creditsAsync.hasError ||
      paymentsAsync.hasError ||
      expensesAsync.hasError ||
      investmentsAsync.hasError ||
      investorPaymentsAsync.hasError ||
      adjustmentsAsync.hasError) {
    return AsyncValue.error(
      'Error centralizando datos financieros',
      StackTrace.current,
    );
  }

  final credits = creditsAsync.value ?? [];
  final payments = paymentsAsync.value ?? [];
  final expenses = expensesAsync.value ?? [];
  final investments = investmentsAsync.value ?? [];
  final investorPayments = investorPaymentsAsync.value ?? [];
  final adjustments = adjustmentsAsync.value ?? [];

  return AsyncValue.data(
    FinancialMetrics.calculate(
      credits: credits,
      payments: payments,
      expenses: expenses,
      investments: investments,
      investorPayments: investorPayments,
      adjustments: adjustments,
    ),
  );
});
