import 'package:finanzas_app/core/repositories/credits_repository.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../shared/theme/app_theme.dart';
import '../../core/models/credit_model.dart';
import '../../core/services/firestore_service.dart';

enum DisbursementPeriod {
  daily,
  weekly,
  monthly,
  quarterly,
  biannual,
  yearly,
}

class _DisbursementPeriodData {
  int count = 0;
  double principalLent = 0;
  double pendingPrincipal = 0;
  double pendingInterest = 0;
  double pendingMora = 0;

  double get pendingTotal => pendingPrincipal + pendingInterest + pendingMora;
}

enum DisbursementMetric {
  cantidad,
  valorPrestado,
  saldoCapital,
  saldoInteres,
  saldoMora,
  saldoTotal
}

class DisbursementsReportScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const DisbursementsReportScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<DisbursementsReportScreen> createState() => _DisbursementsReportScreenState();
}

class _DisbursementsReportScreenState extends ConsumerState<DisbursementsReportScreen> {
  final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  DisbursementPeriod _selectedPeriod = DisbursementPeriod.monthly;
  int _chartPeriodsToDisplay = 6;
  DisbursementMetric _selectedMetric = DisbursementMetric.saldoTotal;

  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  DateTime _getPeriodStart(DateTime date, DisbursementPeriod resolution) {
    switch (resolution) {
      case DisbursementPeriod.daily:
        return DateTime(date.year, date.month, date.day);
      case DisbursementPeriod.weekly:
        return DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
      case DisbursementPeriod.monthly:
        return DateTime(date.year, date.month, 1);
      case DisbursementPeriod.quarterly:
        int qMonth = ((date.month - 1) ~/ 3) * 3 + 1;
        return DateTime(date.year, qMonth, 1);
      case DisbursementPeriod.biannual:
        int hMonth = ((date.month - 1) ~/ 6) * 6 + 1;
        return DateTime(date.year, hMonth, 1);
      case DisbursementPeriod.yearly:
        return DateTime(date.year, 1, 1);
    }
  }

  DateTime _getPrevPeriod(DateTime current, DisbursementPeriod resolution) {
    switch (resolution) {
      case DisbursementPeriod.daily:
        return current.subtract(const Duration(days: 1));
      case DisbursementPeriod.weekly:
        return current.subtract(const Duration(days: 7));
      case DisbursementPeriod.monthly:
        return DateTime(current.year, current.month - 1, 1);
      case DisbursementPeriod.quarterly:
        return DateTime(current.year, current.month - 3, 1);
      case DisbursementPeriod.biannual:
        return DateTime(current.year, current.month - 6, 1);
      case DisbursementPeriod.yearly:
        return DateTime(current.year - 1, 1, 1);
    }
  }

  String _formatPeriodLabel(DateTime date, DisbursementPeriod resolution) {
    switch (resolution) {
      case DisbursementPeriod.daily:
        return DateFormat('dd MMM').format(date);
      case DisbursementPeriod.weekly:
        final end = date.add(const Duration(days: 6));
        return '${date.day}-${end.day} ${DateFormat('MMM').format(date)}';
      case DisbursementPeriod.monthly:
        return DateFormat('MMM yy').format(date);
      case DisbursementPeriod.quarterly:
        int quarter = ((date.month - 1) ~/ 3) + 1;
        return 'Q$quarter ${date.year.toString().substring(2)}';
      case DisbursementPeriod.biannual:
        int half = ((date.month - 1) ~/ 6) + 1;
        return 'S$half ${date.year.toString().substring(2)}';
      case DisbursementPeriod.yearly:
        return '${date.year}';
    }
  }

