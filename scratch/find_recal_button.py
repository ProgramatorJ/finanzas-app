with open(r"c:\Users\Windows 10\Desktop\projects Antigravity\lib\features\credits\credit_detail_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
    for idx, line in enumerate(lines):
        if "recalculate" in line.lower() or "recalc" in line.lower():
            print(f"L{idx+1}: {line.strip()}")
