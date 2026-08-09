import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel extends Equatable {
  final String expenseId;
  final double amount;
  final String category;
  final String description;
  final DateTime date;
  final String createdBy;

  ExpenseModel({
    required this.expenseId,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'expenseId': expenseId,
      'amount': amount,
      'category': category,
      'description': description,
      'date': Timestamp.fromDate(date),
      'createdBy': createdBy,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    return ExpenseModel(
      expenseId: id,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'Otros',
      description: map['description'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }


  ExpenseModel copyWith({
    String? expenseId,
    double? amount,
    String? category,
    String? description,
    DateTime? date,
    String? createdBy
  }) {
    return ExpenseModel(
      expenseId: expenseId ?? this.expenseId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy
    );
  }
  @override
  List<Object?> get props => [expenseId, amount, category, description, date, createdBy];
}
