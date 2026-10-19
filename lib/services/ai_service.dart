import 'package:flutter/services.dart';

class AIService {
  static const String _knowledgePath = 'assets/knowledge.txt';

  final Map<String, String> _knowledge = <String, String>{};
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    final content = await rootBundle.loadString(_knowledgePath);
    _knowledge.clear();

    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();

      if (line.isEmpty || line.startsWith('#')) continue;

      final separator = line.indexOf('=');
      if (separator <= 0) continue;

      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();

      if (key.isNotEmpty && value.isNotEmpty) {
        _knowledge[key] = value;
      }
    }

    _initialized = true;
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('ۀ', 'ه')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp(r'[،؛؟!,.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _containsAny(String text, List<String> phrases) {
    return phrases.any((phrase) => text.contains(phrase));
  }

  Future<String> getResponse(String input) async {
    if (!_initialized) {
      await initialize();
    }

    final text = _normalize(input);

    if (text.isEmpty) {
      return _reply('unknown');
    }

    if (_containsAny(text, <String>[
      'سلام',
      'درود',
      'صبح بخیر',
      'عصر بخیر',
    ])) {
      return _reply('greeting');
    }

    if (_containsAny(text, <String>[
      'ممنون',
      'متشکرم',
      'سپاس',
      'مرسی',
    ])) {
      return _reply('thanks');
    }

    if (_containsAny(text, <String>[
      'خداحافظ',
      'خدانگهدار',
      'فعلا',
      'بدرود',
    ])) {
      return _reply('goodbye');
    }

    if (_containsAny(text, <String>[
      'کمک',
      'راهنما',
      'چه کارهایی',
      'چیکار میتونی',
    ])) {
      return _reply('help');
    }

    if (_containsAny(text, <String>[
      'اسم تو',
      'نام تو',
      'تو کی هستی',
      'درباره خودت',
      'خودت را معرفی',
    ])) {
      return _reply('identity');
    }

    return _reply('unknown');
  }

  String _reply(String key) {
    return _knowledge[key] ??
        'این نسخه پاسخ‌گوی ساده و آفلاین است و هنوز مدل زبانی مولد ندارد.';
  }
}
