import 'package:flutter/material.dart';

import 'package:dastyar/ui/app_settings.dart';

/// توضیح کوتاه بار نخست، پیش از اینکه برنامه شروع به نوشتن داده کند.
///
/// کاربر حق دارد بداند که حتی بدون اینترنت، متن گفتگو روی همان گوشی ذخیره
/// میشود یا خیر. این صفحه جایگزین رضانامهٔ حقوقی نیست؛ یک تصمیم ساده است:
/// «ذخیره شود» یا «فقط در همین اجرا».
class PrivacyNoticePage extends StatelessWidget {
  const PrivacyNoticePage({super.key, required this.settings});

  final AppSettings settings;

  Future<void> _choose(bool saveHistory) {
    return settings.acceptConsent(saveHistory: saveHistory);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.privacy_tip_outlined,
                        size: 40, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('اطلاعات شما کجا میماند؟',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    const Text(
                      'دستیار بدون اینترنت کار میکند و چیزی به بیرون نمیفرستد. '
                      'اما متن گفتگوی شما میتواند روی همین گوشی ذخیره شود تا '
                      'بعداً در «تاریخچه» آنرا ببینید. این ذخیره رمزنگاری '
                      'میشود ولی جایگزین وکیل یا مشاورهٔ محرمانه نیست.',
                      style: TextStyle(height: 1.7),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'اگر گوشی مشترک دارید، گزینهٔ دوم را برگزینید؛ '
                      'همچنین میتوانید از تنظیمات، «محافظت از صفحه» را '
                      'روشن کنید.',
                      style: TextStyle(height: 1.7),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => _choose(true),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('ذخیرهٔ تاریخچه روی همین گوشی'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _choose(false),
                      icon: const Icon(Icons.no_sim_outlined),
                      label: const Text('فقط در همین اجرا؛ ذخیره نشود'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
