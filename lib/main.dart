import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'assistant.dart';
import 'chat_page.dart';
import 'engine.dart';
import 'templates.dart';

void main() => runApp(const DastyarApp());

class DastyarApp extends StatelessWidget {
  const DastyarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دستیار',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1B6B5A),
      ),
      home: const Loader(),
    );
  }
}

class Loader extends StatefulWidget {
  const Loader({super.key});

  @override
  State<Loader> createState() => _LoaderState();
}

class _LoaderState extends State<Loader> {
  final KnowledgeEngine _engine = KnowledgeEngine();
  final TemplateRepository _repo = TemplateRepository();
  // برای اتصال مدل زبانی بعداً: Assistant(_engine, llm: MyLlmBackend())
  late final Assistant _assistant = Assistant(_engine);
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _engine.load();
    } catch (_) {
      _error = 'بارگذاری دانش با خطا روبه‌رو شد.';
    }
    try {
      await _repo.load();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return ChatPage(
      engine: _engine,
      assistant: _assistant,
      repo: _repo,
      loadError: _error,
    );
  }
}
