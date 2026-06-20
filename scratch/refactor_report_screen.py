import re

file_path = r"C:\Users\Windows 10\Desktop\projects Antigravity\lib\features\reports\upcoming_payments_report_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Inject the getters into _UpcomingPaymentsReportScreenState class
state_class_def = "class _UpcomingPaymentsReportScreenState extends ConsumerState<UpcomingPaymentsReportScreen> {"
getters = """
  ThemeData get theme => Theme.of(context);
  bool get isDark => theme.brightness == Brightness.dark;
  Color get secondaryColor => isDark ? const Color(0xFFA5A5B5) : Colors.black54;
  Color get primaryTextColor => isDark ? Colors.white : Colors.black87;
"""
content = content.replace(state_class_def, state_class_def + getters)

# 2. Replace unselectedLabelColor static reference
content = content.replace("? AppTheme.textSecondary", "? const Color(0xFFA5A5B5)")

# 3. Replace cardColor with dynamic theme card color
content = content.replace("surface: AppTheme.cardColor,", "surface: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,")
content = content.replace("color: AppTheme.cardColor,", "color: Theme.of(context).cardTheme.color,")

# 4. Remove const prefix where we inject variables
content = content.replace("const Text(\n                        'EFICIENCIA DE COBRO REAL'", "Text(\n                        'EFICIENCIA DE COBRO REAL'")
content = content.replace("const Text(\n                        'Porcentaje de dinero físico cobrado frente a la meta proyectada'", "Text(\n                        'Porcentaje de dinero físico cobrado frente a la meta proyectada'")
content = content.replace("const Text(\n                        'ARQUEO DIARIO: META PROYECTADA VS EFECTIVO COBRADO'", "Text(\n                        'ARQUEO DIARIO: META PROYECTADA VS EFECTIVO COBRADO'")
content = content.replace("const Text(\n                        'Barra izquierda (Gris) = Programado por vencer | Barra derecha (Verde) = Cobrado real por día'", "Text(\n                        'Barra izquierda (Gris) = Programado por vencer | Barra derecha (Verde) = Cobrado real por día'")
content = content.replace("const Text(\n                        'Historial de Flujo por Fecha'", "Text(\n                        'Historial de Flujo por Fecha'")
content = content.replace("const Text(\n                        'REPARTO DE SALDO POR RANGOS DE ATRASO'", "Text(\n                        'REPARTO DE SALDO POR RANGOS DE ATRASO'")
content = content.replace("const Text(\n                '🚨 Lista de Deudores en Mora Crítica (Atraso > 15 Días)'", "Text(\n                '🚨 Lista de Deudores en Mora Crítica (Atraso > 15 Días)'")
content = content.replace("const Text(\n                '📅 Vencimientos Programados (Próximos 30 Días)'", "Text(\n                '📅 Vencimientos Programados (Próximos 30 Días)'")
content = content.replace("const Text(\n              'FLUJO PROYECTADO POR DÍA PARA LA PRÓXIMA SEMANA'", "Text(\n              'FLUJO PROYECTADO POR DÍA PARA LA PRÓXIMA SEMANA'")

# 5. Replace text colors
content = content.replace("AppTheme.textPrimary", "primaryTextColor")
content = content.replace("AppTheme.textSecondary", "secondaryColor")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Refactoring report screen complete.")
