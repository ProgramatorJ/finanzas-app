import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum InvestmentStatus {
  active,
  completed; // Capital devuelto en su totalidad

  static InvestmentStatus fromString(String status) {
    return InvestmentStatus.values.firstWhere(
      (e) => e.name == status.toLowerCase(),
      orElse: () => InvestmentStatus.active,
    );
  }
}

class InvestmentModel extends Equatable {
  final String investmentId;
  final String investorName;
  final double amount;                    // Monto invertido originalmente
  final double monthlyInterestRate;       // Tasa mensual (0.0 si no cobra interés, ej: el dueño)
  final double totalInterestPaid;         // Acumulado de intereses pagados al inversor
  final double totalPrincipalReturned;    // Acumulado de capital devuelto al inversor
  final double outstandingBalance;        // amount - totalPrincipalReturned
  final InvestmentStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  InvestmentModel({
    required this.investmentId,
    required this.investorName,
    required this.amount,
    required this.monthlyInterestRate,
    required this.totalInterestPaid,
    required this.totalPrincipalReturned,
    required this.outstandingBalance,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InvestmentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return InvestmentModel(
      investmentId: documentId,
      investorName: map['investorName'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      monthlyInterestRate: (map['monthlyInterestRate'] as num?)?.toDouble() ?? 0.0,
      totalInterestPaid: (map['totalInterestPaid'] as num?)?.toDouble() ?? 0.0,
      totalPrincipalReturned: (map['totalPrincipalReturned'] as num?)?.toDouble() ?? 0.0,
      outstandingBalance: (map['outstandingBalance'] as num?)?.toDouble() ?? 0.0,
      status: InvestmentStatus.fromString(map['status'] ?? 'active'),
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'investorName': investorName,
      'amount': amount,
      'monthlyInterestRate': monthlyInterestRate,
      'totalInterestPaid': totalInterestPaid,
      'totalPrincipalReturned': totalPrincipalReturned,
      'outstandingBalance': outstandingBalance,
      'status': status.name,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }


  InvestmentModel copyWith({
    String? investmentId,
    String? investorName,
    double? amount,
    double? monthlyInterestRate,
    double? totalInterestPaid,
    double? totalPrincipalReturned,
    double? outstandingBalance,
    InvestmentStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt
  }) {
    return InvestmentModel(
      investmentId: investmentId ?? this.investmentId,
      investorName: investorName ?? this.investorName,
      amount: amount ?? this.amount,
      monthlyInterestRate: monthlyInterestRate ?? this.monthlyInterestRate,
      totalInterestPaid: totalInterestPaid ?? this.totalInterestPaid,
      totalPrincipalReturned: totalPrincipalReturned ?? this.totalPrincipalReturned,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt
    );
  }
  @override
  List<Object?> get props => [investmentId, investorName, amount, monthlyInterestRate, totalInterestPaid, totalPrincipalReturned, outstandingBalance, status, notes, createdAt, updatedAt];
}
