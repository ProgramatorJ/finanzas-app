import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/payment_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/rbac_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/responsive_sidebar_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../main.dart';

/// Provider de pagos según el rol
final paymentsHistoryProvider = StreamProvider<List<PaymentModel>>((ref) {
  final userAsync = ref.watch(currentUserModelProvider);
  final db = ref.read(firestoreServiceProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      if (user.role == UserRole.admin) {
        return db.getAllPaymentsStream();
      } else {
        return db.getCollectorPaymentsStream(user.uid);
      }
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

class PaymentsHistoryScreen extends ConsumerWidget {
  const PaymentsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? const Color(0xFFA5A5B5) : Colors.black54;

    final paymentsAsync = ref.watch(paymentsHistoryProvider);
    final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    Future<void> _sharePaymentReceipt(PaymentModel pay, BuildContext context) async {
      final String intro = sharedPreferences.getString('whatsapp_intro_message') ?? 'Hola, adjunto tu recibo de pago.';
      
      final StringBuffer sb = StringBuffer();
      sb.writeln(intro);
      sb.writeln('');
      sb.writeln('🧾 *RECIBO DE PAGO*');
      sb.writeln('ID Recibo: ${pay.receiptNumber ?? pay.paymentId.substring(0, 8)}');
      sb.writeln('Fecha: ${DateFormat('dd/MM/yyyy hh:mm a').format(pay.paymentDate)}');
      sb.writeln('');
      sb.writeln('• *Monto Recibido:* ${copFormatter.format(pay.amountReceived)}');
      sb.writeln('  - A Capital: ${copFormatter.format(pay.appliedToPrincipal)}');
      sb.writeln('  - A Interés: ${copFormatter.format(pay.appliedToInterest)}');
      sb.writeln('  - A Mora: ${copFormatter.format(pay.appliedToMora)}');
      sb.writeln('');
      sb.writeln('Método: ${pay.paymentMethod == PaymentMethod.cash ? "Efectivo" : pay.paymentMethod == PaymentMethod.transfer ? "Transferencia" : "Otro"}');
      sb.writeln('Cuotas afectadas: ${pay.affectedInstallmentNumbers.join(", ")}');
      sb.writeln('');
      sb.writeln('¡Gracias por tu pago!');
      sb.writeln('Generado desde BANX App');

      final String text = Uri.encodeComponent(sb.toString());
      final Uri whatsappUrl = Uri.parse("whatsapp://send?text=$text");
      
      try {
        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl);
        } else {
          await Share.share(sb.toString(), subject: 'Recibo de Pago');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Compartiendo vía general...'))
          );
        }
        await Share.share(sb.toString(), subject: 'Recibo de Pago');
      }
    }

    Widget breakdownItem(String label, String value, Color color) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: secondaryColor, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      );
    }

    return ResponsiveSidebarScaffold(
      selectedIndex: 5,
      title: 'Historial de Abonos',
      child: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error al cargar historial: $err', style: const TextStyle(color: AppTheme.errorColor)),
        ),
        data: (payments) {
          if (payments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: secondaryColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No hay abonos registrados.',
                    style: TextStyle(color: secondaryColor, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final pay = payments[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('dd / MM / yyyy (hh:mm a)').format(pay.paymentDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cuotas afectadas: ${pay.affectedInstallmentNumbers.join(", ")}',
                                  style: TextStyle(color: secondaryColor, fontSize: 11),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.share_rounded, size: 20),
                                  color: AppTheme.primaryColor,
                                  onPressed: () => _sharePaymentReceipt(pay, context),
                                  tooltip: 'Compartir Recibo',
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    copFormatter.format(pay.amountReceived),
                                    style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            breakdownItem('Mora', copFormatter.format(pay.appliedToMora), AppTheme.errorColor),
                            breakdownItem('Interés', copFormatter.format(pay.appliedToInterest), AppTheme.warningColor),
                            breakdownItem('Capital', copFormatter.format(pay.appliedToPrincipal), AppTheme.primaryColor),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              pay.paymentMethod == PaymentMethod.cash 
                                  ? Icons.money_rounded 
                                  : pay.paymentMethod == PaymentMethod.transfer 
                                      ? Icons.account_balance_rounded 
                                      : Icons.payment_rounded,
                              size: 14,
                              color: secondaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Método: ${pay.paymentMethod == PaymentMethod.cash ? "Efectivo" : pay.paymentMethod == PaymentMethod.transfer ? "Transferencia" : "Otro"}',
                              style: TextStyle(fontSize: 11, color: secondaryColor),
                            ),
                            if (pay.receiptNumber != null) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.receipt_rounded, size: 14, color: secondaryColor),
                              const SizedBox(width: 4),
                              Text(
                                'Recibo: ${pay.receiptNumber}',
                                style: TextStyle(fontSize: 11, color: secondaryColor),
                              ),
                            ],
                          ],
                        ),
                        if (pay.notes != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Notas: ${pay.notes}',
                            style: TextStyle(fontSize: 11, color: secondaryColor, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
