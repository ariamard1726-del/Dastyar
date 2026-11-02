import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/ui/chat_page.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
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
  ).copyWith(
    surface: bg,
    outlineVariant: dark ? const Color(0xFF45443F) : const Color(0xFFE6E3DA),
  );
  final ink = dark ? const Color(0xFFEDEBE4) : const Color(0xFF2E2D2B);
  final base = ThemeData(useMaterial3: true, brightness: b).textTheme;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: base.apply(
      bodyColor: ink,
      displayColor: ink,
      decorationColor: ink,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: base.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? const Color(0xFF30302E) : Colors.white,
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: TextStyle(fontSize: 12, color: ink),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
  late final Assistant _assistant = Assistant(_engine);
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
    ]);
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
    );
  }
}
