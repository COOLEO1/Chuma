import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'groq.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  final keyC = TextEditingController();
  final modelC = TextEditingController(text: defaultGroqModel);
  bool hide = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      keyC.text = p.getString('groq_key') ?? '';
      modelC.text = p.getString('groq_model') ?? defaultGroqModel;
    });
  }

  void _toast(String s) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _saveAi() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('groq_key', keyC.text.trim());
    final m = modelC.text.trim();
    await p.setString('groq_model', m.isEmpty ? defaultGroqModel : m);
    if (mounted) _toast('Saved');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: store.exportJson()));
    if (mounted) {
      _toast('Backup copied. Paste it into Notes or send it to yourself.');
    }
  }

  Future<void> _restore() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('This replaces everything currently in Chuma.'),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            maxLines: 6,
            decoration: const InputDecoration(
                hintText: 'Paste your backup here',
                border: OutlineInputBorder()),
          ),
        ]),
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
    try {
      await store.importJson(c.text.trim());
      if (mounted) _toast('Backup restored');
    } catch (_) {
      if (mounted) _toast('That is not a valid Chuma backup.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        const Text('Settings',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: C.ink)),
        sectionTitle('Monthly budget'),
        Panel(
          child: Row(children: [
            Expanded(
              child: Text(
                  store.budget > 0 ? mk(store.budget) : 'Not set',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: C.ink)),
            ),
            FilledButton.tonal(
                onPressed: () => editBudget(context),
                child: const Text('Change')),
          ]),
        ),
        sectionTitle('AI (Groq)'),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: keyC,
              obscureText: hide,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Groq API key',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => hide = !hide),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: modelC,
              autocorrect: false,
              decoration: const InputDecoration(
                  labelText: 'Model', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            const Text(
                'Stays on this phone. If the summary says the model is not found, paste a current model name here.',
                style: TextStyle(color: C.muted, fontSize: 13)),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.navy),
              onPressed: _saveAi,
              child: const Text('Save AI settings'),
            ),
          ]),
        ),
        sectionTitle('Backup'),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
                'Your data lives only on this phone. Copy a backup now and then, so clearing app data does not wipe it.',
                style: TextStyle(color: C.muted)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: FilledButton.tonal(
                      onPressed: _copy, child: const Text('Copy backup'))),
              const SizedBox(width: 10),
              Expanded(
                  child: OutlinedButton(
                      onPressed: _restore, child: const Text('Restore'))),
            ]),
          ]),
        ),
        const SizedBox(height: 24),
        const Center(
            child: Text('Chuma 0.2. Know it. Keep it. Grow it.',
                style: TextStyle(color: C.muted, fontSize: 13))),
      ],
    );
  }
}
