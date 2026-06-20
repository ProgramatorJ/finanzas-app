with open(r"c:\Users\Windows 10\Desktop\projects Antigravity\lib\core\services\firestore_service.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
    for idx, line in enumerate(lines):
        if "getAllCreditsStream" in line or "getAssignedCreditsStream" in line:
            print(f"L{idx+1}: {line.strip()}")
