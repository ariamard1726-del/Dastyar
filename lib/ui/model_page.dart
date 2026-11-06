import 'package:flutter/material.dart';

import 'package:dastyar/core/llama_backend.dart';
import 'package:dastyar/core/model_catalog.dart';
import 'package:dastyar/core/model_store.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/settings.dart';

/// صفحهٔ نصب اختیاری مدل هوشمند روی گوشی.
class ModelPage extends StatefulWidget {
  final ModelStore store;
  final AppSettings settings;
  final LlamaLlm? llama;
  const ModelPage({
    super.key,
    required this.store,
    required this.settings,
    this.llama,
  });

  @override
  State<ModelPage> createState() => _ModelPageState();
}

class _ModelPageState extends State<ModelPage> {
  int? _ramMb;
  bool? _abiOk;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    final ram = await widget.store.platform.totalRamMb();
    final abi = await widget.store.platform.supportedAbi();
    if (!mounted) return;
    setState(() {
      _ramMb = ram;
      _abiOk = abi;
    });
  }

  String _fa(Object o) => PersianText.toFaDigits(o.toString());

  Future<void> _download(ModelSpec m) async {
    final ramGb = (_ramMb ?? 0) / 1024;
    final low = _ramMb != null && ramGb + 0.5 < m.minRamGb;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('دانلود ${m.title}'),
        content: Text(
          'حجم دانلود: ${ModelCatalog.sizeLabel(m.sizeBytes)}. بهتر است با وای‌فای دانلود کنید.\n\n'
          'فقط فایل مدل دانلود می‌شود؛ گفتگوها و اطلاعات شما هیچ‌وقت از گوشی خارج نمی‌شوند. '
          'پس از نصب، مدل کاملاً آفلاین کار می‌کند.\n\n'
          'مجوز مدل: ${m.license}.'
          '${low ? '\n\nهشدار: حافظهٔ گوشی شما (حدود ${_fa((ramGb).toStringAsFixed(1))} گیگابایت) از مقدار پیشنهادی کمتر است و ممکن است مدل کند باشد یا اجرا نشود.' : ''}',
          style: const TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('دانلود'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await widget.store.download(m);
    if (done) await _afterInstall();
  }

  Future<void> _import() async {
    final done = await widget.store.importFromFile();
    if (done) await _afterInstall();
  }

  Future<void> _afterInstall() async {
    await widget.llama?.reset();
    await widget.settings.setUseLocalLlm(true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('مدل نصب و روشن شد')),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف مدل'),
        content: const Text(
            'فایل مدل از گوشی حذف شود؟ برنامه بدون مدل هم کامل کار می‌کند.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف شود'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.llama?.reset();
    await widget.settings.setUseLocalLlm(false);
    await widget.store.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مدل هوشمند (اختیاری)')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.store, widget.settings]),
          builder: (context, _) => _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final s = widget.store;
    final theme = Theme.of(context);
    final unsupported = _abiOk == false;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'دستیار بدون مدل هم کامل کار می‌کند. اگر بخواهید، می‌توانید یک مدل زبانی کوچک روی گوشی نصب کنید تا لحن پاسخ‌ها طبیعی‌تر و شخصی‌تر شود و پرسش‌های خارج از موضوعات آماده هم پاسخ روان‌تری بگیرند.\n\n'
              'مدل فقط «نویسنده» است: مواد قانونی، مهلت‌ها و مرجع‌ها همیشه از متن رسمی قوانین برنامه می‌آیند و هر جمله‌ای که مدل دربارهٔ قانون بسازد و در متن قانون نباشد، کنار گذاشته می‌شود.',
              style: TextStyle(height: 1.8),
            ),
          ),
        ),
        if (unsupported)
          Card(
            color: theme.colorScheme.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'این گوشی برای اجرای مدل پشتیبانی نمی‌شود (نیاز به اندروید ۸ و پردازندهٔ ۶۴ بیتی ARM). برنامه بدون مدل کامل کار می‌کند.',
                style: TextStyle(height: 1.7),
              ),
            ),
          ),
        if (s.isInstalled) ...[
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('استفاده از مدل: ${s.installedTitle}'),
                  subtitle: const Text(
                      'با خاموش کردن، پاسخ‌ها فقط از موتور قطعی برنامه می‌آیند.'),
                  value: widget.settings.useLocalLlm,
                  onChanged: unsupported
                      ? null
                      : (v) async {
                          if (!v) await widget.llama?.dispose();
                          await widget.settings.setUseLocalLlm(v);
                        },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('حذف مدل از گوشی'),
                  onTap: s.isBusy ? null : _delete,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (s.isBusy) _progressCard(context),
        if (s.phase == ModelInstallPhase.failed && s.error != null)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(s.error!, style: const TextStyle(height: 1.7)),
            ),
          ),
        for (final m in ModelCatalog.models)
          Card(
            child: ListTile(
              title: Text(m.title),
              subtitle: Text(m.description, style: const TextStyle(height: 1.6)),
              isThreeLine: true,
              trailing: s.installedId == m.id
                  ? const Icon(Icons.check_circle_outline)
                  : FilledButton.tonal(
                      onPressed: s.isBusy || unsupported ? null : () => _download(m),
                      child: const Text('دانلود'),
                    ),
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('واردکردن از فایل'),
            subtitle: const Text(
              'اگر فایل مدل (‎.gguf‎) را قبلاً با مرورگر یا از کسی گرفته‌اید، از اینجا انتخابش کنید؛ نیازی به اینترنت نیست.',
              style: TextStyle(height: 1.6),
            ),
            onTap: s.isBusy || unsupported ? null : _import,
          ),
        ),
        if (_ramMb != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'حافظهٔ این گوشی: حدود ${_fa(((_ramMb ?? 0) / 1024).toStringAsFixed(1))} گیگابایت',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _progressCard(BuildContext context) {
    final s = widget.store;
    final label = switch (s.phase) {
      ModelInstallPhase.downloading =>
        'در حال دانلود: ${ModelCatalog.sizeLabel(s.received)} از ${ModelCatalog.sizeLabel(s.total)}',
      ModelInstallPhase.verifying => 'در حال بررسی سلامت فایل…',
      ModelInstallPhase.importing => 'در حال کپی فایل…',
      _ => '',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: s.phase == ModelInstallPhase.downloading ? s.progress : null,
            ),
            if (s.phase == ModelInstallPhase.downloading)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: s.cancel,
                  child: const Text('توقف (بعداً ادامه می‌یابد)'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
