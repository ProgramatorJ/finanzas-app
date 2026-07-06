import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/theme/app_theme.dart';

import '../../core/models/credit_model.dart';
import '../calendar/calendar_providers.dart'; // Para joinedInstallmentsProvider
import '../credits/credit_list_screen.dart'; // Para allCreditsStreamProvider, creditsClientsStreamProvider
import '../shared/financial_providers.dart'; // Para providers de Tesoreria

enum HistoricalPeriod {
  daily,
  weekly,
  monthly,
  quarterly,
  biannual,
  yearly,
}

class _HistoricalPeriodData {
  double capitalCartera = 0; // Saldo de capital prestado a clientes (sin intereses)
  double capitalCaja = 0;    // Dinero en caja general
  double capitalTotal = 0;   // Caja + Cartera
  double interesMora = 0;    // Interés + Mora pendiente por cobrar
  double totalActivos = 0;   // Caja + Cartera + Interés + Mora (Total General)
}

class HistoricalPortfolioReportScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const HistoricalPortfolioReportScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<HistoricalPortfolioReportScreen> createState() => _HistoricalPortfolioReportScreenState();
}

class _HistoricalPortfolioReportScreenState extends ConsumerState<HistoricalPortfolioReportScreen> {
  final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  HistoricalPeriod _selectedPeriod = HistoricalPeriod.monthly;
  int _chartPeriodsToDisplay = 6;

  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  DateTime _getPeriodStart(DateTime date, HistoricalPeriod resolution) {
    switch (resolution) {
      case HistoricalPeriod.daily:
        return DateTime(date.year, date.month, date.day);
      case HistoricalPeriod.weekly:
        return DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
      case HistoricalPeriod.monthly:
        return DateTime(date.year, date.month, 1);
      case HistoricalPeriod.quarterly:
        int qMonth = ((date.month - 1) ~/ 3) * 3 + 1;
        return DateTime(date.year, qMonth, 1);
      case HistoricalPeriod.biannual:
        int hMonth = ((date.month - 1) ~/ 6) * 6 + 1;
        return DateTime(date.year, hMonth, 1);
      case HistoricalPeriod.yearly:
        return DateTime(date.year, 1, 1);
    }
  }

  DateTime _getPeriodEnd(DateTime start, HistoricalPeriod resolution) {
    switch (resolution) {
      case HistoricalPeriod.daily:
        return start.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
      case HistoricalPeriod.weekly:
        return start.add(const Duration(days: 7)).subtract(const Duration(microseconds: 1));
      case HistoricalPeriod.monthly:
        return DateTime(start.year, start.month + 1, 1).subtract(const Duration(microseconds: 1));
      case HistoricalPeriod.quarterly:
        return DateTime(start.year, start.month + 3, 1).subtract(const Duration(microseconds: 1));
      case HistoricalPeriod.biannual:
        return DateTime(start.year, start.month + 6, 1).subtract(const Duration(microseconds: 1));
      case HistoricalPeriod.yearly:
        return DateTime(start.year + 1, 1, 1).subtract(const Duration(microseconds: 1));
    }
  }

  DateTime _getPrevPeriod(DateTime current, HistoricalPeriod resolution) {
    switch (resolution) {
      case HistoricalPeriod.daily:
        return current.subtract(const Duration(days: 1));
      case HistoricalPeriod.weekly:
        return current.subtract(const Duration(days: 7));
      case HistoricalPeriod.monthly:
        return DateTime(current.year, current.month - 1, 1);
      case HistoricalPeriod.quarterly:
        return DateTime(current.year, current.month - 3, 1);
      case HistoricalPeriod.biannual:
        return DateTime(current.year, current.month - 6, 1);
      case HistoricalPeriod.yearly:
        return DateTime(current.year - 1, 1, 1);
    }
  }

