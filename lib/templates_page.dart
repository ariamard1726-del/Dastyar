import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'engine.dart';
import 'templates.dart';

const String _disclaimer =
    'این متن‌ها فقط پیش‌نویس‌اند و جایگزین مشاورهٔ وکیل نیستند. قبل از ثبت، آن‌ها را با یک کارشناس حقوقی یا مرکز مشاورهٔ رایگان بررسی کنید و به مهلت‌های قانونی دقت کنید.';

class _Banner extends StatelessWidget {
  final String text;
  final bool warn;
  const _Banner(this.text, {this.warn = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warn ? cs.errorContainer : cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          height: 1.6,
          color: warn ? cs.onErrorContainer : cs.onTertiaryContainer,
        ),
      ),
    );
  }
}

class TemplatesPage extends StatelessWidget {
  final TemplateRepository repo;
  final KnowledgeEngine engine;
  const TemplatesPage({super.key, required this.repo, required this.engine});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('تهیه متن حقوقی')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const _Banner(_disclaimer),
            const SizedBox(height: 12),
            if (repo.templates.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('هنوز قالبی در برنامه نیست.'),
              ),
            for (final t in repo.templates)
              Card(
                child: ListTile(
                  title: Text(t.title),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.description),
                        if (!t.reviewed)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'پیش‌نویس بازبینی‌نشده',
                              style: TextStyle(
                                color: cs.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TemplateFormPage(template: t, engine: engine),
                    ),
                  ),
                ),
              ),
            if (repo.problems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${repo.problems.length} قالب معیوب بود و بارگذاری نشد.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TemplateFormPage extends StatefulWidget {
  final LegalTemplate template;
  final KnowledgeEngine engine;
  const TemplateFormPage({
    super.key,
    required this.template,
    required this.engine,
  });

  @override
  State<TemplateFormPage> createState() => _TemplateFormPageState();
}

class _TemplateFormPageState extends State<TemplateFormPage> {
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, String> _vals = {};

  @override
  void initState() {
    super.initState();
    for (final f in widget.template.fields) {
      if (f.type == 'choice') {
        _vals[f.id] = '';
      } else if (f.type == 'check') {
        _vals[f.id] = 'false';
      } else {
        _ctrls[f.id] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _values() {
    final v = <String, String>{};
    for (final f in widget.template.fields) {
      final c = _ctrls[f.id];
      v[f.id] = c != null ? c.text.trim() : (_vals[f.id] ?? '');
    }
    return v;
  }

  void _open(Map<String, String> v) {
    final text = TemplateRenderer.render(widget.template, v);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultPage(
          template: widget.template,
          text: text,
          engine: widget.engine,
        ),
      ),
    );
  }

  Future<void> _make() async {
    final v = _values();
    final miss = TemplateRenderer.missing(widget.template, v);
    if (miss.isEmpty) {
      _open(v);
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اطلاعات ناقص است'),
        content: Text(
          '${miss.map((e) => '• $e').join('\n')}\n\nمی‌توانید با جای خالی ادامه دهید و بعداً دستی پر کنید.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('بازگشت'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ساخت با جای خالی'),
          ),
        ],
      ),
    );
    if (go == true && mounted) _open(v);
  }

  Widget _fieldWidget(TemplateField f) {
    final label = f.required ? '${f.label} *' : f.label;
    switch (f.type) {
      case 'choice':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final o in f.options)
                  ChoiceChip(
                    label: Text(o),
                    selected: _vals[f.id] == o,
                    onSelected: (sel) =>
                        setState(() => _vals[f.id] = sel ? o : ''),
                  ),
              ],
            ),
          ],
        );
      case 'check':
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          value: _vals[f.id] == 'true',
          onChanged: (b) => setState(() => _vals[f.id] = b ? 'true' : 'false'),
        );
      default:
        final c = _ctrls[f.id]!;
        final isNum = f.type == 'number';
        final multi = f.type == 'multiline';
        String? helper;
        if (isNum && c.text.trim().isNotEmpty) {
          helper = TemplateRenderer.money(c.text.trim());
        }
        return TextField(
          controller: c,
          keyboardType: isNum
              ? TextInputType.number
              : (multi ? TextInputType.multiline : TextInputType.text),
          minLines: multi ? 2 : 1,
          maxLines: multi ? 5 : 1,
          onChanged: isNum ? (_) => setState(() {}) : null,
          decoration: InputDecoration(
            labelText: label,
            hintText: f.hint.isEmpty ? null : f.hint,
            helperText: helper,
            border: const OutlineInputBorder(),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (!t.reviewed) ...[
              _Banner(
                t.reviewNote.isEmpty
                    ? 'این قالب هنوز بازبینی نشده است.'
                    : t.reviewNote,
                warn: true,
              ),
              const SizedBox(height: 12),
            ],
            if (t.tips.isNotEmpty) ...[
              _Banner('نکته‌ها:\n${t.tips.map((e) => '• $e').join('\n')}'),
              const SizedBox(height: 16),
            ],
            for (final f in t.fields) ...[
              _fieldWidget(f),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: _make,
              icon: const Icon(Icons.edit_document),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('ساخت متن'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class ResultPage extends StatelessWidget {
  final LegalTemplate template;
  final String text;
  final KnowledgeEngine engine;
  const ResultPage({
    super.key,
    required this.template,
    required this.text,
    required this.engine,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('متن کپی شد')),
    );
  }

  Widget _lawSection(BuildContext context) {
    if (template.lawRefs.isEmpty) return const SizedBox.shrink();
    final items = <Widget>[];
    for (final r in template.lawRefs) {
      final c = engine.findArticle(r.law, r.article);
      if (c == null) continue;
      items.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.source} — ${c.title}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (r.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(r.note),
                ],
                const SizedBox(height: 8),
                SelectableText(
                  c.body,
                  style: const TextStyle(fontSize: 15, height: 1.8),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final Widget content;
    if (items.isEmpty) {
      content = const Text('متن رسمی مواد مرتبط هنوز در برنامه نیست.');
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مواد قانونی مرتبط',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('متن آمادهٔ شما')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (!template.reviewed) ...[
              _Banner(
                template.reviewNote.isEmpty
                    ? 'این قالب هنوز بازبینی نشده است.'
                    : template.reviewNote,
                warn: true,
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SelectableText(
                  text,
                  style: const TextStyle(fontSize: 16, height: 1.9),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('کپی متن'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('ویرایش اطلاعات'),
            ),
            _lawSection(context),
            const SizedBox(height: 12),
            const _Banner(_disclaimer),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
