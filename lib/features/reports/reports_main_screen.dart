import 'package:finanzas_app/core/enums/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/responsive_sidebar_scaffold.dart';
import '../../core/models/user_model.dart';
import '../../core/services/rbac_service.dart';
import 'upcoming_payments_report_screen.dart';
import 'disbursements_report_screen.dart';
import 'historical_portfolio_report_screen.dart';
import 'profit_report_screen.dart';
import 'balance_sheet_report_screen.dart';

class ReportsMainScreen extends ConsumerStatefulWidget {
  const ReportsMainScreen({super.key});

  @override
  ConsumerState<ReportsMainScreen> createState() => _ReportsMainScreenState();
}

class _ReportsMainScreenState extends ConsumerState<ReportsMainScreen> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserModelProvider);
    final selectedIndex = userAsync.maybeWhen(
      data: (user) => user?.role == UserRole.admin ? 5 : 3,
      orElse: () => 5,
    );

    return ResponsiveSidebarScaffold(
      selectedIndex: selectedIndex,
      title: 'Módulo de Informes',
      child: DefaultTabController(
        length: 5,
        child: Column(
          children: [
            Container(
              color: Theme.of(context).cardTheme.color,
              child: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Pagos y Ganancias'),
                  Tab(text: 'Capital y Cartera'),
                  Tab(text: 'Balance General'),
                  Tab(text: 'Programación de Pagos'),
                  Tab(text: 'Desembolsos y Saldos'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                physics: NeverScrollableScrollPhysics(),
                children: [
                  ProfitReportScreen(isEmbedded: true),
                  HistoricalPortfolioReportScreen(isEmbedded: true),
                  BalanceSheetReportScreen(isEmbedded: true),
                  UpcomingPaymentsReportScreen(isEmbedded: true),
                  DisbursementsReportScreen(isEmbedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

