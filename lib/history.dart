import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (store.txns.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Nothing logged yet.\nTap Add to log your first spend.',
              textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
        ),
      );
    }
    final items = <Object>[];
    DateTime? last;
    for (final t in store.txns) {
      if (last == null || !sameDay(last, t.ts)) {
        items.add(dayOf(t.ts));
        last = t.ts;
      }
      items.add(t);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: items.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('History',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: C.ink)),
          );
        }
        final it = items[i - 1];
        if (it is DateTime) {
          final spent = store.spentOn(it);
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Row(children: [
              Text(dayLabel(it),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: C.ink)),
              const Spacer(),
              if (spent > 0)
                Text('Spent ${mk(spent)}',
                    style: const TextStyle(color: C.muted, fontSize: 13)),
            ]),
          );
        }
        final t = it as Txn;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Dismissible(
            key: ValueKey('t${t.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                  color: C.coral, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            onDismissed: (_) {
              final messenger = ScaffoldMessenger.of(ctx);
              store.deleteTxn(t.id!);
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(SnackBar(
                content: const Text('Deleted'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () => store.addTxn(Txn(
                    kind: t.kind,
                    amount: t.amount,
                    category: t.category,
                    note: t.note,
                    goalId: t.goalId,
                    ts: t.ts,
                  )),
                ),
              ));
            },
            child: TxnTile(t),
          ),
        );
      },
    );
  }
}
