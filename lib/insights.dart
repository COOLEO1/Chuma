import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'groq.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

const _catColors = <String, Color>{
  'Airtime': Color(0xFFE5484D),
  'Data': Color(0xFF3E63DD),
  'Transport': Color(0xFFF2B544),
  'Food': Color(0xFF12A594),
  'Fees': Color(0xFF8E4EC6),
  'Other': Color(0xFF8B93A7),
};
Color catColor(String n) => _catColors[n] ?? C.muted;

int _ago(DateTime d) => dayOf(DateTime.now()).difference(dayOf(d)).inDays;

int _sumDay(Kind k, DateTime d) => store.txns
    .where((t) => t.kind == k && sameDay(t.ts, d))
    .fold<int>(0, (s, t) => s + t.amount);

const _systemPrompt =
    'You are Chuma, a friendly money coach inside a personal finance app used in Malawi. '
    'Amounts are in Malawi kwacha (MK). Write 3 to 4 short sentences in plain English, '
    'speaking to the user as "you". Mention one thing that changed versus last week, '
    'one thing to watch, and one concrete action for the next 7 days. '
    'Use only the numbers given. Do not use markdown or lists.';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsState();
}

class _InsightsState extends State<InsightsScreen> {
  int sel = 6;
  String? summary;
  String? error;
  bool loading = false;

  int _sum(Kind k, int from, int to) => store.txns
      .where((t) => t.kind == k && _ago(t.ts) >= from && _ago(t.ts) <= to)
      .fold<int>(0, (s, t) => s + t.amount);

  String _digest() {
    final cats = <String, int>{};
    for (final t in store.txns) {
      if (t.kind == Kind.expense && _ago(t.ts) <= 6) {
        cats[t.category] = (cats[t.category] ?? 0) + t.amount;
      }
    }
    final b = StringBuffer();
    b.writeln('Spent this week: ${mk(_sum(Kind.expense, 0, 6))}');
    b.writeln('Spent last week: ${mk(_sum(Kind.expense, 7, 13))}');
    b.writeln('This week by category: ' +
        (cats.isEmpty
            ? 'none'
            : cats.entries.map((e) => '${e.key} ${mk(e.value)}').join(', ')));
    b.writeln('Received this week: ${mk(_sum(Kind.income, 0, 6))}');
    b.writeln('Saved this week: ${mk(_sum(Kind.saving, 0, 6))}');
    if (store.budget > 0) b.writeln('Monthly budget: ${mk(store.budget)}');
    for (final g in store.goals) {
      final p = store.planFor(g);
      b.writeln(
          'Goal ${g.name}: saved ${mk(p.saved)} of ${mk(g.target)}, needs ${mk(p.perDay)} a day, ${p.onTrack ? "on track" : "behind pace"}');
    }
    return b.toString();
  }

