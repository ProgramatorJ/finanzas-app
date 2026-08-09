enum PaymentFrequency {
  weekly,
  biweekly,
  monthly;

  static PaymentFrequency fromString(String freq) {
    return PaymentFrequency.values.firstWhere(
      (e) => e.name == freq.toLowerCase(),
      orElse: () => PaymentFrequency.monthly,
    );
  }}
