import 'package:finanzas_app/core/repositories/payments_repository.dart';
import 'package:finanzas_app/core/repositories/credits_repository.dart';
import 'package:finanzas_app/core/enums/user_role.dart';
import 'package:finanzas_app/core/enums/payment_frequency.dart';
import 'package:finanzas_app/core/enums/credit_status.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/credit_model.dart';
import '../../core/models/installment_model.dart';
import '../../core/models/payment_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/rbac_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/mora_engine.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/responsive_sidebar_scaffold.dart';
import '../payments/payment_form_screen.dart';
import '../clients/client_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';

// Stream de las cuotas del crédito
final installmentsProvider = StreamProvider.family<List<InstallmentModel>, String>((ref, creditId) {
  return ref.read(creditsRepositoryProvider).getInstallmentsStream(creditId);
});

// Stream de los pagos del crédito
final paymentsProvider = StreamProvider.family<List<PaymentModel>, String>((ref, creditId) {
  return ref.read(paymentsRepositoryProvider).getPaymentsStream(creditId);
});

class CreditDetailScreen extends ConsumerWidget {
  final String creditId;
  final String clientId;

  const CreditDetailScreen({
    super.key,
    required this.creditId,
    required this.clientId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installmentsAsync = ref.watch(installmentsProvider(creditId));
    final paymentsAsync = ref.watch(paymentsProvider(creditId));
    final clientAsync = ref.watch(clientProvider(clientId));
    final userModelAsync = ref.watch(currentUserModelProvider);
    final isAdmin = userModelAsync.maybeWhen(
      data: (user) => user?.role == UserRole.admin,
      orElse: () => false,
    );
    
    // Obtenemos el stream de créditos del cliente para buscar este crédito específico
    final clientCreditsAsync = ref.watch(creditsRepositoryProvider).getClientCreditsStream(clientId);
    final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget _summaryCol(String label, String value, {Color? color}) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final secondaryColor = isDark ? const Color(0xFFA5A5B5) : Colors.black54;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: secondaryColor, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color ?? (isDark ? Colors.white : Colors.black87),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    Widget _paymentBreakdownRow(String label, String value, {Color? color}) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final secondaryColor = isDark ? const Color(0xFFA5A5B5) : Colors.black54;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: secondaryColor, fontSize: 12)),
            Text(value, style: TextStyle(color: color ?? (isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      );
    }

    Color _installmentStatusColor(InstallmentStatus status, bool isOverdue) {
      if (isOverdue) return AppTheme.errorColor;
      switch (status) {
        case InstallmentStatus.pending:
          return Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA5A5B5) : Colors.black54;
        case InstallmentStatus.partial:
          return const Color(0xFFF59E0B);
        case InstallmentStatus.paid:
          return const Color(0xFF10B981);
        case InstallmentStatus.overdue:
          return AppTheme.errorColor;
        case InstallmentStatus.consolidated:
          return Colors.purpleAccent;
      }
    }

