import 'dart:convert';
import 'dart:io';

const defaultGroqModel = 'openai/gpt-oss-120b';

class Groq {
  static Future<String> chat(
      String key, String model, String system, String user) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.postUrl(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'));
      req.headers.set('Authorization', 'Bearer $key');
      req.headers.contentType = ContentType.json;
      final bytes = utf8.encode(jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        'temperature': 0.4,
        'max_completion_tokens': 1500,
        if (model.contains('gpt-oss')) 'reasoning_effort': 'low',
      }));
      req.headers.contentLength = bytes.length;
      req.add(bytes);
      final res = await req.close().timeout(const Duration(seconds: 40));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        var msg = 'Groq error ${res.statusCode}. Check your key in Settings.';
        try {
          msg = jsonDecode(body)['error']['message'] as String;
        } catch (_) {}
        throw msg;
      }
      final j = jsonDecode(body);
      final out = (j['choices'][0]['message']['content'] as String?) ?? '';
      if (out.trim().isEmpty) {
        throw 'The model returned an empty answer. Try again, or change the model in Settings.';
      }
      return out.trim();
    } finally {
      client.close();
    }
  }
}
