import os

project_dir = r"c:\Users\Windows 10\Desktop\projects Antigravity\lib"
filename = "firestore_service.dart"

for root, dirs, files in os.walk(project_dir):
    if filename in files:
        print(os.path.join(root, filename))
