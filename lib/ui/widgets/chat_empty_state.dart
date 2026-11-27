part of 'chat_bubbles.dart';

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.balance, size: 36, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            const Text(
              'سلام، چه کمکی از من برمی‌آید؟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'وکیل و مشاور حقوقی آفلاین (بدون نیاز به اینترنت). مشکل خود را شرح دهید تا با پرسش‌وپاسخ منطقی بررسی کنیم و در صورت نیاز دادخواست، لایحه یا شکوائیه برایتان تنظیم کنم.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// ردیف پیشنهادها بالای کادر نوشتن (مثل چت‌بات‌های امروزی).
///
/// هنگام نوشتن، پیشنهادهای متناسب با موضوع متن ([InputSuggestions]) و در غیر
/// این صورت گزینه‌های آخرین پاسخ دستیار را نشان می‌دهد. تا وقتی پاسخ در حال
/// نوشته‌شدن است پنهان می‌ماند.
