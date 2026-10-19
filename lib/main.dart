import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'assistant.dart';
import 'chat_page.dart';
import 'engine.dart';
import 'history.dart';
import 'settings.dart';
import 'templates.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(DastyarApp(settings: settings));
}

class DastyarApp extends StatelessWidget {
  final AppSettings settings;
  const DastyarApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
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
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(settings.fontScale),
              ),
              child: child ?? const SizedBox(),
            );
          },
          home: Loader(settings: settings),
        );
      },
    );
  }
}

class Loader extends StatefulWidget {
  final AppSettings settings;
  const Loader({super.key, required this.settings});

  @override
  State<Loader> createState() => _LoaderState();
}

class _LoaderState extends State<Loader> {
  final KnowledgeEngine _engine = KnowledgeEngine();
  final TemplateRepository _repo = TemplateRepository();
  final HistoryStore _history = HistoryStore();
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
    try {
      await _history.load();
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
      history: _history,
      settings: widget.settings,
      loadError: _error,
    );
  }
}
