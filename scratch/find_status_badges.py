import os

files = [
    r"c:\Users\Windows 10\Desktop\projects Antigravity\lib\features\clients\client_list_screen.dart",
    r"c:\Users\Windows 10\Desktop\projects Antigravity\lib\features\clients\client_detail_screen.dart",
    r"c:\Users\Windows 10\Desktop\projects Antigravity\lib\features\credits\credit_detail_screen.dart",
    r"c:\Users\Windows 10\Desktop\projects Antigravity\lib\features\credits\credit_list_screen.dart"
]

for file in files:
    print(f"\n=== Searching in {os.path.basename(file)} ===")
    with open(file, "r", encoding="utf-8") as f:
        lines = f.readlines()
        for idx, line in enumerate(lines):
            line_lower = line.lower()
            if "status" in line_lower or "badge" in line_lower or "activo" in line_lower or "mora" in line_lower or "opacity" in line_lower:
                if any(x in line_lower for x in ["color", "container", "boxdecoration", "text"]):
                    print(f"L{idx+1}: {line.strip()}")
