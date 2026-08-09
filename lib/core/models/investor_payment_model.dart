import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum InvestorPaymentConcept {
  interestPayment,    // Pago de intereses/rentabilidad
  principalReturn;    // Devolución de capital

  static InvestorPaymentConcept fromString(String concept) {
    return InvestorPaymentConcept.values.firstWhere(
      (e) => e.name.toLowerCase() == concept.toLowerCase(),
      orElse: () => InvestorPaymentConcept.interestPayment,
    );
  }
}

class InvestorPaymentModel extends Equatable {
  final String paymentId;
  final String investmentId;
  final double amount;
  final InvestorPaymentConcept concept;
  final String? notes;
  final DateTime paymentDate;
  final DateTime createdAt;

  InvestorPaymentModel({
    required this.paymentId,
    required this.investmentId,
    required this.amount,
    required this.concept,
    this.notes,
    required this.paymentDate,
    required this.createdAt,
  });

  factory InvestorPaymentModel.fromMap(Map<String, dynamic> map, String documentId, {String? investmentId}) {
    return InvestorPaymentModel(
      paymentId: documentId,
      investmentId: investmentId ?? map['investmentId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      concept: InvestorPaymentConcept.fromString(map['concept'] ?? 'interestPayment'),
      notes: map['notes'],
      paymentDate: (map['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'investmentId': investmentId,
      'amount': amount,
      'concept': concept.name,
      'notes': notes,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }


  InvestorPaymentModel copyWith({
    String? paymentId,
    String? investmentId,
    double? amount,
    InvestorPaymentConcept? concept,
    String? notes,
    DateTime? paymentDate,
    DateTime? createdAt
  }) {
    return InvestorPaymentModel(
      paymentId: paymentId ?? this.paymentId,
      investmentId: investmentId ?? this.investmentId,
      amount: amount ?? this.amount,
      concept: concept ?? this.concept,
      notes: notes ?? this.notes,
      paymentDate: paymentDate ?? this.paymentDate,
      createdAt: createdAt ?? this.createdAt
    );
  }
  @override
  List<Object?> get props => [paymentId, investmentId, amount, concept, notes, paymentDate, createdAt];
}