    return StreamBuilder<List<CreditModel>>(
      stream: clientCreditsAsync,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle de Crédito')),
            body: Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error al cargar créditos: ${snapshot.error}', style: const TextStyle(color: Colors.red)))),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle de Crédito')),
            body: const Center(child: Text('El crédito no existe o fue eliminado.')),
          );
        }

        final credits = snapshot.data!;
        final credit = credits.firstWhere((c) => c.creditId == creditId, orElse: () => credits.first);

        // Calcular la mora diaria de referencia por cuota (sobre el monto programado original)
        final double refDailyMoraPerInstallment = credit.installmentAmount * credit.dailyMoraRate;



        return ResponsiveSidebarScaffold(
          selectedIndex: 2, // Créditos
          title: 'Detalle de Crédito',
          isDetailScreen: true,
          child: DefaultTabController(
          length: 2,
          child: Scaffold(
          appBar: AppBar(
            title: clientAsync.maybeWhen(
              data: (client) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    client?.fullName ?? 'Crédito',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'ID: ${creditId.substring(0, creditId.length > 8 ? 8 : creditId.length)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
              orElse: () => Text('Crédito: ${creditId.substring(0, creditId.length > 8 ? 8 : creditId.length)}'),
            ),
            actions: [
              if (isAdmin) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar Parámetros del Crédito',
                  onPressed: () => _showEditCreditDialog(context, ref, credit),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
                  tooltip: 'Eliminar Crédito',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => GlassmorphicContainer(
                        child: AlertDialog(
                          title: const Text('¿Eliminar Crédito?'),
                          content: const Text(
                            'Esto eliminará permanentemente este crédito, todas sus cuotas y su historial de abonos. Esta acción no se puede deshacer.'
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (confirm == true) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Eliminando crédito...'))
                        );
                      }
                      await ref.read(creditsRepositoryProvider).deleteCredit(credit.creditId);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                ),
              ],
            ],
          ),
          body: installmentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('Error al cargar cuotas: $err', style: TextStyle(color: theme.colorScheme.error)),
            ),
            data: (dbInstallments) {
              // Recalcular la mora en tiempo real para mostrar los valores vigentes al día de hoy
              final liveInstallments = MoraEngine.updateMoraAndConsolidations(
                installments: dbInstallments,
                dailyMoraRate: credit.dailyMoraRate,
                targetDate: DateTime.now(),
              );

              final double totalMoraGenerada = liveInstallments.fold<double>(0.0, (sum, inst) => sum + inst.accumulatedMora);
              final double totalGeneral = credit.totalAmount + totalMoraGenerada;

              final tabContainerGradient = isDark
                  ? LinearGradient(
                      colors: [
                        const Color(0xFF1E2433).withValues(alpha: 0.8),
                        const Color(0xFF151922).withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        const Color(0xFFF8FAFC),
                        const Color(0xFFEDF2F7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    );

              // Obtener pagos para mostrar historial por cuota
              final payments = paymentsAsync.hasValue ? paymentsAsync.value! : <PaymentModel>[];

              Color getDynamicCreditColor() {
                if (credit.outstandingBalance <= 0) {
                  return Colors.grey.shade400;
                }
                final bool hasOverdue = liveInstallments.any((inst) => inst.status == InstallmentStatus.overdue);
                if (hasOverdue) {
                  return theme.colorScheme.error;
                }
                return theme.colorScheme.primary;
              }

              // --- WIDGET LOCAL: TARJETA DE RESUMEN FINANCIERO ---
              Widget buildFinancialSummaryCard() {
                double paidFull = 0.0;
                double paidPartialFraction = 0.0;
                for (final inst in liveInstallments) {
                  if (inst.status == InstallmentStatus.paid) {
                    paidFull += 1.0;
                  } else if (inst.paidAmount > 0 && inst.scheduledAmount > 0) {
                    paidPartialFraction += inst.paidAmount / inst.scheduledAmount;
                  }
                }
                final double totalPaidInstallments = paidFull + paidPartialFraction;
                final double pendingInstallments = credit.numberOfInstallments - totalPaidInstallments;
                final double progressPct = credit.totalAmount > 0
                    ? ((credit.totalPaid / credit.totalAmount) * 100).clamp(0.0, 100.0)
                    : 0.0;

                final Color creditColor = getDynamicCreditColor();

                return Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: creditColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: creditColor.withValues(alpha: 0.06),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  clientAsync.maybeWhen(
                                    data: (client) => Text(
                                      client?.fullName ?? 'Cargando...',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    orElse: () => const SizedBox(),
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    'ID Crédito: ${credit.creditId}',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 11,
                                      fontFamily: 'Courier',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('Capital Prestado', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(copFormatter.format(credit.principalAmount),
                                      style: theme.textTheme.headlineMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Total con Intereses: ${copFormatter.format(credit.totalAmount)}',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Mora Generada: ${copFormatter.format(totalMoraGenerada)}',
                                    style: TextStyle(
                                      color: AppTheme.errorColor.withValues(alpha: 0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Total General: ${copFormatter.format(totalGeneral)}',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.95),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(),
                          ],
                        ),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _summaryCol('Tasa Interés', '${(credit.monthlyInterestRate * 100).toStringAsFixed(1)}%'),
                            _summaryCol(
                              'Tasa Mora', 
                              '${(credit.dailyMoraRate * 100).toStringAsFixed(1)}% / día',
                            ),
                            _summaryCol(
                              'Mora Diaria',
                              '${copFormatter.format(refDailyMoraPerInstallment)}/día',
                              color: theme.colorScheme.error,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _summaryCol('Frecuencia', _translateFrequency(credit.paymentFrequency)),
                            _summaryCol('Cuotas Pactadas', '${credit.numberOfInstallments}'),
                            _summaryCol('Plazo', '${credit.termInMonths} meses'),
                          ],
                        ),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _summaryCol('Desembolso', DateFormat('dd/MM/yyyy').format(credit.disbursementDate)),
                            _summaryCol('Primera Cuota', DateFormat('dd/MM/yyyy').format(credit.firstInstallmentDate)),
                            _summaryCol('Finalización', liveInstallments.isNotEmpty ? DateFormat('dd/MM/yyyy').format(liveInstallments.last.dueDate) : '-'),
                          ],
                        ),
                        const Divider(height: 32),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _summaryCol(
                                  'Cuotas Pagadas',
                                  totalPaidInstallments == totalPaidInstallments.truncateToDouble()
                                      ? '${totalPaidInstallments.toInt()} de ${credit.numberOfInstallments}'
                                      : '${totalPaidInstallments.toStringAsFixed(2)} de ${credit.numberOfInstallments}',
                                  color: theme.colorScheme.secondary,
                                ),
                                _summaryCol(
                                  'Cuotas Pendientes',
                                  pendingInstallments == pendingInstallments.truncateToDouble()
                                      ? '${pendingInstallments.clamp(0, 9999).toInt()}'
                                      : pendingInstallments.clamp(0.0, 9999.0).toStringAsFixed(2),
                                  color: pendingInstallments > 0 ? theme.colorScheme.error : theme.colorScheme.secondary,
                                ),
                                _summaryCol(
                                  'Progreso',
                                  '${progressPct.toStringAsFixed(1)}%',
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progressPct / 100.0,
                                minHeight: 6,
                                backgroundColor: theme.brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progressPct >= 100 ? theme.colorScheme.secondary : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _summaryCol('Total Pagado', copFormatter.format(credit.totalPaid), color: theme.colorScheme.secondary),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('• A Capital: ${copFormatter.format(credit.totalPaidPrincipal)}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                      Text('• A Interés: ${copFormatter.format(credit.totalPaidInterest)}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                      Text('• Capital e Interés: ${copFormatter.format(credit.totalPaidPrincipal + credit.totalPaidInterest)}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                      Text('• A Mora: ${copFormatter.format(credit.totalPaidMora)}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            _summaryCol('Saldo Pendiente', copFormatter.format(credit.outstandingBalance), color: theme.colorScheme.error),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              // --- WIDGET LOCAL: RESUMEN FINANCIERO COLAPSABLE PARA MÓVIL ---
              Widget buildMobileCollapsibleSummaryCard() {
                double paidFull = 0.0;
                double paidPartialFraction = 0.0;
                for (final inst in liveInstallments) {
                  if (inst.status == InstallmentStatus.paid) {
                    paidFull += 1.0;
                  } else if (inst.paidAmount > 0 && inst.scheduledAmount > 0) {
                    paidPartialFraction += inst.paidAmount / inst.scheduledAmount;
                  }
                }
                final double totalPaidInstallments = paidFull + paidPartialFraction;
                final double pendingInstallments = credit.numberOfInstallments - totalPaidInstallments;
                final double progressPct = credit.totalAmount > 0
                    ? ((credit.totalPaid / credit.totalAmount) * 100).clamp(0.0, 100.0)
                    : 0.0;

                final Color creditColor = getDynamicCreditColor();

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: creditColor.withValues(alpha: 0.06),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: creditColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    elevation: 0,
                    child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: clientAsync.maybeWhen(
                        data: (client) => Text(
                          client?.fullName ?? 'Crédito',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        orElse: () => Text('ID: ${credit.creditId}'),
                      ),
                      subtitle: Text(
                        'Saldo: ${copFormatter.format(credit.outstandingBalance)}',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 16),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SelectableText(
                                        'ID: ${credit.creditId}',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          fontSize: 10,
                                          fontFamily: 'Courier',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text('Capital Prestado', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(copFormatter.format(credit.principalAmount),
                                          style: theme.textTheme.headlineMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total con Intereses: ${copFormatter.format(credit.totalAmount)}',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Mora Generada: ${copFormatter.format(totalMoraGenerada)}',
                                        style: TextStyle(
                                          color: AppTheme.errorColor.withValues(alpha: 0.85),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total General: ${copFormatter.format(totalGeneral)}',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.95),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(),
                                ],
                              ),
                            const Divider(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _summaryCol('Tasa Interés', '${(credit.monthlyInterestRate * 100).toStringAsFixed(1)}%'),
                                _summaryCol(
                                  'Tasa Mora', 
                                  '${(credit.dailyMoraRate * 100).toStringAsFixed(1)}% / día',
                                ),
                                _summaryCol(
                                  'Mora Diaria',
                                  '${copFormatter.format(refDailyMoraPerInstallment)}/día',
                                  color: theme.colorScheme.error,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _summaryCol('Frecuencia', _translateFrequency(credit.paymentFrequency)),
                                _summaryCol('Cuotas Pactadas', '${credit.numberOfInstallments}'),
                                _summaryCol('Plazo', '${credit.termInMonths} meses'),
                              ],
                            ),
                            const Divider(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _summaryCol('Desembolso', DateFormat('dd/MM/yyyy').format(credit.disbursementDate)),
                                _summaryCol('Primera Cuota', DateFormat('dd/MM/yyyy').format(credit.firstInstallmentDate)),
                                _summaryCol('Finalización', liveInstallments.isNotEmpty ? DateFormat('dd/MM/yyyy').format(liveInstallments.last.dueDate) : '-'),
                              ],
                            ),
                            const Divider(height: 32),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _summaryCol(
                                      'Cuotas Pagadas',
                                      totalPaidInstallments == totalPaidInstallments.truncateToDouble()
                                          ? '${totalPaidInstallments.toInt()} de ${credit.numberOfInstallments}'
                                          : '${totalPaidInstallments.toStringAsFixed(2)} de ${credit.numberOfInstallments}',
                                      color: theme.colorScheme.secondary,
                                    ),
                                    _summaryCol(
                                      'Cuotas Pendientes',
                                      pendingInstallments == pendingInstallments.truncateToDouble()
                                          ? '${pendingInstallments.clamp(0, 9999).toInt()}'
                                          : pendingInstallments.clamp(0.0, 9999.0).toStringAsFixed(2),
                                      color: pendingInstallments > 0 ? theme.colorScheme.error : theme.colorScheme.secondary,
                                    ),
                                    _summaryCol(
                                      'Progreso',
                                      '${progressPct.toStringAsFixed(1)}%',
                                      color: theme.colorScheme.primary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progressPct / 100.0,
                                    minHeight: 6,
                                    backgroundColor: theme.brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progressPct >= 100 ? theme.colorScheme.secondary : theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _summaryCol('Total Pagado', copFormatter.format(credit.totalPaid), color: theme.colorScheme.secondary),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('• A Capital: ${copFormatter.format(credit.totalPaidPrincipal)}',
                                              style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                          Text('• A Interés: ${copFormatter.format(credit.totalPaidInterest)}',
                                              style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                          Text('• Capital e Interés: ${copFormatter.format(credit.totalPaidPrincipal + credit.totalPaidInterest)}',
                                              style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                          Text('• A Mora: ${copFormatter.format(credit.totalPaidMora)}',
                                              style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                _summaryCol('Saldo Pendiente', copFormatter.format(credit.outstandingBalance), color: theme.colorScheme.error),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

              // --- WIDGET LOCAL: LISTA DE PLAN DE PAGOS (TAB 1) ---
              Widget buildInstallmentsTab() {
                if (liveInstallments.isEmpty) {
                  return const Center(
                    child: Text('No hay cuotas generadas.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 110),
                  itemCount: liveInstallments.length,
                  itemBuilder: (context, index) {
                    final inst = liveInstallments[index];
                    final isOverdue = inst.status == InstallmentStatus.overdue || 
                                      (inst.status == InstallmentStatus.pending && inst.dueDate.isBefore(DateTime.now()));
                    final isPaid = inst.status == InstallmentStatus.paid || inst.remainingAmount <= 0;
                    final isPartial = inst.status == InstallmentStatus.partial;
                    final isDark = theme.brightness == Brightness.dark;

                    final cardBorderColor = isPaid
                        ? const Color(0xFF10B981).withValues(alpha: 0.35)
                        : isOverdue
                            ? theme.colorScheme.error.withValues(alpha: 0.45)
                            : isPartial
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                                : theme.dividerColor.withValues(alpha: 0.1);
                                
                    final cardGradient = isPaid
                        ? LinearGradient(
                            colors: [
                              const Color(0xFF10B981).withValues(alpha: isDark ? 0.06 : 0.04),
                              const Color(0xFF10B981).withValues(alpha: isDark ? 0.02 : 0.01),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : isOverdue
                            ? LinearGradient(
                                colors: [
                                  theme.colorScheme.error.withValues(alpha: isDark ? 0.12 : 0.06),
                                  theme.colorScheme.error.withValues(alpha: isDark ? 0.04 : 0.02),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : isPartial
                                ? LinearGradient(
                                    colors: [
                                      const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.09 : 0.05),
                                      const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.03 : 0.01),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : isDark
                                    ? LinearGradient(
                                        colors: [
                                          const Color(0xFF2A3247).withValues(alpha: 0.7),
                                          const Color(0xFF1B2230).withValues(alpha: 0.6),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : LinearGradient(
                                        colors: [
                                          Colors.white,
                                          const Color(0xFFF1F5F9).withValues(alpha: 0.9),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      );

                    final DateTime startForDisplay = inst.moraStartDate ?? inst.dueDate;
                    final int delayDays = DateTime.now().difference(startForDisplay).inDays.clamp(0, 9999);
                    final double currentDailyMora = inst.remainingAmount * credit.dailyMoraRate;

                    final installmentPayments = payments.where(
                      (p) => p.affectedInstallmentNumbers.contains(inst.installmentNumber)
                    ).toList();
                    installmentPayments.sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

                    final Color stateColor = isPaid
                        ? (isDark ? Colors.grey.shade600 : Colors.grey.shade500)
                        : (isOverdue
                            ? theme.colorScheme.error
                            : (isDark ? const Color(0xFF4A84E6) : const Color(0xFF2E61D8)));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: cardGradient,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: stateColor.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: stateColor.withValues(alpha: 0.06),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: stateColor.withValues(alpha: 0.15),
                                  child: Text(
                                    '${inst.installmentNumber}',
                                    style: TextStyle(
                                      color: stateColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Vence: ${DateFormat('dd / MM / yyyy').format(inst.dueDate)}',
                                        style: TextStyle(
                                          color: isOverdue ? theme.colorScheme.error : null,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // 1. Valor Base Original
                                      Text(
                                        'Valor Base: ${copFormatter.format(inst.scheduledAmount)} (Cap: ${copFormatter.format(inst.principalPortion)} | Int: ${copFormatter.format(inst.interestPortion)})',
                                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                                      ),
                                      // 2. Mora Generada Histórica
                                      if (inst.accumulatedMora > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Mora Generada: ${copFormatter.format(inst.accumulatedMora)}'
                                            '${isOverdue && inst.remainingAmount > 0 ? ' (+${copFormatter.format(currentDailyMora)}/día)' : ''}',
                                            style: const TextStyle(color: Colors.orange, fontSize: 11),
                                          ),
                                        ),
                                      // 3. Abonos Realizados
                                      if (inst.paidAmount > 0 || inst.moraPaid > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Abonado: ${copFormatter.format(inst.paidAmount + inst.moraPaid)} (A cuota: ${copFormatter.format(inst.paidAmount)} | A mora: ${copFormatter.format(inst.moraPaid)})',
                                            style: const TextStyle(color: Colors.green, fontSize: 11),
                                          ),
                                        ),
                                      // 4. Saldo Real Pendiente (Restante)
                                      if (inst.status != InstallmentStatus.paid)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Saldo Pendiente: ${copFormatter.format(inst.remainingAmount + (inst.accumulatedMora - inst.moraPaid))}'
                                            '${(inst.accumulatedMora - inst.moraPaid) > 0 ? ' (Cuota: ${copFormatter.format(inst.remainingAmount)} | Mora: ${copFormatter.format(inst.accumulatedMora - inst.moraPaid)})' : ''}',
                                            style: TextStyle(color: theme.colorScheme.error, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if ((inst.accumulatedMora - inst.moraPaid) > 0) ...[
                                      Text(
                                        '${copFormatter.format(inst.remainingAmount)} + ${copFormatter.format((inst.accumulatedMora - inst.moraPaid).clamp(0.0, double.infinity)).replaceAll('\$', '').trim()}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    Text(
                                      copFormatter.format(inst.remainingAmount + (inst.accumulatedMora - inst.moraPaid).clamp(0.0, double.infinity)),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(),
                                  ],
                                ),
                              ],
                            ),
                            if (installmentPayments.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              const Text(
                                'Abonos en esta cuota:',
                                style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              ...installmentPayments.map((pay) {
                                final breakdown = pay.installmentBreakdowns['${inst.installmentNumber}'];
                                final bkMora = breakdown?['mora'] ?? 0.0;
                                final bkInteres = breakdown?['interes'] ?? 0.0;
                                final bkCapital = breakdown?['capital'] ?? 0.0;
                                final bkTotal = bkMora + bkInteres + bkCapital;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('dd/MM/yy').format(pay.paymentDate),
                                        style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Total: ${copFormatter.format(bkTotal)} → Mora: ${copFormatter.format(bkMora)} | Int: ${copFormatter.format(bkInteres)} | Cap: ${copFormatter.format(bkCapital)}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 9),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            if (isAdmin) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        inst.isMoraExempt 
                                            ? Icons.money_off_rounded 
                                            : Icons.trending_up_rounded,
                                        size: 16,
                                        color: isPaid
                                            ? Colors.grey.shade400
                                            : (inst.isMoraExempt ? AppTheme.secondaryColor : Colors.grey),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        inst.isMoraExempt 
                                            ? 'Sin mora a partir de ${DateFormat('dd / MM / yyyy').format(inst.dueDate)}'
                                            : 'Condonar Mora',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isPaid
                                              ? Colors.grey.shade400
                                              : (inst.isMoraExempt ? AppTheme.secondaryColor : Colors.grey),
                                          fontWeight: inst.isMoraExempt ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Switch(
                                    value: inst.isMoraExempt,
                                    activeColor: AppTheme.secondaryColor,
                                    onChanged: isPaid
                                        ? null
                                        : (val) async {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(val 
                                                    ? 'Eximiendo cuota #${inst.installmentNumber} de mora...' 
                                                    : 'Reactivando mora para cuota #${inst.installmentNumber}...'),
                                                duration: const Duration(seconds: 1),
                                              ),
                                            );
                                            await ref.read(creditsRepositoryProvider).updateInstallmentFields(
                                              creditId,
                                              inst.installmentId,
                                              {'isMoraExempt': val},
                                            );
                                            await ref.read(firestoreServiceProvider).recalculateCreditHistory(creditId);
                                          },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              }

              // --- WIDGET LOCAL: LISTA DE HISTORIAL DE PAGOS (TAB 2) ---
              Widget buildPaymentsTab() {
                if (payments.isEmpty) {
                  return const Center(
                    child: Text('No hay abonos registrados para este crédito.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 110),
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    final pay = payments[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('dd / MM / yyyy (hh:mm a)').format(pay.paymentDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        copFormatter.format(pay.amountReceived),
                                        style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    if (isAdmin) ...[
                                      const SizedBox(width: 4),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                                        onSelected: (action) async {
                                          if (action == 'edit') {
                                            _showEditPaymentDialog(context, ref, creditId, pay);
                                          } else if (action == 'delete') {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => GlassmorphicContainer(
                                                child: AlertDialog(
                                                  title: const Text('¿Eliminar Abono?'),
                                                  content: const Text('Esto eliminará permanentemente este abono y recalculará automáticamente todo el historial de amortizaciones del crédito. Esta acción no se puede deshacer.'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: const Text('Cancelar'),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
                                                      onPressed: () => Navigator.pop(context, true),
                                                      child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                            if (confirm == true) {
                                              try {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Eliminando abono y recalculando historial...'))
                                                );
                                                await ref.read(paymentsRepositoryProvider).deletePayment(creditId, pay.paymentId);
                                              } catch (e) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Error al eliminar abono: $e'), backgroundColor: Colors.red)
                                                );
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_outlined, size: 18),
                                                SizedBox(width: 8),
                                                Text('Editar Abono'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.error),
                                                SizedBox(width: 8),
                                                Text('Eliminar Abono', style: TextStyle(color: theme.colorScheme.error)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            _paymentBreakdownRow('Mora amortizada (P1):', copFormatter.format(pay.appliedToMora), color: theme.colorScheme.error),
                            _paymentBreakdownRow('Interés amortizado (P2):', copFormatter.format(pay.appliedToInterest), color: theme.colorScheme.primary),
                            _paymentBreakdownRow('Capital amortizado (P3):', copFormatter.format(pay.appliedToPrincipal), color: theme.colorScheme.secondary),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  pay.paymentMethod == PaymentMethod.cash 
                                      ? Icons.money_rounded 
                                      : pay.paymentMethod == PaymentMethod.transfer 
                                          ? Icons.account_balance_rounded 
                                          : Icons.payment_rounded,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Método: ${pay.paymentMethod == PaymentMethod.cash ? "Efectivo" : pay.paymentMethod == PaymentMethod.transfer ? "Transferencia" : "Otro"}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                if (pay.receiptNumber != null) ...[
                                  const SizedBox(width: 12),
                                  const Icon(Icons.receipt_rounded, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Recibo: ${pay.receiptNumber}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ],
                            ),
                            if (pay.notes != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Notas: ${pay.notes}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              }

              // --- DETECTAR Y RENDERIZAR RESPONSIVAMENTE ---
              return isWide
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Columna Izquierda: Tarjeta Financiera
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                              child: buildFinancialSummaryCard(),
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Columna Derecha: TabBar + TabBarView
                          Expanded(
                            flex: 3,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: tabContainerGradient,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  TabBar(
                                    tabs: const [
                                      Tab(icon: Icon(Icons.format_list_bulleted_rounded, size: 20), text: 'Plan de Pagos'),
                                      Tab(icon: Icon(Icons.history_rounded, size: 20), text: 'Historial de Pagos'),
                                    ],
                                    labelColor: theme.colorScheme.primary,
                                    indicatorColor: theme.colorScheme.primary,
                                    indicatorSize: TabBarIndicatorSize.tab,
                                  ),
                                  Expanded(
                                    child: TabBarView(
                                      children: [
                                        buildInstallmentsTab(),
                                        buildPaymentsTab(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
                          SliverToBoxAdapter(
                            child: buildMobileCollapsibleSummaryCard(),
                          ),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _SliverAppBarDelegate(
                              TabBar(
                                tabs: const [
                                  Tab(icon: Icon(Icons.format_list_bulleted_rounded, size: 20), text: 'Plan de Pagos'),
                                  Tab(icon: Icon(Icons.history_rounded, size: 20), text: 'Historial de Pagos'),
                                ],
                                labelColor: theme.colorScheme.primary,
                                indicatorColor: theme.colorScheme.primary,
                                indicatorSize: TabBarIndicatorSize.tab,
                              ),
                              theme.scaffoldBackgroundColor,
                            ),
                          ),
                        ];
                      },
                      body: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: tabContainerGradient,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                            width: 1.5,
                          ),
                        ),
                        child: TabBarView(
                          children: [
                            buildInstallmentsTab(),
                            buildPaymentsTab(),
                          ],
                        ),
                      ),
                    );
            },
          ),
          floatingActionButton: credit.status != CreditStatus.completed
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentFormScreen(
                          clientId: clientId,
                          creditId: creditId,
                          dailyMoraRate: credit.dailyMoraRate,
                        ),
                      ),
                    );
                  },
                  label: const Text('Registrar Abono'),
                  icon: const Icon(Icons.payment_rounded),
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                )
              : null,
        )));
      },
    );
  }



  Color _statusColor(CreditStatus status) {
    switch (status) {
      case CreditStatus.completed:
        return Colors.grey.shade400;
      case CreditStatus.defaulted:
        return AppTheme.errorColor;
      case CreditStatus.active:
      case CreditStatus.restructured:
        return AppTheme.primaryColor;
    }
  }



  String _translateStatus(CreditStatus status) {
    switch (status) {
      case CreditStatus.active:
        return 'Activo';
      case CreditStatus.completed:
        return 'Pagado';
      case CreditStatus.defaulted:
        return 'En Mora';
      case CreditStatus.restructured:
        return 'Reestructurado';
    }
  }

  String _translateInstallmentStatus(InstallmentStatus status) {
    switch (status) {
      case InstallmentStatus.pending:
        return 'Pendiente';
      case InstallmentStatus.partial:
        return 'Parcial';
      case InstallmentStatus.paid:
        return 'Pagada';
      case InstallmentStatus.overdue:
        return 'Vencida';
      case InstallmentStatus.consolidated:
        return 'Consolidada';
    }
  }

  String _translateFrequency(PaymentFrequency freq) {
    switch (freq) {
      case PaymentFrequency.weekly:
        return 'Semanal';
      case PaymentFrequency.biweekly:
        return 'Quincenal';
      case PaymentFrequency.monthly:
        return 'Mensual';
    }
  }

  void _showEditCreditDialog(BuildContext context, WidgetRef ref, CreditModel credit) {
    final principalController = TextEditingController(text: credit.principalAmount.toStringAsFixed(0));
    final interestController = TextEditingController(text: (credit.monthlyInterestRate * 100).toStringAsFixed(1));
    final moraController = TextEditingController(text: (credit.dailyMoraRate * 100).toStringAsFixed(2));
    final termController = TextEditingController(text: credit.termInMonths.toString());
    final installmentAmountController = TextEditingController(text: credit.installmentAmount.toStringAsFixed(0));
    final notesController = TextEditingController(text: credit.notes ?? '');
    DateTime selectedFirstInstallmentDate = credit.firstInstallmentDate;
    DateTime selectedDisbursementDate = credit.disbursementDate;
    final firstInstallmentDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(credit.firstInstallmentDate),
    );
    final disbursementDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(credit.disbursementDate),
    );
    String selectedFrequency = credit.paymentFrequency.name;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
          final secondaryColor = isDark ? const Color(0xFFA5A5B5) : Colors.black54;
          return GlassmorphicContainer(
            child: AlertDialog(
              title: const Text('Editar Crédito'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── SECCIÓN: Montos ─────────────────────────────────
                  Text('Montos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: secondaryColor)),
                const SizedBox(height: 8),
                TextField(
                  controller: principalController,
                  decoration: const InputDecoration(
                    labelText: 'Capital Prestado (COP)',
                    prefixText: '\$',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: installmentAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Valor de cada Cuota (COP)',
                    prefixText: '\$',
                    helperText: 'Ingresa el valor exacto de la cuota programada',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                // ── SECCIÓN: Tasas ──────────────────────────────────
                Text('Tasas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: secondaryColor)),
                const SizedBox(height: 8),
                TextField(
                  controller: interestController,
                  decoration: const InputDecoration(
                    labelText: 'Tasa de Interés Mensual (%)',
                    suffixText: '%',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: moraController,
                  decoration: const InputDecoration(
                    labelText: 'Tasa de Mora Diaria (%)',
                    suffixText: '% / día',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 20),

                // ── SECCIÓN: Plazo y Frecuencia ─────────────────────
                Text('Plazo y Calendario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: secondaryColor)),
                const SizedBox(height: 8),
                TextField(
                  controller: termController,
                  decoration: const InputDecoration(
                    labelText: 'Plazo (meses)',
                    suffixText: 'meses',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedFrequency,
                  decoration: const InputDecoration(labelText: 'Frecuencia de Pago'),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
                    DropdownMenuItem(value: 'biweekly', child: Text('Quincenal')),
                    DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedFrequency = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedFirstInstallmentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedFirstInstallmentDate = picked;
                        firstInstallmentDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                      });
                    }
                  },
                  child: IgnorePointer(
                    child: TextField(
                      controller: firstInstallmentDateController,
                      decoration: const InputDecoration(
                        labelText: 'Fecha Primera Cuota',
                        suffixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDisbursementDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        final difference = picked.difference(selectedDisbursementDate);
                        selectedDisbursementDate = picked;
                        disbursementDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                        
                        selectedFirstInstallmentDate = selectedFirstInstallmentDate.add(difference);
                        firstInstallmentDateController.text = DateFormat('yyyy-MM-dd').format(selectedFirstInstallmentDate);
                      });
                    }
                  },
                  child: IgnorePointer(
                    child: TextField(
                      controller: disbursementDateController,
                      decoration: const InputDecoration(
                        labelText: 'Fecha de Desembolso',
                        suffixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── SECCIÓN: Notas ──────────────────────────────────
                Text('Notas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: secondaryColor)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notas / Observaciones'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final double? newPrincipal = double.tryParse(principalController.text);
                final double? newInterest = double.tryParse(interestController.text);
                final double? newMora = double.tryParse(moraController.text);
                final int? newTerm = int.tryParse(termController.text);
                final double? newInstallmentAmount = double.tryParse(installmentAmountController.text);

                if (newPrincipal == null || newInterest == null || newMora == null ||
                    newTerm == null || newInstallmentAmount == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Por favor, ingresa todos los valores correctamente.'))
                  );
                  return;
                }

                final db = ref.read(firestoreServiceProvider);
                Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Actualizando crédito...'))
                  );
                }

                // 1. Recalcular totales derivados
                final PaymentFrequency newFrequency = PaymentFrequency.fromString(selectedFrequency);
                int numberOfInstallments;
                switch (newFrequency) {
                  case PaymentFrequency.weekly:
                    numberOfInstallments = newTerm * 4;
                    break;
                  case PaymentFrequency.biweekly:
                    numberOfInstallments = newTerm * 2;
                    break;
                  case PaymentFrequency.monthly:
                    numberOfInstallments = newTerm;
                    break;
                }
                final double totalInterest = (newInstallmentAmount * numberOfInstallments) - newPrincipal;
                final double totalAmount = newPrincipal + totalInterest.clamp(0.0, double.infinity);

                // 2. Actualizar campos del crédito
                await db.updateCreditFields(credit.creditId, {
                  'principalAmount': newPrincipal,
                  'monthlyInterestRate': newInterest / 100.0,
                  'dailyMoraRate': newMora / 100.0,
                  'termInMonths': newTerm,
                  'paymentFrequency': newFrequency.name,
                  'installmentAmount': newInstallmentAmount,
                  'numberOfInstallments': numberOfInstallments,
                  'totalInterest': totalInterest.clamp(0.0, double.infinity),
                  'totalAmount': totalAmount,
                  'firstInstallmentDate': Timestamp.fromDate(selectedFirstInstallmentDate),
                  'disbursementDate': Timestamp.fromDate(selectedDisbursementDate),
                  'notes': notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                  'outstandingBalance': (totalAmount - credit.totalPaidPrincipal - credit.totalPaidInterest).clamp(0.0, double.infinity),
                });

                // 3. Actualizar tasa de mora en todas las cuotas
                final instSnap = await FirebaseFirestore.instance
                    .collection(AppConstants.creditsCollection)
                    .doc(credit.creditId)
                    .collection(AppConstants.installmentsSubCollection)
                    .get();

                final batch = FirebaseFirestore.instance.batch();
                for (final doc in instSnap.docs) {
                  batch.update(doc.reference, {
                    'dailyMoraRate': newMora / 100.0,
                  });
                }
                await batch.commit();

                // 4. Recalcular el historial completo
                await db.recalculateCreditHistory(credit.creditId);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
    },
  ),
);
}



  void _showEditPaymentDialog(BuildContext context, WidgetRef ref, String creditId, PaymentModel payment) {
    final amountController = TextEditingController(text: payment.amountReceived.toStringAsFixed(0));
    final notesController = TextEditingController(text: payment.notes ?? '');
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(payment.paymentDate));
    String selectedMethod = payment.paymentMethod.name.substring(0, 1).toUpperCase() + payment.paymentMethod.name.substring(1);
    DateTime selectedDate = payment.paymentDate;

    showDialog(
      context: context,
      builder: (context) => GlassmorphicContainer(
        child: AlertDialog(
          title: const Text('Editar Abono'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Monto del Abono (COP)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    selectedDate = picked;
                    dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                  }
                },
                child: IgnorePointer(
                  child: TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Fecha del Pago',
                      suffixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedMethod,
                decoration: const InputDecoration(labelText: 'Método de Pago'),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Efectivo')),
                  DropdownMenuItem(value: 'Transfer', child: Text('Transferencia')),
                  DropdownMenuItem(value: 'Other', child: Text('Otro')),
                ],
                onChanged: (val) {
                  if (val != null) selectedMethod = val;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notas'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final double? newAmount = double.tryParse(amountController.text);
              if (newAmount == null || newAmount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Por favor, ingresa un monto válido.'))
                );
                return;
              }

              final db = ref.read(firestoreServiceProvider);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Actualizando abono y recalculando historial...'))
              );

              PaymentMethod method;
              if (selectedMethod.toLowerCase() == 'cash' || selectedMethod.toLowerCase() == 'efectivo') {
                method = PaymentMethod.cash;
              } else if (selectedMethod.toLowerCase() == 'transfer' || selectedMethod.toLowerCase() == 'transferencia') {
                method = PaymentMethod.transfer;
              } else {
                method = PaymentMethod.other;
              }

              // Actualizar el pago e indicar que requiere recálculo
              await db.updatePaymentFields(
                creditId,
                payment.paymentId,
                {
                  'amountReceived': newAmount,
                  'paymentDate': Timestamp.fromDate(selectedDate),
                  'paymentMethod': method.name,
                  'notes': notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                },
                
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, this._color);

  final TabBar _tabBar;
  final Color _color;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _color,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

