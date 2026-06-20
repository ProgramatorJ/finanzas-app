import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/theme/app_theme.dart';
import '../calendar/calendar_providers.dart';
import '../credits/credit_detail_screen.dart';
import '../../core/models/installment_model.dart';

class AlertCenterWidget extends ConsumerWidget {
  const AlertCenterWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joinedInstallmentsAsync = ref.watch(joinedInstallmentsProvider);

    return joinedInstallmentsAsync.when(
      loading: () => IconButton(
        icon: Icon(Icons.notifications_none_rounded, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA5A5B5) : Colors.black54),
        onPressed: null,
      ),
      error: (_, __) => const IconButton(
        icon: Icon(Icons.notifications_off_rounded, color: AppTheme.errorColor),
        onPressed: null,
      ),
      data: (joinedList) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Filtrar las cuotas que representan una alerta: no pagadas, no consolidadas y con saldo pendiente
        final alerts = joinedList.where((joined) {
          final inst = joined.installment;
          final isUnpaid = inst.status != InstallmentStatus.paid && 
                           inst.status != InstallmentStatus.consolidated;
          if (!isUnpaid) return false;

          final dueMidnight = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
          final daysDiff = dueMidnight.difference(today).inDays;

          // Son alerta las cuotas vencidas (diferencia < 0), las que vencen hoy (0) y mañana (1)
          return daysDiff <= 1;
        }).toList();

        // Ordenar las alertas: primero las vencidas (mora), luego las de hoy, luego las de mañana
        alerts.sort((a, b) {
          final dueA = DateTime(a.installment.dueDate.year, a.installment.dueDate.month, a.installment.dueDate.day);
          final dueB = DateTime(b.installment.dueDate.year, b.installment.dueDate.month, b.installment.dueDate.day);
          return dueA.compareTo(dueB);
        });

        final alertCount = alerts.length;

        return Badge(
          isLabelVisible: alertCount > 0,
          label: Text(alertCount.toString()),
          backgroundColor: AppTheme.errorColor,
          textColor: Colors.white,
          offset: const Offset(-2, 2),
          child: IconButton(
            icon: Icon(
              alertCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
              color: alertCount > 0 ? AppTheme.warningColor : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
            ),
            tooltip: 'Centro de Alertas de Pago',
            onPressed: () => _showAlertsBottomSheet(context, alerts),
          ),
        );
      },
    );
  }

  void _showAlertsBottomSheet(BuildContext context, List<JoinedInstallment> alerts) {
    final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final secondaryColor = isDark ? const Color(0xFFA5A5B5) : Colors.black54;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return GlassmorphicContainer(
              isBottomSheet: true,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: secondaryColor,
                          borderRadius: const BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Alertas de Pago',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: alerts.isEmpty ? AppTheme.secondaryColor.withOpacity(0.15) : AppTheme.errorColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            alerts.isEmpty ? 'Al día' : '${alerts.length} pendientes',
                            style: TextStyle(
                              color: alerts.isEmpty ? AppTheme.secondaryColor : AppTheme.errorColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ).buildWithCorrectFormat(alerts.length),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: alerts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, size: 64, color: AppTheme.secondaryColor),
                                  const SizedBox(height: 16),
                                  Text(
                                    '¡Excelente! No hay cobros vencidos ni pendientes para hoy o mañana.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: secondaryColor, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: alerts.length,
                              itemBuilder: (context, index) {
                                final item = alerts[index];
                                final inst = item.installment;
                                final credit = item.credit;
                                final client = item.client;

                                final dueMidnight = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
                                final daysDiff = dueMidnight.difference(today).inDays;

                                String label = '';
                                Color badgeColor = Colors.grey;
                                if (daysDiff < 0) {
                                  label = 'VENCIDO (hace ${-daysDiff} ${-daysDiff == 1 ? "día" : "días"})';
                                  badgeColor = AppTheme.errorColor;
                                } else if (daysDiff == 0) {
                                  label = 'VENCE HOY';
                                  badgeColor = AppTheme.warningColor;
                                } else if (daysDiff == 1) {
                                  label = 'VENCE MAÑANA';
                                  badgeColor = AppTheme.primaryColor;
                                }

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: badgeColor.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                label,
                                                style: TextStyle(
                                                  color: badgeColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              copFormatter.format(inst.remainingAmount),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          client.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Ref: ${credit.creditId.substring(0, credit.creditId.length > 8 ? 8 : credit.creditId.length)} | Cuota #${inst.installmentNumber}',
                                              style: TextStyle(
                                                color: secondaryColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () {
                                                Navigator.pop(context); // Cerrar bottom sheet
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => CreditDetailScreen(
                                                      creditId: credit.creditId,
                                                      clientId: credit.clientId,
                                                    ),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                              label: const Text('Ver Crédito'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: AppTheme.primaryColor,
                                                padding: EdgeInsets.zero,
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Extensión simple para formatear el texto del badge de forma elegante
extension on Widget {
  Widget buildWithCorrectFormat(int length) {
    return this;
  }
}
