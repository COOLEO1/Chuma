import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

class SmsResult {
  final Kind? kind; // null when the message does not say
  final int amount, fee;
  final String category;
  SmsResult(this.kind, this.amount, this.category, this.fee);
}

int? _num(String s) => double.tryParse(s.replaceAll(',', ''))?.round();

const _n = r'([0-9][0-9,]*(?:\.[0-9]+)?)';

SmsResult? parseSms(String raw) {
  final text = raw.replaceAll(RegExp(r'\s+'), ' ');
  final lower = text.toLowerCase();

  int? amount;
  final amtM =
      RegExp('(?:amt|amount)[^0-9]{0,8}$_n', caseSensitive: false)
          .firstMatch(text);
  if (amtM != null) amount = _num(amtM.group(1)!);
  if (amount == null || amount <= 0) {
    amount = null;
    final any = RegExp('(?:mwk|mk)\\s?$_n|$_n\\s?(?:mwk|mk)\\b',
        caseSensitive: false);
    for (final m in any.allMatches(text)) {
      final v = _num(m.group(1) ?? m.group(2)!);
      if (v == null || v <= 0) continue;
      final before = lower.substring(m.start < 12 ? 0 : m.start - 12, m.start);
      if (before.contains('bal') ||
          before.contains('fee') ||
          before.contains('levy') ||
          before.contains('charge')) {
        continue;
      }
      amount = v;
      break;
    }
  }
  if (amount == null) return null;

  int firstAt(List<String> words) {
    var best = -1;
    for (final w in words) {
      final i = lower.indexOf(w);
      if (i >= 0 && (best < 0 || i < best)) best = i;
    }
    return best;
  }

  final inc = firstAt(['received', 'cash in', 'cash-in', 'deposit', 'credited']);
  final exp = firstAt([
    'sent', 'paid', 'payment', 'withdraw', 'bought', 'purchase',
    'airtime', 'transferred', 'debited', 'cash out', 'cash-out'
  ]);
  Kind? kind;
  if (inc >= 0 || exp >= 0) {
    kind = (inc >= 0 && (exp < 0 || inc < exp)) ? Kind.income : Kind.expense;
  }

  var cat = 'Other';
  if (kind == Kind.expense) {
    if (lower.contains('airtime')) {
      cat = 'Airtime';
    } else if (lower.contains('bundle') ||
        lower.contains('data') ||
        lower.contains('internet')) {
      cat = 'Data';
    }
  }

  int label(String l) {
    final m =
        RegExp('$l[^0-9]{0,12}$_n', caseSensitive: false).firstMatch(text);
    return m == null ? 0 : (_num(m.group(1)!) ?? 0);
  }

  final fee = kind == Kind.income ? 0 : label('fee') + label('levy') + label('charge');
  return SmsResult(kind, amount, cat, fee);
}

Future<void> openSmsPaste(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: C.bg,
      builder: (_) => const _SmsSheet(),
    );

class _SmsSheet extends StatefulWidget {
  const _SmsSheet();

  @override
  State<_SmsSheet> createState() => _SmsSheetState();
}

class _SmsSheetState extends State<_SmsSheet> {
  final c = TextEditingController();
  Kind? forced;

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) {
      setState(() {
        c.text = d!.text!;
        forced = null;
      });
    }
  }

  Future<void> _log(SmsResult r, Kind k) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cat = k == r.kind ? r.category : 'Other';
    await store.addTxn(Txn(
        kind: k,
        amount: r.amount,
        category: cat,
        note: 'From SMS',
        ts: DateTime.now()));
    if (k == Kind.expense && r.fee > 0) {
      await store.addTxn(Txn(
          kind: Kind.expense,
          amount: r.fee,
          category: 'Fees',
          note: 'From SMS',
          ts: DateTime.now()));
    }
    HapticFeedback.mediumImpact();
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text('Logged ${mk(r.amount)}')));
  }

  @override
  Widget build(BuildContext context) {
    final r = c.text.trim().isEmpty ? null : parseSms(c.text);
    final k = r == null ? null : (forced ?? r.kind);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Paste a mobile money message',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: C.ink)),
        const SizedBox(height: 12),
        TextField(
          controller: c,
          maxLines: 5,
          onChanged: (_) => setState(() => forced = null),
          decoration: const InputDecoration(
              hintText: 'Paste your Airtel Money or Mpamba SMS here',
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
            onPressed: _paste,
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste from clipboard')),
        if (c.text.trim().isNotEmpty && r == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
                'Could not find an amount in that message. You can log it by hand with Add.',
                style: TextStyle(color: C.coral)),
          ),
        if (r != null) ...[
          const SizedBox(height: 8),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  k == null
                      ? 'Amount ${mk(r.amount)}'
                      : '${k == Kind.income ? "Received" : "Spent"} ${mk(r.amount)}',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: k == null
                          ? C.ink
                          : (k == Kind.income ? C.teal : C.coral))),
              if (k == null)
                const Text(
                    'This message does not say if money came in or went out. Pick one.',
                    style: TextStyle(color: C.muted)),
              if (k == Kind.expense)
                Text('Category: ${k == r.kind ? r.category : "Other"}',
                    style: const TextStyle(color: C.muted)),
              if (k == Kind.expense && r.fee > 0)
                Text('Fee and levy ${mk(r.fee)} will be logged under Fees',
                    style: const TextStyle(color: C.muted)),
              const SizedBox(height: 10),
              SegmentedButton<Kind>(
                emptySelectionAllowed: r.kind == null,
                segments: const [
                  ButtonSegment(value: Kind.expense, label: Text('Spent')),
                  ButtonSegment(value: Kind.income, label: Text('Received')),
                ],
                selected: k == null ? <Kind>{} : {k},
                onSelectionChanged: (s) =>
                    setState(() => forced = s.isEmpty ? null : s.first),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.navy),
              onPressed: k == null ? null : () => _log(r, k),
              child: const Text('Log it'),
            ),
          ),
        ],
      ]),
    );
  }
}
