import re

file_path = r'c:\dev\finanzas-app\lib\core\repositories\payments_repository.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import if missing
if 'app_constants.dart' not in content:
    content = re.sub(
        r"(import 'package:finanzas_app/core/models/payment_model\.dart';)",
        r"\1\nimport 'package:finanzas_app/core/constants/app_constants.dart';",
        content
    )

content = content.replace(
    "'accumulatedMora': finalAccumulatedMora,\n          'updatedAt': FieldValue.serverTimestamp(),",
    "'accumulatedMora': finalAccumulatedMora,\n          'schemaVersion': AppConstants.currentMathSchemaVersion,\n          'updatedAt': FieldValue.serverTimestamp(),"
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated PaymentsRepository")
