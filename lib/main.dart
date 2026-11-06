import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/ui/chat_page.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/core/llama_backend.dart';
import 'package:dastyar/core/llm.dart';
import 'package:dastyar/core/model_store.dart';
import 'package:dastyar/domain/lawyer/llm_writer.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  if (settings.secureScreen) {
    await PrivacyService.setSecureScreen(true);
  }
  runApp(DastyarApp(settings: settings));
}

ThemeData _buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final bg = dark ? const Color(0xFF262624) : const Color(0xFFFAF9F5);
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFC96442),
    brightness: b,
  ).copyWith(surface: bg);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF30302E) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
  );
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
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: settings.themeMode,
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
  /// مدل زبانی اختیاری: فقط وقتی کاربر خودش نصب و روشنش کرده باشد.
  final ModelStore _models = ModelStore();
  late final LlamaLlm _llama = LlamaLlm(
    store: _models,
    enabled: () => widget.settings.useLocalLlm,
  );
  late final LlmBackend _llm = AdaptiveLlm(
    candidates: [_llama],
    isEnabled: () => widget.settings.useLocalLlm && _models.isInstalled,
  );
  late final Assistant _assistant = Assistant(_engine, llm: _llm);
  late final LlmWriter _writer = LlmWriter(_llm);
  DraftSession? _initialDraft;
  CounselingSession? _initialCounsel;

  /// شبکهٔ عصبی آفلاین تشخیص نیت؛ پیش از نخستین فریم بارگذاری می‌شود تا
  /// گفتگو از همان پیام اول هوشمند باشد (در تست‌های ویجتی تزریق‌نشده و
  /// مسیر نمادین فعال می‌ماند).
  IntentNet? _intentNet;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      _engine.load().catchError((_) {
        _error = 'بارگذاری دانش با خطا روبه‌رو شد.';
      }),
      _repo.load().catchError((_) {}),
      _history.load().catchError((_) {}),
      IntentNet.load().then((n) => _intentNet = n),
      _models.load().catchError((_) {}),
    ]);
    // اگر مدل از قبل روشن است، در پس‌زمینه بارگذاری شود تا پاسخ اول معطل نماند.
    if (widget.settings.useLocalLlm && _models.isInstalled) {
      unawaited(_llama.load().catchError((_) {}));
    }
    if (widget.settings.saveDraftProgress && _repo.templates.isNotEmpty) {
      _initialDraft = await DraftCheckpointStore.load(_repo.templates);
      _initialCounsel = await CounselCheckpointStore.load();
    }
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
      initialDraft: _initialDraft,
      intentNet: _intentNet,
      initialCounsel: _initialCounsel,
      models: _models,
      llama: _llama,
      writer: _writer,
    );
  }
}
