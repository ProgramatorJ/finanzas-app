/// Motor de Calendario Comercial (Año 360)
///
/// Reglas:
/// - Todos los meses se asumen de 30 días exactos.
/// - En pagos quincenales, los ciclos son de 15 días exactos.
/// - Los días 31 se ignoran algorítmicamente.
/// - Los días 28/29 de febrero se procesan como '30' para asegurar
///   el salto correcto al siguiente mes.
class CommercialCalendar {
  /// Añade [days] días a [date] usando el calendario comercial 360.
  /// Nunca produce días 29/30/31 que rompan la lógica; trata el mes
  /// como si siempre tuviera 30 días.
  static DateTime addCommercialDays(DateTime date, int days) {
    int day = date.day;
    int month = date.month;
    int year = date.year;

    // Normalizar día de inicio: si es 29, 30, 31 → tratar como 30
    if (day > 30) day = 30;

    int totalDays = (year * 360) + ((month - 1) * 30) + day + days;

    int newYear = totalDays ~/ 360;
    int remainder = totalDays % 360;

    int newMonth = (remainder ~/ 30) + 1;
    int newDay = remainder % 30;

    // Si el día es 0, significa que cayó exactamente al final del mes anterior
    if (newDay == 0) {
      newDay = 30;
      newMonth -= 1;
      if (newMonth == 0) {
        newMonth = 12;
        newYear -= 1;
      }
    }

    // Convertir de vuelta a fecha real: si el mes tiene menos de 30 días reales,
    // ajustar al último día real del mes (ej: Feb → 28)
    int realLastDay = _lastDayOfMonth(newYear, newMonth);
    if (newDay > realLastDay) newDay = realLastDay;

    return DateTime(newYear, newMonth, newDay);
  }

  /// Calcula los días de diferencia entre dos fechas en calendario comercial 360.
  static int commercialDaysBetween(DateTime from, DateTime to) {
    int d1 = from.day > 30 ? 30 : from.day;
    int d2 = to.day > 30 ? 30 : to.day;

    return ((to.year - from.year) * 360) +
        ((to.month - from.month) * 30) +
        (d2 - d1);
  }

  /// Genera la lista de fechas de vencimiento para todas las cuotas
  /// a partir de [firstInstallmentDate], según la frecuencia de pago.
  ///
  /// [numberOfInstallments]: Total de cuotas a generar.
  /// [frequency]: 'weekly' (7 días), 'biweekly' (15 días), 'monthly' (30 días).
  static List<DateTime> generateInstallmentDates({
    required DateTime firstInstallmentDate,
    required int numberOfInstallments,
    required String frequency,
  }) {
    int intervalDays;
    switch (frequency) {
      case 'weekly':
        intervalDays = 7;
        break;
      case 'biweekly':
        intervalDays = 15;
        break;
      case 'monthly':
      default:
        intervalDays = 30;
        break;
    }

    List<DateTime> dates = [];
    DateTime current = DateTime(firstInstallmentDate.year, firstInstallmentDate.month, firstInstallmentDate.day);

    for (int i = 0; i < numberOfInstallments; i++) {
      if (i == 0) {
        dates.add(current);
      } else {
        if (frequency == 'weekly') {
          current = current.add(const Duration(days: 7));
        } else {
          current = addCommercialDays(current, intervalDays);
        }
        dates.add(current);
      }
    }

    return dates;
  }

  /// Calcula el número de cuotas según la frecuencia y el plazo en meses.
  static int calculateNumberOfInstallments({
    required int termInMonths,
    required String frequency,
  }) {
    switch (frequency) {
      case 'weekly':
        // 4 semanas por mes comercial
        return termInMonths * 4;
      case 'biweekly':
        // 2 quincenas por mes comercial
        return termInMonths * 2;
      case 'monthly':
      default:
        return termInMonths;
    }
  }

  /// Devuelve el último día real del mes en el calendario gregoriano.
  static int _lastDayOfMonth(int year, int month) {
    if (month == 12) return 31;
    return DateTime(year, month + 1, 0).day;
  }
}
