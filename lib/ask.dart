import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'groq.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

const _askPrompt =
    'You are Chuma, a calm, friendly money assistant inside the personal finance app of the user. '
    'The user lives in Malawi and all amounts are in Malawi kwacha (MK). '
    'Answer only from the data below and the formulas given. Never invent transactions, balances or dates. '
    'Formulas: money left = target minus saved. Minimum per day = money left divided by days left, rounded up. '
    'Days to finish at X a day = money left divided by X, rounded up. Total on the deadline = saved plus X times days left. '
    'For what if questions: state your assumptions in one short line, show the key calculation steps briefly, then give the result with dates. '
    'A lump sum comes first, then daily saving continues. Say these are best case estimates because they assume saving happens every day. '
    'Check your arithmetic twice. Keep answers under 120 words, in plain text with no markdown, no tables and no bullet symbols. '
    'Never judge or guilt the user. You cannot move money, you only know what the user has logged. '
    'If the data is not enough to answer, say what is missing in one sentence.';

class _Msg {
  final bool user, err;
  final String text;
  _Msg(this.user, this.text, {this.err = false});
}

String _context() {
  final now = DateTime.now();
  final today = dayOf(now);
  final df = DateFormat('d MMM yyyy');
  final b = StringBuffer();
  b.writeln("The user's name is ${store.name}.");
  b.writeln('Today is ${DateFormat('EEEE').format(now)} ${df.format(now)}.');
  if (store.goals.isEmpty) b.writeln('The user has no goals yet.');
  for (final g in store.goals) {
    final plan = store.planFor(g);
    final pct = g.target == 0 ? 0 : (plan.saved * 100 / g.target).round();
    b.writeln(
        'GOAL "${g.name}": target ${mk(g.target)}, saved ${mk(plan.saved)} ($pct%), left ${mk(plan.remaining)}, deadline ${df.format(g.deadline)}, ${plan.daysLeft} days left, minimum needed per day ${mk(plan.perDay)}.');
    if (plan.eta != null) {
      b.writeln(
          'App pace line: at the real recent pace the goal is reached on ${df.format(plan.eta!)}.');
    } else if (!plan.done) {
      b.writeln('App pace line: not available yet (needs 7 days of saving).');
    }
    if (plan.remaining > 0) {
      b.writeln(
          'Projection if the user saves the same amount every day starting today (best case):');
      for (final r in const [500, 700, 1000, 1400, 2000, 3000]) {
        final days = (plan.remaining / r).ceil();
        b.writeln(
            '- ${mk(r)} a day: target reached in $days days (${df.format(today.add(Duration(days: days)))}); total saved on the deadline ${mk(plan.saved + r * plan.daysLeft)}.');
      }
    }
  }
  b.writeln('Daily log, last 14 days (saved to goals / spent):');
  var savedWeek = 0;
  for (var i = 0; i < 14; i++) {
    final d = today.subtract(Duration(days: i));
    final sv = store.txns
        .where((t) =>
            t.kind == Kind.saving &&
            t.category != 'Opening' &&
            sameDay(t.ts, d))
        .fold<int>(0, (s, t) => s + t.amount);
    final sp = store.spentOn(d);
    if (i < 7) savedWeek += sv;
    if (sv > 0 || sp > 0) {
      b.writeln(
          '- ${DateFormat('EEE d MMM').format(d)}: saved ${mk(sv)}, spent ${mk(sp)}');
    }
  }
  b.writeln(
      'Saved in the last 7 days (not counting starting amounts): ${mk(savedWeek)}, about ${mk((savedWeek / 7).round())} a day.');
  final cats = <String, int>{};
  for (final t in store.txns) {
    if (t.kind == Kind.expense &&
        t.ts.year == now.year &&
        t.ts.month == now.month) {
      cats[t.category] = (cats[t.category] ?? 0) + t.amount;
    }
  }
  b.writeln('Spent this month: ' +
      (cats.isEmpty
          ? 'nothing logged'
          : cats.entries.map((e) => '${e.key} ${mk(e.value)}').join(', ')) +
      '.');
  if (store.budget > 0) {
    b.writeln(
        'Monthly spending budget: ${mk(store.budget)}; safe to spend today: ${mk(store.leftToday)}.');
  }
  return b.toString();
}

class AskScreen extends StatefulWidget {
  const AskScreen({super.key});

  @override
  State<AskScreen> createState() => _AskState();
}

class _AskState extends State<AskScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final msgs = <_Msg>[];
  bool busy = false;

  static const chips = [
    'How much should I save each day?',
    'When will I reach my goal if I save MK 1,400 every day?',
    'What if I skip 3 days?',
    'What if I save MK 7,000 on Friday and MK 1,400 on other days?',
    'How much did I spend this week?',
  ];

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String q) async {
    q = q.trim();
    if (q.isEmpty || busy) return;
    final p = await SharedPreferences.getInstance();
    final key = p.getString('groq_key') ?? '';
    final model = p.getString('groq_model') ?? defaultGroqModel;
    setState(() {
      msgs.add(_Msg(true, q));
      input.clear();
    });
    _toEnd();
    if (key.isEmpty) {
      setState(() => msgs.add(
          _Msg(false, 'Add your Groq key in Settings first.', err: true)));
      return;
    }
    setState(() => busy = true);
    try {
      final hist = msgs.where((m) => !m.err).toList();
      final recent = hist.length > 8 ? hist.sublist(hist.length - 8) : hist;
      final reply = await Groq.converse(key, model, [
        {'role': 'system', 'content': '$_askPrompt\n\n${_context()}'},
        for (final m in recent)
          {'role': m.user ? 'user' : 'assistant', 'content': m.text},
      ]);
      if (!mounted) return;
      setState(() => msgs.add(_Msg(false, reply)));
    } on SocketException {
      if (!mounted) return;
      setState(() => msgs.add(_Msg(
          false, 'No internet right now. Try again when you are online.',
          err: true)));
    } catch (e) {
      if (!mounted) return;
      setState(() => msgs.add(_Msg(false, '$e', err: true)));
    } finally {
      if (mounted) setState(() => busy = false);
      _toEnd();
    }
  }

  Widget _bubble(_Msg m) => Align(
        alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82),
          decoration: BoxDecoration(
            color: m.user ? C.navy : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: m.user
                ? null
                : Border.all(color: m.err ? C.coral : C.line),
          ),
          child: SelectableText(
            m.text,
            style: TextStyle(
                color: m.user ? Colors.white : (m.err ? C.coral : C.ink),
                height: 1.4,
                fontSize: 15),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        foregroundColor: C.ink,
        elevation: 0,
        title: const Text('Ask Chuma',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (msgs.isNotEmpty)
            IconButton(
              tooltip: 'Clear chat',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(msgs.clear),
            ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: msgs.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                        'Ask what if questions about your goal, saving or spending. I answer from your own numbers.',
                        style: TextStyle(color: C.muted, fontSize: 15)),
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final q in chips)
                        ActionChip(label: Text(q), onPressed: () => _send(q)),
                    ]),
                  ],
                )
              : ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: msgs.length + (busy ? 1 : 0),
                  itemBuilder: (_, i) =>
                      i < msgs.length ? _bubble(msgs[i]) : _bubble(_Msg(false, 'Thinking...')),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: input,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: _send,
                  decoration: InputDecoration(
                    hintText: 'Ask a what if question',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: C.line),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: C.navy),
                onPressed: busy ? null : () => _send(input.text),
                icon: const Icon(Icons.arrow_upward),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