  String _formatPeriodLabel(DateTime date, HistoricalPeriod resolution) {
    switch (resolution) {
      case HistoricalPeriod.daily:
        return DateFormat('dd MMM').format(date);
      case HistoricalPeriod.weekly:
        final end = date.add(const Duration(days: 6));
        return '${date.day}-${end.day} ${DateFormat('MMM').format(date)}';
      case HistoricalPeriod.monthly:
        return DateFormat('MMM yy').format(date);
      case HistoricalPeriod.quarterly:
        int quarter = ((date.month - 1) ~/ 3) + 1;
        return 'Q$quarter ${date.year.toString().substring(2)}';
      case HistoricalPeriod.biannual:
        int half = ((date.month - 1) ~/ 6) + 1;
        return 'S$half ${date.year.toString().substring(2)}';
      case HistoricalPeriod.yearly:
        return '${date.year}';
    }
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final creditsAsync = ref.watch(allCreditsStreamProvider);
    final clientsAsync = ref.watch(creditsClientsStreamProvider);
    final paymentsAsync = ref.watch(allPaymentsProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final investmentsAsync = ref.watch(investmentsStreamProvider);
    final investorPaymentsAsync = ref.watch(allInvestorPaymentsStreamProvider);
    final adjustmentsAsync = ref.watch(cashAdjustmentsStreamProvider);
    final centralMetricsAsync = ref.watch(financialMetricsProvider);

    final isLoading = creditsAsync.isLoading ||
        clientsAsync.isLoading ||
        paymentsAsync.isLoading ||
        expensesAsync.isLoading ||
        investmentsAsync.isLoading ||
        investorPaymentsAsync.isLoading ||
        adjustmentsAsync.isLoading ||
        centralMetricsAsync.isLoading;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final credits = creditsAsync.value ?? [];
    final clients = clientsAsync.value ?? [];
    final payments = paymentsAsync.value ?? [];
    final expenses = expensesAsync.value ?? [];
    final investments = investmentsAsync.value ?? [];
    final investorPayments = investorPaymentsAsync.value ?? [];
    final adjustments = adjustmentsAsync.value ?? [];
    final centralMetrics = centralMetricsAsync.value ?? FinancialMetrics(
      cajaActual: 0,
      carteraActivaCapital: 0,
      interesesPorCobrar: 0,
      moraAcumulada: 0,
      deudaInversores: 0,
      patrimonioNeto: 0,
      utilidadNeta: 0,
    );

    final clientMap = {for (final cl in clients) cl.clientId: cl};
    
    final activeCredits = credits.where((c) => c.status == CreditStatus.active || c.status == CreditStatus.restructured || c.outstandingBalance > 0).toList();

    activeCredits.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnIndex) {
        case 0: cmp = a.creditId.compareTo(b.creditId); break;
        case 1: cmp = a.disbursementDate.compareTo(b.disbursementDate); break;
        case 2: 
          final cA = clientMap[a.clientId]?.fullName ?? '';
          final cB = clientMap[b.clientId]?.fullName ?? '';
          cmp = cA.compareTo(cB); 
          break;
        case 3: cmp = a.clientId.compareTo(b.clientId); break;
        case 4: cmp = a.principalAmount.compareTo(b.principalAmount); break;
        case 5: cmp = a.termInMonths.compareTo(b.termInMonths); break;
        case 6: cmp = (a.totalAmount + a.accumulatedMora).compareTo(b.totalAmount + b.accumulatedMora); break;
        case 7: cmp = a.paymentFrequency.name.compareTo(b.paymentFrequency.name); break;
        case 8: cmp = a.numberOfInstallments.compareTo(b.numberOfInstallments); break;
        case 9: cmp = a.installmentAmount.compareTo(b.installmentAmount); break;
        case 10: cmp = a.totalPaid.compareTo(b.totalPaid); break;
        case 11: cmp = (a.principalAmount - a.totalPaidPrincipal).compareTo(b.principalAmount - b.totalPaidPrincipal); break;
        case 12: cmp = (a.totalInterest - a.totalPaidInterest).compareTo(b.totalInterest - b.totalPaidInterest); break;
        case 13: cmp = (a.accumulatedMora - a.totalPaidMora).compareTo(b.accumulatedMora - b.totalPaidMora); break;
        case 14: 
          final saldoA = (a.principalAmount - a.totalPaidPrincipal) + (a.totalInterest - a.totalPaidInterest) + (a.accumulatedMora - a.totalPaidMora);
          final saldoB = (b.principalAmount - b.totalPaidPrincipal) + (b.totalInterest - b.totalPaidInterest) + (b.accumulatedMora - b.totalPaidMora);
          cmp = saldoA.compareTo(saldoB); 
          break;
        case 15: cmp = a.status.name.compareTo(b.status.name); break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    final now = DateTime.now();
    DateTime latestPeriodStart = _getPeriodStart(now, _selectedPeriod);
    
    List<DateTime> contiguousPeriods = [];
    DateTime current = latestPeriodStart;
    for (int i = 0; i < _chartPeriodsToDisplay; i++) {
      contiguousPeriods.add(current);
      current = _getPrevPeriod(current, _selectedPeriod);
    }
    contiguousPeriods = contiguousPeriods.reversed.toList();

    final Map<DateTime, _HistoricalPeriodData> dataByPeriod = {};
    for (var p in contiguousPeriods) {
      dataByPeriod[p] = _HistoricalPeriodData();
    }

    for (var p in contiguousPeriods) {
      final pEnd = _getPeriodEnd(p, _selectedPeriod);
      final md = dataByPeriod[p]!;

      double totalCapitalDesembolsado = 0;
      double totalCapitalPagado = 0;
      double totalInteresEsperado = 0;
      double totalInteresPagado = 0;
      double totalMoraPendiente = 0;

      for (var c in credits) {
        if (c.disbursementDate.isBefore(pEnd) || c.disbursementDate.isAtSameMomentAs(pEnd)) {
          totalCapitalDesembolsado += c.principalAmount;
          totalInteresEsperado += c.totalInterest;
          
          double capitalPagado = 0;
          double interestPagado = 0;
          double moraPagada = 0;
          double totalMoraPagadaAllTime = 0;

          for (var pay in payments) {
            if (pay.creditId == c.creditId) {
              totalMoraPagadaAllTime += pay.appliedToMora;
              if (pay.paymentDate.isBefore(pEnd) || pay.paymentDate.isAtSameMomentAs(pEnd)) {
                capitalPagado += pay.appliedToPrincipal;
                interestPagado += pay.appliedToInterest;
                moraPagada += pay.appliedToMora;
              }
            }
          }
          totalCapitalPagado += capitalPagado;
          totalInteresPagado += interestPagado;

          if (capitalPagado < c.principalAmount) {
            double moraRem = (c.accumulatedMora - totalMoraPagadaAllTime + moraPagada).clamp(0.0, double.infinity);
            totalMoraPendiente += moraRem;
          }
        }
      }

      md.capitalCartera = totalCapitalDesembolsado - totalCapitalPagado;
      if (md.capitalCartera < 0) md.capitalCartera = 0;

      final double interesPendiente = (totalInteresEsperado - totalInteresPagado).clamp(0.0, double.infinity);
      md.interesMora = interesPendiente + totalMoraPendiente;

      // Calcular Caja General histórica al final de este periodo (pEnd)
      final DateTime cutoffDate = DateTime(2026, 7, 1);
      double recSubs = 0;
      for (var pay in payments) {
        if (!pay.paymentDate.isBefore(cutoffDate) && (pay.paymentDate.isBefore(pEnd) || pay.paymentDate.isAtSameMomentAs(pEnd))) {
          recSubs += pay.amountReceived;
        }
      }
      double invSubs = 0;
      for (var inv in investments) {
        if (!inv.createdAt.isBefore(cutoffDate) && (inv.createdAt.isBefore(pEnd) || inv.createdAt.isAtSameMomentAs(pEnd))) {
          invSubs += inv.amount;
        }
      }
      double credSubs = 0;
      for (var cred in credits) {
        if (!cred.disbursementDate.isBefore(cutoffDate) && (cred.disbursementDate.isBefore(pEnd) || cred.disbursementDate.isAtSameMomentAs(pEnd))) {
          credSubs += cred.principalAmount;
        }
      }
      double expSubs = 0;
      for (var e in expenses) {
        if (!e.date.isBefore(cutoffDate) && (e.date.isBefore(pEnd) || e.date.isAtSameMomentAs(pEnd))) {
          expSubs += e.amount;
        }
      }
      double ipSubs = 0;
      for (var ip in investorPayments) {
        if (!ip.paymentDate.isBefore(cutoffDate) && (ip.paymentDate.isBefore(pEnd) || ip.paymentDate.isAtSameMomentAs(pEnd))) {
          ipSubs += ip.amount;
        }
      }
      double adjSubs = 0;
      for (var adj in adjustments) {
        if (!adj.date.isBefore(cutoffDate) && (adj.date.isBefore(pEnd) || adj.date.isAtSameMomentAs(pEnd))) {
          adjSubs += adj.amount;
        }
      }

      md.capitalCaja = recSubs + invSubs - credSubs - expSubs - ipSubs + adjSubs;
      md.capitalTotal = md.capitalCartera + md.capitalCaja;
      md.totalActivos = md.capitalTotal + md.interesMora;
    }

    double maxY = 0;
    for (var p in contiguousPeriods) {
      final val = dataByPeriod[p]!.totalActivos;
      if (val > maxY) maxY = val;
    }
    if (maxY == 0) maxY = 100;

    final currentCaja = centralMetrics.cajaActual;
    final currentCartera = centralMetrics.carteraActivaCapital;
    final currentTotal = currentCaja + currentCartera;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<HistoricalPeriod>(
                  value: _selectedPeriod,
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedPeriod = v);
                  },
                  items: const [
                    DropdownMenuItem(value: HistoricalPeriod.daily, child: Text('Días')),
                    DropdownMenuItem(value: HistoricalPeriod.weekly, child: Text('Semanas')),
                    DropdownMenuItem(value: HistoricalPeriod.monthly, child: Text('Meses')),
                    DropdownMenuItem(value: HistoricalPeriod.quarterly, child: Text('Trimestres')),
                    DropdownMenuItem(value: HistoricalPeriod.biannual, child: Text('Semestres')),
                    DropdownMenuItem(value: HistoricalPeriod.yearly, child: Text('Años')),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Mostrar: '),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        if (_chartPeriodsToDisplay > 2) {
                          setState(() => _chartPeriodsToDisplay--);
                        }
                      },
                    ),
                    Text('$_chartPeriodsToDisplay', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        if (_chartPeriodsToDisplay < 30) {
                          setState(() => _chartPeriodsToDisplay++);
                        }
                      },
                    ),
                    const Text(' periodos'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tarjetas de Resumen de Capital
          Center(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _buildCapitalCard(
                  title: 'Capital en Caja',
                  subtitle: 'Disponible líquido (Jul/26+)',
                  value: copFormatter.format(currentCaja),
                  icon: Icons.wallet_rounded,
                  color: const Color(0xFF7E9CD8),
                  isDark: isDark,
                ),
                _buildCapitalCard(
                  title: 'Capital en Cartera',
                  subtitle: 'Créditos activos colocados',
                  value: copFormatter.format(currentCartera),
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF3D8BFF),
                  isDark: isDark,
                ),
                _buildCapitalCard(
                  title: 'Capital Total',
                  subtitle: 'Suma de Caja y Cartera',
                  value: copFormatter.format(currentTotal),
                  icon: Icons.account_balance_rounded,
                  color: const Color(0xFF00E5FF),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          _buildSectionHeader('Evolución del Capital y Cartera', isDark),
          const SizedBox(height: 16),
          Container(
            height: 350,
            padding: const EdgeInsets.only(top: 24, right: 24, left: 16, bottom: 16),
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
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < 0 || value.toInt() >= contiguousPeriods.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _formatPeriodLabel(contiguousPeriods[value.toInt()], _selectedPeriod),
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87),
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
                        if (value == 0) return const SizedBox();
                        return Text(
                          '\$${(value / 1000).toStringAsFixed(0)}k',
                          style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: -0.2,
                maxX: (contiguousPeriods.length - 0.5).toDouble(),
                minY: 0,
                maxY: maxY * 1.15,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(contiguousPeriods.length, (i) {
                      return FlSpot(i.toDouble(), dataByPeriod[contiguousPeriods[i]]!.interesMora);
                    }),
                    isCurved: true,
                    gradient: const LinearGradient(colors: [Color(0xFFAEC4EB), Color(0xFFC5D4F0)]),
                    barWidth: 1.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: const Color(0xFFAEC4EB),
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [const Color(0xFFAEC4EB).withValues(alpha: 0.06), const Color(0xFFAEC4EB).withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: List.generate(contiguousPeriods.length, (i) {
                      return FlSpot(i.toDouble(), dataByPeriod[contiguousPeriods[i]]!.capitalCaja);
                    }),
                    isCurved: true,
                    gradient: const LinearGradient(colors: [Color(0xFF7E9CD8), Color(0xFF9EBAE8)]),
                    barWidth: 1.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: const Color(0xFF7E9CD8),
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [const Color(0xFF7E9CD8).withValues(alpha: 0.06), const Color(0xFF7E9CD8).withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: List.generate(contiguousPeriods.length, (i) {
                      return FlSpot(i.toDouble(), dataByPeriod[contiguousPeriods[i]]!.capitalCartera);
                    }),
                    isCurved: true,
                    gradient: const LinearGradient(colors: [Color(0xFF3D8BFF), Color(0xFF6BA0FF)]),
                    barWidth: 1.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: const Color(0xFF3D8BFF),
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [const Color(0xFF3D8BFF).withValues(alpha: 0.06), const Color(0xFF3D8BFF).withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: List.generate(contiguousPeriods.length, (i) {
                      return FlSpot(i.toDouble(), dataByPeriod[contiguousPeriods[i]]!.capitalTotal);
                    }),
                    isCurved: true,
                    gradient: const LinearGradient(colors: [Color(0xFF00B0FF), Color(0xFF00E5FF)]),
                    barWidth: 1.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: const Color(0xFF00B0FF),
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [const Color(0xFF00B0FF).withValues(alpha: 0.08), const Color(0xFF00B0FF).withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: List.generate(contiguousPeriods.length, (i) {
                      return FlSpot(i.toDouble(), dataByPeriod[contiguousPeriods[i]]!.totalActivos);
                    }),
                    isCurved: true,
                    gradient: const LinearGradient(colors: [Color(0xFF00F0FF), Color(0xFF00FFCC)]),
                    barWidth: 2.2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: const Color(0xFF00F0FF),
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [const Color(0xFF00F0FF).withValues(alpha: 0.12), const Color(0xFF00F0FF).withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => isDark ? const Color(0xFF1A1A2E) : Colors.grey.shade200,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final date = contiguousPeriods[spot.x.toInt()];
                        String label = '';
                        if (spot.barIndex == 0) label = 'Int+Mora: ';
                        if (spot.barIndex == 1) label = 'Caja: ';
                        if (spot.barIndex == 2) label = 'Cartera: ';
                        if (spot.barIndex == 3) label = 'Cap. Total: ';
                        if (spot.barIndex == 4) label = 'Total Activos: ';
                        return LineTooltipItem(
                          '$label${copFormatter.format(spot.y)}',
                          TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendDot(const Color(0xFFAEC4EB), 'Interés + Mora x Cobrar'),
                _buildLegendDot(const Color(0xFF7E9CD8), 'Capital en Caja'),
                _buildLegendDot(const Color(0xFF3D8BFF), 'Capital en Cartera'),
                _buildLegendDot(const Color(0xFF00B0FF), 'Capital Total'),
                _buildLegendDot(const Color(0xFF00F0FF), 'Total Activos (Caja+Cart+Int+Mora)'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Detalle de Créditos Activos', isDark),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: activeCredits.isEmpty 
              ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No hay créditos activos')))
              : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                columns: [
                  DataColumn(label: const Text('ID Crédito'), onSort: _onSort),
                  DataColumn(label: const Text('Fecha Inicio'), onSort: _onSort),
                  DataColumn(label: const Text('Cliente'), onSort: _onSort),
                  DataColumn(label: const Text('ID Cliente'), onSort: _onSort),
                  DataColumn(label: const Text('Valor Crédito'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Plazo'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Total (C+I+M)'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Periodo'), onSort: _onSort),
                  DataColumn(label: const Text('Cuotas'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Valor Cuota'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Pagado'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Saldo Capital'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Saldo Interés'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Saldo Mora'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Saldo Total'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Estado'), onSort: _onSort),
                ],
                rows: activeCredits.map((c) {
                  final clientName = clientMap[c.clientId]?.fullName ?? 'Desconocido';
                  final totalCIM = c.totalAmount + c.accumulatedMora;
                  final saldoCap = c.principalAmount - c.totalPaidPrincipal;
                  final saldoInt = c.totalInterest - c.totalPaidInterest;
                  final saldoMora = c.accumulatedMora - c.totalPaidMora;
                  final saldoTotal = saldoCap + saldoInt + saldoMora;

                  return DataRow(
                    cells: [
                      DataCell(Text(c.creditId.length > 8 ? c.creditId.substring(0,8) : c.creditId)),
                      DataCell(Text(DateFormat('dd/MM/yyyy').format(c.disbursementDate))),
                      DataCell(Text(clientName)),
                      DataCell(Text(c.clientId.length > 8 ? c.clientId.substring(0,8) : c.clientId)),
                      DataCell(Text(copFormatter.format(c.principalAmount))),
                      DataCell(Text('${c.termInMonths} m')),
                      DataCell(Text(copFormatter.format(totalCIM))),
                      DataCell(Text(c.paymentFrequency.name)),
                      DataCell(Text('${c.numberOfInstallments}')),
                      DataCell(Text(copFormatter.format(c.installmentAmount))),
                      DataCell(Text(copFormatter.format(c.totalPaid), style: const TextStyle(color: Colors.green))),
                      DataCell(Text(copFormatter.format(saldoCap))),
                      DataCell(Text(copFormatter.format(saldoInt))),
                      DataCell(Text(copFormatter.format(saldoMora))),
                      DataCell(Text(copFormatter.format(saldoTotal), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(c.status.name.toUpperCase())),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Capital Total')),
      body: content,
    );
  }

  Widget _buildCapitalCard({
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
}
