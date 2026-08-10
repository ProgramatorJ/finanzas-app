import re

file_path = r'c:\dev\finanzas-app\lib\core\models\credit_model.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add schemaVersion field
content = re.sub(
    r'(final DateTime updatedAt;)',
    r'\1\n  final int schemaVersion;',
    content
)

# 2. Add to constructor
content = re.sub(
    r'(required this\.updatedAt,)',
    r'\1\n    this.schemaVersion = 1,',
    content
)

# 3. Add to fromMap
content = re.sub(
    r"(updatedAt: \(map\['updatedAt'\] as Timestamp\?\)\?\.toDate\(\) \?\? DateTime\.now\(\),)",
    r"\1\n      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,",
    content
)

# 4. Add to toMap
content = re.sub(
    r"('updatedAt': Timestamp\.fromDate\(updatedAt\),)",
    r"\1\n      'schemaVersion': schemaVersion,",
    content
)

# 5. Add to copyWith params
content = re.sub(
    r'(DateTime\? updatedAt)',
    r'\1,\n    int? schemaVersion',
    content
)

# 6. Add to copyWith return
content = re.sub(
    r'(updatedAt: updatedAt \?\? this\.updatedAt)',
    r'\1,\n      schemaVersion: schemaVersion ?? this.schemaVersion',
    content
)

# 7. Add to props
content = re.sub(
    r'(createdAt, \nupdatedAt)\];',
    r'\1, schemaVersion];',
    content
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated CreditModel")
