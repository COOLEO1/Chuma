import 'package:flutter/material.dart';

enum Kind { expense, income, saving }

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class Cat {
  final String name;
  final IconData icon;
  const Cat(this.name, this.icon);
}

const expenseCats = [
  Cat('Airtime', Icons.phone_android),
  Cat('Data', Icons.wifi),
  Cat('Transport', Icons.directions_bus),
  Cat('Food', Icons.restaurant),
  Cat('Fees', Icons.receipt_long),
  Cat('Other', Icons.more_horiz),
];

const incomeCats = [
  Cat('Business', Icons.storefront),
  Cat('Gift', Icons.card_giftcard),
  Cat('Allowance', Icons.account_balance_wallet),
  Cat('Other', Icons.more_horiz),
];

class Txn {
  final int? id;
  final Kind kind;
  final int amount;
  final String category;
  final String note;
  final int? goalId;
  final DateTime ts;

  Txn({
    this.id,
    required this.kind,
    required this.amount,
    required this.category,
    this.note = '',
    this.goalId,
    required this.ts,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'kind': kind.index,
        'amount': amount,
        'category': category,
        'note': note,
        'goal_id': goalId,
        'ts': ts.millisecondsSinceEpoch,
      };

  factory Txn.fromMap(Map<String, Object?> m) => Txn(
        id: m['id'] as int?,
        kind: Kind.values[m['kind'] as int],
        amount: m['amount'] as int,
        category: m['category'] as String,
        note: (m['note'] as String?) ?? '',
        goalId: m['goal_id'] as int?,
        ts: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
      );
}

class Goal {
  final int? id;
  final String name;
  final int target;
  final DateTime deadline;
  final DateTime created;

  Goal({
    this.id,
    required this.name,
    required this.target,
    required this.deadline,
    required this.created,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'target': target,
        'deadline': deadline.millisecondsSinceEpoch,
        'created': created.millisecondsSinceEpoch,
      };

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: m['id'] as int?,
        name: m['name'] as String,
        target: m['target'] as int,
        deadline: DateTime.fromMillisecondsSinceEpoch(m['deadline'] as int),
        created: DateTime.fromMillisecondsSinceEpoch(m['created'] as int),
      );
}

IconData iconFor(Txn t) {
  if (t.kind == Kind.saving) return Icons.savings;
  final list = t.kind == Kind.income ? incomeCats : expenseCats;
  for (final c in list) {
    if (c.name == t.category) return c.icon;
  }
  return Icons.circle_outlined;
}