  String _getMetricLabel(DisbursementMetric metric) {
    switch (metric) {
      case DisbursementMetric.cantidad: return 'Cantidad de Créditos';
      case DisbursementMetric.valorPrestado: return 'Valor Prestado';
      case DisbursementMetric.saldoCapital: return 'Saldo a Capital';
      case DisbursementMetric.saldoInteres: return 'Saldo de Interés';
      case DisbursementMetric.saldoMora: return 'Saldo de Mora';
      case DisbursementMetric.saldoTotal: return 'Saldo Total (Cap+Int+Mora)';
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
    final creditsAsync = ref.watch(creditsRepositoryProvider).getAllCreditsStream();

    return StreamBuilder<List<CreditModel>>(
      stream: creditsAsync,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final credits = snapshot.data ?? [];
        
        // Group by period
        final Map<DateTime, _DisbursementPeriodData> dataByPeriod = {};
        for (var c in credits) {
          final pStart = _getPeriodStart(c.disbursementDate, _selectedPeriod);
          dataByPeriod.putIfAbsent(pStart, () => _DisbursementPeriodData());
          final md = dataByPeriod[pStart]!;
          
          md.count += 1;
          md.principalLent += c.principalAmount;
          
          double pCapital = c.principalAmount - c.totalPaidPrincipal;
          double pInterest = c.totalInterest - c.totalPaidInterest;
          double pMora = c.accumulatedMora - c.totalPaidMora;
          
          md.pendingPrincipal += pCapital > 0 ? pCapital : 0;
          md.pendingInterest += pInterest > 0 ? pInterest : 0;
          md.pendingMora += pMora > 0 ? pMora : 0;
        }

        // Generate contiguous periods for the chart
        final now = DateTime.now();
        DateTime latestPeriod = _getPeriodStart(now, _selectedPeriod);
        
        // If there is data in the future, maybe adjust latestPeriod? No, disbursement is usually past/present.
        if (dataByPeriod.isNotEmpty) {
          final maxDate = dataByPeriod.keys.reduce((a, b) => a.isAfter(b) ? a : b);
          if (maxDate.isAfter(latestPeriod)) {
            latestPeriod = maxDate;
          }
        }

        List<DateTime> contiguousPeriods = [];
        DateTime current = latestPeriod;
        for (int i = 0; i < _chartPeriodsToDisplay; i++) {
          contiguousPeriods.add(current);
          current = _getPrevPeriod(current, _selectedPeriod);
        }
        contiguousPeriods = contiguousPeriods.reversed.toList();
        
        for (var p in contiguousPeriods) {
          dataByPeriod.putIfAbsent(p, () => _DisbursementPeriodData());
        }

        // Table Data Sorting
        final tablePeriods = dataByPeriod.keys.toList();
        tablePeriods.sort((a, b) {
          int cmp = 0;
          if (_sortColumnIndex == 0) {
            cmp = a.compareTo(b);
          } else {
            final da = dataByPeriod[a]!;
            final db = dataByPeriod[b]!;
            switch (_sortColumnIndex) {
              case 1: cmp = da.count.compareTo(db.count); break;
              case 2: cmp = da.principalLent.compareTo(db.principalLent); break;
              case 3: cmp = da.pendingPrincipal.compareTo(db.pendingPrincipal); break;
              case 4: cmp = da.pendingInterest.compareTo(db.pendingInterest); break;
              case 5: cmp = da.pendingMora.compareTo(db.pendingMora); break;
              case 6: cmp = da.pendingTotal.compareTo(db.pendingTotal); break;
            }
          }
          return _sortAscending ? cmp : -cmp;
        });

        // Chart setup
        double maxY = 0;
        for (var p in contiguousPeriods) {
          final md = dataByPeriod[p]!;
          double val = 0;
          if (_selectedMetric == DisbursementMetric.cantidad) {
            val = md.count.toDouble();
          } else if (_selectedMetric == DisbursementMetric.valorPrestado) {
            val = md.principalLent;
          } else if (_selectedMetric == DisbursementMetric.saldoCapital) {
            val = md.pendingPrincipal;
          } else if (_selectedMetric == DisbursementMetric.saldoInteres) {
            val = md.pendingInterest;
          } else if (_selectedMetric == DisbursementMetric.saldoMora) {
            val = md.pendingMora;
          } else if (_selectedMetric == DisbursementMetric.saldoTotal) {
            val = md.pendingTotal;
          }
          if (val > maxY) maxY = val;
        }

        if (maxY == 0) maxY = 100;
        
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return SingleChildScrollView(
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
                    DropdownButton<DisbursementPeriod>(
                      value: _selectedPeriod,
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedPeriod = v);
                      },
                      items: const [
                        DropdownMenuItem(value: DisbursementPeriod.daily, child: Text('Días')),
                        DropdownMenuItem(value: DisbursementPeriod.weekly, child: Text('Semanas')),
                        DropdownMenuItem(value: DisbursementPeriod.monthly, child: Text('Meses')),
                        DropdownMenuItem(value: DisbursementPeriod.quarterly, child: Text('Trimestres')),
                        DropdownMenuItem(value: DisbursementPeriod.biannual, child: Text('Semestres')),
                        DropdownMenuItem(value: DisbursementPeriod.yearly, child: Text('Años')),
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
                    DropdownButton<DisbursementMetric>(
                      value: _selectedMetric,
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedMetric = v);
                      },
                      items: DisbursementMetric.values.map((m) {
                        return DropdownMenuItem(value: m, child: Text(_getMetricLabel(m)));
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Gráfica ---
              _buildSectionHeader('Evolución', isDark),
              const SizedBox(height: 16),
              Container(
                height: 300,
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
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY * 1.2,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => isDark ? const Color(0xFF1A1A2E) : Colors.grey.shade200,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final date = contiguousPeriods[group.x];
                          final md = dataByPeriod[date]!;
                          String valStr = '';
                          if (_selectedMetric == DisbursementMetric.cantidad) {
                            valStr = md.count.toString();
                          } else if (_selectedMetric == DisbursementMetric.valorPrestado) {
                            valStr = copFormatter.format(md.principalLent);
                          } else if (_selectedMetric == DisbursementMetric.saldoCapital) {
                            valStr = copFormatter.format(md.pendingPrincipal);
                          } else if (_selectedMetric == DisbursementMetric.saldoInteres) {
                            valStr = copFormatter.format(md.pendingInterest);
                          } else if (_selectedMetric == DisbursementMetric.saldoMora) {
                            valStr = copFormatter.format(md.pendingMora);
                          } else if (_selectedMetric == DisbursementMetric.saldoTotal) {
                            valStr = copFormatter.format(md.pendingTotal);
                          }
                          return BarTooltipItem(
                            '${_formatPeriodLabel(date, _selectedPeriod)}\n$valStr',
                            TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() < 0 || value.toInt() >= contiguousPeriods.length) {
                              return const SizedBox();
                            }
                            final date = contiguousPeriods[value.toInt()];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _formatPeriodLabel(date, _selectedPeriod),
                                style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87),
                              ),
                            );
                          },
                          reservedSize: 32,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox();
                            return Text(
                              _selectedMetric == DisbursementMetric.cantidad 
                                  ? value.toInt().toString() 
                                  : '\$${(value / 1000).toStringAsFixed(0)}k',
                              style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54),
                            );
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
                    barGroups: List.generate(contiguousPeriods.length, (i) {
                      final md = dataByPeriod[contiguousPeriods[i]]!;
                      
                      double yVal = 0;
                      if (_selectedMetric == DisbursementMetric.cantidad) yVal = md.count.toDouble();
                      if (_selectedMetric == DisbursementMetric.valorPrestado) yVal = md.principalLent;
                      if (_selectedMetric == DisbursementMetric.saldoCapital) yVal = md.pendingPrincipal;
                      if (_selectedMetric == DisbursementMetric.saldoInteres) yVal = md.pendingInterest;
                      if (_selectedMetric == DisbursementMetric.saldoMora) yVal = md.pendingMora;
                      if (_selectedMetric == DisbursementMetric.saldoTotal) yVal = md.pendingTotal;

                      List<BarChartRodStackItem> stackItems = [];
                      if (_selectedMetric == DisbursementMetric.saldoTotal && yVal > 0) {
                        // Stacked for Saldo Total
                        double acc = 0;
                        if (md.pendingPrincipal > 0) {
                          stackItems.add(BarChartRodStackItem(acc, acc + md.pendingPrincipal, const Color(0xFF3D8BFF)));
                          acc += md.pendingPrincipal;
                        }
                        if (md.pendingInterest > 0) {
                          stackItems.add(BarChartRodStackItem(acc, acc + md.pendingInterest, const Color(0xFF00E5FF)));
                          acc += md.pendingInterest;
                        }
                        if (md.pendingMora > 0) {
                          stackItems.add(BarChartRodStackItem(acc, acc + md.pendingMora, const Color(0xFF00FFCC)));
                          acc += md.pendingMora;
                        }
                      }

                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: yVal,
                            color: _selectedMetric == DisbursementMetric.saldoTotal ? Colors.transparent : null,
                            gradient: _selectedMetric != DisbursementMetric.saldoTotal
                                ? const LinearGradient(
                                    colors: [Color(0xFF3D8BFF), Color(0xFF00E5FF)],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  )
                                : null,
                            width: 20,
                            borderRadius: BorderRadius.circular(4),
                            rodStackItems: stackItems.isNotEmpty ? stackItems : null,
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxY * 1.2,
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),

              if (_selectedMetric == DisbursementMetric.saldoTotal)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(const Color(0xFF3D8BFF), 'Capital'),
                      const SizedBox(width: 16),
                      _buildLegendItem(const Color(0xFF00E5FF), 'Interés'),
                      const SizedBox(width: 16),
                      _buildLegendItem(const Color(0xFF00FFCC), 'Mora'),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // --- Tabla de Datos ---
              _buildSectionHeader('Detalle por Periodo', isDark),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14141E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    sortColumnIndex: _sortColumnIndex,
                    sortAscending: _sortAscending,
                    columns: [
                      DataColumn(label: const Text('Periodo'), onSort: _onSort),
                      DataColumn(label: const Text('Cantidad'), numeric: true, onSort: _onSort),
                      DataColumn(label: const Text('Valor Prestado'), numeric: true, onSort: _onSort),
                      DataColumn(label: const Text('Saldo Capital'), numeric: true, onSort: _onSort),
                      DataColumn(label: const Text('Saldo Interés'), numeric: true, onSort: _onSort),
                      DataColumn(label: const Text('Saldo Mora'), numeric: true, onSort: _onSort),
                      DataColumn(label: const Text('Saldo Total'), numeric: true, onSort: _onSort),
                    ],
                    rows: tablePeriods.map((p) {
                      final md = dataByPeriod[p]!;
                      return DataRow(
                        cells: [
                          DataCell(Text(_formatPeriodLabel(p, _selectedPeriod))),
                          DataCell(Text('${md.count}')),
                          DataCell(Text(copFormatter.format(md.principalLent))),
                          DataCell(Text(copFormatter.format(md.pendingPrincipal))),
                          DataCell(Text(copFormatter.format(md.pendingInterest))),
                          DataCell(Text(copFormatter.format(md.pendingMora))),
                          DataCell(Text(
                            copFormatter.format(md.pendingTotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      }
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

  Widget _buildLegendItem(Color color, String text) {
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
