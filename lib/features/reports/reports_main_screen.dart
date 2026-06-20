import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/responsive_sidebar_scaffold.dart';
import '../../core/models/user_model.dart';
import '../../core/services/rbac_service.dart';
import 'upcoming_payments_report_screen.dart';
import 'disbursements_report_screen.dart';
import 'historical_portfolio_report_screen.dart';

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
      data: (user) => user?.role == UserRole.admin ? 4 : 3,
      orElse: () => 3,
    );

    return ResponsiveSidebarScaffold(
      selectedIndex: selectedIndex,
      title: 'Módulo de Informes',
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              color: Theme.of(context).cardTheme.color,
              child: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Próximos Pagos'),
                  Tab(text: 'Desembolsos y Saldos'),
                  Tab(text: 'Evolución y Ganancias'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                physics: NeverScrollableScrollPhysics(),
                children: [
                  UpcomingPaymentsReportScreen(isEmbedded: true),
                  DisbursementsReportScreen(isEmbedded: true),
                  HistoricalPortfolioReportScreen(isEmbedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
