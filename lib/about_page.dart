import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'engine.dart';
import 'templates.dart';

class AboutPage extends StatefulWidget {
  final KnowledgeEngine engine;
  final TemplateRepository repo;
  const AboutPage({super.key, required this.engine, required this.repo});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  Map<String, dynamic> _info = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final text = await rootBundle.loadString('assets/data_info.json');
      final m = jsonDecode(text);
      if (m is Map<String, dynamic> && mounted) {
        setState(() => _info = m);
      }
    } catch (_) {}
  }

  String _fa(Object n) => TemplateRenderer.toFa(n.toString());

  String _text(String key, String empty) {
    final v = (_info[key] ?? '').toString().trim();
    return v.isEmpty ? empty : _fa(v);
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Text(k)),
          Expanded(
            flex: 2,
            child: Text(
              v,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _p(String s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(s, style: const TextStyle(height: 1.7)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.repo.templates.length;
    final reviewed = widget.repo.templates.where((t) => t.reviewed).length;
    final note = (_info['note'] ?? '').toString().trim();
    return Scaffold(
      appBar: AppBar(title: const Text('اطلاعات و وضعیت داده‌ها')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _card('وضعیت داده‌ها', [
              _row('نسخهٔ داده‌ها', _text('dataVersion', 'ثبت نشده')),
              _row('آخرین به‌روزرسانی قوانین', _text('lawsUpdated', 'ثبت نشده')),
              _row('بخش‌های دانش', _fa(widget.engine.size)),
              _row('قالب‌ها', _fa(total)),
              _row('قالب‌های بازبینی‌شده', _fa(reviewed)),
              if (note.isNotEmpty) _p(note),
            ]),
            const SizedBox(height: 8),
            _card('این برنامه چه کاری می‌کند', [
              _p('• از متن‌های داخل خود برنامه جواب می‌دهد و هیچ اطلاعاتی را به اینترنت نمی‌فرستد.'),
              _p('• متن دادخواست و نامه را از روی قالب و اطلاعاتی که شما وارد می‌کنید می‌سازد.'),
            ]),
            const SizedBox(height: 8),
            _card('این برنامه چه کاری نمی‌کند', [
              _p('• جایگزین وکیل نیست و نتیجهٔ پرونده را پیش‌بینی نمی‌کند.'),
              _p('• اگر قانونی تغییر کرده باشد، ممکن است متن داخل برنامه قدیمی باشد؛ تاریخ به‌روزرسانی را بالا ببینید.'),
              _p('• قالب‌های «بازبینی‌نشده» فقط پیش‌نویس‌اند.'),
            ]),
            const SizedBox(height: 8),
            _card('اگر توان پرداخت وکیل را ندارید', [
              _p('درخواست معاضدت قضایی (کمک وکیل برای کسانی که توان مالی ندارند) و مراکز مشاورهٔ حقوقی رایگان را از دادگاه یا دفتر خدمات قضایی محل خود بپرسید؛ شرایط و روش آن را همان‌جا می‌گویند.'),
              _p('به مهلت‌های قانونی، مثل مهلت اعتراض، حتماً توجه کنید.'),
            ]),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
