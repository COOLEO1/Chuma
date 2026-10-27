import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_sheet.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

Future<void> showNewGoal(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: C.bg,
    builder: (_) => const NewGoalSheet(),
  );
}

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Row(children: [
          const Text('Goals',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: C.ink)),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: C.navy),
            onPressed: () => showNewGoal(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New goal'),
          ),
        ]),
        const SizedBox(height: 16),
        if (store.goals.isEmpty)
          const Panel(
            child: Text(
                'No goals yet. Name something you are saving for, like a laptop or a car, and Chuma tells you how much to save each day.',
                style: TextStyle(color: C.muted)),
          )
        else
          for (final g in store.goals)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _card(context, g)),
      ],
    );
  }

  Widget _card(BuildContext context, Goal g) {
    final plan = store.planFor(g);
    final pct = g.target == 0
        ? 0.0
        : (plan.saved / g.target).clamp(0.0, 1.0).toDouble();
    final fmt = DateFormat('d MMM yyyy');

    Widget pace;
    if (plan.done) {
      pace = const Text('Goal reached.',
          style: TextStyle(color: C.teal, fontWeight: FontWeight.w600));
    } else if (plan.eta == null) {
      pace = const Text(
          'Your pace appears after 7 days of saving, so it reflects your real habit.',
          style: TextStyle(color: C.muted));
    } else if (plan.onTrack) {
      pace = Text('At your pace you will reach it by ${fmt.format(plan.eta!)}.',
          style: const TextStyle(color: C.teal, fontWeight: FontWeight.w600));
    } else {
      pace = Text(
          'At your pace you will reach it by ${fmt.format(plan.eta!)}, after your deadline.',
          style: const TextStyle(color: C.coral, fontWeight: FontWeight.w600));
    }

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Ring(
            value: pct,
            size: 64,
            color: C.gold,
            child: Text('${(pct * 100).round()}%',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 17, color: C.ink)),
              Text('${mk(plan.saved)} of ${mk(g.target)}',
                  style: const TextStyle(color: C.muted)),
            ]),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'open') {
                store.markOpening(g);
              } else {
                _confirmDelete(context, g);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'open',
                  child: Text('Count first saving as starting amount')),
              PopupMenuItem(value: 'del', child: Text('Delete goal')),
            ],
          ),
        ]),
        const SizedBox(height: 14),
        if (!plan.done) ...[
          Text('Save ${mk(plan.perDay)} a day',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: C.ink)),
          const SizedBox(height: 2),
          Text('${plan.daysLeft} days until ${fmt.format(g.deadline)}',
              style: const TextStyle(color: C.muted, fontSize: 13)),
          const SizedBox(height: 10),
        ],
        pace,
        if (!plan.done) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () =>
                  openAdd(context, kind: Kind.saving, goalId: g.id),
              child: const Text('Add saving'),
            ),
          ),
        ],
      ]),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Goal g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${g.name}?'),
        content: const Text('Your saving entries stay in History.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete goal')),
        ],
      ),
    );
    if (ok == true) await store.deleteGoal(g.id!);
  }
}

class NewGoalSheet extends StatefulWidget {
  const NewGoalSheet({super.key});

  @override
  State<NewGoalSheet> createState() => _NewGoalSheetState();
}

class _NewGoalSheetState extends State<NewGoalSheet> {
  final name = TextEditingController();
  final target = TextEditingController();
  DateTime deadline = DateTime.now().add(const Duration(days: 90));

  int get _target => int.tryParse(target.text.replaceAll(',', '').trim()) ?? 0;
  bool get _ok => name.text.trim().isNotEmpty && _target > 0;

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (d != null) setState(() => deadline = d);
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    await store.addGoal(Goal(
      name: name.text.trim(),
      target: _target,
      deadline: deadline,
      created: DateTime.now(),
    ));
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New goal',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: C.ink)),
          const SizedBox(height: 14),
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'What are you saving for?',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: target,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'Target amount',
                prefixText: 'MK ',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.event),
            label: Text('Deadline: ${DateFormat('d MMM yyyy').format(deadline)}'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.navy),
              onPressed: _ok ? _save : null,
              child: const Text('Create goal'),
            ),
          ),
        ],
      ),
    );
  }
}
