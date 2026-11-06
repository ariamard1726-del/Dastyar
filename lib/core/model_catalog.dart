/// فهرست مدل‌های زبانی اختیاری که کاربر می‌تواند داخل برنامه نصب کند.
///
/// نشانی‌ها به یک نسخهٔ مشخص (commit) سنجاق شده‌اند و اندازه و SHA-256 هر فایل
/// ثبت شده است تا فایل ناقص یا دست‌کاری‌شده هرگز بارگذاری نشود.
library;

class ModelSpec {
  final String id;
  final String title;
  final String description;
  final String url;
  final String fileName;
  final int sizeBytes;
  final String sha256;

  /// قالب گفتگوی مدل در llama.cpp (مثل `gemma` یا `chatml`).
  final String chatTemplate;

  /// حداقل حافظهٔ پیشنهادی گوشی (گیگابایت).
  final int minRamGb;
  final String license;

  const ModelSpec({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
    required this.chatTemplate,
    required this.minRamGb,
    required this.license,
  });
}

class ModelCatalog {
  ModelCatalog._();

  /// شناسهٔ مدلی که کاربر خودش از فایل وارد کرده است.
  static const String importedId = 'imported';

  static const List<ModelSpec> models = [
    ModelSpec(
      id: 'gemma3_1b_q4km',
      title: 'سبک (Gemma 3 1B)',
      description:
          'حدود ۸۰۰ مگابایت؛ برای بیشتر گوشی‌ها با ۴ گیگابایت حافظه یا بیشتر. سریع، با فارسی قابل قبول.',
      url:
          'https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF/resolve/f9c28bcd85737ffc5aef028638d3341d49869c27/gemma-3-1b-it-Q4_K_M.gguf',
      fileName: 'gemma-3-1b-it-Q4_K_M.gguf',
      sizeBytes: 806058240,
      sha256:
          '8ccc5cd1f1b3602548715ae25a66ed73fd5dc68a210412eea643eb20eb75a135',
      chatTemplate: 'gemma3',
      minRamGb: 4,
      license: 'Gemma Terms of Use',
    ),
    ModelSpec(
      id: 'gemma3_4b_q4km',
      title: 'دقیق‌تر (Gemma 3 4B)',
      description:
          'حدود ۲٫۵ گیگابایت؛ برای گوشی‌های قوی با ۸ گیگابایت حافظه. فارسی روان‌تر، اما کندتر.',
      url:
          'https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/resolve/d0976223747697cb51e056d85c532013931fe52e/gemma-3-4b-it-Q4_K_M.gguf',
      fileName: 'gemma-3-4b-it-Q4_K_M.gguf',
      sizeBytes: 2489757856,
      sha256:
          '882e8d2db44dc554fb0ea5077cb7e4bc49e7342a1f0da57901c0802ea21a0863',
      chatTemplate: 'gemma3',
      minRamGb: 8,
      license: 'Gemma Terms of Use',
    ),
  ];

  static ModelSpec? byId(String? id) {
    if (id == null) return null;
    for (final m in models) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// اندازهٔ خوانا به فارسی («۸۰۶ مگابایت»، «۲٫۵ گیگابایت»).
  static String sizeLabel(int bytes) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    String d(String s) =>
        s.split('').map((c) {
          final i = c.codeUnitAt(0) - 48;
          if (c == '.') return '٫';
          return i >= 0 && i <= 9 ? fa[i] : c;
        }).join();
    if (bytes >= 1000000000) {
      return '${d((bytes / 1000000000).toStringAsFixed(1))} گیگابایت';
    }
    return '${d((bytes / 1000000).round().toString())} مگابایت';
  }
}
