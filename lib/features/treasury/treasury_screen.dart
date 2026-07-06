import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/expense_model.dart';
import '../../core/models/treasury_model.dart';
import '../../core/models/investment_model.dart';
import '../../core/models/investor_payment_model.dart';
import '../../core/models/cash_adjustment_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/responsive_sidebar_scaffold.dart';
import '../../core/models/user_model.dart';
import '../../core/services/rbac_service.dart';

import 'dart:async';
import '../calendar/calendar_providers.dart'; // Para allPaymentsProvider y allCreditsStreamProvider
import '../credits/credit_list_screen.dart'; // Para allCreditsStreamProvider
import '../shared/financial_providers.dart'; // Providers financieros compartidos

// Los providers financieros (treasuryStreamProvider, expensesStreamProvider,
// investmentsStreamProvider, allInvestorPaymentsStreamProvider, cashAdjustmentsStreamProvider)
// ahora están centralizados en '../shared/financial_providers.dart'
// para ser compartidos entre Tesorería e Informes sin duplicación.

class TreasuryScreen extends ConsumerStatefulWidget {
  const TreasuryScreen({super.key});

  @override
  ConsumerState<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends ConsumerState<TreasuryScreen> with SingleTickerProviderStateMixin {
  final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final _dateFormat = DateFormat('dd/MM/yyyy');
  late TabController _tabController;

  // Formulario de Gastos
  final _expenseFormKey = GlobalKey<FormState>();
  final _expenseAmountController = TextEditingController();
  final _expenseDescController = TextEditingController();
  String _selectedCategory = 'Otros';
  bool _isSavingExpense = false;
  DateTime _expenseDate = DateTime.now();

  final List<String> _categories = [
    'Papelería', 'Transporte', 'Viáticos', 'Mantenimiento',
    'Nómina', 'Servicios', 'Publicidad', 'Otros',
  ];

  // Formulario de Inversiones
  final _investFormKey = GlobalKey<FormState>();
  final _investorNameController = TextEditingController();
  final _investAmountController = TextEditingController();
  final _investRateController = TextEditingController();
  final _investNotesController = TextEditingController();
  bool _isSavingInvestment = false;
  DateTime _investmentDate = DateTime.now();

  // Formulario de Pago a Inversor
  final _payInvestorFormKey = GlobalKey<FormState>();
  final _payInvestorAmountController = TextEditingController();
  final _payInvestorNotesController = TextEditingController();
  InvestorPaymentConcept _paymentConcept = InvestorPaymentConcept.interestPayment;
  bool _isSavingInvestorPayment = false;
  DateTime _investorPaymentDate = DateTime.now();

  // Formulario de Ajuste de Caja
  final _adjustFormKey = GlobalKey<FormState>();
  final _adjustAmountController = TextEditingController();
  final _adjustDescController = TextEditingController();
  bool _isAdjustmentPositive = true; // true = entrada, false = salida
  bool _isSavingAdjustment = false;
  DateTime _adjustmentDate = DateTime.now();

  // Filtro de periodos en la Caja General
  String _selectedCajaPeriod = 'Historico'; // 'Historico', 'Este Mes', 'Mes Pasado', 'Personalizado'
  DateTimeRange? _customCajaRange;

  DateTimeRange? _resolveCajaDateRange() {
    final now = DateTime.now();
    switch (_selectedCajaPeriod) {
      case 'Este Mes':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1).subtract(const Duration(microseconds: 1)),
        );
      case 'Mes Pasado':
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        return DateTimeRange(
          start: prevMonth,
          end: DateTime(now.year, now.month, 1).subtract(const Duration(microseconds: 1)),
        );
      case 'Personalizado':
        return _customCajaRange;
      case 'Historico':
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _expenseAmountController.dispose();
    _expenseDescController.dispose();
    _investorNameController.dispose();
    _investAmountController.dispose();
    _investRateController.dispose();
    _investNotesController.dispose();
    _payInvestorAmountController.dispose();
    _payInvestorNotesController.dispose();
    _adjustAmountController.dispose();
    _adjustDescController.dispose();
    super.dispose();
  }

