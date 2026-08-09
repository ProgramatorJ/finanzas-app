enum PaymentMethod {
  efectivo,
  transferencia,
  consignacion;

  static PaymentMethod fromString(String method) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name == method.toLowerCase(),
      orElse: () => PaymentMethod.efectivo,
    );
  }
}
