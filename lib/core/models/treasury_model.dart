class TreasuryModel {
  final double currentBalance;
  final double totalExpenses;
  final double totalInterestsEarned;
  final double totalMoraEarned;
  final double totalInvestmentsReceived;      // Capital total inyectado por inversores
  final double totalReturnedToInvestors;      // Capital devuelto a inversores
  final double totalInterestPaidToInvestors;  // Intereses pagados a inversores
  final DateTime lastUpdated;

  TreasuryModel({
    required this.currentBalance,
    required this.totalExpenses,
    required this.totalInterestsEarned,
    required this.totalMoraEarned,
    required this.totalInvestmentsReceived,
    required this.totalReturnedToInvestors,
    required this.totalInterestPaidToInvestors,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'currentBalance': currentBalance,
      'totalExpenses': totalExpenses,
      'totalInterestsEarned': totalInterestsEarned,
      'totalMoraEarned': totalMoraEarned,
      'totalInvestmentsReceived': totalInvestmentsReceived,
      'totalReturnedToInvestors': totalReturnedToInvestors,
      'totalInterestPaidToInvestors': totalInterestPaidToInvestors,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory TreasuryModel.fromMap(Map<String, dynamic> map) {
    return TreasuryModel(
      currentBalance: (map['currentBalance'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (map['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      totalInterestsEarned: (map['totalInterestsEarned'] as num?)?.toDouble() ?? 0.0,
      totalMoraEarned: (map['totalMoraEarned'] as num?)?.toDouble() ?? 0.0,
      totalInvestmentsReceived: (map['totalInvestmentsReceived'] as num?)?.toDouble() ?? 0.0,
      totalReturnedToInvestors: (map['totalReturnedToInvestors'] as num?)?.toDouble() ?? 0.0,
      totalInterestPaidToInvestors: (map['totalInterestPaidToInvestors'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: map['lastUpdated'] != null 
          ? DateTime.tryParse(map['lastUpdated']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory TreasuryModel.empty() {
    return TreasuryModel(
      currentBalance: 0.0,
      totalExpenses: 0.0,
      totalInterestsEarned: 0.0,
      totalMoraEarned: 0.0,
      totalInvestmentsReceived: 0.0,
      totalReturnedToInvestors: 0.0,
      totalInterestPaidToInvestors: 0.0,
      lastUpdated: DateTime.now(),
    );
  }
}
