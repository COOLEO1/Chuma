import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup.dart';
import 'theme.dart';

class AutoBackupPanel extends StatefulWidget {
  const AutoBackupPanel({super.key});

  @override
  State<AutoBackupPanel> createState() => _AutoBackupState();
}

class _AutoBackupState extends State<AutoBackupPanel> {
  final repoC = TextEditingController();
  final tokenC = TextEditingController();
  bool hide = true;
  bool busy = false;
  String status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _status(SharedPreferences p) {
    final err = p.getString('backup_err');
    if (err != null) return err;
    final ts = p.getInt('backup_ts');
    if (ts == null) return 'No backup yet.';
    return 'Last backup: ${DateFormat('d MMM, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts))}';
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      repoC.text = p.getString('gh_repo') ?? '';
      tokenC.text = p.getString('gh_token') ?? '';
      status = _status(p);
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('gh_repo', repoC.text.trim());
    await p.setString('gh_token', tokenC.text.trim());
  }

  Future<void> _backupNow() async {
    setState(() => busy = true);
    await _save();
    final err = await Backup.run(force: true);
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      busy = false;
      status = err ?? _status(p);
    });
  }

  Future<void> _restore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from GitHub?'),
        content: const Text(
            'This replaces everything in Chuma with your last backup.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    await _save();
    final err = await Backup.restore();
    if (!mounted) return;
    setState(() {
      busy = false;
      status = err ?? 'Restored from your last backup.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
            'Chuma saves your data to a private GitHub repo about 30 seconds after each change.',
            style: TextStyle(color: C.muted)),
        const SizedBox(height: 12),
        TextField(
          controller: repoC,
          autocorrect: false,
          decoration: const InputDecoration(
              labelText: 'Repo (owner/name)',
              hintText: 'COOLEO1/chuma-backup',
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: tokenC,
          obscureText: hide,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'GitHub token',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => hide = !hide),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.navy),
              onPressed: busy ? null : _backupNow,
              child: Text(busy ? 'Working...' : 'Save and back up now'),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
              onPressed: busy ? null : _restore, child: const Text('Restore')),
        ]),
        const SizedBox(height: 10),
        Text(status,
            style: TextStyle(
                color: status.startsWith('Last') || status.startsWith('Restored')
                    ? C.teal
                    : C.muted,
                fontSize: 13)),
      ]),
    );
  }
}
