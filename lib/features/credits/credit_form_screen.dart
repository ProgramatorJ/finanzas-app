import 'package:finanzas_app/core/enums/payment_frequency.dart';
import 'package:finanzas_app/core/enums/credit_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/credit_model.dart';
import '../../core/models/installment_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/commercial_calendar.dart';
import '../../shared/theme/app_theme.dart';

class CreditFormScreen extends ConsumerStatefulWidget {
  final String clientId;

  const CreditFormScreen({super.key, required this.clientId});

  @override
  ConsumerState<CreditFormScreen> createState() => _CreditFormScreenState();
}

class _CreditFormScreenState extends ConsumerState<CreditFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores de entrada
  final _principalController = TextEditingController();
  final _interestRateController = TextEditingController(text: '10.0'); // 10% mensual por defecto
  final _moraRateController = TextEditingController(text: '0.7');       // 0.7% diario por defecto
  final _termController = TextEditingController(text: '1');             // 1 mes por defecto
  final _notesController = TextEditingController();

  PaymentFrequency _selectedFrequency = PaymentFrequency.monthly;
  late DateTime _disbursementDate;
  late DateTime _firstInstallmentDate;
  bool _userChangedFirstDate = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _disbursementDate = DateTime(now.year, now.month, now.day);
    _firstInstallmentDate = DateTime(now.year, now.month, now.day);
    _updateFirstInstallmentDateDefault();
  }

  @override
  void dispose() {
    _principalController.dispose();
    _interestRateController.dispose();
    _moraRateController.dispose();
    _termController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Actualiza la fecha por defecto de la primera cuota según la frecuencia elegida
  void _updateFirstInstallmentDateDefault() {
    if (_userChangedFirstDate) return;

    setState(() {
      if (_selectedFrequency == PaymentFrequency.weekly) {
        _firstInstallmentDate = _disbursementDate.add(const Duration(days: 7));
      } else {
        int daysToAdd;
        switch (_selectedFrequency) {
          case PaymentFrequency.biweekly:
            daysToAdd = 15;
            break;
          case PaymentFrequency.monthly:
          default:
            daysToAdd = 30;
            break;
        }
        _firstInstallmentDate = CommercialCalendar.addCommercialDays(_disbursementDate, daysToAdd);
      }
    });
  }

  // Proyección financiera en tiempo real
  Map<String, dynamic> _calculateProjection() {
    final principal = double.tryParse(_principalController.text) ?? 0.0;
    final interestRate = (double.tryParse(_interestRateController.text) ?? 0.0) / 100.0;
    final term = int.tryParse(_termController.text) ?? 0;

    final totalInterest = principal * interestRate * term;
    final totalAmount = principal + totalInterest;

    final numInstallments = CommercialCalendar.calculateNumberOfInstallments(
      termInMonths: term,
      frequency: _selectedFrequency.name,
    );

    double installmentAmount = 0.0;
    double principalPortion = 0.0;
    double interestPortion = 0.0;

    if (numInstallments > 0) {
      // Redondeo siempre hacia arriba (ceil) según lo acordado con el usuario
      installmentAmount = (totalAmount / numInstallments).ceilToDouble();
      principalPortion = (principal / numInstallments).ceilToDouble();
      interestPortion = installmentAmount - principalPortion;
    }

    return {
      'principal': principal,
      'totalInterest': totalInterest,
      'totalAmount': totalAmount,
      'numInstallments': numInstallments,
      'installmentAmount': installmentAmount,
      'principalPortion': principalPortion,
      'interestPortion': interestPortion,
    };
  }

  Future<void> _selectDate(BuildContext context, bool isDisbursement) async {
    final theme = Theme.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isDisbursement ? _disbursementDate : _firstInstallmentDate,
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
        if (isDisbursement) {
          _disbursementDate = picked;
          _updateFirstInstallmentDateDefault();
        } else {
          _firstInstallmentDate = picked;
          _userChangedFirstDate = true;
        }
      });
    }
  }

  Future<void> _saveCredit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final projection = _calculateProjection();
    if (projection['principal'] <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('El monto del capital debe ser mayor a 0.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final currentUser = ref.read(authServiceProvider).currentUser;
    final db = ref.read(firestoreServiceProvider);

    final term = int.parse(_termController.text);
    final numInstallments = projection['numInstallments'] as int;

    // 1. Crear el modelo del Crédito
    final credit = CreditModel(
      creditId: '',
      clientId: widget.clientId,
      createdByUid: currentUser?.uid ?? '',
      principalAmount: projection['principal'],
      monthlyInterestRate: (double.parse(_interestRateController.text)) / 100.0,
      dailyMoraRate: (double.parse(_moraRateController.text)) / 100.0,
      termInMonths: term,
      paymentFrequency: _selectedFrequency,
      totalInterest: projection['totalInterest'],
      totalAmount: projection['totalAmount'],
      installmentAmount: projection['installmentAmount'],
      numberOfInstallments: numInstallments,
      disbursementDate: _disbursementDate,
      firstInstallmentDate: _firstInstallmentDate,
      status: CreditStatus.active,
      paidInstallments: 0,
      totalPaid: 0.0,
      totalPaidPrincipal: 0.0,
      totalPaidInterest: 0.0,
      totalPaidMora: 0.0,
      outstandingBalance: projection['totalAmount'],
      currentConsolidatedDebt: 0.0,
      accumulatedMora: 0.0,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      // Registrar Crédito en Firestore para obtener su Auto-ID
      final creditId = await db.createCredit(credit);

      // 2. Generar plan de cuotas con reconciliación en la última cuota
      final List<DateTime> dueDates = CommercialCalendar.generateInstallmentDates(
        firstInstallmentDate: _firstInstallmentDate,
        numberOfInstallments: numInstallments,
        frequency: _selectedFrequency.name,
      );

      final List<InstallmentModel> installments = [];
      final double stdInstallmentAmount = projection['installmentAmount'];
      final double stdPrincipalPortion = projection['principalPortion'];
      final double stdInterestPortion = projection['interestPortion'];

      double accumulatedPrincipal = 0.0;
      double accumulatedInterest = 0.0;

      for (int i = 0; i < numInstallments; i++) {
        final isLast = (i == numInstallments - 1);
        double currentPrincipal;
        double currentInterest;
        double currentScheduled;

        if (isLast) {
          // Reconciliación: la última cuota ajusta los centavos restantes exactos
          currentPrincipal = credit.principalAmount - accumulatedPrincipal;
          currentInterest = credit.totalInterest - accumulatedInterest;
          currentScheduled = currentPrincipal + currentInterest;
        } else {
          currentPrincipal = stdPrincipalPortion;
          currentInterest = stdInterestPortion;
          currentScheduled = stdInstallmentAmount;

          accumulatedPrincipal += currentPrincipal;
          accumulatedInterest += currentInterest;
        }

        installments.add(
          InstallmentModel(
            installmentId: '',
            installmentNumber: i + 1,
            dueDate: dueDates[i],
            principalPortion: currentPrincipal,
            interestPortion: currentInterest,
            scheduledAmount: currentScheduled,
            status: InstallmentStatus.pending,
            paidAmount: 0.0,
            remainingAmount: currentScheduled,
            isMoraActive: false,
            moraStartDate: dueDates[i],
            dailyMoraRate: credit.dailyMoraRate,
            moraBase: currentScheduled, // Base de mora = cuota total programada (mora = moraBase * tasa * días)
            accumulatedMora: 0.0,
            moraPaid: 0.0,
            isConsolidated: false,
            consolidatedIntoInstallment: null,
            consolidationDate: null,
            createdAt: DateTime.now(),
            updatedAt: credit.disbursementDate,
          ),
        );
      }

      // Guardar todas las cuotas de forma atómica
      await db.createInstallments(creditId, installments);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Crédito registrado y cuotas generadas correctamente.'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear crédito: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projection = _calculateProjection();
    final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Crédito'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Formulario de Parámetros ---
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.edit_document, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Parámetros del Crédito',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Campo Capital
                          TextFormField(
                            controller: _principalController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Monto del Capital (COP)',
                              prefixIcon: Icon(Icons.attach_money_rounded),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el capital' : null,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),

                          // Plazo en Meses
                          TextFormField(
                            controller: _termController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Plazo (Meses)',
                              prefixIcon: Icon(Icons.calendar_month_outlined),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el plazo' : null,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),

                          // Frecuencia Dropdown
                          DropdownButtonFormField<PaymentFrequency>(
                            value: _selectedFrequency,
                            decoration: const InputDecoration(
                              labelText: 'Frecuencia de Pago',
                              prefixIcon: Icon(Icons.sync_rounded),
                            ),
                            dropdownColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                            items: PaymentFrequency.values.map((f) {
                              String label = 'Mensual';
                              if (f == PaymentFrequency.weekly) label = 'Semanal';
                              if (f == PaymentFrequency.biweekly) label = 'Quincenal';
                              return DropdownMenuItem(
                                value: f,
                                child: Text(label),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedFrequency = val;
                                  _updateFirstInstallmentDateDefault();
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Fila de Tasas de Interés y Mora
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _interestRateController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Interés Corriente (% mes)',
                                    prefixIcon: Icon(Icons.percent_rounded),
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _moraRateController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Mora Diaria (% día)',
                                    prefixIcon: Icon(Icons.trending_up_rounded),
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Selección de Fechas ---
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.date_range_rounded, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Calendario de Desembolso',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Selector Fecha Desembolso
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Fecha de Desembolso', style: TextStyle(fontSize: 14)),
                            subtitle: Text(DateFormat('dd / MM / yyyy').format(_disbursementDate),
                                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                            trailing: Icon(Icons.edit_calendar_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            onTap: () => _selectDate(context, true),
                          ),
                          const Divider(height: 8),

                          // Selector Fecha Primera Cuota (Manualmente Editable)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Fecha de Primera Cuota', style: TextStyle(fontSize: 14)),
                            subtitle: Text(DateFormat('dd / MM / yyyy').format(_firstInstallmentDate),
                                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                            trailing: Icon(Icons.edit_calendar_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            onTap: () => _selectDate(context, false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Panel de Proyección en Tiempo Real ---
                  Card(
                    color: (theme.cardTheme.color ?? theme.colorScheme.surface).withValues(alpha: 0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.analytics_outlined, color: theme.colorScheme.secondary),
                              const SizedBox(width: 8),
                              Text(
                                'Proyección del Préstamo (Año 360)',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          _projectionRow('Capital Prestado:', copFormatter.format(projection['principal'])),
                          _projectionRow('Interés Total Corriente:', copFormatter.format(projection['totalInterest'])),
                          _projectionRow('Total Neto a Pagar:', copFormatter.format(projection['totalAmount'])),
                          const Divider(height: 24),
                          _projectionRow('Total de Cuotas a Generar:', '${projection['numInstallments']} cuotas'),
                          _projectionRow('Monto por Cuota (Base redondeada):', copFormatter.format(projection['installmentAmount'])),
                          _projectionRow('  ↳ Porción Capital:', copFormatter.format(projection['principalPortion'])),
                          _projectionRow('  ↳ Porción Interés:', copFormatter.format(projection['interestPortion'])),
                          const SizedBox(height: 8),
                          Text(
                            '* La última cuota reajustará los decimales sobrantes exactos del redondeo.',
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontStyle: FontStyle.italic),
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
                      labelText: 'Notas adicionales (Opcional)',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Botón Guardar Crédito
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: theme.brightness == Brightness.dark
                            ? [const Color(0xFF4A84E6), const Color(0xFF2B5292)]
                            : [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (theme.brightness == Brightness.dark ? const Color(0xFF4A84E6) : theme.colorScheme.primary)
                              .withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveCredit,
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
                          : const Text(
                              'Registrar Crédito',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
}
