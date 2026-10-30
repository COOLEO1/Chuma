import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'store.dart';

class Backup {
  static const _file = 'chuma-backup.json';
  static Timer? _timer;
  static String? _last;
  static bool _busy = false;

  // Called after every change. Waits 30 seconds, then backs up.
  static void schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 30), () => run(silent: true));
  }

  static String _msg(int code) {
    switch (code) {
      case 401:
        return 'GitHub rejected the token. Make a new one and paste it again.';
      case 403:
        return 'The token cannot write to this repo. Give it Contents: Read and write.';
      case 404:
        return 'Repo or token not found. Check the repo name (owner/name) and that the token covers this repo.';
      case 409:
      case 422:
        return 'Backup clashed with an older upload. Tap Back up now again.';
      default:
        return 'GitHub error $code.';
    }
  }

  static Future<HttpClientResponse> _call(
      HttpClient c, String method, String repo, String token,
      {String? body}) async {
    final req = await c.openUrl(method,
        Uri.parse('https://api.github.com/repos/$repo/contents/$_file'));
    req.headers.set('Authorization', 'Bearer $token');
    req.headers.set('Accept', 'application/vnd.github+json');
    req.headers.set('User-Agent', 'chuma-app');
    req.headers.set('X-GitHub-Api-Version', '2022-11-28');
    if (body != null) {
      final bytes = utf8.encode(body);
      req.headers.contentType = ContentType.json;
      req.headers.contentLength = bytes.length;
      req.add(bytes);
    }
    return await req.close().timeout(const Duration(seconds: 30));
  }

  /// Returns null on success, or a short error message.
  static Future<String?> run({bool silent = false, bool force = false}) async {
    if (_busy) return null;
    final p = await SharedPreferences.getInstance();
    final token = (p.getString('gh_token') ?? '').trim();
    final repo = (p.getString('gh_repo') ?? '').trim();
    if (token.isEmpty || repo.isEmpty) {
      return silent ? null : 'Add your repo and token first.';
    }
    // Never overwrite a good backup with an empty app (for example on a new phone).
    if (store.txns.isEmpty && store.goals.isEmpty) {
      return silent ? null : 'Nothing to back up yet.';
    }
    final data = store.exportJson();
    if (!force && data == _last) return null;
    _busy = true;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      String? sha;
      final g = await _call(client, 'GET', repo, token);
      final gb = await g.transform(utf8.decoder).join();
      if (g.statusCode == 200) {
        sha = jsonDecode(gb)['sha'] as String?;
      } else if (g.statusCode != 404) {
        throw _msg(g.statusCode);
      }
      final put = await _call(client, 'PUT', repo, token,
          body: jsonEncode({
            'message': 'Chuma backup ${DateTime.now().toIso8601String()}',
            'content': base64Encode(utf8.encode(data)),
            if (sha != null) 'sha': sha,
          }));
      await put.transform(utf8.decoder).join();
      if (put.statusCode != 200 && put.statusCode != 201) {
        throw _msg(put.statusCode);
      }
      _last = data;
      await p.setInt('backup_ts', DateTime.now().millisecondsSinceEpoch);
      await p.remove('backup_err');
      return null;
    } on SocketException {
      return silent
          ? null
          : 'No internet. Chuma will try again after your next change.';
    } catch (e) {
      await p.setString('backup_err', '$e');
      return '$e';
    } finally {
      client.close();
      _busy = false;
    }
  }

  /// Replaces everything in the app with the last backup.
  static Future<String?> restore() async {
    final p = await SharedPreferences.getInstance();
    final token = (p.getString('gh_token') ?? '').trim();
    final repo = (p.getString('gh_repo') ?? '').trim();
    if (token.isEmpty || repo.isEmpty) return 'Add your repo and token first.';
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final g = await _call(client, 'GET', repo, token);
      final gb = await g.transform(utf8.decoder).join();
      if (g.statusCode == 404) {
        return 'No backup found in that repo yet, or the repo or token is wrong.';
      }
      if (g.statusCode != 200) throw _msg(g.statusCode);
      final b64 = (jsonDecode(gb)['content'] as String)
          .replaceAll(RegExp(r'\s'), '');
      await store.importJson(utf8.decode(base64Decode(b64)));
      return null;
    } on SocketException {
      return 'No internet.';
    } catch (e) {
      return '$e';
    } finally {
      client.close();
    }
  }
}
