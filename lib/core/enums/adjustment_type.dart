enum AdjustmentType {
  ingreso,
  egreso;

  static AdjustmentType fromString(String type) {
    return AdjustmentType.values.firstWhere(
      (e) => e.name == type.toLowerCase(),
      orElse: () => AdjustmentType.ingreso,
    );
  }
}
