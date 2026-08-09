enum CreditStatus {
  active,
  completed,
  defaulted,
  restructured;

  static CreditStatus fromString(String status) {
    return CreditStatus.values.firstWhere(
      (e) => e.name == status.toLowerCase(),
      orElse: () => CreditStatus.active,
    );
  }}
