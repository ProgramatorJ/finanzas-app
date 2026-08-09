import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../enums/credit_status.dart';
import '../enums/payment_frequency.dart';




class CreditModel extends Equatable {
  final String creditId;
  final String clientId;
  final String createdByUid;
  final List<String> assignedCollectorIds;

  // Parámetros de crédito (Editables)
  final double principalAmount;        // Monto del capital (en centavos o unidad mínima recomendada para evitar flotantes)
  final double monthlyInterestRate;    // Tasa de interés mensual (Ej: 0.10 para 10%)
  final double dailyMoraRate;          // Tasa de mora diaria (Ej: 0.007 para 0.7%)
  final int termInMonths;              // Plazo en meses
  final PaymentFrequency paymentFrequency;

  // Totales calculados al crear
  final double totalInterest;
  final double totalAmount;            // Principal + totalInterest
  final double installmentAmount;      // Valor de cada cuota
  final int numberOfInstallments;

  // Calendario
  final DateTime disbursementDate;
  final DateTime firstInstallmentDate; // Editable por el usuario

  // Estado financiero actualizable en tiempo real
  final CreditStatus status;
  final int paidInstallments;
  final double totalPaid;
  final double totalPaidPrincipal;
  final double totalPaidInterest;
  final double totalPaidMora;
  final double outstandingBalance;     // Saldo total pendiente (inicialmente totalAmount)
  final double currentConsolidatedDebt; // Deuda consolidada (bola de nieve)
  final double accumulatedMora;         // Mora acumulada hasta hoy

  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  CreditModel({
    required this.creditId,
    required this.clientId,
    required this.createdByUid,
    this.assignedCollectorIds = const [],
    required this.principalAmount,
    required this.monthlyInterestRate,
    required this.dailyMoraRate,
    required this.termInMonths,
    required this.paymentFrequency,
    required this.totalInterest,
    required this.totalAmount,
    required this.installmentAmount,
    required this.numberOfInstallments,
    required this.disbursementDate,
    required this.firstInstallmentDate,
    required this.status,
    required this.paidInstallments,
    required this.totalPaid,
    required this.totalPaidPrincipal,
    required this.totalPaidInterest,
    required this.totalPaidMora,
    required this.outstandingBalance,
    required this.currentConsolidatedDebt,
    required this.accumulatedMora,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CreditModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CreditModel(
      creditId: documentId,
      clientId: map['clientId'] ?? '',
      createdByUid: map['createdByUid'] ?? '',
      assignedCollectorIds: List<String>.from(map['assignedCollectorIds'] ?? []),
      principalAmount: (map['principalAmount'] as num?)?.toDouble() ?? 0.0,
      monthlyInterestRate: (map['monthlyInterestRate'] as num?)?.toDouble() ?? 0.10,
      dailyMoraRate: (map['dailyMoraRate'] as num?)?.toDouble() ?? 0.007,
      termInMonths: map['termInMonths'] ?? 1,
      paymentFrequency: PaymentFrequency.fromString(map['paymentFrequency'] ?? 'monthly'),
      totalInterest: (map['totalInterest'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      installmentAmount: (map['installmentAmount'] as num?)?.toDouble() ?? 0.0,
      numberOfInstallments: map['numberOfInstallments'] ?? 1,
      disbursementDate: (map['disbursementDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      firstInstallmentDate: (map['firstInstallmentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: CreditStatus.fromString(map['status'] ?? 'active'),
      paidInstallments: map['paidInstallments'] ?? 0,
      totalPaid: (map['totalPaid'] as num?)?.toDouble() ?? 0.0,
      totalPaidPrincipal: (map['totalPaidPrincipal'] as num?)?.toDouble() ?? 0.0,
      totalPaidInterest: (map['totalPaidInterest'] as num?)?.toDouble() ?? 0.0,
      totalPaidMora: (map['totalPaidMora'] as num?)?.toDouble() ?? 0.0,
      outstandingBalance: (map['outstandingBalance'] as num?)?.toDouble() ?? 0.0,
      currentConsolidatedDebt: (map['currentConsolidatedDebt'] as num?)?.toDouble() ?? 0.0,
      accumulatedMora: (map['accumulatedMora'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'createdByUid': createdByUid,
      'assignedCollectorIds': assignedCollectorIds,
      'principalAmount': principalAmount,
      'monthlyInterestRate': monthlyInterestRate,
      'dailyMoraRate': dailyMoraRate,
      'termInMonths': termInMonths,
      'paymentFrequency': paymentFrequency.name,
      'totalInterest': totalInterest,
      'totalAmount': totalAmount,
      'installmentAmount': installmentAmount,
      'numberOfInstallments': numberOfInstallments,
      'disbursementDate': Timestamp.fromDate(disbursementDate),
      'firstInstallmentDate': Timestamp.fromDate(firstInstallmentDate),
      'status': status.name,
      'paidInstallments': paidInstallments,
      'totalPaid': totalPaid,
      'totalPaidPrincipal': totalPaidPrincipal,
      'totalPaidInterest': totalPaidInterest,
      'totalPaidMora': totalPaidMora,
      'outstandingBalance': outstandingBalance,
      'currentConsolidatedDebt': currentConsolidatedDebt,
      'accumulatedMora': accumulatedMora,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }


  CreditModel copyWith({
    String? creditId,
    String? clientId,
    String? createdByUid,
    List<String>? assignedCollectorIds,
    double? principalAmount,
    double? monthlyInterestRate,
    double? dailyMoraRate,
    int? termInMonths,
    PaymentFrequency? paymentFrequency,
    double? totalInterest,
    double? totalAmount,
    double? installmentAmount,
    int? numberOfInstallments,
    DateTime? disbursementDate,
    DateTime? firstInstallmentDate,
    CreditStatus? status,
    int? paidInstallments,
    double? totalPaid,
    double? totalPaidPrincipal,
    double? totalPaidInterest,
    double? totalPaidMora,
    double? outstandingBalance,
    double? currentConsolidatedDebt,
    double? accumulatedMora,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt
  }) {
    return CreditModel(
      creditId: creditId ?? this.creditId,
      clientId: clientId ?? this.clientId,
      createdByUid: createdByUid ?? this.createdByUid,
      assignedCollectorIds: assignedCollectorIds ?? this.assignedCollectorIds,
      principalAmount: principalAmount ?? this.principalAmount,
      monthlyInterestRate: monthlyInterestRate ?? this.monthlyInterestRate,
      dailyMoraRate: dailyMoraRate ?? this.dailyMoraRate,
      termInMonths: termInMonths ?? this.termInMonths,
      paymentFrequency: paymentFrequency ?? this.paymentFrequency,
      totalInterest: totalInterest ?? this.totalInterest,
      totalAmount: totalAmount ?? this.totalAmount,
      installmentAmount: installmentAmount ?? this.installmentAmount,
      numberOfInstallments: numberOfInstallments ?? this.numberOfInstallments,
      disbursementDate: disbursementDate ?? this.disbursementDate,
      firstInstallmentDate: firstInstallmentDate ?? this.firstInstallmentDate,
      status: status ?? this.status,
      paidInstallments: paidInstallments ?? this.paidInstallments,
      totalPaid: totalPaid ?? this.totalPaid,
      totalPaidPrincipal: totalPaidPrincipal ?? this.totalPaidPrincipal,
      totalPaidInterest: totalPaidInterest ?? this.totalPaidInterest,
      totalPaidMora: totalPaidMora ?? this.totalPaidMora,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      currentConsolidatedDebt: currentConsolidatedDebt ?? this.currentConsolidatedDebt,
      accumulatedMora: accumulatedMora ?? this.accumulatedMora,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt
    );
  }
  @override
  List<Object?> get props => [creditId, clientId, createdByUid, assignedCollectorIds, principalAmount, monthlyInterestRate, dailyMoraRate, termInMonths, paymentFrequency, totalInterest, totalAmount, installmentAmount, numberOfInstallments, disbursementDate, firstInstallmentDate, status, paidInstallments, totalPaid, totalPaidPrincipal, totalPaidInterest, totalPaidMora, outstandingBalance, currentConsolidatedDebt, accumulatedMora, notes, createdAt, updatedAt];
}