  // ─── LÓGICA DE GASTOS ──────────────────────────────────────────────────
  Future<void> _registerExpense() async {
    if (!_expenseFormKey.currentState!.validate()) return;
    setState(() => _isSavingExpense = true);
    try {
      final user = await ref.read(firestoreServiceProvider).getUser(ref.read(authServiceProvider).currentUser!.uid);
      final expense = ExpenseModel(
        expenseId: '',
        amount: double.parse(_expenseAmountController.text.replaceAll(',', '')),
        category: _selectedCategory,
        description: _expenseDescController.text.trim(),
        date: _expenseDate,
        createdBy: user?.displayName ?? 'Admin',
      );
      await ref.read(firestoreServiceProvider).registerExpenseTransaction(expense);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gasto registrado exitosamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) setState(() => _isSavingExpense = false);
    }
  }

  Future<void> _updateExpense(ExpenseModel oldExp) async {
    if (!_expenseFormKey.currentState!.validate()) return;
    setState(() => _isSavingExpense = true);
    try {
      final updatedExp = ExpenseModel(
        expenseId: oldExp.expenseId,
        amount: double.parse(_expenseAmountController.text.replaceAll(',', '')),
        category: _selectedCategory,
        description: _expenseDescController.text.trim(),
        date: _expenseDate,
        createdBy: oldExp.createdBy,
      );

      await ref.read(firestoreServiceProvider).updateExpense(oldExp, updatedExp);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gasto actualizado exitosamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) setState(() => _isSavingExpense = false);
    }
  }

  Future<void> _confirmDeleteExpense(ExpenseModel exp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Gasto'),
        content: Text('¿Está seguro de que desea eliminar el gasto de "${exp.description}" por valor de ${copFormatter.format(exp.amount)}?\n\nEl saldo de caja se actualizará automáticamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(firestoreServiceProvider).deleteExpense(exp.expenseId, exp.amount);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gasto eliminado correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    }
  }

  void _showExpenseDetail(ExpenseModel exp) {
    showDialog(
      context: context,
      builder: (context) {
        return GlassmorphicContainer(
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Detalle de Gasto'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Descripción', exp.description),
                  _detailRow('Monto', copFormatter.format(exp.amount)),
                  _detailRow('Categoría', exp.category),
                  _detailRow('Fecha', DateFormat('dd/MM/yyyy').format(exp.date)),
                  _detailRow('Registrado por', exp.createdBy),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDeleteExpense(exp);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Eliminar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddExpenseDialog(editExp: exp);
                },
                child: const Text('Editar'),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
            ],
          ),
        );
      },
    );
  }

  void _showAddExpenseDialog({ExpenseModel? editExp}) {
    if (editExp != null) {
      _expenseAmountController.text = editExp.amount.toStringAsFixed(0);
      _expenseDescController.text = editExp.description;
      _selectedCategory = editExp.category;
      _expenseDate = editExp.date;
    } else {
      _expenseAmountController.clear();
      _expenseDescController.clear();
      _selectedCategory = 'Otros';
      _expenseDate = DateTime.now();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return GlassmorphicContainer(
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(editExp != null ? 'Editar Gasto Operativo' : 'Registrar Gasto Operativo'),
              content: Form(
                key: _expenseFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(labelText: 'Categoría'),
                        items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                        onChanged: (val) { if (val != null) setDialogState(() => _selectedCategory = val); },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _expenseAmountController,
                        decoration: const InputDecoration(labelText: 'Monto (\$)'),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Requerido';
                          if (double.tryParse(val.replaceAll(',', '')) == null) return 'Monto inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _expenseDescController,
                        decoration: const InputDecoration(labelText: 'Descripción'),
                        maxLines: 2,
                        validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _expenseDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setDialogState(() => _expenseDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Fecha del Gasto', suffixIcon: Icon(Icons.calendar_today)),
                          child: Text(_dateFormat.format(_expenseDate)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: _isSavingExpense ? null : () async {
                    setDialogState(() => _isSavingExpense = true);
                    if (editExp != null) {
                      await _updateExpense(editExp);
                    } else {
                      await _registerExpense();
                    }
                    setDialogState(() => _isSavingExpense = false);
                  },
                  child: _isSavingExpense
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(editExp != null ? 'Guardar Cambios' : 'Guardar Gasto'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ─── LÓGICA DE INVERSIONES ─────────────────────────────────────────────
  Future<void> _registerInvestment() async {
    if (!_investFormKey.currentState!.validate()) return;
    setState(() => _isSavingInvestment = true);
    try {
      final investment = InvestmentModel(
        investmentId: '',
        investorName: _investorNameController.text.trim(),
        amount: double.parse(_investAmountController.text.replaceAll(',', '')),
        monthlyInterestRate: double.tryParse(_investRateController.text.replaceAll(',', '')) ?? 0.0,
        totalInterestPaid: 0,
        totalPrincipalReturned: 0,
        outstandingBalance: 0,
        status: InvestmentStatus.active,
        notes: _investNotesController.text.isEmpty ? null : _investNotesController.text,
        createdAt: _investmentDate,
        updatedAt: _investmentDate,
      );
      await ref.read(firestoreServiceProvider).registerInvestmentTransaction(investment);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inversión registrada exitosamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) setState(() => _isSavingInvestment = false);
    }
  }

  Future<void> _updateInvestment(InvestmentModel oldInv) async {
    if (!_investFormKey.currentState!.validate()) return;
    setState(() => _isSavingInvestment = true);
    try {
      final double newAmount = double.parse(_investAmountController.text.replaceAll(',', ''));
      final double newRate = double.tryParse(_investRateController.text.replaceAll(',', '')) ?? 0.0;
      
      final double diff = newAmount - oldInv.amount;
      final double newOutstanding = (oldInv.outstandingBalance + diff).clamp(0.0, double.infinity);
      final isNowCompleted = newOutstanding == 0 && oldInv.totalPrincipalReturned > 0;

      final updatedInv = InvestmentModel(
        investmentId: oldInv.investmentId,
        investorName: _investorNameController.text.trim(),
        amount: newAmount,
        monthlyInterestRate: newRate,
        totalInterestPaid: oldInv.totalInterestPaid,
        totalPrincipalReturned: oldInv.totalPrincipalReturned,
        outstandingBalance: newOutstanding,
        status: isNowCompleted ? InvestmentStatus.completed : oldInv.status,
        notes: _investNotesController.text.isEmpty ? null : _investNotesController.text.trim(),
        createdAt: _investmentDate,
        updatedAt: DateTime.now(),
      );

      await ref.read(firestoreServiceProvider).updateInvestment(oldInv, updatedInv);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inversión actualizada exitosamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) setState(() => _isSavingInvestment = false);
    }
  }

  Future<void> _confirmDeleteInvestment(InvestmentModel inv) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Inversión'),
        content: Text('¿Está seguro de que desea eliminar la inversión de "${inv.investorName}" por valor de ${copFormatter.format(inv.amount)}?\n\n¡ADVERTENCIA! Se eliminarán de forma permanente todos sus pagos asociados y se revertirá el saldo de caja correspondiente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(firestoreServiceProvider).deleteInvestment(inv.investmentId, inv.amount);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Inversión eliminada correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    }
  }

  void _showAddInvestmentDialog({InvestmentModel? editInv}) {
    if (editInv != null) {
      _investorNameController.text = editInv.investorName;
      _investAmountController.text = editInv.amount.toStringAsFixed(0);
      _investRateController.text = editInv.monthlyInterestRate.toString();
      _investNotesController.text = editInv.notes ?? '';
      _investmentDate = editInv.createdAt;
    } else {
      _investorNameController.clear();
      _investAmountController.clear();
      _investRateController.clear();
      _investNotesController.clear();
      _investmentDate = DateTime.now();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return GlassmorphicContainer(
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(editInv != null ? 'Editar Inversión' : 'Registrar Inversión'),
              content: Form(
                key: _investFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _investorNameController,
                        decoration: const InputDecoration(labelText: 'Nombre del Inversor', hintText: 'Ej: Capital Propio, Juan Pérez'),
                        validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _investAmountController,
                        decoration: const InputDecoration(labelText: 'Monto Invertido (\$)'),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Requerido';
                          if (double.tryParse(val.replaceAll(',', '')) == null) return 'Monto inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _investRateController,
                        decoration: const InputDecoration(
                          labelText: 'Tasa Mensual (%)',
                          hintText: '0 si no cobra interés',
                          suffixText: '%',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _investmentDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setDialogState(() => _investmentDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Fecha de Ingreso', suffixIcon: Icon(Icons.calendar_today)),
                          child: Text(_dateFormat.format(_investmentDate)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _investNotesController,
                        decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: _isSavingInvestment ? null : () async {
                    setDialogState(() => _isSavingInvestment = true);
                    if (editInv != null) {
                      await _updateInvestment(editInv);
                    } else {
                      await _registerInvestment();
                    }
                    setDialogState(() => _isSavingInvestment = false);
                  },
                  child: _isSavingInvestment
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(editInv != null ? 'Guardar Cambios' : 'Registrar Inversión'),
                ),
              ],
            ),
          );
        });
      },
    );
  }
  // ─── LÓGICA DE PAGO A INVERSOR ─────────────────────────────────────────
  Future<void> _registerInvestorPayment(String investmentId) async {
    if (!_payInvestorFormKey.currentState!.validate()) return;
    setState(() => _isSavingInvestorPayment = true);
    try {
      final payment = InvestorPaymentModel(
        paymentId: '',
        investmentId: investmentId,
        amount: double.parse(_payInvestorAmountController.text.replaceAll(',', '')),
        concept: _paymentConcept,
        notes: _payInvestorNotesController.text.isEmpty ? null : _payInvestorNotesController.text,
        paymentDate: _investorPaymentDate,
        createdAt: DateTime.now(),
      );
      await ref.read(firestoreServiceProvider).registerInvestorPaymentTransaction(
        investmentId: investmentId,
        payment: payment,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago a inversor registrado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) setState(() => _isSavingInvestorPayment = false);
    }
  }

  void _showPayInvestorDialog(InvestmentModel investment) {
    _payInvestorAmountController.clear();
    _payInvestorNotesController.clear();
    _paymentConcept = InvestorPaymentConcept.interestPayment;
    _investorPaymentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return GlassmorphicContainer(
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text('Pagar a ${investment.investorName}'),
              content: Form(
                key: _payInvestorFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saldo pendiente: ${copFormatter.format(investment.outstandingBalance)}',
                        style: TextStyle(color: Colors.grey.shade400)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<InvestorPaymentConcept>(
                        value: _paymentConcept,
                        decoration: const InputDecoration(labelText: 'Concepto'),
                        items: const [
                          DropdownMenuItem(value: InvestorPaymentConcept.interestPayment, child: Text('Pago de Intereses')),
                          DropdownMenuItem(value: InvestorPaymentConcept.principalReturn, child: Text('Devolución de Capital')),
                        ],
                        onChanged: (val) { if (val != null) setDialogState(() => _paymentConcept = val); },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _payInvestorAmountController,
                        decoration: const InputDecoration(labelText: 'Monto (\$)'),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Requerido';
                          final parsed = double.tryParse(val.replaceAll(',', ''));
                          if (parsed == null || parsed <= 0) return 'Monto inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _investorPaymentDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setDialogState(() => _investorPaymentDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Fecha del Pago', suffixIcon: Icon(Icons.calendar_today)),
                          child: Text(_dateFormat.format(_investorPaymentDate)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _payInvestorNotesController,
                        decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: _isSavingInvestorPayment ? null : () async {
                    setDialogState(() => _isSavingInvestorPayment = true);
                    await _registerInvestorPayment(investment.investmentId);
                    setDialogState(() => _isSavingInvestorPayment = false);
                  },
                  child: _isSavingInvestorPayment
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Registrar Pago'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showInvestmentDetail(InvestmentModel inv) {
    showDialog(
      context: context,
      builder: (context) {
        return GlassmorphicContainer(
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(inv.investorName),
            content: StreamBuilder<List<InvestorPaymentModel>>(
              stream: ref.read(firestoreServiceProvider).getInvestorPaymentsStream(inv.investmentId),
              builder: (context, snap) {
                final payments = snap.data ?? [];
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow('Monto Invertido', copFormatter.format(inv.amount)),
                      _detailRow('Tasa Mensual', '${inv.monthlyInterestRate}%'),
                      _detailRow('Intereses Pagados', copFormatter.format(inv.totalInterestPaid)),
                      _detailRow('Capital Devuelto', copFormatter.format(inv.totalPrincipalReturned)),
                      _detailRow('Saldo Pendiente', copFormatter.format(inv.outstandingBalance)),
                      _detailRow('Estado', inv.status.name.toUpperCase()),
                      _detailRow('Fecha Ingreso', DateFormat('dd/MM/yyyy').format(inv.createdAt)),
                      if (inv.notes != null && inv.notes!.isNotEmpty) _detailRow('Notas', inv.notes!),
                      const SizedBox(height: 16),
                      const Divider(),
                      Text('Historial de Pagos', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (payments.isEmpty) const Text('Sin pagos registrados.', style: TextStyle(color: Colors.grey)),
                      ...payments.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              p.concept == InvestorPaymentConcept.interestPayment ? Icons.percent : Icons.reply,
                              size: 18,
                              color: p.concept == InvestorPaymentConcept.interestPayment ? Colors.amber : Colors.blueAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.concept == InvestorPaymentConcept.interestPayment ? 'Intereses' : 'Devolución Capital',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Text(copFormatter.format(p.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Text(DateFormat('dd/MM/yy').format(p.paymentDate), style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      )),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDeleteInvestment(inv);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Eliminar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddInvestmentDialog(editInv: inv);
                },
                child: const Text('Editar'),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 12),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  // ─── RECÁLCULO DE TESORERÍA ────────────────────────────────────────────
  Future<void> _calculateInitialTreasury() async {
    try {
      final db = ref.read(firestoreServiceProvider);
      final credits = await db.getAllCreditsStream().first;
      final payments = await db.getAllPaymentsStream().first;
      final investments = await db.getInvestmentsStream().first;
      
      double initialBalance = 0;
      double interests = 0;
      double mora = 0;
      
      for (var pay in payments) {
        initialBalance += pay.amountReceived;
        interests += pay.appliedToInterest;
        mora += pay.appliedToMora;
      }
      for (var cred in credits) {
        initialBalance -= cred.principalAmount;
      }

      // Sumar inversiones recibidas
      double totalInvested = 0;
      double totalReturnedPrincipal = 0;
      double totalPaidInterestInv = 0;
      for (var inv in investments) {
        totalInvested += inv.amount;
        totalReturnedPrincipal += inv.totalPrincipalReturned;
        totalPaidInterestInv += inv.totalInterestPaid;
      }
      initialBalance += totalInvested - totalReturnedPrincipal - totalPaidInterestInv;

      final Map<String, dynamic> updateData = {
        'currentBalance': initialBalance,
        'totalInterestsEarned': interests,
        'totalMoraEarned': mora,
        'totalInvestmentsReceived': totalInvested,
        'totalReturnedToInvestors': totalReturnedPrincipal,
        'totalInterestPaidToInvestors': totalPaidInterestInv,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      await FirebaseFirestore.instance.collection('treasury').doc('main').set(updateData, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tesorería sincronizada con el historial completo')),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // ─── AJUSTE MANUAL DE CAJA ──────────────────────────────────────────────
  Future<void> _registerCashAdjustment() async {
    if (!_adjustFormKey.currentState!.validate()) return;
    setState(() => _isSavingAdjustment = true);
    try {
      final user = await ref.read(firestoreServiceProvider).getUser(ref.read(authServiceProvider).currentUser!.uid);
      final rawAmount = double.parse(_adjustAmountController.text.replaceAll(',', ''));
      final finalAmount = _isAdjustmentPositive ? rawAmount : -rawAmount;

      final adjustment = CashAdjustmentModel(
        adjustmentId: '',
        amount: finalAmount,
        description: _adjustDescController.text,
        date: _adjustmentDate,
        createdBy: user?.displayName ?? 'Admin',
        createdAt: DateTime.now(),
      );
      await ref.read(firestoreServiceProvider).registerCashAdjustment(adjustment);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajuste de caja registrado exitosamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) setState(() => _isSavingAdjustment = false);
    }
  }

  void _showCashAdjustmentDialog() {
    _adjustAmountController.clear();
    _adjustDescController.clear();
    _isAdjustmentPositive = true;
    _adjustmentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return GlassmorphicContainer(
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Ajustar Saldo de Caja'),
              content: Form(
                key: _adjustFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Use esta opción para corregir el saldo real de caja cuando hay movimientos históricos que no fueron registrados.',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      // Tipo de ajuste
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() => _isAdjustmentPositive = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isAdjustmentPositive ? Colors.green.withValues(alpha: 0.2) : Colors.transparent,
                                  border: Border.all(color: _isAdjustmentPositive ? Colors.green : Colors.grey),
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                ),
                                child: Center(child: Text('+ Entrada', style: TextStyle(
                                  color: _isAdjustmentPositive ? Colors.green : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ))),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() => _isAdjustmentPositive = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_isAdjustmentPositive ? Colors.red.withValues(alpha: 0.2) : Colors.transparent,
                                  border: Border.all(color: !_isAdjustmentPositive ? Colors.red : Colors.grey),
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                ),
                                child: Center(child: Text('- Salida', style: TextStyle(
                                  color: !_isAdjustmentPositive ? Colors.red : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ))),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _adjustAmountController,
                        decoration: const InputDecoration(labelText: 'Monto (\$)'),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Requerido';
                          final parsed = double.tryParse(val.replaceAll(',', ''));
                          if (parsed == null || parsed <= 0) return 'Monto inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _adjustDescController,
                        decoration: const InputDecoration(labelText: 'Descripción / Motivo'),
                        validator: (val) => (val == null || val.isEmpty) ? 'Requerido' : null,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _adjustmentDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setDialogState(() => _adjustmentDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Fecha del Ajuste', suffixIcon: Icon(Icons.calendar_today)),
                          child: Text(_dateFormat.format(_adjustmentDate)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: _isSavingAdjustment ? null : () async {
                    setDialogState(() => _isSavingAdjustment = true);
                    await _registerCashAdjustment();
                    setDialogState(() => _isSavingAdjustment = false);
                  },
                  child: _isSavingAdjustment
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Registrar Ajuste'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _confirmDeleteAdjustment(CashAdjustmentModel adj) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Ajuste de Caja'),
        content: Text('¿Está seguro de que desea eliminar el ajuste "${adj.description}" por valor de ${copFormatter.format(adj.amount)}? El saldo de caja se actualizará automáticamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(firestoreServiceProvider).deleteCashAdjustment(adj.adjustmentId, adj.amount);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ajuste de caja eliminado correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserModelProvider);
    final selectedIndex = userAsync.maybeWhen(
      data: (user) => user?.role == UserRole.admin ? 4 : 3,
      orElse: () => 4,
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ResponsiveSidebarScaffold(
      selectedIndex: selectedIndex,
      title: 'Tesorería y Finanzas',
      child: Column(
        children: [
          Container(
            color: theme.cardTheme.color,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Caja General'),
                Tab(text: 'Inversores'),
                Tab(text: 'Gastos Operativos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildCajaTab(isDark),
                _buildInversoresTab(isDark),
                _buildGastosTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 1: CAJA GENERAL
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildCajaTab(bool isDark) {
    final creditsAsync = ref.watch(allCreditsStreamProvider);
    final paymentsAsync = ref.watch(allPaymentsProvider);
    final investmentsAsync = ref.watch(investmentsStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final investorPaymentsAsync = ref.watch(allInvestorPaymentsStreamProvider);
    final adjustmentsAsync = ref.watch(cashAdjustmentsStreamProvider);

    if (creditsAsync.isLoading ||
        paymentsAsync.isLoading ||
        investmentsAsync.isLoading ||
        expensesAsync.isLoading ||
        investorPaymentsAsync.isLoading ||
        adjustmentsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (creditsAsync.hasError ||
        paymentsAsync.hasError ||
        investmentsAsync.hasError ||
        expensesAsync.hasError ||
        investorPaymentsAsync.hasError ||
        adjustmentsAsync.hasError) {
      return const Center(child: Text('Error al cargar datos financieros.'));
    }

    final credits = creditsAsync.value ?? [];
    final payments = paymentsAsync.value ?? [];
    final investments = investmentsAsync.value ?? [];
    final expenses = expensesAsync.value ?? [];
    final investorPayments = investorPaymentsAsync.value ?? [];
    final adjustments = adjustmentsAsync.value ?? [];

    final DateTime cutoffDate = DateTime(2026, 7, 1);
    final range = _resolveCajaDateRange();
    final hasFilter = range != null;
    
    // El rango efectivo debe respetar la fecha de corte (01/07/2026)
    final DateTime filterStart = range?.start ?? DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime filterEnd = range?.end ?? DateTime.now().add(const Duration(days: 36500));
    
    final DateTime effectiveStart = filterStart.isBefore(cutoffDate) ? cutoffDate : filterStart;

    // --- CÁLCULOS ACUMULADOS PARA EL SALDO EN CAJA (Hasta el fin del periodo 'filterEnd', respetando cutoff) ---
    final metrics = FinancialMetrics.calculate(
      credits: credits,
      payments: payments,
      expenses: expenses,
      investments: investments,
      investorPayments: investorPayments,
      adjustments: adjustments,
      dateLimit: hasFilter ? filterEnd : null,
    );

    final double currentBalance = metrics.cajaActual;

    // --- CÁLCULOS ESPECÍFICOS DEL PERIODO (Filtrados estrictamente en [effectiveStart, filterEnd]) ---
    double interestsEarned = 0;
    double moraEarned = 0;
    double expensesPaid = 0;
    double investmentsReceived = 0;
    double returnedToInvestors = 0;
    double interestPaidToInvestors = 0;
    double adjustmentsInPeriod = 0;

    for (var p in payments) {
      if (p.paymentDate.isAfter(effectiveStart.subtract(const Duration(microseconds: 1))) && p.paymentDate.isBefore(filterEnd.add(const Duration(microseconds: 1)))) {
        interestsEarned += p.appliedToInterest;
        moraEarned += p.appliedToMora;
      }
    }

    for (var e in expenses) {
      if (e.date.isAfter(effectiveStart.subtract(const Duration(microseconds: 1))) && e.date.isBefore(filterEnd.add(const Duration(microseconds: 1)))) {
        expensesPaid += e.amount;
      }
    }

    for (var inv in investments) {
      if (inv.createdAt.isAfter(effectiveStart.subtract(const Duration(microseconds: 1))) && inv.createdAt.isBefore(filterEnd.add(const Duration(microseconds: 1)))) {
        investmentsReceived += inv.amount;
      }
    }

    for (var ip in investorPayments) {
      if (ip.paymentDate.isAfter(effectiveStart.subtract(const Duration(microseconds: 1))) && ip.paymentDate.isBefore(filterEnd.add(const Duration(microseconds: 1)))) {
        if (ip.concept == InvestorPaymentConcept.principalReturn) {
          returnedToInvestors += ip.amount;
        } else {
          interestPaidToInvestors += ip.amount;
        }
      }
    }

    for (var adj in adjustments) {
      if (adj.date.isAfter(effectiveStart.subtract(const Duration(microseconds: 1))) && adj.date.isBefore(filterEnd.add(const Duration(microseconds: 1)))) {
        adjustmentsInPeriod += adj.amount;
      }
    }

    final pasivosActivos = metrics.deudaInversores;

    final utilidadBruta = interestsEarned + moraEarned;
    final utilidadNeta = utilidadBruta - expensesPaid - interestPaidToInvestors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de Periodo + Botón de Ajuste
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      DropdownButton<String>(
                        value: _selectedCajaPeriod,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down),
                        items: const [
                          DropdownMenuItem(value: 'Historico', child: Text('Histórico (Todo)')),
                          DropdownMenuItem(value: 'Este Mes', child: Text('Este Mes')),
                          DropdownMenuItem(value: 'Mes Pasado', child: Text('Mes Pasado')),
                          DropdownMenuItem(value: 'Personalizado', child: Text('Rango Personalizado')),
                        ],
                        onChanged: (val) async {
                          if (val == 'Personalizado') {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedCajaPeriod = val!;
                                _customCajaRange = picked;
                              });
                            }
                          } else if (val != null) {
                            setState(() {
                              _selectedCajaPeriod = val;
                            });
                          }
                        },
                      ),
                      if (_selectedCajaPeriod == 'Personalizado' && _customCajaRange != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            '${_dateFormat.format(_customCajaRange!.start)} - ${_dateFormat.format(_customCajaRange!.end)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                // Botón de Ajuste Manual
                OutlinedButton.icon(
                  onPressed: _showCashAdjustmentDialog,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Ajustar Saldo', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: const BorderSide(color: Colors.amber),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tarjetas principales
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildSummaryCard('Saldo en Caja', copFormatter.format(currentBalance), Icons.account_balance_wallet,
                currentBalance >= 0 ? Colors.green : Colors.red, isDark),
              _buildSummaryCard('Utilidad Neta', copFormatter.format(utilidadNeta), Icons.trending_up,
                utilidadNeta >= 0 ? Colors.teal : Colors.red, isDark),
              _buildSummaryCard('Pasivos (Deuda a Inversores)', copFormatter.format(pasivosActivos), Icons.account_balance,
                Colors.orange, isDark),
              _buildSummaryCard('Gastos Operativos', copFormatter.format(expensesPaid), Icons.receipt_long,
                Colors.redAccent, isDark),
              _buildSummaryCard('Interés Cobrado', copFormatter.format(interestsEarned), Icons.attach_money,
                Colors.blueAccent, isDark),
              _buildSummaryCard('Mora Cobrada', copFormatter.format(moraEarned), Icons.money,
                Colors.amber, isDark),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            hasFilter ? 'Flujo de Caja del Periodo' : 'Flujo de Caja Histórico (Desde Julio 2026)',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          const SizedBox(height: 8),
          _flowRow(Icons.arrow_downward, Colors.green, 'Cobros de Clientes (Periodo)', copFormatter.format(interestsEarned + moraEarned), true),
          _flowRow(Icons.arrow_downward, Colors.blue, 'Inversiones Recibidas (Periodo)', copFormatter.format(investmentsReceived), true),
          if (adjustmentsInPeriod != 0)
            _flowRow(
              adjustmentsInPeriod > 0 ? Icons.arrow_downward : Icons.arrow_upward,
              Colors.amber,
              'Ajustes Manuales de Caja (Periodo)',
              copFormatter.format(adjustmentsInPeriod.abs()),
              adjustmentsInPeriod > 0,
            ),
          _flowRow(Icons.arrow_upward, Colors.orange, 'Gastos Operativos (Periodo)', copFormatter.format(expensesPaid), false),
          _flowRow(Icons.arrow_upward, Colors.purple, 'Devolución de Capital a Inversores (Periodo)', copFormatter.format(returnedToInvestors), false),
          _flowRow(Icons.arrow_upward, Colors.amber, 'Pago de Intereses a Inversores (Periodo)', copFormatter.format(interestPaidToInvestors), false),

          // Historial de ajustes manuales recientes
          if (adjustments.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text('Ajustes Manuales Recientes', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            const SizedBox(height: 8),
            ...adjustments.take(5).map((adj) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    adj.amount > 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    color: adj.amount > 0 ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(adj.description, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        Text('${_dateFormat.format(adj.date)} • ${adj.createdBy}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Text(
                    '${adj.amount > 0 ? '+' : ''}${copFormatter.format(adj.amount)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: adj.amount > 0 ? Colors.green : Colors.red),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    onPressed: () => _confirmDeleteAdjustment(adj),
                    tooltip: 'Eliminar Ajuste',
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _flowRow(IconData icon, Color color, String label, String value, bool isIncome) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.red)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 2: INVERSORES
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildInversoresTab(bool isDark) {
    final investmentsAsync = ref.watch(investmentsStreamProvider);

    return investmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (investments) {
        final activeInvestments = investments.where((i) => i.status == InvestmentStatus.active).toList();
        final completedInvestments = investments.where((i) => i.status == InvestmentStatus.completed).toList();
        final totalActive = activeInvestments.fold<double>(0, (s, i) => s + i.outstandingBalance);
        final totalInterestPaid = investments.fold<double>(0, (s, i) => s + i.totalInterestPaid);

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildSummaryCard('Capital Activo de Inversores', copFormatter.format(totalActive), Icons.savings,
                        Colors.blueAccent, isDark),
                      _buildSummaryCard('Intereses Pagados', copFormatter.format(totalInterestPaid), Icons.percent,
                        Colors.amber, isDark),
                      _buildSummaryCard('Inversores Activos', '${activeInvestments.length}', Icons.people,
                        Colors.teal, isDark),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text('Inversiones Activas', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (activeInvestments.isEmpty)
                    const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No hay inversiones activas.')))
                  else
                    ...activeInvestments.map((inv) => _buildInvestmentCard(inv, isDark)),
                  if (completedInvestments.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Inversiones Completadas', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ...completedInvestments.map((inv) => _buildInvestmentCard(inv, isDark)),
                  ],
                ],
              ),
            ),
            Positioned(
              bottom: 16, right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'addInvestment',
                onPressed: _showAddInvestmentDialog,
                icon: const Icon(Icons.add),
                label: const Text('Recibir Inversión'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInvestmentCard(InvestmentModel inv, bool isDark) {
    final isCompleted = inv.status == InvestmentStatus.completed;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showInvestmentDetail(inv),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isCompleted ? Colors.green.withValues(alpha: 0.2) : Colors.blueAccent.withValues(alpha: 0.2),
                child: Icon(isCompleted ? Icons.check : Icons.savings, color: isCompleted ? Colors.green : Colors.blueAccent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.investorName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      'Invertido: ${copFormatter.format(inv.amount)} • Tasa: ${inv.monthlyInterestRate}% • ${DateFormat('dd/MM/yyyy').format(inv.createdAt)}',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(copFormatter.format(inv.outstandingBalance), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(isCompleted ? 'COMPLETADO' : 'PENDIENTE', style: TextStyle(fontSize: 11, color: isCompleted ? Colors.green : Colors.orange)),
                ],
              ),
              if (!isCompleted) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.payment, color: Colors.blueAccent),
                  tooltip: 'Registrar Pago',
                  onPressed: () => _showPayInvestorDialog(inv),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 3: GASTOS OPERATIVOS
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildGastosTab(bool isDark) {
    final expensesAsync = ref.watch(expensesStreamProvider);

    return Stack(
      children: [
        expensesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
          data: (expenses) {
            if (expenses.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No hay gastos registrados aún.')));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final exp = expenses[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _showExpenseDetail(exp),
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withValues(alpha: 0.2),
                      child: const Icon(Icons.money_off, color: Colors.orange),
                    ),
                    title: Text(exp.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${exp.category} • ${DateFormat('dd/MM/yyyy').format(exp.date)} • Por: ${exp.createdBy}'),
                    trailing: Text(
                      '-${copFormatter.format(exp.amount)}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'addExpense',
            onPressed: _showAddExpenseDialog,
            icon: const Icon(Icons.money_off),
            label: const Text('Registrar Gasto'),
          ),
        ),
      ],
    );
  }

  // ─── WIDGETS AUXILIARES ────────────────────────────────────────────────
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey))),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
