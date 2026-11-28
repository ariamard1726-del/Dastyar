import 'package:shared_preferences/shared_preferences.dart';

export 'storage_migration.dart';

/// رابط انتزاعی ذخیره‌سازی کلید-مقدار محلی (مستقل از `SharedPreferences`).
///
/// تمام انبارهای دادهٔ برنامه ([HistoryStore]، [FeedbackStore]،
/// [DraftCheckpointStore]) فقط با این رابط کار می‌کنند تا جایگزینی یا
/// مهاجرت به انبار رمزنگاری‌شدهٔ بومی (مانند SQLite + SQLCipher پس از
/// دسترسی به بستهٔ آن) بدون تغییر منطق دامنه و رابط کاربری ممکن باشد.
abstract interface class KeyValueStore {
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
  Future<bool> remove(String key);
  Future<Set<String>> getKeys();

  /// اجرای اتمیک یا صف‌شدهٔ یک دسته خواندن/نوشتن روی این انبار.
  Future<T> runTransaction<T>(Future<T> Function(KeyValueStore tx) action);
}

/// پیاده‌سازی پیش‌فرض روی `SharedPreferences` همراه با صف تراکنش خطی.
class SharedPrefsKeyValueStore implements KeyValueStore {
  SharedPrefsKeyValueStore([SharedPreferences? prefs]) : _prefs = prefs;

  SharedPreferences? _prefs;
  Future<void> _txQueue = Future<void>.value();

  Future<SharedPreferences> _instance() async {
    final ready = _prefs;
    if (ready != null) return ready;
    final loaded = await SharedPreferences.getInstance();
    _prefs = loaded;
    return loaded;
  }

  @override
  Future<String?> getString(String key) async => (await _instance()).getString(key);

  @override
  Future<bool> setString(String key, String value) async =>
      (await _instance()).setString(key, value);

  @override
  Future<bool> remove(String key) async => (await _instance()).remove(key);

  @override
  Future<Set<String>> getKeys() async => (await _instance()).getKeys();

  @override
  Future<T> runTransaction<T>(Future<T> Function(KeyValueStore tx) action) {
    final next = _txQueue.then((_) => action(this));
    _txQueue = next.then((_) {}, onError: (Object _) {});
    return next;
  }
}

/// انبار حافظه‌ایِ خالص در Dart (بدون هیچ وابستگی به پلاگین یا فلاتر) برای آزمون.
class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? seed])
      : _data = Map<String, String>.from(seed ?? const <String, String>{});

  final Map<String, String> _data;
  Future<void> _txQueue = Future<void>.value();

  Map<String, String> get rawMap => Map<String, String>.unmodifiable(_data);

  @override
  Future<String?> getString(String key) async => _data[key];

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<Set<String>> getKeys() async => Set<String>.from(_data.keys);

  @override
  Future<T> runTransaction<T>(Future<T> Function(KeyValueStore tx) action) {
    final next = _txQueue.then((_) => action(this));
    _txQueue = next.then((_) {}, onError: (Object _) {});
    return next;
  }
}

/// رجیستری پیش‌فرض انبار کلید-مقدار برنامه.
class LocalStoreRegistry {
  LocalStoreRegistry._();

  static KeyValueStore Function() _factory = () => SharedPrefsKeyValueStore();

  static KeyValueStore open() => _factory();

  static void useForTesting(KeyValueStore store) {
    _factory = () => store;
  }

  static void reset() {
    _factory = () => SharedPrefsKeyValueStore();
  }
}
