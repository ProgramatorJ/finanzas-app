import os

project_dir = r"c:\Users\Windows 10\Desktop\projects Antigravity\lib"

search_terms = ["showDialog", "showModalBottomSheet", "AlertDialog", "Dialog("]

print(f"Searching in: {project_dir}")
for root, dirs, files in os.walk(project_dir):
    for file in files:
        if file.endswith(".dart"):
            file_path = os.path.join(root, file)
            with open(file_path, "r", encoding="utf-8") as f:
                lines = f.readlines()
                for idx, line in enumerate(lines):
                    for term in search_terms:
                        if term in line:
                            print(f"{os.path.basename(file_path)}:{idx+1}: {line.strip()}")
