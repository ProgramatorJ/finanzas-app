import os

project_dir = r"c:\Users\Windows 10\Desktop\projects Antigravity\lib"
search_term = "CreditStatus.defaulted"

print(f"Searching for '{search_term}' in {project_dir}...")

for root, dirs, files in os.walk(project_dir):
    for file in files:
        if file.endswith(".dart"):
            filepath = os.path.join(root, file)
            with open(filepath, "r", encoding="utf-8") as f:
                lines = f.readlines()
                for idx, line in enumerate(lines):
                    if search_term in line or "CreditStatus" in line:
                        print(f"{file}:{idx+1}: {line.strip()}")
