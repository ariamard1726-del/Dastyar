import 'package:flutter/material.dart';

import 'history.dart';
import 'settings.dart';

class SettingsPage extends StatefulWidget {
  final AppSettings settings;
  final HistoryStore history;
  const SettingsPage({
    super.key,
    required this.settings,
    required this.history,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پاک کردن تاریخچه'),
        content: const Text('همهٔ گفتگوهای ذخیره‌شده برای همیشه پاک شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('پاک شود'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.history.clear();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تاریخچه پاک شد')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اندازهٔ نوشته',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (var i = 0; i < AppSettings.scales.length; i++)
                          ChoiceChip(
                            label: Text(AppSettings.scaleNames[i]),
                            selected: s.fontScale == AppSettings.scales[i],
                            onSelected: (_) {
                              s.setFontScale(AppSettings.scales[i]);
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('نمونهٔ نوشته: دستیار حقوقی آفلاین'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('ذخیرهٔ تاریخچهٔ گفتگوها'),
                    subtitle: const Text(
                      'اگر گوشی را با دیگران مشترک استفاده می‌کنید، آن را خاموش کنید.',
                    ),
                    value: s.saveHistory,
                    onChanged: (v) {
                      s.setSaveHistory(v);
                      setState(() {});
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('پاک کردن همهٔ تاریخچه'),
                    subtitle: Text(
                      '${widget.history.sessions.length} گفتگو ذخیره شده',
                    ),
                    onTap: _clearHistory,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'فرم‌های تهیهٔ متن حقوقی و اطلاعات شخصی داخل آن‌ها (نام، نشانی، مبلغ) هرگز ذخیره نمی‌شوند.',
                style: TextStyle(height: 1.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
