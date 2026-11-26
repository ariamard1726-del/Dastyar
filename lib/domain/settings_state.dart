/// وضعیت تنظیمات، کاملاً مستقل از فلاتر و SharedPreferences.
///
/// این کلاس فقط «چه تنظیماتی مجازاند و چگونه تبدیل میشوند» را میداند؛ نه
/// `ChangeNotifier` دارد، نه `ThemeMode` و نه دیسک. لایهٔ رابط [`AppSettings`]
/// همان وضعیت را نگه میدارد و ChangeNotifier/SharedPreferences را دور آن میپیچد.
enum AppThemeMode { system, light, dark }

class SettingsSnapshot {
  const SettingsSnapshot({
    this.fontScale = 1.0,
    this.saveHistory = true,
    this.saveDraftProgress = false,
    this.secureScreen = false,
    this.themeMode = AppThemeMode.system,
  });

  static const double defaultFontScale = 1.0;
  static const List<double> scales = [0.9, 1.0, 1.2, 1.4];
  static const List<String> scaleNames = ['کوچک', 'متوسط', 'بزرگ', 'خیلی بزرگ'];
  static const List<AppThemeMode> themeModes = AppThemeMode.values;
  static const List<String> themeNames = ['هماهنگ با گوشی', 'روشن', 'تیره'];

  final double fontScale;
  final bool saveHistory;
  final bool saveDraftProgress;
  final bool secureScreen;
  final AppThemeMode themeMode;

  static const SettingsSnapshot defaults = SettingsSnapshot();

  SettingsSnapshot copyWith({
    double? fontScale,
    bool? saveHistory,
    bool? saveDraftProgress,
    bool? secureScreen,
    AppThemeMode? themeMode,
  }) =>
      SettingsSnapshot(
        fontScale: fontScale ?? this.fontScale,
        saveHistory: saveHistory ?? this.saveHistory,
        saveDraftProgress: saveDraftProgress ?? this.saveDraftProgress,
        secureScreen: secureScreen ?? this.secureScreen,
        themeMode: themeMode ?? this.themeMode,
      );

  /// مقدار خواندهشده از دیسک اگر معتبر نباشد به پیشفرض برمیگردد؛اینجا
  /// تصمیمگیری صرفاً دامنهای است و هیچ خطایی بلعیده نمیشود.
  factory SettingsSnapshot.fromValues({
    double? fontScale,
    bool? saveHistory,
    bool? saveDraftProgress,
    bool? secureScreen,
    String? themeMode,
  }) =>
      SettingsSnapshot(
        fontScale: fontScale != null && scales.contains(fontScale)
            ? fontScale
            : defaultFontScale,
        saveHistory: saveHistory ?? true,
        saveDraftProgress: saveDraftProgress ?? false,
        secureScreen: secureScreen ?? false,
        themeMode: themeFromRaw(themeMode),
      );

  static AppThemeMode themeFromRaw(String? raw) => switch (raw) {
        'light' => AppThemeMode.light,
        'dark' => AppThemeMode.dark,
        _ => AppThemeMode.system,
      };

  static String themeToRaw(AppThemeMode mode) => switch (mode) {
        AppThemeMode.light => 'light',
        AppThemeMode.dark => 'dark',
        AppThemeMode.system => 'system',
      };
}
