import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() => runApp(const DastyarApp());

class DastyarApp extends StatelessWidget {
  const DastyarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دستیار',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1B6B5A),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox(),
      ),
      home: const ChatPage(),
    );
  }
}

class _Chunk {
  final String title;
  final String body;
  final List<String> tokens;
  _Chunk(this.title, this.body, this.tokens);
}

class _Hit {
  final _Chunk chunk;
  final double score;
  _Hit(this.chunk, this.score);
}

class KnowledgeEngine {
  final List<_Chunk> _chunks = [];
  final Map<String, double> _idf = {};

  static const Set<String> _stop = {
    'و', 'در', 'به', 'از', 'که', 'را', 'با', 'این', 'آن', 'برای', 'یک',
    'است', 'هست', 'چه', 'چی', 'چیست', 'کی', 'کجا', 'چرا', 'چطور',
    'چگونه', 'آیا', 'من', 'تو', 'شما', 'می', 'هم', 'یا', 'تا', 'بر',
    'هر', 'های', 'ها', 'بود', 'شد', 'باشد', 'کند', 'کنم', 'کن', 'بگو',
    'درباره', 'مورد', 'لطفا', 'ممنون',
  };

  static const List<String> _suffixes = [
    'ترین', 'هایی', 'های', 'ها', 'تر', 'ان', 'ات', 'ی',
  ];

  static String normalize(String s) {
    const map = {
      'ي': 'ی', 'ى': 'ی', 'ك': 'ک', 'ۀ': 'ه', 'ة': 'ه',
      'أ': 'ا', 'إ': 'ا', 'ٱ': 'ا',
    };
    final sb = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0x06F0 && r <= 0x06F9) {
        sb.write(r - 0x06F0);
        continue;
      }
      if (r >= 0x0660 && r <= 0x0669) {
        sb.write(r - 0x0660);
        continue;
      }
      if (r == 0x200C || r == 0x200D || r == 0x200E || r == 0x200F) {
        sb.write(' ');
        continue;
      }
      if (r >= 0x064B && r <= 0x065F) continue;
      if (r == 0x0640) continue;
      final ch = String.fromCharCode(r);
      sb.write(map[ch] ?? ch);
    }
    return sb.toString().toLowerCase();
  }

  static String _stem(String w) {
    for (final suf in _suffixes) {
      if (w.length - suf.length >= 3 && w.endsWith(suf)) {
        return w.substring(0, w.length - suf.length);
      }
    }
    return w;
  }

  static List<String> tokenize(String s) {
    final cleaned = normalize(s).replaceAll(
      RegExp(r'[^\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CCa-z0-9]+'),
      ' ',
    );
    final out = <String>[];
    for (final w in cleaned.split(' ')) {
      if (w.isEmpty || _stop.contains(w)) continue;
      out.add(_stem(w));
    }
    return out;
  }

  void load(String text) {
    _chunks.clear();
    _idf.clear();
    final parts = text.replaceAll('\r', '').split(RegExp(r'\n\s*\n'));
    for (final p in parts) {
      final lines = p.trim().split('\n');
      if (lines.isEmpty || lines.first.trim().isEmpty) continue;
      final title = lines.first.trim();
      final body = lines.length > 1 ? lines.sublist(1).join('\n').trim() : title;
      final tokens = <String>[
        ...tokenize(title),
        ...tokenize(title),
        ...tokenize(body),
      ];
      _chunks.add(_Chunk(title, body, tokens));
    }
    final df = <String, int>{};
    for (final c in _chunks) {
      for (final t in c.tokens.toSet()) {
        df[t] = (df[t] ?? 0) + 1;
      }
    }
    final n = _chunks.length;
    df.forEach((t, d) {
      _idf[t] = math.log((n + 1) / (d + 1)) + 1.0;
    });
  }

  int get size => _chunks.length;

  String answer(String question) {
    final q = normalize(question);
    if (q.contains('سلام') && tokenize(question).length <= 1) {
      return 'سلام! چه کمکی از من برمی‌آید؟';
    }
    if (_chunks.isEmpty) {
      return 'هنوز دانشی در برنامه نیست. فایل assets/knowledge.txt را پر کنید.';
    }
    final qTokens = tokenize(question).toSet().toList();
    if (qTokens.isEmpty) {
      return 'لطفاً پرسش خود را کامل‌تر بنویسید.';
    }
    double total = 0;
    for (final t in qTokens) {
      total += _idf[t] ?? 1.0;
    }
    final hits = <_Hit>[];
    for (final c in _chunks) {
      double s = 0;
      for (final t in qTokens) {
        final w = _idf[t] ?? 1.0;
        final tf = c.tokens.where((x) => x == t).length;
        if (tf > 0) {
          s += w * (1 + math.log(tf));
        } else if (t.length >= 3) {
          final partial = c.tokens.any((x) =>
              x.length >= 3 && (x.startsWith(t) || t.startsWith(x)));
          if (partial) s += w * 0.5;
        }
      }
      hits.add(_Hit(c, s / total));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    final best = hits.first;
    if (best.score < 0.3) {
      return 'پاسخ این پرسش را در دانش خودم پیدا نکردم. می‌توانید آن را به فایل knowledge.txt اضافه کنید.';
    }
    var res = '${best.chunk.title}\n${best.chunk.body}';
    if (hits.length > 1 && hits[1].score >= best.score * 0.8 && hits[1].score >= 0.3) {
      res += '\n\nموضوع مرتبط: ${hits[1].chunk.title}';
    }
    return res;
  }
}

class _Msg {
  final String text;
  final bool fromUser;
  _Msg(this.text, this.fromUser);
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final KnowledgeEngine _engine = KnowledgeEngine();
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    String text = '';
    try {
      text = await rootBundle.loadString('assets/knowledge.txt');
    } catch (_) {}
    _engine.load(text);
    if (!mounted) return;
    setState(() {
      _ready = true;
      _msgs.add(_Msg(
        'سلام! من دستیار هستم و بدون اینترنت کار می‌کنم. هر چه می‌خواهید بپرسید.',
        false,
      ));
    });
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || !_ready) return;
    final reply = _engine.answer(text);
    setState(() {
      _msgs.add(_Msg(text, true));
      _msgs.add(_Msg(reply, false));
    });
    _ctrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('دستیار')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: !_ready
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _msgs.length,
                      itemBuilder: (context, i) {
                        final m = _msgs[i];
                        return Align(
                          alignment: m.fromUser
                              ? AlignmentDirectional.centerStart
                              : AlignmentDirectional.centerEnd,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.82,
                            ),
                            decoration: BoxDecoration(
                              color: m.fromUser
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: SelectableText(
                              m.text,
                              style: const TextStyle(fontSize: 16, height: 1.6),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'پرسش خود را بنویسید...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
