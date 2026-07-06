# 📐 Arquitectura y Fuente Única de Verdad Financiera (SSOT)

Este documento define la estructura oficial, las fórmulas matemáticas y las funciones reutilizables que rigen los cálculos financieros de la plataforma. Su propósito es actuar como la **Fuente Única de Verdad (Single Source of Truth - SSOT)**, garantizando la consistencia absoluta de los datos entre todas las pestañas y evitando la redundancia de código.

---

## 1. Reglas Generales de Desarrollo

> [!IMPORTANT]
> **PROHIBICIÓN DE RECALCULAR**: Queda terminantemente prohibido escribir bucles de cálculo o fórmulas financieras (`for`, `map`, `reduce`) directamente dentro del código de los widgets visuales (UI).
> Si una vista necesita una métrica financiera, debe suscribirse al proveedor de lógica central (`financialMetricsProvider`) y leer el valor precalculado.

---

## 2. Fuentes de Datos (Colecciones Base en Firestore)

Las métricas financieras se construyen a partir de estas seis colecciones principales de la base de datos:

| Colección | Modelo Dart | Descripción |
| :--- | :--- | :--- |
| `credits` | `CreditModel` | Información de créditos desembolsados a clientes. |
| `payments` | `PaymentModel` | Registros de pagos/abonos realizados por los clientes. |
| `expenses` | `ExpenseModel` | Gastos administrativos y operativos de la empresa. |
| `investments` | `InvestmentModel` | Inyecciones de capital realizadas por inversores externos. |
| `investorPayments` | `InvestorPaymentModel` | Pagos realizados a los inversores (Retorno de capital o pago de intereses). |
| `cashAdjustments` | `CashAdjustmentModel` | Ajustes manuales (entradas/salidas) en la caja general. |

---

## 3. Fórmulas Financieras Unificadas

Para evitar discrepancias matemáticas, se definen las siguientes fórmulas oficiales que deben ser utilizadas de forma idéntica en toda la aplicación:

### A. Caja General (Liquidez)
* **Definición**: Dinero en efectivo disponible físicamente en la caja de la empresa.
* **Restricción**: Se calculan los flujos **únicamente a partir del 1 de julio de 2026** (fecha de corte).
* **Fórmula**:
  $$\text{Caja Actual} = \text{Recaudos} + \text{Inversiones Recibidas} - \text{Desembolsos} - \text{Gastos} - \text{Pagos a Inversores} + \text{Ajustes de Caja}$$
  * *Recaudos*: Suma de `amountReceived` de los pagos.
  * *Inversiones Recibidas*: Suma de `amount` de las inversiones.
  * *Desembolsos*: Suma de `principalAmount` de los créditos.
  * *Gastos*: Suma de `amount` de los gastos operativos.
  * *Pagos a Inversores*: Suma de `amount` de los pagos a inversores (ambos conceptos).
  * *Ajustes de Caja*: Suma algebraica de `amount` (los egresos restan, los ingresos suman).

### B. Capital de Cartera Activa (Créditos Colocados)
* **Definición**: Capital pendiente de cobro prestado a los clientes, sin incluir intereses ni mora.
* **Restricción**: **Sin restricción de fecha**. Se toman todos los créditos activos históricos para reflejar el activo real.
* **Fórmula**:
  $$\text{Cartera Activa} = \sum (\text{c.principalAmount} - \text{Capital Pagado por Crédito})$$
  * *Capital Pagado por Crédito*: Sumatoria de `p.appliedToPrincipal` de la colección de `payments` correspondiente a ese crédito.
  * *Filtro de Crédito*: Se consideran los créditos cuyo saldo pendiente sea mayor a cero o tengan estado `active` o `restructured`.

### C. Deuda con Inversores (Pasivos)
* **Definición**: El capital total que la empresa le adeuda actualmente a los inversores externos.
* **Restricción**: **Sin restricción de fecha**.
* **Fórmula**:
  $$\text{Deuda a Inversores} = \sum (\text{inv.amount} - \text{Capital Devuelto})$$
  * *Capital Devuelto*: Sumatoria de los pagos hechos al inversor bajo el concepto `principalReturn` (retorno de capital).

