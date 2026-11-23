import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:dastyar/ui/chat_page.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/core/legacy_cleanup.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/domain/understanding/reader_service.dart';
import 'package:dastyar/domain/understanding/topic_guess.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // پروانهٔ مدل برداری Noql در صفحهٔ پروانه‌های برنامه.
  LicenseRegistry.addLicense(() async* {
    try {
      yield LicenseEntryWithLineBreaks(
        const ['Noql (shekar-ai)'],
        await rootBundle.loadString('assets/brain/noql_licenses.txt'),
      );
    } catch (_) {}
  });
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
            // اندازهٔ فونت گوشی پایه است و تنظیم برنامه روی آن ضرب می‌شود؛
            // پیش‌فرض ۱ یعنی همان اندازهٔ گوشی.
            final system = mq.textScaler.scale(1.0);
            final factor = (system * settings.fontScale).clamp(0.8, 2.6).toDouble();
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(factor),
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
  DraftSession? _initialDraft;

  /// طبقه‌بند سبک نیت (یک فایل JSON کوچک، نه مدل زبانی). وکیل فقط وقتی
  /// از آن کمک می‌گیرد که قاعده‌های خودش موضوع پیام را نشناخته باشند.
  IntentNet? _intentNet;

  /// خوانندهٔ موضوع (مدل برداری Noql). در پس‌زمینه بار می‌شود تا بالاآمدن
  /// برنامه را کند نکند؛ تا آماده نشده، وکیل فقط با قاعده‌ها کار می‌کند.
  ReaderService? _reader;
  bool _readerTried = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _reader?.dispose();
    super.dispose();
  }

  Future<TopicGuess?> _guess(String text) async => _reader?.read(text);

  String _fa(int n) => PersianText.toFaDigits(n.toString());

  List<String> _readerNotes() {
    final r = _reader;
    if (r == null) {
      return [
        _readerTried
            ? 'مدل برداری بار نشد؛ برنامه فقط با قاعده‌های خودش پیام را می‌فهمد.'
            : 'مدل برداری هنوز در حال آماده‌شدن است.',
      ];
    }
    final g = r.last;
    return [
      'مدل برداری Noql (shekar-ai) درون خودِ برنامه اجرا می‌شود و چیزی به اینترنت نمی‌فرستد. فقط وقتی قاعده‌ها موضوع پیام را نشناسند، موضوع را حدس می‌زند؛ متن جواب همچنان از قاعده‌ها و متن قانون است.',
      'آماده‌شدن مدل روی این دستگاه: ${_fa(r.loadMillis)} میلی‌ثانیه',
      if (g != null)
        'آخرین خواندن: ${_fa(g.millis)} میلی‌ثانیه برای ${_fa(g.tokens)} توکن',
    ];
  }

  Future<void> _init() async {
    unawaited(ReaderService.start().then((r) {
      _readerTried = true;
      if (mounted) {
        _reader = r;
      } else {
        r?.dispose();
      }
    }));
    // هر خطای بارگذاری به کاربر گفته می‌شود؛ بارگذاری ناقصِ بی‌صدا یعنی
    // دکمه‌ای که کار نمی‌کند و کاربر نمی‌داند چرا.
    final problems = <String>[];
    await Future.wait([
      _engine.load().catchError((Object e) {
        problems.add('بارگذاری دانش قوانین با خطا روبه‌رو شد.');
      }),
      _repo.load().catchError((Object e) {
        problems.add('قالب‌های سند بار نشدند؛ «تنظیم سند» کار نمی‌کند.');
      }),
      _history.load().catchError((Object e) {
        problems.add('تاریخچهٔ گفتگوها بار نشد؛ گفتگوهای قبلی دیده نمی‌شوند.');
      }),
      IntentNet.load().then((n) {
        _intentNet = n;
      }).catchError((Object e) {
        // طبقه‌بند اختیاری است؛ نبودش فقط یعنی «نظر دوم» نداریم.
        _intentNet = null;
      }),
      // پاک‌کردن ردّ قابلیت‌هایی که دیگر در برنامه نیستند (فایل مدل زبانی
      // و مشاورهٔ نیمه‌کاره) تا جای گوشی و دادهٔ کاربر بی‌دلیل نماند.
      LegacyCleanup.run(),
    ]);
    // [HistoryStore.load] خطا را می‌بلعد و در `lastError` می‌گذارد.
    final historyError = _history.lastError;
    if (historyError != null) problems.add('تاریخچه: $historyError');
    if (_repo.problems.isNotEmpty) {
      problems.add('${_repo.problems.length} قالب سند خوانده نشد.');
    }
    _error = problems.isEmpty ? null : problems.join('\n');
    if (widget.settings.saveDraftProgress && _repo.templates.isNotEmpty) {
      _initialDraft = await DraftCheckpointStore.load(_repo.templates);
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
      repo: _repo,
      history: _history,
      settings: widget.settings,
      loadError: _error,
      initialDraft: _initialDraft,
      intentNet: _intentNet,
      guesser: _guess,
      readerNotes: _readerNotes,
    );
  }
}
