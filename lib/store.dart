import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class GoalPlan {
  final int saved, remaining, daysLeft, perDay;
  final DateTime? eta;
  final bool done, onTrack, paceReady;
  GoalPlan({
    required this.saved,
    required this.remaining,
    required this.daysLeft,
    required this.perDay,
    required this.eta,
    required this.done,
    required this.onTrack,
    required this.paceReady,
  });
}

class Store extends ChangeNotifier {
  late Database _db;
  late SharedPreferences _prefs;
  List<Txn> txns = [];
  List<Goal> goals = [];
  int budget = 0;
  String name = 'Leon';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    budget = _prefs.getInt('budget') ?? 0;
    name = _prefs.getString('name') ?? 'Leon';
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'chuma.db'),
      version: 1,
      onCreate: (db, v) async {
        await db.execute(
            'CREATE TABLE txns(id INTEGER PRIMARY KEY AUTOINCREMENT, kind INTEGER NOT NULL, amount INTEGER NOT NULL, category TEXT NOT NULL, note TEXT, goal_id INTEGER, ts INTEGER NOT NULL)');
        await db.execute(
            'CREATE TABLE goals(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, target INTEGER NOT NULL, deadline INTEGER NOT NULL, created INTEGER NOT NULL)');
      },
    );
    await _reload();
  }

  Future<void> _reload() async {
    txns = (await _db.query('txns', orderBy: 'ts DESC'))
        .map(Txn.fromMap)
        .toList();
    goals = (await _db.query('goals', orderBy: 'id')).map(Goal.fromMap).toList();
    notifyListeners();
  }

  Future<int> addTxn(Txn t) async {
    final id = await _db.insert('txns', t.toMap());
    await _reload();
    return id;
  }

  Future<void> deleteTxn(int id) async {
    txns = txns.where((t) => t.id != id).toList();
    notifyListeners();
    await _db.delete('txns', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addGoal(Goal g) async {
    await _db.insert('goals', g.toMap());
    await _reload();
  }

  Future<void> deleteGoal(int id) async {
    goals = goals.where((g) => g.id != id).toList();
    notifyListeners();
    await _db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setBudget(int v) async {
    budget = v;
    await _prefs.setInt('budget', v);
    notifyListeners();
  }

  String exportJson() => jsonEncode({
        'v': 1,
        'budget': budget,
        'goals': goals.map((g) => g.toMap()).toList(),
        'txns': txns.map((t) => t.toMap()).toList(),
      });

  Future<void> importJson(String s) async {
    final j = jsonDecode(s) as Map<String, dynamic>;
    final gs = (j['goals'] as List).cast<Map<String, dynamic>>();
    final ts = (j['txns'] as List).cast<Map<String, dynamic>>();
    await _db.transaction((tx) async {
      await tx.delete('txns');
      await tx.delete('goals');
      for (final g in gs) {
        await tx.insert('goals', g);
      }
      for (final t in ts) {
        await tx.insert('txns', t);
      }
    });
    await setBudget((j['budget'] as num?)?.toInt() ?? 0);
    await _reload();
  }

  String goalName(int? id) {
    for (final g in goals) {
      if (g.id == id) return g.name;
    }
    return 'Saving';
  }

  // ---- spending ----
  int spentOn(DateTime d) => txns
      .where((t) => t.kind == Kind.expense && sameDay(t.ts, d))
      .fold<int>(0, (s, t) => s + t.amount);

  int get spentToday => spentOn(DateTime.now());

  int get spentBeforeToday {
    final n = DateTime.now();
    final start = dayOf(n);
    final m0 = DateTime(n.year, n.month, 1);
    return txns
        .where((t) =>
            t.kind == Kind.expense &&
            !t.ts.isBefore(m0) &&
            t.ts.isBefore(start))
        .fold<int>(0, (s, t) => s + t.amount);
  }

  // Budget left this month, spread over the days left (today included).
  int get allowanceToday {
    if (budget <= 0) return 0;
    final n = DateTime.now();
    final daysLeft = DateTime(n.year, n.month + 1, 0).day - n.day + 1;
    final v = ((budget - spentBeforeToday) / daysLeft).floor();
    return v < 0 ? 0 : v;
  }

  int get leftToday => allowanceToday - spentToday;

  // ---- goals ----
  int savedFor(Goal g) => txns
      .where((t) => t.kind == Kind.saving && t.goalId == g.id)
      .fold<int>(0, (s, t) => s + t.amount);

  int savedTodayFor(Goal g) => txns
      .where((t) =>
          t.kind == Kind.saving &&
          t.goalId == g.id &&
          sameDay(t.ts, DateTime.now()))
      .fold<int>(0, (s, t) => s + t.amount);

  GoalPlan planFor(Goal g) {
    final today = dayOf(DateTime.now());
    final saved = savedFor(g);
    final remaining = max(0, g.target - saved);
    final daysLeft = max(1, dayOf(g.deadline).difference(today).inDays);
    final perDay = (remaining / daysLeft).ceil();
    final own = txns
        .where((t) =>
            t.kind == Kind.saving &&
            t.goalId == g.id &&
            t.category != 'Opening')
        .toList();
    var paceReady = false;
    DateTime? eta;
    if (own.isNotEmpty) {
      final first = dayOf(
          own.map((t) => t.ts).reduce((a, b) => a.isBefore(b) ? a : b));
      final active = today.difference(first).inDays + 1;
      final ownSum = own.fold<int>(0, (s, t) => s + t.amount);
      paceReady = active >= 7;
      if (paceReady && remaining > 0 && ownSum > 0) {
        eta = today
            .add(Duration(days: (remaining / (ownSum / active)).ceil()));
      }
    }
    final done = remaining == 0;
    final onTrack = done || (eta != null && !eta.isAfter(dayOf(g.deadline)));
    return GoalPlan(
      saved: saved,
      remaining: remaining,
      daysLeft: daysLeft,
      perDay: perDay,
      eta: eta,
      done: done,
      onTrack: onTrack,
      paceReady: paceReady,
    );
  }

  // Marks a goal's first saving as its starting amount, so it is not
  // counted as a saving habit when working out your pace.
  Future<void> markOpening(Goal g) async {
    final list = txns
        .where((t) => t.kind == Kind.saving && t.goalId == g.id)
        .toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
    if (list.isEmpty) return;
    await _db.update('txns', {'category': 'Opening'},
        where: 'id = ?', whereArgs: [list.first.id]);
    await _reload();
  }

  Future<void> setName(String v) async {
    name = v.trim().isEmpty ? 'Leon' : v.trim();
    await _prefs.setString('name', name);
    notifyListeners();
  }
}

final store = Store();
