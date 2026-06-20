import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/installment_model.dart';
import '../../core/models/credit_model.dart';
import '../../core/models/client_model.dart';
import '../../core/models/payment_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/rbac_service.dart';
import '../../core/utils/mora_engine.dart';
import '../credits/credit_list_screen.dart';

/// Clase contenedora que une una cuota con su crédito y su cliente.
class JoinedInstallment {
  final InstallmentModel installment;
  final CreditModel credit;
  final ClientModel client;

  JoinedInstallment({
    required this.installment,
    required this.credit,
    required this.client,
  });
}

/// Stream de todas las cuotas sin procesar desde Firestore.
final allInstallmentsStreamProvider = StreamProvider<List<InstallmentModel>>((ref) {
  final db = ref.read(firestoreServiceProvider);
  return db.getAllInstallmentsStream();
});

/// Proveedor principal que realiza la unión (join) en memoria de Cuota, Crédito y Cliente.
/// Filtra automáticamente los datos de acuerdo con el rol del usuario
/// (cobradores solo verán sus clientes asignados gracias a la lógica interna de los streams de créditos y clientes).
final joinedInstallmentsProvider = Provider<AsyncValue<List<JoinedInstallment>>>((ref) {
  final installmentsAsync = ref.watch(allInstallmentsStreamProvider);
  final creditsAsync = ref.watch(allCreditsStreamProvider);
  final clientsAsync = ref.watch(creditsClientsStreamProvider);

  // Si cualquiera de los streams principales está cargando, retornamos cargando.
  if (installmentsAsync.isLoading || creditsAsync.isLoading || clientsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  // Manejo de errores de cualquiera de los streams.
  if (installmentsAsync.hasError) {
    return AsyncValue.error(installmentsAsync.error!, installmentsAsync.stackTrace!);
  }
  if (creditsAsync.hasError) {
    return AsyncValue.error(creditsAsync.error!, creditsAsync.stackTrace!);
  }
  if (clientsAsync.hasError) {
    return AsyncValue.error(clientsAsync.error!, clientsAsync.stackTrace!);
  }

  final installments = installmentsAsync.value ?? [];
  final credits = creditsAsync.value ?? [];
  final clients = clientsAsync.value ?? [];

  // Mapear créditos y clientes a mapas O(1) para búsquedas eficientes
  final creditMap = {for (final c in credits) c.creditId: c};
  final clientMap = {for (final cl in clients) cl.clientId: cl};

  // Agrupar cuotas por creditId
  final Map<String, List<InstallmentModel>> installmentsByCredit = {};
  for (final inst in installments) {
    if (inst.creditId != null) {
      installmentsByCredit.putIfAbsent(inst.creditId!, () => []).add(inst);
    }
  }

  final List<JoinedInstallment> joined = [];

  for (final entry in installmentsByCredit.entries) {
    final creditId = entry.key;
    final credit = creditMap[creditId];
    if (credit == null) continue;

    final client = clientMap[credit.clientId];
    if (client == null) continue;

    // Recalcular Mora dinámicamente al momento de construir la vista
    final liveInstallments = MoraEngine.updateMoraAndConsolidations(
      installments: entry.value,
      dailyMoraRate: credit.dailyMoraRate,
      targetDate: DateTime.now(),
    );

    for (final inst in liveInstallments) {
      joined.add(JoinedInstallment(
        installment: inst,
        credit: credit,
        client: client,
      ));
    }
  }

  // Ordenar cronológicamente por fecha de vencimiento
  joined.sort((a, b) => a.installment.dueDate.compareTo(b.installment.dueDate));

  return AsyncValue.data(joined);
});

/// Stream de todos los pagos unificados (según rol, para reportes de recaudo real)
final allPaymentsProvider = StreamProvider<List<PaymentModel>>((ref) {
  final userAsync = ref.watch(currentUserModelProvider);
  final creditsAsync = ref.watch(allCreditsStreamProvider);
  final db = ref.read(firestoreServiceProvider);

  // Si está cargando la info del usuario o los créditos, esperamos
  if (userAsync.isLoading || creditsAsync.isLoading) {
    return Stream.value(<PaymentModel>[]);
  }

  final user = userAsync.value;
  final credits = creditsAsync.value ?? [];

  if (user == null) return Stream.value(<PaymentModel>[]);

  final allowedCreditIds = credits.map((c) => c.creditId).toSet();

  return db.getAllPaymentsStream().map((payments) {
    if (user.role == UserRole.admin) {
      return payments;
    } else {
      // Cobrador: filtrar para que solo pueda ver pagos de créditos que tiene permitidos
      return payments.where((p) => allowedCreditIds.contains(p.creditId)).toList();
    }
  });
});
