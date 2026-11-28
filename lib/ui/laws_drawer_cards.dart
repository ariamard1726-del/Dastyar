// قطعات نمایشیِ دراور فهرست قوانین: نوار جست‌وجو، کاشی قانون (آکاردئون)،
// کارت ماده و پیام‌های حالت خالی.
//
// نگه‌داشتن این ویجت‌ها در فایلِ جدا، سقفِ ۴۲۰ خطی هر فایلِ `lib/` را حفظ
// می‌کند؛ منطق دراور و وضعیتش در `laws_drawer.dart` است.

import 'package:flutter/material.dart';

import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/ui/laws_library.dart';

const Color drawerPanelBg = Color(0xFF2C2C2C);
const Color _cardBg = Color(0xFF37342F);
const Color drawerCopper = Color(0xFFE2A061);
const Color _offWhite = Color(0xFFF2EDE4);
const Color _muted = Color(0xFFB7AE9F);

/// رنگ متن‌های فرعی؛ بیرون از این فایل هم لازم است.
const Color drawerMuted = _muted;
const Color _divider = Color(0x14FFFFFF);
const String drawerFont = 'Vazirmatn';

/// نوار جست‌وجوی ثابت بالای دراور — RTL، آیکون ذره‌بین، دکمهٔ پاک‌کردن.
class DrawerSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool showClear;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const DrawerSearchBar({
    super.key,
    required this.controller,
    required this.showClear,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlign: TextAlign.right,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
            fontFamily: drawerFont, fontSize: 14, color: _offWhite),
        cursorColor: drawerCopper,
        decoration: InputDecoration(
          hintText: 'شماره ماده را وارد کنید...',
          hintStyle: const TextStyle(
              fontFamily: drawerFont, fontSize: 13, color: _muted),
          filled: true,
          fillColor: const Color(0xFF3A3735),
          prefixIcon: const Icon(Icons.search, color: _muted),
          suffixIcon: showClear
              ? IconButton(
                  icon: const Icon(Icons.clear, color: _muted),
                  tooltip: 'پاک کردن جست‌وجو',
                  onPressed: onClear,
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// عنوان هر قانون در حالت آکاردئون؛ در حالت بازشده دکمهٔ «کپی کل قانون»
/// کنار عنوان ظاهر می‌شود.
class LawTile extends StatelessWidget {
  final LawEntry law;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onCopyLaw;
  final ValueChanged<ArticleEntry> onCopyArticle;

  const LawTile({
    super.key,
    required this.law,
    required this.expanded,
    required this.onToggle,
    required this.onCopyLaw,
    required this.onCopyArticle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _divider),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            law.title,
                            style: const TextStyle(
                              fontFamily: drawerFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              height: 1.55,
                              color: drawerCopper, // عنوان قانون: مسی پررنگ
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${PersianText.toFaDigits(law.articles.length.toString())} ماده',
                            style: const TextStyle(
                                fontFamily: drawerFont,
                                fontSize: 11,
                                color: _muted),
                          ),
                        ],
                      ),
                    ),
                    if (expanded)
                      IconButton(
                        icon: const Icon(Icons.copy_all_outlined,
                            color: drawerCopper, size: 21),
                        tooltip: 'کپی کل قانون',
                        onPressed: onCopyLaw,
                      ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: const Icon(Icons.expand_more, color: _muted),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Column(
                      children: [
                        for (final a in law.articles)
                          ArticleBlock(
                            article: a,
                            onCopy: () => onCopyArticle(a),
                          ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// کارت مادهٔ نتیجهٔ جست‌وجو؛ عنوان قانون بالای آن نشان داده می‌شود.
class ArticleCard extends StatelessWidget {
  final ArticleHit hit;
  final ValueChanged<ArticleEntry> onCopyArticle;

  const ArticleCard({
    super.key,
    required this.hit,
    required this.onCopyArticle,
  });

  @override
  Widget build(BuildContext context) {
    final a = hit.article;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
              child: Text(
                hit.law.title,
                style: const TextStyle(
                  fontFamily: drawerFont,
                  fontSize: 10.5,
                  height: 1.4,
                  color: drawerCopper,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ArticleBlock(
              article: a,
              onCopy: () => onCopyArticle(a),
              divider: false,
            ),
          ],
        ),
      ),
    );
  }
}

/// بدنهٔ یک ماده: سرخط + متن انتخاب‌شدنی + دکمهٔ کپی.
class ArticleBlock extends StatelessWidget {
  final ArticleEntry article;
  final VoidCallback onCopy;

  /// در لیست آکاردئون، بالای هر ماده خط جداکننده می‌آید؛ در کارت نتایج نه.
  final bool divider;

  const ArticleBlock({
    super.key,
    required this.article,
    required this.onCopy,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (divider) const Divider(height: 1, thickness: 1, color: _divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontFamily: drawerFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: _offWhite,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        size: 17, color: _muted),
                    tooltip: 'کپی متن ماده',
                    onPressed: onCopy,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // نگه‌داشتن انگشت روی متن، انتخاب و کپی هر بخشی را ممکن می‌کند.
              SelectableText(
                article.text.isEmpty
                    ? 'متن این ماده در نسخهٔ بسته‌بندی‌شده ثبت نشده است.'
                    : article.text,
                style: const TextStyle(
                  fontFamily: drawerFont,
                  fontSize: 12.5,
                  height: 1.8,
                  color: _offWhite, // متن ماده: ساده و سفیدِ گرمیافته
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// برچسبِ تکه‌های نتایج («متن دقیق ماده» / «مواد مرتبط»).
class DrawerSectionLabel extends StatelessWidget {
  final String text;
  const DrawerSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: drawerFont,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: drawerCopper,
        ),
      ),
    );
  }
}

/// حالت خالی/خطا: آیکون + عنوان + راهنما.
class DrawerMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const DrawerMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: _muted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: drawerFont,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _offWhite,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: drawerFont,
                fontSize: 12,
                height: 1.6,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