  Future<void> _summarize() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('groq_key') ?? '';
    final model = prefs.getString('groq_model') ?? defaultGroqModel;
    if (key.isEmpty) {
      setState(() {
        error = 'Add your Groq key in Settings first.';
        summary = null;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final text = await Groq.chat(key, model, _systemPrompt, _digest());
      if (!mounted) return;
      setState(() => summary = text);
    } on SocketException {
      if (!mounted) return;
      setState(() =>
          error = 'No internet. Everything else in Chuma works offline.');
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  int _streak() {
    if (store.budget <= 0 || store.txns.isEmpty) return 0;
    final n = DateTime.now();
    final daily = store.budget ~/ DateTime(n.year, n.month + 1, 0).day;
    final first = dayOf(
        store.txns.map((t) => t.ts).reduce((a, b) => a.isBefore(b) ? a : b));
    var d = dayOf(n);
    var c = 0;
    while (!d.isBefore(first) && store.spentOn(d) <= daily) {
      c++;
      d = d.subtract(const Duration(days: 1));
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final today = dayOf(DateTime.now());
    const wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final vals = [for (final d in days) store.spentOn(d)];
    final thisWeek = vals.fold<int>(0, (a, b) => a + b);
    var lastWeek = 0;
    for (var i = 7; i < 14; i++) {
      lastWeek += store.spentOn(today.subtract(Duration(days: i)));
    }
    var change = 'Nothing logged yet.';
    var changeColor = C.muted;
    if (lastWeek > 0) {
      final p = ((thisWeek - lastWeek) * 100 / lastWeek).round();
      if (p == 0) {
        change = 'Same as last week.';
      } else if (p > 0) {
        change = '$p% more than last week.';
        changeColor = C.coral;
      } else {
        change = '${-p}% less than last week.';
        changeColor = C.teal;
      }
    } else if (thisWeek > 0) {
      change = 'Nothing logged the week before.';
    }

    final now = DateTime.now();
    final monthCats = <String, int>{};
    for (final t in store.txns) {
      if (t.kind == Kind.expense &&
          t.ts.year == now.year &&
          t.ts.month == now.month) {
        monthCats[t.category] = (monthCats[t.category] ?? 0) + t.amount;
      }
    }
    final entries = monthCats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final monthTotal = entries.fold<int>(0, (s, e) => s + e.value);

    final d30 = List.generate(30, (i) => today.subtract(Duration(days: 29 - i)));
    final spend30 = [for (final d in d30) _sumDay(Kind.expense, d).toDouble()];
    final inc30 = [for (final d in d30) _sumDay(Kind.income, d).toDouble()];
    final has30 = spend30.any((v) => v > 0) || inc30.any((v) => v > 0);
    final streak = _streak();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        const Text('Insights',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: C.ink)),
        sectionTitle('Last 7 days'),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mk(thisWeek),
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w700, color: C.ink)),
            Text(change,
                style: TextStyle(
                    color: changeColor, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text('${dayLabel(days[sel])}: ${mk(vals[sel])}',
                style: const TextStyle(color: C.muted, fontSize: 13)),
            const SizedBox(height: 6),
            SizedBox(
              height: 170,
              child: LayoutBuilder(
                builder: (_, c) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => setState(() => sel =
                      (d.localPosition.dx / (c.maxWidth / 7))
                          .floor()
                          .clamp(0, 6)
                          .toInt()),
                  child: CustomPaint(
                    size: Size(c.maxWidth, 170),
                    painter: _BarsPainter(
                        vals, [for (final d in days) wd[d.weekday - 1]], sel),
                  ),
                ),
              ),
            ),
          ]),
        ),
        if (store.budget > 0 && streak > 0) ...[
          const SizedBox(height: 10),
          Panel(
            child: Row(children: [
              const Icon(Icons.local_fire_department, color: C.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    '$streak ${streak == 1 ? "day" : "days"} under your daily budget in a row',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: C.ink)),
              ),
            ]),
          ),
        ],
        sectionTitle('Where it went this month'),
        if (entries.isEmpty)
          const Panel(
              child: Text('Log some spending to see where your money goes.',
                  style: TextStyle(color: C.muted)))
        else
          Panel(
            child: Column(children: [
              SizedBox(
                width: 170,
                height: 170,
                child: CustomPaint(
                  painter: _DonutPainter([for (final e in entries) e.value],
                      [for (final e in entries) catColor(e.key)]),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Spent',
                          style: TextStyle(color: C.muted, fontSize: 12)),
                      Text(mk(monthTotal),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: C.ink)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: catColor(e.key),
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(e.key,
                            style: const TextStyle(color: C.ink))),
                    Text(mk(e.value),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, color: C.ink)),
                    SizedBox(
                      width: 46,
                      child: Text('${(e.value * 100 / monthTotal).round()}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: C.muted)),
                    ),
                  ]),
                ),
            ]),
          ),
        sectionTitle('Last 30 days'),
        if (!has30)
          const Panel(
              child: Text('Your 30-day trend appears after you log a few days.',
                  style: TextStyle(color: C.muted)))
        else
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: const [
                Icon(Icons.circle, size: 10, color: C.coral),
                SizedBox(width: 6),
                Text('Spent', style: TextStyle(color: C.muted)),
                SizedBox(width: 16),
                Icon(Icons.circle, size: 10, color: C.teal),
                SizedBox(width: 6),
                Text('Received', style: TextStyle(color: C.muted)),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                height: 140,
                width: double.infinity,
                child: CustomPaint(painter: _LinesPainter(spend30, inc30)),
              ),
            ]),
          ),
        sectionTitle('Weekly summary'),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (summary != null)
              Text(summary!,
                  style: const TextStyle(color: C.ink, height: 1.4))
            else if (error != null)
              Text(error!, style: const TextStyle(color: C.coral))
            else
              const Text(
                  'Get a short read on your week from your own numbers. Needs internet and your Groq key.',
                  style: TextStyle(color: C.muted)),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: loading ? null : _summarize,
              child: Text(loading
                  ? 'Reading your week...'
                  : summary == null
                      ? 'Get weekly summary'
                      : 'Refresh summary'),
            ),
          ]),
        ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<int> v;
  final List<String> labels;
  final int sel;
  _BarsPainter(this.v, this.labels, this.sel);

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 24.0;
    final chartH = size.height - labelH;
    final maxV = max(1, v.reduce(max));
    final w = size.width / v.length;
    for (var i = 0; i < v.length; i++) {
      final h = max(4.0, chartH * v[i] / maxV);
      final bw = w * 0.5;
      final x = i * w + (w - bw) / 2;
      final r = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, chartH - h, bw, h),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      );
      canvas.drawRRect(
          r, Paint()..color = i == sel ? C.coral : C.coral.withAlpha(80));
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
              fontSize: 12,
              fontWeight: i == sel ? FontWeight.w700 : FontWeight.w500,
              color: i == sel ? C.ink : C.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(i * w + (w - tp.width) / 2, chartH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _DonutPainter extends CustomPainter {
  final List<int> v;
  final List<Color> colors;
  _DonutPainter(this.v, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final total = v.fold<int>(0, (a, b) => a + b);
    if (total == 0) return;
    const stroke = 24.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    var start = -pi / 2;
    for (var i = 0; i < v.length; i++) {
      final sweep = 2 * pi * v[i] / total;
      canvas.drawArc(
        rect,
        start,
        max(0.0, sweep - 0.04),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = colors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _LinesPainter extends CustomPainter {
  final List<double> a, b;
  _LinesPainter(this.a, this.b);

  Path _path(List<double> s, double maxV, Size size) {
    final p = Path();
    for (var i = 0; i < s.length; i++) {
      final x = size.width * i / (s.length - 1);
      final y = size.height - 6 - (size.height - 12) * s[i] / maxV;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = max(1.0, [...a, ...b].reduce(max));
    canvas.drawLine(Offset(0, size.height - 1), Offset(size.width, size.height - 1),
        Paint()
          ..color = C.line
          ..strokeWidth = 1);
    Paint line(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = c;
    canvas.drawPath(_path(a, maxV, size), line(C.coral));
    canvas.drawPath(_path(b, maxV, size), line(C.teal));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
