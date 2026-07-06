/// ═══════════════════════════════════════════════════════════════════════════
/// balance_sheet_report_screen.dart — "Balance General"
/// ═══════════════════════════════════════════════════════════════════════════
/// Muestra la posición financiera de la empresa:
/// Activos (Liquidez/Caja, Cartera Activa, Intereses por cobrar, Mora acumulada)
/// Pasivos (Deuda a inversores)
/// Patrimonio Neto (Activos - Pasivos)
/// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/theme/responsive_sidebar_scaffold.dart';
import '../../core/models/user_model.dart';
import '../../core/models/credit_model.dart';
import '../../core/models/investment_model.dart';
import '../../core/models/investor_payment_model.dart';
import '../../core/services/rbac_service.dart';

import '../shared/financial_providers.dart';
import '../calendar/calendar_providers.dart';
import '../credits/credit_list_screen.dart';

class BalanceSheetReportScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const BalanceSheetReportScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<BalanceSheetReportScreen> createState() => _BalanceSheetReportScreenState();
}

class _BalanceSheetReportScreenState extends ConsumerState<BalanceSheetReportScreen> {
  final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0, customPattern: '\u00A4#,##0');

  String _selectedPeriod = 'Historico'; // 'Historico', 'Este Mes', 'Mes Pasado', 'Personalizado'
  DateTimeRange? _customRange;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  DateTimeRange? _resolveDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
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
        return _customRange;
      case 'Historico':
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final creditsAsync = ref.watch(allCreditsStreamProvider);
    final paymentsAsync = ref.watch(allPaymentsProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final investmentsAsync = ref.watch(investmentsStreamProvider);
    final investorPaymentsAsync = ref.watch(allInvestorPaymentsStreamProvider);
    final adjustmentsAsync = ref.watch(cashAdjustmentsStreamProvider);
    final userAsync = ref.watch(currentUserModelProvider);

    final isLoading = creditsAsync.isLoading || paymentsAsync.isLoading ||
        expensesAsync.isLoading || investmentsAsync.isLoading ||
        investorPaymentsAsync.isLoading || adjustmentsAsync.isLoading;

    if (isLoading) {
      if (widget.isEmbedded) return const Center(child: CircularProgressIndicator());
      return ResponsiveSidebarScaffold(
        selectedIndex: 5,
        title: 'Balance General',
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final credits = creditsAsync.value ?? [];
    final payments = paymentsAsync.value ?? [];
    final expenses = expensesAsync.value ?? [];
    final investments = investmentsAsync.value ?? [];
    final investorPayments = investorPaymentsAsync.value ?? [];
    final adjustments = adjustmentsAsync.value ?? [];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final range = _resolveDateRange();
    final hasFilter = range != null;
    final DateTime cutoffDate = DateTime(2026, 7, 1);
    
    final DateTime filterStart = range?.start ?? DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime filterEnd = range?.end ?? DateTime.now().add(const Duration(days: 36500));
    
    final DateTime effectiveStart = filterStart.isBefore(cutoffDate) ? cutoffDate : filterStart;

    // ─── CÁLCULO DE ACTIVOS HISTÓRICOS (Respetando cutoff) ───
    // 1. Liquidez (Caja)
    double recSubs = 0;
    for (var p in payments) {
      if (!p.paymentDate.isBefore(cutoffDate)) {
        if (!hasFilter || p.paymentDate.isBefore(filterEnd) || p.paymentDate.isAtSameMomentAs(filterEnd)) {
          recSubs += p.amountReceived;
        }
      }
    }
    double invSubs = 0;
    for (var inv in investments) {
      if (!inv.createdAt.isBefore(cutoffDate)) {
        if (!hasFilter || inv.createdAt.isBefore(filterEnd) || inv.createdAt.isAtSameMomentAs(filterEnd)) {
          invSubs += inv.amount;
        }
      }
    }
    double credSubs = 0;
    for (var c in credits) {
      if (!c.disbursementDate.isBefore(cutoffDate)) {
        if (!hasFilter || c.disbursementDate.isBefore(filterEnd) || c.disbursementDate.isAtSameMomentAs(filterEnd)) {
          credSubs += c.principalAmount;
        }
      }
    }
    double expSubs = 0;
    for (var e in expenses) {
      if (!e.date.isBefore(cutoffDate)) {
        if (!hasFilter || e.date.isBefore(filterEnd) || e.date.isAtSameMomentAs(filterEnd)) {
          expSubs += e.amount;
        }
      }
    }
    double ipSubs = 0;
    for (var ip in investorPayments) {
      if (!ip.paymentDate.isBefore(cutoffDate)) {
        if (!hasFilter || ip.paymentDate.isBefore(filterEnd) || ip.paymentDate.isAtSameMomentAs(filterEnd)) {
          ipSubs += ip.amount;
        }
      }
    }
    double adjSubs = 0;
    for (var adj in adjustments) {
      if (!adj.date.isBefore(cutoffDate)) {
        if (!hasFilter || adj.date.isBefore(filterEnd) || adj.date.isAtSameMomentAs(filterEnd)) {
          adjSubs += adj.amount;
        }
      }
    }
    final double liquidezCaja = recSubs + invSubs - credSubs - expSubs - ipSubs + adjSubs;

    // 2. Cartera Activa, Intereses, Mora (Respetando cutoff)
    double carteraActiva = 0;
    double interesPorCobrar = 0;
    double moraAcumulada = 0;

    for (var c in credits) {
      if (c.disbursementDate.isBefore(cutoffDate)) {
        continue;
      }
      if (hasFilter && c.disbursementDate.isAfter(filterEnd)) {
        continue;
      }

      double capitalPaidUpToCutoff = 0;
      double interestPaidUpToCutoff = 0;
      double moraPaidUpToCutoff = 0;
      double totalMoraPaidAllTime = 0;

      for (var p in payments) {
        if (p.creditId == c.creditId) {
          totalMoraPaidAllTime += p.appliedToMora;
          if (!hasFilter || p.paymentDate.isBefore(filterEnd) || p.paymentDate.isAtSameMomentAs(filterEnd)) {
            capitalPaidUpToCutoff += p.appliedToPrincipal;
            interestPaidUpToCutoff += p.appliedToInterest;
            moraPaidUpToCutoff += p.appliedToMora;
          }
        }
      }

      // Si a la fecha de corte el capital no se había devuelto por completo (crédito no finalizado)
      if (capitalPaidUpToCutoff < c.principalAmount) {
        carteraActiva += (c.principalAmount - capitalPaidUpToCutoff).clamp(0.0, double.infinity);
        interesPorCobrar += (c.totalInterest - interestPaidUpToCutoff).clamp(0.0, double.infinity);
        
        double moraRem = (c.accumulatedMora - totalMoraPaidAllTime + moraPaidUpToCutoff).clamp(0.0, double.infinity);
        moraAcumulada += moraRem;
      }
    }

    final double totalActivos = liquidezCaja + carteraActiva + interesPorCobrar + moraAcumulada;

    // ─── CÁLCULO DE PASIVOS HISTÓRICOS (Respetando cutoff) ───
    double deudaInversores = 0;
    for (var inv in investments) {
      if (inv.createdAt.isBefore(cutoffDate)) {
        continue;
      }
      if (hasFilter && inv.createdAt.isAfter(filterEnd)) {
        continue;
      }
      double returnedUpToCutoff = 0;
      for (var ip in investorPayments) {
        if (ip.investmentId == inv.investmentId && ip.concept == InvestorPaymentConcept.principalReturn) {
          if (!hasFilter || ip.paymentDate.isBefore(filterEnd) || ip.paymentDate.isAtSameMomentAs(filterEnd)) {
            returnedUpToCutoff += ip.amount;
          }
        }
      }

      double outstanding = inv.amount - returnedUpToCutoff;
      if (outstanding > 0) {
        deudaInversores += outstanding;
      }
    }
    final double totalPasivos = deudaInversores;

    // ─── CÁLCULO DE PATRIMONIO NETO ───
    final double patrimonioNeto = totalActivos - totalPasivos;

    // ─── CÁLCULO DE ROE (Filtrados en el rango efectivo >= cutoffDate) ───
    double interestsEarnedInPeriod = 0;
    double moraEarnedInPeriod = 0;
    double expensesInPeriod = 0;
    double interestPaidToInvestorsInPeriod = 0;

    for (var p in payments) {
      if (p.paymentDate.isAfter(effectiveStart.subtract(const Duration(microseconds: 1))) &&
          p.paymentDate.isBefore(filterEnd.add(const Duration(microseconds: 1)))) {
        interestsEarnedInPeriod += p.appliedToInterest;
        moraEarnedInPeriod += p.appliedToMora;
      }
    }

    for (var e in expenses) {
      if (e.date.isAfter(effectiveStart.subtract(const Duration(microseconds: 1))) &&
          e.date.isBefore(filterEnd.add(const Duration(microseconds: 1)))) {
        expensesInPeriod += e.amount;
      }
    }

    for (var ip in investorPayments) {
      if (ip.paymentDate.isAfter(effectiveStart.subtract(const Duration(microseconds: 1))) &&
          ip.paymentDate.isBefore(filterEnd.add(const Duration(microseconds: 1)))) {
        if (ip.concept == InvestorPaymentConcept.interestPayment) {
          interestPaidToInvestorsInPeriod += ip.amount;
        }
      }
    }

    final double utilidadBrutaPeriodo = interestsEarnedInPeriod + moraEarnedInPeriod;
    final double utilidadNetaPeriodo = utilidadBrutaPeriodo - expensesInPeriod - interestPaidToInvestorsInPeriod;
    final double roe = patrimonioNeto > 0 ? (utilidadNetaPeriodo / patrimonioNeto) * 100 : 0.0;

    // ─── WIDGET CONTENT ───
    Widget content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector de Periodo de Balance
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: _selectedPeriod,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down),
                  items: const [
                    DropdownMenuItem(value: 'Historico', child: Text('Corte Histórico (Todo)')),
                    DropdownMenuItem(value: 'Este Mes', child: Text('Corte a Fin de este Mes')),
                    DropdownMenuItem(value: 'Mes Pasado', child: Text('Corte a Fin del Mes Pasado')),
                    DropdownMenuItem(value: 'Personalizado', child: Text('Corte Personalizado')),
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
                          _selectedPeriod = val!;
                          _customRange = picked;
                        });
                      }
                    } else if (val != null) {
                      setState(() {
                        _selectedPeriod = val;
                      });
                    }
                  },
                ),
                if (_selectedPeriod == 'Personalizado' && _customRange != null)
                  Text(
                    '${_dateFormat.format(_customRange!.start)} - ${_dateFormat.format(_customRange!.end)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tarjetas de Resumen del Balance (Wrap)
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _buildBalanceCard(
                title: 'Total Activos',
                subtitle: 'Liquidez, Cartera y Mora',
                value: copFormatter.format(totalActivos),
                icon: Icons.trending_up,
                color: const Color(0xFF00C9A7),
                isDark: isDark,
              ),
              _buildBalanceCard(
                title: 'Total Pasivos',
                subtitle: 'Deuda actual a inversores',
                value: copFormatter.format(totalPasivos),
                icon: Icons.trending_down,
                color: const Color(0xFFEF4444),
                isDark: isDark,
              ),
              _buildBalanceCard(
                title: 'Patrimonio Neto',
                subtitle: 'Activos menos Pasivos',
                value: copFormatter.format(patrimonioNeto),
                icon: Icons.account_balance,
                color: const Color(0xFF4A84E6),
                isDark: isDark,
              ),
              _buildBalanceCard(
                title: 'Retorno (ROE)',
                subtitle: 'Rentabilidad s/ Patrimonio',
                value: '${roe.toStringAsFixed(2)}%',
                icon: Icons.pie_chart,
                color: roe >= 0 ? Colors.purple : Colors.red,
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Sección de Gráficos Distribución
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gráfico Donut de Composición de Activos
              Expanded(
                flex: 4,
                child: Container(
                  height: 320,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF14141E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Distribución de Activos',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 50,
                                  sections: [
                                    PieChartSectionData(
                                      value: max(0.1, liquidezCaja),
                                      title: totalActivos > 0 && liquidezCaja > 0
                                          ? '${(liquidezCaja / totalActivos * 100).toStringAsFixed(0)}%'
                                          : '',
                                      color: Colors.teal,
                                      radius: 40,
                                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                    PieChartSectionData(
                                      value: max(0.1, carteraActiva),
                                      title: totalActivos > 0 && carteraActiva > 0
                                          ? '${(carteraActiva / totalActivos * 100).toStringAsFixed(0)}%'
                                          : '',
                                      color: AppTheme.primaryColor,
                                      radius: 40,
                                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                    PieChartSectionData(
                                      value: max(0.1, interesPorCobrar),
                                      title: totalActivos > 0 && interesPorCobrar > 0
                                          ? '${(interesPorCobrar / totalActivos * 100).toStringAsFixed(0)}%'
                                          : '',
                                      color: Colors.blueAccent,
                                      radius: 40,
                                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                    PieChartSectionData(
                                      value: max(0.1, moraAcumulada),
                                      title: totalActivos > 0 && moraAcumulada > 0
                                          ? '${(moraAcumulada / totalActivos * 100).toStringAsFixed(0)}%'
                                          : '',
                                      color: Colors.amber,
                                      radius: 40,
                                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPieLegend(Colors.teal, 'Caja (Liquidez)', copFormatter.format(liquidezCaja)),
                                const SizedBox(height: 8),
                                _buildPieLegend(AppTheme.primaryColor, 'Cartera Activa', copFormatter.format(carteraActiva)),
                                const SizedBox(height: 8),
                                _buildPieLegend(Colors.blueAccent, 'Intereses x Cobrar', copFormatter.format(interesPorCobrar)),
                                const SizedBox(height: 8),
                                _buildPieLegend(Colors.amber, 'Mora Pendiente', copFormatter.format(moraAcumulada)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Tabla del Balance General Estructurada Profesional
          _buildSectionHeader('Reporte de Balance Estructurado', isDark),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- ACTIVOS ---
                Text('ACTIVOS (Recursos Disponibles)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF00C9A7))),
                const Divider(color: Color(0xFF00C9A7), thickness: 1.5),
                const SizedBox(height: 8),
                _buildBalanceTableRow('Disponibilidades en Caja / Liquidez', copFormatter.format(liquidezCaja), indent: true),
                _buildBalanceTableRow('Capital de Cartera Activa', copFormatter.format(carteraActiva), indent: true),
                _buildBalanceTableRow('Intereses Ordinarios Proyectados por Cobrar', copFormatter.format(interesPorCobrar), indent: true),
                _buildBalanceTableRow('Intereses de Mora Acumulados por Cobrar', copFormatter.format(moraAcumulada), indent: true),
                const SizedBox(height: 8),
                _buildBalanceTableRow('TOTAL ACTIVOS', copFormatter.format(totalActivos), isBold: true),

                const SizedBox(height: 32),

                // --- PASIVOS ---
                Text('PASIVOS (Obligaciones Financieras)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFFEF4444))),
                const Divider(color: Color(0xFFEF4444), thickness: 1.5),
                const SizedBox(height: 8),
                _buildBalanceTableRow('Deuda de Capital Pendiente a Inversores', copFormatter.format(totalPasivos), indent: true),
                const SizedBox(height: 8),
                _buildBalanceTableRow('TOTAL PASIVOS', copFormatter.format(totalPasivos), isBold: true),

                const SizedBox(height: 32),

                // --- PATRIMONIO NETO ---
                Text('PATRIMONIO NETO (Capital Neto Disponible)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF4A84E6))),
                const Divider(color: Color(0xFF4A84E6), thickness: 2),
                const SizedBox(height: 8),
                _buildBalanceTableRow('Capital de Trabajo y Patrimonio Neto Real', copFormatter.format(patrimonioNeto), isBold: true, isDoubleUnderline: true),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.isEmbedded) return content;

    return ResponsiveSidebarScaffold(
      selectedIndex: userAsync.maybeWhen(
        data: (user) => user?.role == UserRole.admin ? 5 : 3,
        orElse: () => 5,
      ),
      title: 'Balance General',
      child: content,
    );
  }

  // ─── AUXILIAR WIDGETS ───

  Widget _buildBalanceCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: 290,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? const Color(0xFF14141E) : Colors.white,
            isDark ? color.withValues(alpha: 0.05) : color.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 16, spreadRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
                    Text(subtitle, style: TextStyle(fontSize: 10, color: isDark ? Colors.white30 : Colors.black38)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildPieLegend(Color color, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A84E6), Color(0xFF00C9A7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBalanceTableRow(
    String label,
    String value, {
    bool indent = false,
    bool isBold = false,
    bool isDoubleUnderline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: isDoubleUnderline
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white24, width: 3, style: BorderStyle.solid),
                ),
              )
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: EdgeInsets.only(left: indent ? 16.0 : 0.0),
              child: Text(
                label,
                style: isBold
                    ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                    : TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
            ),
            Text(
              value,
              style: isBold
                  ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                  : const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
