import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_model.dart';
import '../models/credit_model.dart';
import '../models/installment_model.dart';
import '../models/payment_model.dart';
import '../models/treasury_model.dart';
import '../models/expense_model.dart';
import '../models/investment_model.dart';
import '../models/investor_payment_model.dart';
import '../models/cash_adjustment_model.dart';
import '../models/user_model.dart';
import '../models/appointment_model.dart';

import '../repositories/clients_repository.dart';
import '../repositories/credits_repository.dart';
import '../repositories/payments_repository.dart';
import '../repositories/treasury_repository.dart';
import '../repositories/users_repository.dart';
import '../repositories/appointments_repository.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(
    clientsRepo: ref.read(clientsRepositoryProvider),
    creditsRepo: ref.read(creditsRepositoryProvider),
    paymentsRepo: ref.read(paymentsRepositoryProvider),
    treasuryRepo: ref.read(treasuryRepositoryProvider),
    usersRepo: ref.read(usersRepositoryProvider),
    appointmentsRepo: ref.read(appointmentsRepositoryProvider),
  );
});

class FirestoreService {
  final ClientsRepository clientsRepo;
  final CreditsRepository creditsRepo;
  final PaymentsRepository paymentsRepo;
  final TreasuryRepository treasuryRepo;
  final UsersRepository usersRepo;
  final AppointmentsRepository appointmentsRepo;

  FirestoreService({
    required this.clientsRepo,
    required this.creditsRepo,
    required this.paymentsRepo,
    required this.treasuryRepo,
    required this.usersRepo,
    required this.appointmentsRepo,
  });

  // --- Clients ---
  Future<String> createClient(ClientModel client) => clientsRepo.createClient(client);
  Future<void> updateClient(String clientId, Map<String, dynamic> data) => clientsRepo.updateClient(clientId, data);
  Stream<List<ClientModel>> getAllClientsStream() => clientsRepo.getClientsStream();
  Stream<List<ClientModel>> getAssignedClientsStream(String collectorUid) => clientsRepo.getAssignedClientsStream(collectorUid);
  Future<void> deleteClient(String clientId) => clientsRepo.deleteClient(clientId);

  // --- Credits ---
  Future<String> createCredit(CreditModel credit) => creditsRepo.createCredit(credit);
  Future<void> updateCredit(String creditId, Map<String, dynamic> data) => creditsRepo.updateCredit(creditId, data);
  Future<void> updateCreditFields(String creditId, Map<String, dynamic> data) => creditsRepo.updateCreditFields(creditId, data);
  Stream<List<CreditModel>> getClientCreditsStream(String clientId) => creditsRepo.getClientCreditsStream(clientId);
  Stream<List<CreditModel>> getAllCreditsStream() => creditsRepo.getAllCreditsStream();
  Future<void> deleteCredit(String creditId) => creditsRepo.deleteCredit(creditId);
  Future<void> createInstallments(String creditId, List<InstallmentModel> installments) => creditsRepo.createInstallments(creditId, installments);
  Stream<List<InstallmentModel>> getInstallmentsStream(String creditId) => creditsRepo.getInstallmentsStream(creditId);
  Future<void> updateInstallment(String creditId, InstallmentModel installment) => creditsRepo.updateInstallment(creditId, installment);
  Future<void> updateInstallmentFields(String creditId, String installmentId, Map<String, dynamic> data) => creditsRepo.updateInstallmentFields(creditId, installmentId, data);
  Stream<List<InstallmentModel>> getAllInstallmentsStream() => creditsRepo.getAllInstallmentsStream();
  Future<void> deleteInstallment(String creditId, String installmentId) => creditsRepo.deleteInstallment(creditId, installmentId);

  // --- Payments ---
  Future<void> registerPaymentTransaction({required String creditId, required PaymentModel payment, required double dailyMoraRate}) => paymentsRepo.registerPaymentTransaction(creditId: creditId, payment: payment, dailyMoraRate: dailyMoraRate);
  Stream<List<PaymentModel>> getPaymentsStream(String creditId) => paymentsRepo.getPaymentsStream(creditId);
  Stream<List<PaymentModel>> getCollectorPaymentsStream(String collectorUid) => paymentsRepo.getCollectorPaymentsStream(collectorUid);
  Stream<List<PaymentModel>> getAllPaymentsStream() => paymentsRepo.getAllPaymentsStream();
  Future<void> deletePayment(String creditId, String paymentId) => paymentsRepo.deletePayment(creditId, paymentId);
  Future<void> updatePaymentFields(String creditId, String paymentId, Map<String, dynamic> data) => paymentsRepo.updatePaymentFields(creditId, paymentId, data);

