import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'store.dart';

class C {
  static const navy = Color(0xFF0F1B3D);
  static const bg = Color(0xFFF4F6FA);
  static const coral = Color(0xFFE5484D);
  static const teal = Color(0xFF12A594);
  static const gold = Color(0xFFF2B544);
  static const goldDark = Color(0xFF9A6B00);
  static const ink = Color(0xFF1B2338);
  static const muted = Color(0xFF6B7690);
  static const line = Color(0xFFE3E7F0);
}

final _fmt = NumberFormat('#,##0');
String mk(int v) => v < 0 ? '-MK ${_fmt.format(-v)}' : 'MK ${_fmt.format(v)}';

String dayLabel(DateTime d) {
  final now = DateTime.now();
  if (sameDay(d, now)) return 'Today';
  if (sameDay(d, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  return DateFormat('EEE d MMM').format(d);
}

ThemeData chumaTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: C.navy),
      scaffoldBackgroundColor: C.bg,
      navigationBarTheme:
          const NavigationBarThemeData(backgroundColor: Colors.white),
    );

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: color == Colors.white ? Border.all(color: C.line) : null,
        ),
        child: child,
      );
}

Widget sectionTitle(String s) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(s,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: C.ink)),
    );

class Ring extends StatelessWidget {
  final double value, size;
  final Color color;
  final Widget? child;
  const Ring({
    super.key,
    required this.value,
    required this.size,
    required this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => CircularProgressIndicator(
                value: v,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: color.withAlpha(46),
              ),
            ),
          ),
          if (child != null) child!,
        ]),
      );
}

class TxnTile extends StatelessWidget {
  final Txn t;
  const TxnTile(this.t, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = switch (t.kind) {
      Kind.expense => C.coral,
      Kind.income => C.teal,
      Kind.saving => C.goldDark,
    };
    final sign = switch (t.kind) {
      Kind.expense => '-',
      Kind.income => '+',
      Kind.saving => '',
    };
    final when = sameDay(t.ts, DateTime.now())
        ? DateFormat('HH:mm').format(t.ts)
        : DateFormat('d MMM HH:mm').format(t.ts);
    final sub =
        t.kind == Kind.saving ? '${store.goalName(t.goalId)}, $when' : when;
    final title = t.kind == Kind.saving ? 'Saved' : t.category;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.line),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withAlpha(30),
          child: Icon(iconFor(t), color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15, color: C.ink)),
            Text(sub, style: const TextStyle(color: C.muted, fontSize: 13)),
          ]),
        ),
        Text('$sign${mk(t.amount)}',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15, color: color)),
      ]),
    );
  }
}
