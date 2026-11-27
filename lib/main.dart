import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:dastyar/ui/chat_page.dart';
import 'package:dastyar/ui/privacy_notice_page.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/core/legacy_cleanup.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/advocate/advocate_texts_loader.dart';
import 'package:dastyar/domain/advocate/topics/rent_texts_loader.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';
import 'package:dastyar/domain/lawyer/legal_guides_loader.dart';
import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/core/privacy_migration.dart';
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
  // اگر گوشی FLAG_SECURE را اعمال نکند، تیک ذخیرهشده نباید دروغ بگوید.
  await settings.applySecureScreenAtStartup();
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
          home: settings.consentGiven
              ? Loader(settings: settings)
              : PrivacyNoticePage(settings: settings),
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

  /// خوانندهٔ موضوع (مدل برداری Noql). در پس‌زمینه بار می‌شود تا بالاآمدن
  /// برنامه را کند نکند؛ تا آماده نشده، وکیل فقط با قاعده‌ها کار می‌کند.
  /// خوانندهٔ موضوع (مدل برداری Noql). ۱۲ مگابایت وزن دارد؛ بارش آن تا
  /// نخستین پیامی که قاعدهها نتوانستند موضوعش را بفهمند به تأخیر میافتد تا
  /// استارتآپ سریعتر و مصرف حافظهٔ همزمان کمتر شود.
  ReaderService? _reader;
  Future<ReaderService?>? _readerStarting;
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
    _engine.dispose();
    super.dispose();
  }

  Future<TopicGuess?> _guess(String text) async {
    final reader = await _ensureReader();
    return reader?.read(text);
  }

  /// تنها یک بار بارگذاری آغاز میشود، حتی اگر چند پیام پشت سر هم حدس بخواهند.
  Future<ReaderService?> _ensureReader() async {
    final ready = _reader;
    if (ready != null) return ready;
    final starting = _readerStarting;
    if (starting != null) return starting;
    _readerTried = true;
    final future = ReaderService.start();
    _readerStarting = future;
    try {
      final r = await future;
      if (!mounted) {
        r?.dispose();
        return null;
      }
      _reader = r;
      return r;
    } finally {
      _readerStarting = null;
    }
  }

  String _fa(int n) => PersianText.toFaDigits(n.toString());

  List<String> _readerNotes() {
    final r = _reader;
    if (r == null) {
      return [
        if (!_readerTried)
          'مدل برداری هنوز بار نشده است؛ فقط وقتی قاعدهها موضوع پیامی را '
          'نشناختند بار میشود تا استارتآپ و حافظه صرفهجویی شود.'
        else if (_readerStarting != null)
          'مدل برداری در حال آمادهشدن است.'
        else
          'مدل برداری بار نشد؛ برنامه فقط با قاعدههای خودش پیام را میفهمد.',
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
    // هر خطای بارگذاری به کاربر گفته می‌شود؛ بارگذاری ناقصِ بی‌صدا یعنی
    // دکمه‌ای که کار نمی‌کند و کاربر نمی‌داند چرا.
    final problems = <String>[];
    // پیش از هر نوشتن، باسنجی Keystore. اگر کار نکند، ذخیرهٔ محلی قفل میشود
    // تا رکوردی نوشته نشود که پس از بستهشدن برنامه خوانده نخواهد شد.
    final nativeCrypto = await PrivacyService.beginSession();
    if (!nativeCrypto) {
      widget.settings.lockLocalPersistence(PrivacyService.lastError ??
          'رمزنگاری بومی دردسترس نیست؛ ذخیرهٔ محلی خاموش شد.');
      problems.add(PrivacyService.lastError ?? 'رمزنگاری بومی دردسترس نیست.');
    }
    // قبل از خواندن تاریخچه: کلید/دادهٔ نسخهٔ پیشین یکبار مهاجرت میشود.
    final migration = await PrivacyMigration.run();
    if (migration.migrated > 0) {
      problems.add('${migration.migrated} رکورد قدیمی با کلید سختافزاری دوباره مهروموم شد.');
    }
    if (migration.dropped > 0) {
      problems.add('${migration.dropped} رکورد قدیمی که کلیدش قابلاعتماد نبود حذف شد.');
    }
    await Future.wait([
      _engine.load(startWorker: true).catchError((Object e) {
        problems.add('بارگذاری دانش قوانین با خطا روبه‌رو شد.');
      }),
      // راهنماهای آماده از فایلِ داده خوانده می‌شوند؛ اگر نباشند، پاسخ‌های
      // «راهنمای وکیل» بی‌صدا خالی می‌مانند.
      () async {
        try {
          await loadLegalGuides();
        } catch (e) {
          problems.add('راهنماهای آماده بار نشدند؛ بعضی پاسخ‌ها کامل نیستند.');
        }
      }(),
      // متنِ ثابتِ موضوع اجاره از داده خوانده میشود؛ نبودنش یعنی پاسخهای
      // اجاره با خطای صریح متوقف میشود، نه اینکه متن قدیمی بیصدا برگردد.
      () async {
        try {
          await loadRentTexts();
        } catch (e) {
          problems.add('متنِ موضوع اجاره بار نشد؛ پاسخهای اجاره کامل نیستند.');
        }
      }(),
      // متنِ ثابتِ موضوعهای دیگر نیز از داده خوانده میشود؛ نبودنش پاسخها را
      // با خطای صریح متوقف میکند، نه اینکه متن قدیمی بیصدا برگردد.
      () async {
        try {
          await loadTopicTexts();
        } catch (e) {
          problems.add('متنِ موضوعهای وکیل بار نشد؛ بعضی پاسخها کامل نیستند.');
        }
      }(),
      // متنِ عمومیِ گفت‌وگو، واژه‌نامه، ایمنی و استدلال وکیل از داده خوانده
      // میشود؛ نبودنش به جای پاسخ ناقصِ بیصدا، خطای صریح میدهد.
      () async {
        try {
          await loadAdvocateTexts();
        } catch (e) {
          problems.add('متنهای عمومی وکیل بار نشدند؛ پاسخگویی کامل نیست.');
        }
      }(),
      _repo.load().catchError((Object e) {
        problems.add('قالب‌های سند بار نشدند؛ «تنظیم سند» کار نمی‌کند.');
      }),
      _history.load().catchError((Object e) {
        problems.add('تاریخچهٔ گفتگوها بار نشد؛ گفتگوهای قبلی دیده نمی‌شوند.');
      }),
      // پاک‌کردن ردّ قابلیت‌هایی که دیگر در برنامه نیستند (فایل مدل زبانی
      // و مشاورهٔ نیمه‌کاره) تا جای گوشی و دادهٔ کاربر بی‌دلیل نماند.
      LegacyCleanup.run(),
      PrivacyService.discardLegacyKey(),
    ]);
    // [HistoryStore.load] خطا را می‌بلعد و در `lastError` می‌گذارد.
    final historyError = _history.lastError;
    if (historyError != null) problems.add('تاریخچه: $historyError');
    if (_repo.problems.isNotEmpty) {
      problems.add('${_repo.problems.length} قالب سند خوانده نشد.');
    }
    // سکوت در مورد افتادن به رمزنگاری جایگزین بدترین حالت است: کاربر فکر
    // میکند کلید روی سختافزار است، در حالی که در حافظهٔ محلی برنامه است.
    if (nativeCrypto &&
        PrivacyService.fallbackUsed &&
        PrivacyService.lastError != null) {
      problems.add(PrivacyService.lastError!);
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
      guesser: _guess,
      readerNotes: _readerNotes,
    );
  }
}
