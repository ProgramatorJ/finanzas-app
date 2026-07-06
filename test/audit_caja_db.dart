import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Audit Caja Db', () async {
    print('--- STARTING DATABASE AUDIT ---');
    
    // Inicializar Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final db = FirebaseFirestore.instance;
    final DateTime cutoffDate = DateTime(2026, 7, 1);

    print('Cutoff Date: $cutoffDate');

    // 1. Obtener Ajustes Manuales
    final adjSnap = await db.collection('cash_adjustments').get();
    double totalAdjustments = 0;
    print('\n[AJUSTES MANUALES >= 01/07/2026]');
    for (var doc in adjSnap.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp).toDate();
      final amount = (data['amount'] as num).toDouble();
      final desc = data['description'] ?? '';
      if (!date.isBefore(cutoffDate)) {
        totalAdjustments += amount;
        print('- Fecha: $date, Monto: $amount, Desc: $desc');
      }
    }
    print('Total Ajustes: $totalAdjustments');

    // 2. Obtener Cobros de Clientes (Pagos en subcolecciones)
    double totalPayments = 0;
    final paymentsSnap = await db.collectionGroup('payments').get();
    print('\n[COBROS DE CLIENTES >= 01/07/2026]');
    for (var doc in paymentsSnap.docs) {
      final data = doc.data();
      final date = (data['paymentDate'] as Timestamp).toDate();
      final amount = (data['amountReceived'] as num).toDouble();
      final principal = (data['appliedToPrincipal'] as num?)?.toDouble() ?? 0.0;
      final interest = (data['appliedToInterest'] as num?)?.toDouble() ?? 0.0;
      final mora = (data['appliedToMora'] as num?)?.toDouble() ?? 0.0;
      if (!date.isBefore(cutoffDate)) {
        totalPayments += amount;
        print('- Fecha: $date, Cobro: $amount (Cap: $principal, Int: $interest, Mora: $mora)');
      }
    }
    print('Total Cobros: $totalPayments');

    // 3. Obtener Inversiones (Inversionistas)
    double totalInvestments = 0;
    final invSnap = await db.collection('investments').get();
    print('\n[INVERSIONES RECIBIDAS >= 01/07/2026]');
    for (var doc in invSnap.docs) {
      final data = doc.data();
      final date = (data['createdAt'] as Timestamp?)?.toDate() ?? cutoffDate; // fallback
      final amount = (data['amount'] as num).toDouble();
      final name = data['investorName'] ?? '';
      if (!date.isBefore(cutoffDate)) {
        totalInvestments += amount;
        print('- Fondeador: $name, Monto: $amount, Creado: $date');
      }
    }
    print('Total Inversiones: $totalInvestments');

    // 4. Obtener Créditos Desembolsados
    double totalCredits = 0;
    final creditsSnap = await db.collection('credits').get();
    print('\n[CRÉDITOS DESEMBOLSADOS >= 01/07/2026]');
    for (var doc in creditsSnap.docs) {
      final data = doc.data();
      final date = (data['disbursementDate'] as Timestamp).toDate();
      final amount = (data['principalAmount'] as num).toDouble();
      final client = data['clientName'] ?? '';
      if (!date.isBefore(cutoffDate)) {
        totalCredits += amount;
        print('- Cliente: $client, Monto: $amount, Desembolso: $date');
      }
    }
    print('Total Créditos: $totalCredits');

    // 5. Obtener Gastos Operativos
    double totalExpenses = 0;
    final expSnap = await db.collection('expenses').get();
    print('\n[GASTOS OPERATIVOS >= 01/07/2026]');
    for (var doc in expSnap.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp).toDate();
      final amount = (data['amount'] as num).toDouble();
      final desc = data['description'] ?? '';
      if (!date.isBefore(cutoffDate)) {
        totalExpenses += amount;
        print('- Gasto: $desc, Monto: $amount, Fecha: $date');
      }
    }
    print('Total Gastos: $totalExpenses');

    // 6. Obtener Pagos a Inversores
    double totalInvestorPayments = 0;
    final ipSnap = await db.collectionGroup('investor_payments').get();
    print('\n[PAGOS A INVERSORES >= 01/07/2026]');
    for (var doc in ipSnap.docs) {
      final data = doc.data();
      final date = (data['paymentDate'] as Timestamp).toDate();
      final amount = (data['amount'] as num).toDouble();
      final concept = data['concept'] ?? '';
      if (!date.isBefore(cutoffDate)) {
        totalInvestorPayments += amount;
        print('- Concepto: $concept, Pago: $amount, Fecha: $date');
      }
    }
    print('Total Pagos a Inversores: $totalInvestorPayments');

    // Balance Final en Caja
    final double saldoCalculado = totalPayments + totalInvestments + totalAdjustments - totalCredits - totalExpenses - totalInvestorPayments;
    print('\n=== RESUMEN CONTABLE CAJA (DESDE 01/07/2026) ===');
    print('(+) Cobros de Clientes:    $totalPayments');
    print('(+) Inversiones Recibidas: $totalInvestments');
    print('(+) Ajustes de Caja:       $totalAdjustments');
    print('(-) Créditos Otorgados:    $totalCredits');
    print('(-) Gastos Operativos:     $totalExpenses');
    print('(-) Pagos a Inversores:    $totalInvestorPayments');
    print('-------------------------------------------');
    print('(=) SALDO EN CAJA:         $saldoCalculado');
    print('=== FIN AUDIT ===');
  });
}
