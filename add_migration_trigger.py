import re

file_path = r'c:\dev\finanzas-app\lib\features\credits\credit_detail_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

migration_code = """        final credit = credits.firstWhere((c) => c.creditId == creditId, orElse: () => credits.first);

        if (credit.schemaVersion < AppConstants.currentMathSchemaVersion) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(paymentsRepositoryProvider).forceRebuildAndMigrateCredit(credit.creditId).catchError((e) {
              debugPrint('Error en migracion forzada: $e');
            });
          });
        }
"""

content = content.replace(
    "        final credit = credits.firstWhere((c) => c.creditId == creditId, orElse: () => credits.first);",
    migration_code
)

if 'app_constants.dart' not in content:
    content = re.sub(
        r"(import 'package:finanzas_app/core/models/credit_model\.dart';)",
        r"\1\nimport 'package:finanzas_app/core/constants/app_constants.dart';",
        content
    )

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Added migration trigger to CreditDetailScreen")
