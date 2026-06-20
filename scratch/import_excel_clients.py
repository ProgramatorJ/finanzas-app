import os
import json
import datetime
import openpyxl
from google.oauth2.credentials import Credentials
from google.cloud import firestore

# --- Configuración de Autenticación de Firebase ---
print("Cargando credenciales de Firebase CLI...")
config_path = os.path.expanduser(r"~\.config\configstore\firebase-tools.json")
if not os.path.exists(config_path):
    raise FileNotFoundError(f"No se encontró la configuración del Firebase CLI en {config_path}. ¿Ejecutaste 'firebase login'?")

with open(config_path, "r", encoding="utf-8") as f:
    config = json.load(f)

tokens = config.get("tokens", {})
access_token = tokens.get("access_token")
refresh_token = tokens.get("refresh_token")

client_id = "563584335869-uu3v1rfjqc2msthab9xgbe2nt9gg7ddp.apps.googleusercontent.com"
client_secret = "j9Te1-i5g3gJnS5s1RLk98Ls"

creds = Credentials(
    token=access_token,
    refresh_token=refresh_token,
    token_uri="https://oauth2.googleapis.com/token",
    client_id=client_id,
    client_secret=client_secret
)

db = firestore.Client(project="mi-gestor-prestamos", credentials=creds)
print("Conectado con éxito a Firestore!")

# Obtener un ID de usuario de administrador de la colección 'users' para asociar los registros creados
print("Buscando usuario administrador...")
users = list(db.collection("users").limit(1).stream())
if users:
    user_uid = users[0].id
    print(f"Usuario asignado para 'createdByUid': {user_uid} ({users[0].to_dict().get('email')})")
else:
    user_uid = "migration_admin"
    print("No se encontraron usuarios, usando ID por defecto: 'migration_admin'")

# --- Funciones de Normalización ---
def clean_str(val):
    if val is None or str(val).strip().lower() in ["none", "null", "n/a", "#n/a"]:
        return ""
    return str(val).strip()

def normalize_id(val):
    if val is None:
        return ""
    val_str = str(val).strip()
    if val_str.lower() in ["none", "null", "n/a", "#n/a"]:
        return ""
    if "." in val_str:
        try:
            return str(int(float(val_str)))
        except ValueError:
            pass
    return val_str

def normalize_name(val):
    if val is None:
        return ""
    val_str = str(val).strip()
    if val_str.lower() in ["none", "null", "n/a", "#n/a"]:
        return ""
    return val_str

def clean_phone(val):
    if val is None:
        return ""
    val_str = str(val).strip()
    if val_str.lower() in ["none", "null", "n/a", "#n/a", "0", "0.0"]:
        return ""
    if "." in val_str:
        try:
            return str(int(float(val_str)))
        except ValueError:
            pass
    return val_str

# --- Obtener clientes ya existentes en Firestore ---
print("Consultando clientes existentes en la base de datos...")
existing_clients_stream = db.collection("clients").stream()
existing_client_ids = set()
existing_id_numbers = set()

for doc in existing_clients_stream:
    existing_client_ids.add(doc.id)
    data = doc.to_dict()
    if 'idNumber' in data:
        existing_id_numbers.add(normalize_id(data['idNumber']))

print(f"Encontrados {len(existing_client_ids)} clientes en la base de datos.")

# --- Cargar Excel ---
excel_path = r"C:\Users\Windows 10\Desktop\projects Antigravity\Copia de BANX.xlsx"
print(f"Cargando archivo Excel desde {excel_path}...")
wb = openpyxl.load_workbook(excel_path, data_only=True)

# --- Leer Clientes de la pestaña 'Clientes' ---
print("\n--- Analizando clientes en la pestaña 'Clientes' ---")
ws_clientes = wb['Clientes']

clients_to_import = []
skipped_count = 0

for r_idx in range(2, ws_clientes.max_row + 1):
    c_cedula = ws_clientes.cell(row=r_idx, column=1)
    c_nombre = ws_clientes.cell(row=r_idx, column=2)
    c_telefono = ws_clientes.cell(row=r_idx, column=3)
    c_direccion = ws_clientes.cell(row=r_idx, column=4)
    c_comentario = ws_clientes.cell(row=r_idx, column=6)
    
    val_cedula = normalize_id(c_cedula.value)
    val_nombre = normalize_name(c_nombre.value)
    
    if not val_cedula or not val_nombre:
        continue
        
    # Verificar si ya existe por ID de documento o por número de cédula
    if val_cedula in existing_client_ids or val_cedula in existing_id_numbers:
        skipped_count += 1
        continue
        
    clients_to_import.append({
        'clientId': val_cedula,
        'fullName': val_nombre,
        'idNumber': val_cedula,
        'phone': clean_phone(c_telefono.value),
        'address': clean_str(c_direccion.value) if c_direccion.value else "",
        'assignedCollectorIds': [],
        'createdByUid': user_uid,
        'isActive': True,
        'notes': clean_str(c_comentario.value) if c_comentario.value else None
    })
    # Añadir a locales para evitar duplicar en el mismo lote si se repiten en el Excel
    existing_client_ids.add(val_cedula)
    print(f"Nuevo cliente detectado en fila {r_idx:3d}: ID={val_cedula}, Nombre={val_nombre}")

print(f"\nClientes ya existentes (omitidos): {skipped_count}")
print(f"Nuevos clientes a importar: {len(clients_to_import)}")

if len(clients_to_import) > 0:
    print("\nGuardando nuevos clientes en Firestore...")
    batch = db.batch()
    for idx, cl in enumerate(clients_to_import):
        cl_ref = db.collection("clients").document(cl['clientId'])
        cl_data = cl.copy()
        cl_data['createdAt'] = datetime.datetime.now()
        cl_data['updatedAt'] = datetime.datetime.now()
        batch.set(cl_ref, cl_data)
        if (idx + 1) % 400 == 0:
            batch.commit()
            batch = db.batch()
    batch.commit()
    print(f"[OK] {len(clients_to_import)} clientes adicionales importados correctamente.")
else:
    print("[INFO] Todos los clientes de la hoja ya existen en Firestore. No se realizaron cambios.")
