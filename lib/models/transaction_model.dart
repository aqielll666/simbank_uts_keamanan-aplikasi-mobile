// models/transaction_model.dart
class BankTransaction {
  final String id;
  final String type;          // 'transfer', 'tarik', 'topup'
  final double amount;
  final String description;
  final String targetAccount;
  final DateTime createdAt;

  BankTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.targetAccount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'amount': amount.toString(),
    'description': description,
    'targetAccount': targetAccount,
    'createdAt': createdAt.toIso8601String(),
  };

  factory BankTransaction.fromMap(Map<String, dynamic> map) => BankTransaction(
    id: map['id'],
    type: map['type'],
    amount: double.parse(map['amount']),
    description: map['description'],
    targetAccount: map['targetAccount'],
    createdAt: DateTime.parse(map['createdAt']),
  );
}