  // --- Treasury ---
  Future<String> registerExpenseTransaction(ExpenseModel expense) => treasuryRepo.registerExpenseTransaction(expense);
  Future<void> updateExpense(ExpenseModel oldExp, ExpenseModel newExp) => treasuryRepo.updateExpense(oldExp, newExp);
  Future<void> deleteExpense(String expenseId, double amount) => treasuryRepo.deleteExpense(expenseId, amount);
  Stream<TreasuryModel> getTreasuryStream() => treasuryRepo.getTreasuryStream();
  Stream<List<ExpenseModel>> getExpensesStream() => treasuryRepo.getExpensesStream();
  Future<String> registerInvestmentTransaction(InvestmentModel investment) => treasuryRepo.registerInvestmentTransaction(investment);
  Future<void> updateInvestment(InvestmentModel oldInv, InvestmentModel newInv) => treasuryRepo.updateInvestment(oldInv, newInv);
  Future<void> deleteInvestment(String investmentId, double amount) => treasuryRepo.deleteInvestment(investmentId, amount);
  Future<void> registerInvestorPaymentTransaction({required String investmentId, required InvestorPaymentModel payment}) => treasuryRepo.registerInvestorPaymentTransaction(investmentId: investmentId, payment: payment);
  Future<void> deleteInvestorPaymentTransaction({required String investmentId, required InvestorPaymentModel payment}) => treasuryRepo.deleteInvestorPaymentTransaction(investmentId: investmentId, payment: payment);
  Future<void> updateInvestorPaymentTransaction({required String investmentId, required InvestorPaymentModel oldPayment, required InvestorPaymentModel newPayment}) => treasuryRepo.updateInvestorPaymentTransaction(investmentId: investmentId, oldPayment: oldPayment, newPayment: newPayment);
  Future<void> completeInvestment(String investmentId) => treasuryRepo.completeInvestment(investmentId);
  Stream<List<InvestmentModel>> getInvestmentsStream() => treasuryRepo.getInvestmentsStream();
  Stream<List<InvestorPaymentModel>> getInvestorPaymentsStream(String investmentId) => treasuryRepo.getInvestorPaymentsStream(investmentId);
  Stream<List<InvestorPaymentModel>> getAllInvestorPaymentsStream() => treasuryRepo.getAllInvestorPaymentsStream();
  Future<String> registerCashAdjustment(CashAdjustmentModel adjustment) => treasuryRepo.registerCashAdjustment(adjustment);
  Stream<List<CashAdjustmentModel>> getCashAdjustmentsStream() => treasuryRepo.getCashAdjustmentsStream();
  Future<void> deleteCashAdjustment(String adjustmentId, double amount) => treasuryRepo.deleteCashAdjustment(adjustmentId, amount);

  // --- Users ---
  Future<void> setUser(UserModel user) => usersRepo.setUser(user);
  Future<UserModel?> getUser(String uid) => usersRepo.getUser(uid);
  Stream<List<UserModel>> getAllUsersStream() => usersRepo.getAllUsersStream();
  Stream<List<UserModel>> getCollectorsStream() => usersRepo.getCollectorsStream();

  // --- Appointments ---
  Future<String> createAppointment(AppointmentModel appointment) => appointmentsRepo.createAppointment(appointment);
  Future<void> updateAppointmentStatus(String appointmentId, bool isCompleted) => appointmentsRepo.updateAppointmentStatus(appointmentId, isCompleted);
  Future<void> deleteAppointment(String appointmentId) => appointmentsRepo.deleteAppointment(appointmentId);
  Stream<List<AppointmentModel>> getAllAppointmentsStream() => appointmentsRepo.getAllAppointmentsStream();
  Stream<List<AppointmentModel>> getCollectorAppointmentsStream(String collectorUid) => appointmentsRepo.getCollectorAppointmentsStream(collectorUid);

  // --- Mora y Recalculo ---
  Future<void> autoScanMora() => creditsRepo.autoScanMora();
  Future<void> recalculateCreditHistory(String creditId) => creditsRepo.recalculateCreditHistory(creditId);

}
