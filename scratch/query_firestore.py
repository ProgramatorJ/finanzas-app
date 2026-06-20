import os
import json
from google.oauth2.credentials import Credentials
from google.cloud import firestore

config_path = os.path.expanduser(r"~\.config\configstore\firebase-tools.json")
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
credit_id = "26021001"

print(f"Querying Firestore for credit: {credit_id}")
credit_ref = db.collection("credits").document(credit_id)
credit_doc = credit_ref.get()

if not credit_doc.exists:
    print(f"Credit {credit_id} does not exist in Firestore.")
else:
    credit_data = credit_doc.to_dict()
    print("--- Credit Data ---")
    for k, v in credit_data.items():
        print(f"{k}: {v}")
        
    print("\n--- Installments ---")
    installments = list(credit_ref.collection("installments").stream())
    # Sort installments by installmentNumber
    inst_list = []
    for inst in installments:
        inst_list.append(inst.to_dict())
    inst_list.sort(key=lambda x: x.get('installmentNumber', 0))
    for inst in inst_list:
        print(f"Installment #{inst.get('installmentNumber')}: Due {inst.get('dueDate')}, "
              f"Scheduled: {inst.get('scheduledAmount')}, Paid: {inst.get('paidAmount')}, "
              f"Remaining: {inst.get('remainingAmount')}, Status: {inst.get('status')}, "
              f"Mora Paid: {inst.get('moraPaid')}, Acc Mora: {inst.get('accumulatedMora')}, "
              f"Is Mora Exempt: {inst.get('isMoraExempt')}, Mora Start Date: {inst.get('moraStartDate')}")
        
    print("\n--- Payments ---")
    payments = list(credit_ref.collection("payments").stream())
    pay_list = []
    for pay in payments:
        pay_list.append(pay.to_dict())
    pay_list.sort(key=lambda x: x.get('paymentDate', ''))
    for pay in pay_list:
        print(f"Payment: Date {pay.get('paymentDate')}, Amount: {pay.get('amountReceived')}, "
              f"To Mora: {pay.get('appliedToMora')}, To Int: {pay.get('appliedToInterest')}, "
              f"To Pri: {pay.get('appliedToPrincipal')}, "
              f"Affected: {pay.get('affectedInstallmentNumbers')}, Breakdowns: {pay.get('installmentBreakdowns')}")
