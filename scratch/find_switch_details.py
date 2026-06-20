with open(r"c:\Users\Windows 10\Desktop\projects Antigravity\lib\features\credits\credit_detail_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
    for idx, line in enumerate(lines):
        line_lower = line.lower()
        if "exempt" in line_lower or "condon" in line_lower or "mora" in line_lower or "switch" in line_lower:
            # print surrounding context or lines
            if "exempt" in line_lower or "condon" in line_lower:
                print(f"L{idx+1}: {line.strip()}")
