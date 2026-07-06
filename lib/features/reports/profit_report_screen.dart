/// ═══════════════════════════════════════════════════════════════════════════
/// profit_report_screen.dart — "Pagos y Ganancias"
/// ═══════════════════════════════════════════════════════════════════════════
/// Muestra la rentabilidad del negocio: Utilidad Bruta (Interés + Mora)
/// vs Utilidad Neta (después de gastos e intereses a inversores).
/// Totales de dinero prestado, intereses, mora, y saldo en caja.
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
import '../../core/models/investor_payment_model.dart';
import '../../core/services/rbac_service.dart';

import '../shared/financial_providers.dart';
import '../calendar/calendar_providers.dart';
import '../credits/credit_list_screen.dart';

enum ProfitPeriod {
  monthly,
  quarterly,
  biannual,
  yearly,
}

class _ProfitPeriodData {
  double interestEarned = 0;
  double moraEarned = 0;
  double expenses = 0;
  double interestPaidInvestors = 0;
  double capitalLent = 0;
  double capitalRecovered = 0;
}

class ProfitReportScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const ProfitReportScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends ConsumerState<ProfitReportScreen> {
  final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0, customPattern: '\u00A4#,##0');

  ProfitPeriod _selectedPeriod = ProfitPeriod.monthly;
  int _periodsToShow = 6;

  DateTime _getPeriodStart(DateTime date, ProfitPeriod resolution) {
    switch (resolution) {
      case ProfitPeriod.monthly:
        return DateTime(date.year, date.month, 1);
      case ProfitPeriod.quarterly:
        int qMonth = ((date.month - 1) ~/ 3) * 3 + 1;
        return DateTime(date.year, qMonth, 1);
      case ProfitPeriod.biannual:
        int hMonth = ((date.month - 1) ~/ 6) * 6 + 1;
        return DateTime(date.year, hMonth, 1);
      case ProfitPeriod.yearly:
        return DateTime(date.year, 1, 1);
    }
  }

  DateTime _getPrevPeriod(DateTime current, ProfitPeriod resolution) {
    switch (resolution) {
      case ProfitPeriod.monthly:
        return DateTime(current.year, current.month - 1, 1);
      case ProfitPeriod.quarterly:
        return DateTime(current.year, current.month - 3, 1);
      case ProfitPeriod.biannual:
        return DateTime(current.year, current.month - 6, 1);
      case ProfitPeriod.yearly:
        return DateTime(current.year - 1, 1, 1);
    }
  }

  String _formatPeriodLabel(DateTime date, ProfitPeriod resolution) {
    switch (resolution) {
      case ProfitPeriod.monthly:
        return DateFormat('MMM yy').format(date);
      case ProfitPeriod.quarterly:
        int quarter = ((date.month - 1) ~/ 3) + 1;
        return 'Q$quarter ${date.year.toString().substring(2)}';
      case ProfitPeriod.biannual:
        int half = ((date.month - 1) ~/ 6) + 1;
        return 'S$half ${date.year.toString().substring(2)}';
      case ProfitPeriod.yearly:
        return '${date.year}';
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
        title: 'Pagos y Ganancias',
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

    // ═══ CÁLCULOS GLOBALES (Respetando la fecha de corte 01/07/2026) ═══
    final DateTime cutoffDate = DateTime(2026, 7, 1);

    double totalInterestEarned = 0;
    double totalMoraEarned = 0;
    double totalCapitalLent = 0;
    double totalCapitalRecovered = 0;

    for (var p in payments) {
      if (!p.paymentDate.isBefore(cutoffDate)) {
        totalInterestEarned += p.appliedToInterest;
        totalMoraEarned += p.appliedToMora;
        totalCapitalRecovered += p.appliedToPrincipal;
      }
    }

    for (var c in credits) {
      if (!c.disbursementDate.isBefore(cutoffDate)) {
        totalCapitalLent += c.principalAmount;
      }
    }

    double totalExpenses = 0;
    for (var e in expenses) {
      if (!e.date.isBefore(cutoffDate)) {
        totalExpenses += e.amount;
      }
    }

    double totalInterestPaidInvestors = 0;
    double totalReturnedInvestors = 0;
    for (var ip in investorPayments) {
      if (!ip.paymentDate.isBefore(cutoffDate)) {
        if (ip.concept == InvestorPaymentConcept.interestPayment) {
          totalInterestPaidInvestors += ip.amount;
        } else {
          totalReturnedInvestors += ip.amount;
        }
      }
    }

    double totalInvReceived = 0;
    for (var inv in investments) {
      if (!inv.createdAt.isBefore(cutoffDate)) {
        totalInvReceived += inv.amount;
      }
    }

    double totalAdjustments = 0;
    for (var adj in adjustments) {
      if (!adj.date.isBefore(cutoffDate)) {
        totalAdjustments += adj.amount;
      }
    }

    final utilidadBruta = totalInterestEarned + totalMoraEarned;
    final utilidadNeta = utilidadBruta - totalExpenses - totalInterestPaidInvestors;

    // Saldo en caja recalculado
    double cashReceivedFromPayments = 0;
    for (var p in payments) {
      if (!p.paymentDate.isBefore(cutoffDate)) {
        cashReceivedFromPayments += p.amountReceived;
      }
    }
    double cashPaidToInvestors = 0;
    for (var ip in investorPayments) {
      if (!ip.paymentDate.isBefore(cutoffDate)) {
        cashPaidToInvestors += ip.amount;
      }
    }

    final cashBalance = cashReceivedFromPayments
        + totalInvReceived - totalCapitalLent - totalExpenses
        - cashPaidToInvestors
        + totalAdjustments;

    // ═══ DATOS POR PERIODO PARA EL GRÁFICO ═══
    final now = DateTime.now();
    final currentPeriod = _getPeriodStart(now, _selectedPeriod);
    List<DateTime> periods = [];
    var cursor = currentPeriod;
    for (int i = 0; i < _periodsToShow; i++) {
      periods.add(cursor);
      cursor = _getPrevPeriod(cursor, _selectedPeriod);
    }
    periods = periods.reversed.toList();

    Map<DateTime, _ProfitPeriodData> dataByPeriod = {
      for (var pd in periods) pd: _ProfitPeriodData()
    };

    for (var p in payments) {
      if (!p.paymentDate.isBefore(cutoffDate)) {
        final ps = _getPeriodStart(p.paymentDate, _selectedPeriod);
        if (dataByPeriod.containsKey(ps)) {
          dataByPeriod[ps]!.interestEarned += p.appliedToInterest;
          dataByPeriod[ps]!.moraEarned += p.appliedToMora;
          dataByPeriod[ps]!.capitalRecovered += p.appliedToPrincipal;
        }
      }
    }

    for (var e in expenses) {
      if (!e.date.isBefore(cutoffDate)) {
        final ps = _getPeriodStart(e.date, _selectedPeriod);
        if (dataByPeriod.containsKey(ps)) {
          dataByPeriod[ps]!.expenses += e.amount;
        }
      }
    }

    for (var ip in investorPayments) {
      if (!ip.paymentDate.isBefore(cutoffDate)) {
        if (ip.concept == InvestorPaymentConcept.interestPayment) {
          final ps = _getPeriodStart(ip.paymentDate, _selectedPeriod);
          if (dataByPeriod.containsKey(ps)) {
            dataByPeriod[ps]!.interestPaidInvestors += ip.amount;
          }
        }
      }
    }

    for (var c in credits) {
      if (!c.disbursementDate.isBefore(cutoffDate)) {
        final ps = _getPeriodStart(c.disbursementDate, _selectedPeriod);
        if (dataByPeriod.containsKey(ps)) {
          dataByPeriod[ps]!.capitalLent += c.principalAmount;
        }
      }
    }

    // Max Y for chart
    double chartMaxY = 0;
    for (var pd in dataByPeriod.values) {
      final bruta = pd.interestEarned + pd.moraEarned;
      final neta = bruta - pd.expenses - pd.interestPaidInvestors;
      chartMaxY = max(chartMaxY, max(bruta, neta.abs()));
    }
    chartMaxY = chartMaxY == 0 ? 100 : chartMaxY * 1.2;

    // ═══ CONSTRUIR UI ═══
    Widget content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarjetas de resumen con gradientes
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _buildGlowCard(
                title: 'Utilidad Bruta',
                subtitle: 'Intereses + Mora',
                value: copFormatter.format(utilidadBruta),
                icon: Icons.trending_up,
                color: const Color(0xFF00C9A7),
                isDark: isDark,
              ),
              _buildGlowCard(
                title: 'Utilidad Neta',
                subtitle: 'Después de gastos e inversores',
                value: copFormatter.format(utilidadNeta),
                icon: utilidadNeta >= 0 ? Icons.sentiment_very_satisfied : Icons.sentiment_dissatisfied,
                color: utilidadNeta >= 0 ? const Color(0xFF4A84E6) : AppTheme.errorColor,
                isDark: isDark,
              ),
              _buildGlowCard(
                title: 'Saldo en Caja',
                subtitle: 'Liquidez disponible',
                value: copFormatter.format(cashBalance),
                icon: Icons.account_balance_wallet,
                color: cashBalance >= 0 ? Colors.teal : Colors.red,
                isDark: isDark,
              ),
              _buildGlowCard(
                title: 'Total Prestado',
                subtitle: 'Capital colocado históricamente',
                value: copFormatter.format(totalCapitalLent),
                icon: Icons.monetization_on_outlined,
                color: const Color(0xFF7C4DFF),
                isDark: isDark,
              ),
              _buildGlowCard(
                title: 'Total Intereses',
                subtitle: 'Intereses cobrados acumulados',
                value: copFormatter.format(totalInterestEarned),
                icon: Icons.percent,
                color: Colors.blueAccent,
                isDark: isDark,
              ),
              _buildGlowCard(
                title: 'Total Mora',
                subtitle: 'Mora cobrada acumulada',
                value: copFormatter.format(totalMoraEarned),
                icon: Icons.warning_amber_rounded,
                color: Colors.amber,
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ═══ GRÁFICO DE UTILIDAD BRUTA VS NETA ═══
          _buildSectionHeader('Rentabilidad por Periodo', isDark),
          const SizedBox(height: 8),

          // Controls
          Row(
            children: [
              DropdownButton<ProfitPeriod>(
                value: _selectedPeriod,
                underline: const SizedBox(),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: ProfitPeriod.monthly, child: Text('Mensual')),
                  DropdownMenuItem(value: ProfitPeriod.quarterly, child: Text('Trimestral')),
                  DropdownMenuItem(value: ProfitPeriod.biannual, child: Text('Semestral')),
                  DropdownMenuItem(value: ProfitPeriod.yearly, child: Text('Anual')),
                ],
                onChanged: (val) { if (val != null) setState(() => _selectedPeriod = val); },
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Periodos: ', style: TextStyle(fontSize: 12)),
                  DropdownButton<int>(
                    value: _periodsToShow,
                    underline: const SizedBox(),
                    items: [3, 6, 9, 12].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                    onChanged: (val) { if (val != null) setState(() => _periodsToShow = val); },
                  ),
                ],
              ),
            ],
          ),

          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 24,
              children: [
                _buildLegendDot(const Color(0xFF00C9A7), 'Utilidad Bruta'),
                _buildLegendDot(const Color(0xFF4A84E6), 'Utilidad Neta'),
                _buildLegendDot(AppTheme.errorColor.withValues(alpha: 0.6), 'Gastos + Int. Inversores'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Chart
          Container(
            height: 300,
            padding: const EdgeInsets.fromLTRB(4, 16, 16, 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A84E6).withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: BarChart(
              BarChartData(
                maxY: chartMaxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final labels = ['U. Bruta', 'U. Neta', 'Egresos'];
                      final colors = [const Color(0xFF00C9A7), const Color(0xFF4A84E6), AppTheme.errorColor];
                      return BarTooltipItem(
                        '${labels[rodIndex]}\n${copFormatter.format(rod.toY)}',
                        TextStyle(color: colors[rodIndex], fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value >= periods.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _formatPeriodLabel(periods[value.toInt()], _selectedPeriod),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(NumberFormat.compactCurrency(symbol: '\$').format(value), style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(periods.length, (i) {
                  final pd = dataByPeriod[periods[i]]!;
                  final bruta = pd.interestEarned + pd.moraEarned;
                  final egresos = pd.expenses + pd.interestPaidInvestors;
                  final neta = bruta - egresos;

                  return BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: bruta,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C9A7), Color(0xFF00E5BF)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      BarChartRodData(
                        toY: max(0, neta),
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: neta >= 0
                              ? [const Color(0xFF4A84E6), const Color(0xFF6BA0FF)]
                              : [AppTheme.errorColor, AppTheme.errorColor.withValues(alpha: 0.7)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      BarChartRodData(
                        toY: egresos,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [AppTheme.errorColor.withValues(alpha: 0.8), AppTheme.errorColor.withValues(alpha: 0.4)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ═══ COMPOSICIÓN DE GANANCIAS (Donut Chart) ═══
          _buildSectionHeader('Composición de Ingresos', isDark),
          const SizedBox(height: 16),

          Container(
            height: 280,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 50,
                      sections: [
                        PieChartSectionData(
                          value: totalInterestEarned,
                          title: totalInterestEarned > 0 ? '${(totalInterestEarned / max(1, utilidadBruta) * 100).toStringAsFixed(0)}%' : '',
                          color: Colors.blueAccent,
                          radius: 50,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        PieChartSectionData(
                          value: totalMoraEarned,
                          title: totalMoraEarned > 0 ? '${(totalMoraEarned / max(1, utilidadBruta) * 100).toStringAsFixed(0)}%' : '',
                          color: Colors.amber,
                          radius: 50,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPieLegend(Colors.blueAccent, 'Intereses', copFormatter.format(totalInterestEarned)),
                      const SizedBox(height: 12),
                      _buildPieLegend(Colors.amber, 'Mora', copFormatter.format(totalMoraEarned)),
                      const Divider(height: 32),
                      _buildPieLegend(const Color(0xFF00C9A7), 'Total Bruto', copFormatter.format(utilidadBruta)),
                      const SizedBox(height: 8),
                      _buildPieLegend(AppTheme.errorColor, 'Gastos Op.', copFormatter.format(totalExpenses)),
                      const SizedBox(height: 8),
                      _buildPieLegend(Colors.purple, 'Int. Inv.', copFormatter.format(totalInterestPaidInvestors)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ═══ RESUMEN DE CAPITAL ═══
          _buildSectionHeader('Resumen de Capital', isDark),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Column(
              children: [
                _buildMetricRow('Total Capital Prestado', copFormatter.format(totalCapitalLent), const Color(0xFF7C4DFF), isDark),
                _buildMetricRow('Capital Recuperado', copFormatter.format(totalCapitalRecovered), Colors.teal, isDark),
                _buildMetricRow('Capital en Cartera', copFormatter.format(totalCapitalLent - totalCapitalRecovered), AppTheme.primaryColor, isDark),
                const Divider(height: 24),
                _buildMetricRow('Inversiones Recibidas', copFormatter.format(totalInvReceived), Colors.blue, isDark),
                _buildMetricRow('Devuelto a Inversores', copFormatter.format(totalReturnedInvestors), Colors.orange, isDark),
                _buildMetricRow('Deuda a Inversores', copFormatter.format(totalInvReceived - totalReturnedInvestors), AppTheme.errorColor, isDark),
                const Divider(height: 24),
                _buildMetricRow('Intereses Cobrados', copFormatter.format(totalInterestEarned), Colors.blueAccent, isDark),
                _buildMetricRow('Mora Cobrada', copFormatter.format(totalMoraEarned), Colors.amber, isDark),
                _buildMetricRow('Gastos Operativos', copFormatter.format(totalExpenses), Colors.redAccent, isDark),
                _buildMetricRow('Int. Pagados a Inversores', copFormatter.format(totalInterestPaidInvestors), Colors.purple, isDark),
                if (totalAdjustments != 0)
                  _buildMetricRow('Ajustes Manuales de Caja', copFormatter.format(totalAdjustments), Colors.amber, isDark),
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
      title: 'Pagos y Ganancias',
      child: content,
    );
  }

  // ═══ WIDGETS AUXILIARES ═══

  Widget _buildGlowCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: 280,
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
          BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 16, spreadRadius: 2),
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

  Widget _buildLegendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildPieLegend(Color color, String label, String value) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        ],
      ),
    );
  }
}
