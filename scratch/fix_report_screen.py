import os

file_path = r"C:\Users\Windows 10\Desktop\projects Antigravity\lib\features\reports\upcoming_payments_report_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix ProjectionChart build method
chart_build_old = """  @override
  Widget build(BuildContext context) {
    final double maxVal = data.values.isEmpty ? 1.0 : data.values.reduce((a, b) => a > b ? a : b);"""

chart_build_new = """  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? const Color(0xFFA5A5B5) : Colors.black54;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final double maxVal = data.values.isEmpty ? 1.0 : data.values.reduce((a, b) => a > b ? a : b);"""

content = content.replace(chart_build_old, chart_build_new)

# 2. Fix PortfolioRiskBar build method and legend row calls
risk_build_old = """  @override
  Widget build(BuildContext context) {
    final double total = alDia + moraTemprana + moraCritica;"""

risk_build_new = """  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? const Color(0xFFA5A5B5) : Colors.black54;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final double total = alDia + moraTemprana + moraCritica;"""

content = content.replace(risk_build_old, risk_build_new)

# Replace legend calls
content = content.replace("_buildLegendRow(\n          'Al Día / Recaudado',", "_buildLegendRow(\n          context,\n          'Al Día / Recaudado',")
content = content.replace("_buildLegendRow(\n          'Mora Temprana (1-15 días)',", "_buildLegendRow(\n          context,\n          'Mora Temprana (1-15 días)',")
content = content.replace("_buildLegendRow(\n          'Mora Crítica (Más de 15 días)',", "_buildLegendRow(\n          context,\n          'Mora Crítica (Más de 15 días)',")

# 3. Fix _buildLegendRow definition and add colors
legend_old = """  Widget _buildLegendRow(String title, double amount, double pct, Color color, String description) {"""
legend_new = """  Widget _buildLegendRow(BuildContext context, String title, double amount, double pct, Color color, String description) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? const Color(0xFFA5A5B5) : Colors.black54;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;"""

content = content.replace(legend_old, legend_new)

# 4. Remove const keyword in placeholders
content = content.replace("child: const Center(\n                        child: Text(\n                          '¡Excelente! No hay cobros pendientes en rango crítico.',", "child: Center(\n                        child: Text(\n                          '¡Excelente! No hay cobros pendientes en rango crítico.',")

content = content.replace("child: const Center(\n                        child: Text(\n                          'No hay cobros agendados para los siguientes 30 días.',", "child: Center(\n                        child: Text(\n                          'No hay cobros agendados para los siguientes 30 días.',")

content = content.replace("child: const Center(\n                        child: Text(\n                          'Sin saldo pendiente en el rango',", "child: Center(\n                        child: Text(\n                          'Sin saldo pendiente en el rango',")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fix applied successfully.")
