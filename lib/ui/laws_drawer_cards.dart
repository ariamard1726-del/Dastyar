// قطعات نمایشیِ دراور فهرست قوانین: نوار جست‌وجو، کاشی قانون (آکاردئون)،
// برچسبِ بخش‌ها و حالت‌های خالی. کارت‌های ماده در `laws_drawer_articles.dart`
// و پالت در `laws_drawer_theme.dart` هستند.

import 'package:flutter/material.dart';

import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/ui/laws_drawer_articles.dart';
import 'package:dastyar/ui/laws_drawer_theme.dart';
import 'package:dastyar/ui/laws_library.dart';

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
            fontFamily: drawerFont, fontSize: 14, color: drawerOffWhite),
        cursorColor: drawerCopper,
        decoration: InputDecoration(
          hintText: 'شماره ماده را وارد کنید...',
          hintStyle: const TextStyle(
              fontFamily: drawerFont, fontSize: 13, color: drawerMuted),
          filled: true,
          fillColor: const Color(0xFF3A3735),
          prefixIcon: const Icon(Icons.search, color: drawerMuted),
          suffixIcon: showClear
              ? IconButton(
                  icon: const Icon(Icons.clear, color: drawerMuted),
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
          color: drawerCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: drawerCardBorder),
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
                                color: drawerMuted),
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
                      child: const Icon(Icons.expand_more, color: drawerMuted),
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

/// برچسبِ بخش‌های نتایج («متن دقیق ماده» / «مواد مرتبط»).
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
            Icon(icon, size: 42, color: drawerMuted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: drawerFont,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: drawerOffWhite,
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
                color: drawerMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
