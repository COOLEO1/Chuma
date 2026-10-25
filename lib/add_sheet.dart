import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

Future<void> openAdd(BuildContext context,
    {Kind kind = Kind.expense, int? goalId}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: C.bg,
    builder: (_) => AddSheet(kind: kind, goalId: goalId),
  );
}

class AddSheet extends StatefulWidget {
  final Kind kind;
  final int? goalId;
  const AddSheet({super.key, required this.kind, this.goalId});

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  late Kind kind = widget.kind;
  String digits = '';
  String? cat;
  int? goalId;

  @override
  void initState() {
    super.initState();
    goalId = widget.goalId ??
        (store.goals.isNotEmpty ? store.goals.first.id : null);
  }

  bool get _canSave =>
      digits.isNotEmpty && (kind == Kind.saving ? goalId != null : cat != null);

  Color get _color => switch (kind) {
        Kind.expense => C.coral,
        Kind.income => C.teal,
        Kind.saving => C.goldDark,
      };

  void _press(String k) {
    setState(() {
      if (k == 'back') {
        digits = digits.isEmpty ? '' : digits.substring(0, digits.length - 1);
      } else {
        if (digits.isEmpty && k.startsWith('0')) return;
        if (digits.length + k.length > 9) return;
        digits += k;
      }
    });
  }

  Future<void> _save() async {
    final amount = int.parse(digits);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final id = await store.addTxn(Txn(
      kind: kind,
      amount: amount,
      category: kind == Kind.saving ? 'Saving' : cat!,
      goalId: kind == Kind.saving ? goalId : null,
      ts: DateTime.now(),
    ));
    HapticFeedback.mediumImpact();
    nav.pop();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('Logged ${mk(amount)}'),
      action: SnackBarAction(label: 'Undo', onPressed: () => store.deleteTxn(id)),
    ));
  }

  Widget _key(String k) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _press(k),
              child: SizedBox(
                height: 54,
                child: Center(
                  child: k == 'back'
                      ? const Icon(Icons.backspace_outlined, color: C.ink)
                      : Text(k,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: C.ink)),
                ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['000', '0', 'back'],
    ];
    final cats = kind == Kind.income ? incomeCats : expenseCats;
    final label = switch (kind) {
      Kind.expense => 'Log spending',
      Kind.income => 'Log income',
      Kind.saving => 'Add saving',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SegmentedButton<Kind>(
          segments: const [
            ButtonSegment(value: Kind.expense, label: Text('Spent')),
            ButtonSegment(value: Kind.income, label: Text('Received')),
            ButtonSegment(value: Kind.saving, label: Text('Saved')),
          ],
          selected: {kind},
          onSelectionChanged: (s) => setState(() {
            kind = s.first;
            cat = null;
          }),
        ),
        const SizedBox(height: 16),
        Text(
          digits.isEmpty ? 'MK 0' : mk(int.parse(digits)),
          style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: digits.isEmpty ? C.muted : _color),
        ),
        const SizedBox(height: 12),
        if (kind == Kind.saving)
          store.goals.isEmpty
              ? const Text('Create a goal first, then add savings to it.',
                  style: TextStyle(color: C.muted))
              : Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final g in store.goals)
                    ChoiceChip(
                      avatar: const Icon(Icons.flag, size: 18),
                      label: Text(g.name),
                      selected: goalId == g.id,
                      onSelected: (_) => setState(() => goalId = g.id),
                    ),
                ])
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in cats)
              ChoiceChip(
                avatar: Icon(c.icon, size: 18),
                label: Text(c.name),
                selected: cat == c.name,
                onSelected: (_) => setState(() => cat = c.name),
              ),
          ]),
        const SizedBox(height: 12),
        for (final r in rows) Row(children: [for (final k in r) _key(k)]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.navy),
            onPressed: _canSave ? _save : null,
            child: Text(label, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ]),
    );
  }
}