### D. Patrimonio Neto
* **Definición**: El valor líquido real de la empresa descontando las obligaciones externas.
* **Fórmula**:
  $$\text{Patrimonio Neto} = \text{Total Activos} - \text{Total Pasivos}$$
  * Donde $\text{Total Activos} = \text{Caja} + \text{Cartera Activa} + \text{Intereses por Cobrar} + \text{Mora por Cobrar}$.
  * Donde $\text{Total Pasivos} = \text{Deuda a Inversores}$.

### E. Utilidad Bruta
* **Definición**: Rentabilidad generada por el cobro de la cartera de clientes.
* **Restricción**: Filtro por periodo y desde el 1 de julio de 2026.
* **Fórmula**:
  $$\text{Utilidad Bruta} = \text{Intereses Cobrados} + \text{Mora Cobrada}$$
  * Calculado a partir de `appliedToInterest` y `appliedToMora` de la colección de `payments`.

### F. Utilidad Neta
* **Definición**: Rentabilidad limpia de la empresa después de cubrir gastos y costo de fondeo.
* **Restricción**: Filtro por periodo y desde el 1 de julio de 2026.
* **Fórmula**:
  $$\text{Utilidad Neta} = \text{Utilidad Bruta} - \text{Gastos Operativos} - \text{Intereses Pagados a Inversores}$$

---

## 4. Funciones Reutilizables Compartidas

Estas funciones deben estar centralizadas en clases de utilidades (ej. `FinancialUtils`) o dentro del servicio central de cálculos:

### A. Cálculo de Saldo de Capital Histórico a una Fecha ($t$)
Evita recalcular usando cuotas y se apoya en los pagos reales:
```dart
double calcularSaldoCapitalHistorico(CreditModel c, List<PaymentModel> payments, DateTime fechaLimite) {
  double capitalPagado = payments
      .where((p) => p.creditId == c.creditId && !p.paymentDate.isAfter(fechaLimite))
      .map((p) => p.appliedToPrincipal)
      .fold(0.0, (prev, element) => prev + element);
  return (c.principalAmount - capitalPagado).clamp(0.0, double.infinity);
}
```

### B. Formateador Único de Moneda (COP)
Evita instanciar múltiples `NumberFormat` con diferentes locales o estilos:
```dart
final NumberFormat copFormatter = NumberFormat.currency(
  locale: 'es_CO',
  symbol: '\$ ',
  decimalDigits: 0,
  customPattern: '\u00A4#,##0',
);
```

### C. Resolución y Agrupación de Periodos Temporales
Función estandarizada para obtener el inicio de un periodo (usada en gráficos de barras y líneas):
```dart
DateTime obtenerInicioPeriodo(DateTime fecha, String resolucion) {
  switch (resolucion) {
    case 'daily':
      return DateTime(fecha.year, fecha.month, fecha.day);
    case 'weekly':
      // Obtener el lunes de esa semana
      return fecha.subtract(Duration(days: fecha.weekday - 1));
    case 'monthly':
      return DateTime(fecha.year, fecha.month, 1);
    case 'quarterly':
      int qMonth = ((fecha.month - 1) ~/ 3) * 3 + 1;
      return DateTime(fecha.year, qMonth, 1);
    case 'yearly':
      return DateTime(fecha.year, 1, 1);
    default:
      return DateTime(fecha.year, fecha.month, 1);
  }
}
```

---

## 5. Arquitectura de Implementación Propuesta

### Capa de Lógica Centralizada (`financialMetricsProvider`)
Implementaremos un proveedor de estado Riverpod que escuche todos los streams de base de datos y provea un modelo unificado `FinancialMetrics`:

```dart
class FinancialMetrics {
  final double cajaActual;
  final double carteraActivaCapital;
  final double interesesPorCobrar;
  final double moraAcumulada;
  final double deudaInversores;
  final double patrimonioNeto;
  final double utilidadNeta;
  
  FinancialMetrics({
    required this.cajaActual,
    required this.carteraActivaCapital,
    required this.interesesPorCobrar,
    required this.moraAcumulada,
    required this.deudaInversores,
    required this.patrimonioNeto,
    required this.utilidadNeta,
  });
}
```

Cualquier widget de Flutter podrá consumir estas métricas escribiendo únicamente:
```dart
final metrics = ref.watch(financialMetricsProvider).value;
if (metrics != null) {
  double caja = metrics.cajaActual;
  double cartera = metrics.carteraActivaCapital;
}
```
