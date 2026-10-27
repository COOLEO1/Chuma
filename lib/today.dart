import 'package:flutter/material.dart';
import 'add_sheet.dart';
import 'goals.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

Future<void> editBudget(BuildContext context) async {
  final c = TextEditingController(
      text: store.budget > 0 ? '${store.budget}' : '');
  final v = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Monthly spending budget'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text(
            'How much can you spend this month, after setting aside your savings?'),
        const SizedBox(height: 12),
        TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(prefixText: 'MK '),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text.trim())),
            child: const Text('Save budget')),
      ],
    ),
  );
  if (v != null && v > 0) await store.setBudget(v);
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text('${greeting()}, ${store.name}',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: C.ink)),
        const SizedBox(height: 16),
        _hero(context),
        if (store.goals.isEmpty) ...[
          sectionTitle('Your goals'),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                  'Name something you are saving for and Chuma tells you how much to save each day.',
                  style: TextStyle(color: C.muted)),
              const SizedBox(height: 12),
              FilledButton.tonal(
                  onPressed: () => showNewGoal(context),
                  child: const Text('Create a goal')),
            ]),
          ),
        ] else ...[
          sectionTitle('Your goals'),
          for (final g in store.goals.take(3))
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _goalRow(context, g)),
        ],
        sectionTitle('Recent'),
        if (store.txns.isEmpty)
          const Panel(
            child: Text('Tap Add to log your first spend.',
                style: TextStyle(color: C.muted)),
          )
        else
          for (final t in store.txns.take(5))
            Padding(
                padding: const EdgeInsets.only(bottom: 8), child: TxnTile(t)),
      ],
    );
  }

  Widget _hero(BuildContext context) {
    final allowance = store.allowanceToday;
    final left = store.leftToday;
    final spent = store.spentToday;
    final over = left < 0;
    return Panel(
      color: C.navy,
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(over ? "Over today's limit" : 'Safe to spend today',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 18),
            onPressed: () => editBudget(context),
          ),
        ]),
        if (store.budget <= 0) ...[
          const Text('Set a monthly budget to see your daily number.',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: C.gold, foregroundColor: C.navy),
            onPressed: () => editBudget(context),
            child: const Text('Set budget'),
          ),
        ] else ...[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: left.abs().toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(
              mk(v.round()),
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: over ? const Color(0xFFFF8A8E) : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: allowance == 0
                    ? (spent > 0 ? 1.0 : 0.0)
                    : (spent / allowance).clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: Colors.white24,
                color: over ? C.coral : C.teal,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('${mk(spent)} spent of ${mk(allowance)}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ]),
    );
  }

  Widget _goalRow(BuildContext context, Goal g) {
    final plan = store.planFor(g);
    final pct = g.target == 0
        ? 0.0
        : (plan.saved / g.target).clamp(0.0, 1.0).toDouble();
    final doneToday = store.savedTodayFor(g) >= plan.perDay;
    final msg = plan.done
        ? 'Goal reached'
        : doneToday
            ? "Today's saving target reached"
            : 'Save ${mk(plan.perDay)} today';
    return Panel(
      child: Row(children: [
        Ring(
          value: pct,
          size: 56,
          color: C.gold,
          child: Text('${(pct * 100).round()}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16, color: C.ink)),
            Text(msg, style: const TextStyle(color: C.muted, fontSize: 13)),
          ]),
        ),
        if (plan.done || doneToday)
          const Icon(Icons.check_circle, color: C.teal, size: 30)
        else
          FilledButton.tonal(
            onPressed: () => openAdd(context, kind: Kind.saving, goalId: g.id),
            child: const Text('Save'),
          ),
      ]),
    );
  }
}
