import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/expense_model.dart';
import '../../core/models/treasury_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../shared/theme/app_theme.dart';

final treasuryStreamProvider = StreamProvider<TreasuryModel>((ref) {
  return ref.watch(firestoreServiceProvider).getTreasuryStream();
});

final expensesStreamProvider = StreamProvider<List<ExpenseModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getExpensesStream();
});

class TreasuryScreen extends ConsumerStatefulWidget {
  const TreasuryScreen({super.key});

  @override
  ConsumerState<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends ConsumerState<TreasuryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'Papelería';
  bool _isSaving = false;

  final List<String> _categories = [
    'Papelería',
    'Transporte',
    'Viáticos',
    'Mantenimiento',
    'Nómina',
    'Servicios',
    'Publicidad',
    'Otros'
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _registerExpense() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final user = await ref.read(firestoreServiceProvider).getUser(ref.read(authServiceProvider).currentUser!.uid);
      final expense = ExpenseModel(
        expenseId: '',
        amount: double.parse(_amountController.text.replaceAll(',', '')),
        category: _selectedCategory,
        description: _descController.text,
        date: DateTime.now(),
        createdBy: user?.displayName ?? 'Admin',
      );
      
      await ref.read(firestoreServiceProvider).registerExpenseTransaction(expense);
      
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gasto registrado exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddExpenseDialog() {
    _amountController.clear();
    _descController.clear();
    _selectedCategory = 'Otros';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return GlassmorphicContainer(
              child: AlertDialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text('Registrar Gasto Operativo'),
                content: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(labelText: 'Categoría'),
                          items: _categories.map((cat) {
                            return DropdownMenuItem(value: cat, child: Text(cat));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => _selectedCategory = val);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(labelText: 'Monto (\$)'),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Requerido';
                            if (double.tryParse(val) == null) return 'Monto inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descController,
                          decoration: const InputDecoration(labelText: 'Descripción'),
                          maxLines: 2,
                          validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: _isSaving ? null : () async {
                      setDialogState(() => _isSaving = true);
                      await _registerExpense();
                      setDialogState(() => _isSaving = false);
                    },
                    child: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Guardar Gasto'),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _calculateInitialTreasury() async {
    try {
      final db = ref.read(firestoreServiceProvider);
      // Get all credits
      final creditsStream = db.getAllCreditsStream();
      final credits = await creditsStream.first;
      // Get all payments
      final paymentsStream = db.getAllPaymentsStream();
      final payments = await paymentsStream.first;
      
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
      
      // We don't overwrite if there are expenses already, but we will just merge.
      final Map<String, dynamic> updateData = {
        'currentBalance': initialBalance,
        'totalInterestsEarned': interests,
        'totalMoraEarned': mora,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      await FirebaseFirestore.instance.collection('treasury').doc('main').set(updateData, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tesorería sincronizada con el historial de préstamos')),
        );
      }
    } catch (e) {
       debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final treasuryAsync = ref.watch(treasuryStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final theme = Theme.of(context);
    final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Tesorería y Contabilidad', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Recalcular Saldo Inicial Histórico',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('¿Recalcular Tesorería?'),
                  content: const Text('Esto sumará todos los pagos pasados y restará los desembolsos para calcular tu saldo real actual. Útil solo para la primera vez.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Recalcular')),
                  ],
                ),
              );
              if (confirm == true) {
                _calculateInitialTreasury();
              }
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        icon: const Icon(Icons.money_off),
        label: const Text('Registrar Gasto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Tarjetas de Resumen ---
            treasuryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (treasury) {
                final utilidadNeta = (treasury.totalInterestsEarned + treasury.totalMoraEarned) - treasury.totalExpenses;
                
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildSummaryCard(
                      'Saldo en Caja (Efectivo)',
                      copFormatter.format(treasury.currentBalance),
                      Icons.account_balance_wallet,
                      treasury.currentBalance >= 0 ? theme.colorScheme.primary : theme.colorScheme.error,
                    ),
                    _buildSummaryCard(
                      'Utilidad Neta (Ganancia)',
                      copFormatter.format(utilidadNeta),
                      Icons.trending_up,
                      utilidadNeta >= 0 ? Colors.green : theme.colorScheme.error,
                    ),
                    _buildSummaryCard(
                      'Total Gastos Operativos',
                      copFormatter.format(treasury.totalExpenses),
                      Icons.receipt_long,
                      Colors.orange,
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 32),
            Text('Historial de Gastos', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            const SizedBox(height: 8),

            // --- Lista de Gastos ---
            expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No hay gastos registrados aún.')),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final exp = expenses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
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
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey))),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
