import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/installment_model.dart';
import '../../core/models/payment_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/rbac_service.dart';
import '../../core/utils/mora_engine.dart';
import '../../shared/theme/app_theme.dart';

final paymentInstallmentsProvider = StreamProvider.family<List<InstallmentModel>, String>((ref, creditId) {
  return ref.read(firestoreServiceProvider).getInstallmentsStream(creditId);
});

class PaymentFormScreen extends ConsumerStatefulWidget {
  final String clientId;
  final String creditId;
  final double dailyMoraRate;

  const PaymentFormScreen({
    super.key,
    required this.clientId,
    required this.creditId,
    required this.dailyMoraRate,
  });

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _receiptController = TextEditingController();

  PaymentMethod _selectedMethod = PaymentMethod.cash;
  DateTime _paymentDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _receiptController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _paymentDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserModelProvider);
    final installmentsAsync = ref.watch(paymentInstallmentsProvider(widget.creditId));

    final isAdmin = userAsync.maybeWhen(
      data: (user) => user?.role == UserRole.admin,
      orElse: () => false,
    );

    final theme = Theme.of(context);
    final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Abono'),
      ),
      body: installmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error al cargar cuotas: $err', style: TextStyle(color: theme.colorScheme.error)),
        ),
        data: (installments) {
          if (installments.isEmpty) {
            return const Center(
              child: Text('No hay cuotas asociadas a este crédito.', style: TextStyle(color: Colors.grey)),
            );
          }

          // Realizar proyección en tiempo real según el monto ingresado
          final double inputAmount = double.tryParse(_amountController.text) ?? 0.0;
          
          // 1. Proyectar mora a la fecha seleccionada
          final projectedInstallmentsWithMora = MoraEngine.updateMoraAndConsolidations(
            installments: installments,
            dailyMoraRate: widget.dailyMoraRate,
            targetDate: _paymentDate,
          );

          // 2. Aplicar cascada
          final cascadeResult = MoraEngine.applyPaymentCascade(
            currentInstallments: projectedInstallmentsWithMora,
            paymentAmount: inputAmount,
            paymentDate: _paymentDate,
          );

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Card de entrada del Pago ---
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.payment_rounded, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Datos del Recibo',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Campo Monto
                              TextFormField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  labelText: 'Monto a Recibir (COP)',
                                  prefixIcon: Icon(Icons.attach_money_rounded),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Ingresa el monto';
                                  final val = double.tryParse(v);
                                  if (val == null || val <= 0) return 'Monto inválido';
                                  return null;
                                },
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 16),

                              // Método de Pago
                              DropdownButtonFormField<PaymentMethod>(
                                value: _selectedMethod,
                                decoration: const InputDecoration(
                                  labelText: 'Método de Pago',
                                  prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                                ),
                                dropdownColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                                items: PaymentMethod.values.map((m) {
                                  String label = 'Efectivo';
                                  if (m == PaymentMethod.transfer) label = 'Transferencia';
                                  if (m == PaymentMethod.other) label = 'Otro';
                                  return DropdownMenuItem(
                                    value: m,
                                    child: Text(label),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedMethod = val;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 16),

                              // Campo N° de Comprobante / Recibo
                              TextFormField(
                                controller: _receiptController,
                                decoration: const InputDecoration(
                                  labelText: 'N° de Recibo (Opcional)',
                                  prefixIcon: Icon(Icons.receipt_long_rounded),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Fecha del Pago (Editable sólo para Admin, lectura para Cobrador)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Fecha de Aplicación', style: TextStyle(fontSize: 14)),
                                subtitle: Text(DateFormat('dd / MM / yyyy').format(_paymentDate),
                                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                                trailing: isAdmin 
                                    ? const Icon(Icons.edit_calendar_rounded)
                                    : const Icon(Icons.lock_rounded, size: 18),
                                onTap: isAdmin ? () => _selectDate(context) : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Panel de Proyección e Impacto en Cascada ---
                      if (inputAmount > 0)
                        Card(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFF16162D).withValues(alpha: 0.5)
                              : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.waterfall_chart_rounded, color: theme.colorScheme.secondary),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Proyección del Pago en Cascada',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                _projectionRow('Abono Total Recibido:', copFormatter.format(inputAmount)),
                                const Divider(height: 16),
                                _projectionRow('  ↳ Amortización a Mora (P1):', copFormatter.format(cascadeResult.totalAppliedToMora), color: theme.colorScheme.error),
                                _projectionRow('  ↳ Amortización a Interés (P2):', copFormatter.format(cascadeResult.totalAppliedToInterest), color: const Color(0xFFFF9100)),
                                _projectionRow('  ↳ Amortización a Capital (P3):', copFormatter.format(cascadeResult.totalAppliedToPrincipal), color: theme.colorScheme.primary),
                                const Divider(height: 16),
                                _projectionRow('Monto Restante Excedente:', copFormatter.format(cascadeResult.remainingPayment), color: Colors.grey),
                                
                                const SizedBox(height: 20),
                                const Text(
                                  'Cuotas Afectadas:',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                if (cascadeResult.affectedInstallmentNumbers.isEmpty)
                                  const Text('Ninguna cuota se verá afectada.', style: TextStyle(color: Colors.grey, fontSize: 12))
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: cascadeResult.affectedInstallmentNumbers.length,
                                    itemBuilder: (context, index) {
                                      final num = cascadeResult.affectedInstallmentNumbers[index];
                                      final updatedInst = cascadeResult.updatedInstallments.firstWhere((c) => c.installmentNumber == num);
                                      
                                      final breakdown = cascadeResult.installmentBreakdowns['$num'] ?? {'mora': 0.0, 'interes': 0.0, 'capital': 0.0};
                                      final appliedMora = breakdown['mora'] ?? 0.0;
                                      final appliedInterest = breakdown['interes'] ?? 0.0;
                                      final appliedPrincipal = breakdown['capital'] ?? 0.0;

                                      String finalState = _translateStatus(updatedInst.status);

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 10,
                                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                              child: Text('$num', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Cuota $num — Estado: $finalState',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                  Text(
                                                    'Mora: ${copFormatter.format(appliedMora)} | Int: ${copFormatter.format(appliedInterest)} | Cap: ${copFormatter.format(appliedPrincipal)}',
                                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Campo de Notas
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notas / Observaciones (Opcional)',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Botón de Registrar Pago
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4A84E6), Color(0xFF2B5292)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4A84E6).withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : () => _submitPayment(userAsync.value?.uid ?? ''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Registrar Abono', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _projectionRow(String label, String value, {Color? color}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
          Text(value, style: TextStyle(color: color ?? theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  String _translateStatus(InstallmentStatus status) {
    switch (status) {
      case InstallmentStatus.pending:
        return 'PENDIENTE';
      case InstallmentStatus.partial:
        return 'PARCIAL';
      case InstallmentStatus.paid:
        return 'PAGADA';
      case InstallmentStatus.overdue:
        return 'VENCIDA';
      case InstallmentStatus.consolidated:
        return 'CONSOLIDADA';
    }
  }

  Future<void> _submitPayment(String userId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final double? amount = double.tryParse(_amountController.text.replaceAll(',', '.').trim());
      if (amount == null || amount <= 0) {
        throw Exception('Monto de abono inválido.');
      }

      final payment = PaymentModel(
        paymentId: '',
        registeredByUid: userId,
        paymentDate: _paymentDate,
        amountReceived: amount,
        appliedToMora: 0.0,      // Calculado atómicamente en transacción
        appliedToInterest: 0.0, // Calculado atómicamente en transacción
        appliedToPrincipal: 0.0, // Calculado atómicamente en transacción
        affectedInstallmentNumbers: [],
        paymentMethod: _selectedMethod,
        receiptNumber: _receiptController.text.trim().isNotEmpty ? _receiptController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: DateTime.now(),
      );

      await ref.read(firestoreServiceProvider).registerPaymentTransaction(
        creditId: widget.creditId,
        payment: payment,
        dailyMoraRate: widget.dailyMoraRate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abono registrado y distribuido correctamente.'),
            backgroundColor: AppTheme.secondaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar pago: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
