const admin = require('firebase-admin');
const serviceAccount = require('./mi-gestor-prestamos-firebase-adminsdk-h4w96-a1859c2cb4.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}
const db = admin.firestore();

async function run() {
  const snapshot = await db.collection('credits').doc('26031701').collection('installments').where('installmentNumber', '==', 4).get();
  snapshot.forEach(doc => {
    const data = doc.data();
    console.log("Installment 4:");
    console.log("accumulatedMora:", data.accumulatedMora);
    console.log("moraStartDate:", data.moraStartDate ? data.moraStartDate.toDate() : null);
    console.log("moraPaid:", data.moraPaid);
    console.log("dueDate:", data.dueDate ? data.dueDate.toDate() : null);
    console.log("updatedAt:", data.updatedAt ? data.updatedAt.toDate() : null);
  });
}

run().catch(console.error);
