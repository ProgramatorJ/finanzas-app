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
import '../../core/services/firestore_service.dart';

// ─── Providers de Tesorería ──────────────────────────────────────────────

/// Stream del documento principal de tesorería (resumen)
final treasuryStreamProvider = StreamProvider<TreasuryModel>((ref) {
  return ref.watch(firestoreServiceProvider).getTreasuryStream();
});

/// Stream de todos los gastos operativos
final expensesStreamProvider = StreamProvider<List<ExpenseModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getExpensesStream();
});

/// Stream de todas las inversiones
final investmentsStreamProvider = StreamProvider<List<InvestmentModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getInvestmentsStream();
});

/// Stream de todos los ajustes manuales de caja
final cashAdjustmentsStreamProvider = StreamProvider<List<CashAdjustmentModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getCashAdjustmentsStream();
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
