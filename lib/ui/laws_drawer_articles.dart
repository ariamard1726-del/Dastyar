// کارت‌های مادهٔ دراور فهرست قوانین: کارت نتیجهٔ جست‌وجو، بدنهٔ ماده با متن
// انتخاب‌شدنی و دکمهٔ کپی، و چیپ «واژهٔ حقوقی».

import 'package:flutter/material.dart';

import 'package:dastyar/ui/laws_drawer_theme.dart';
import 'package:dastyar/ui/laws_library.dart';

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
          color: drawerCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: drawerCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
              child: Row(
                children: [
                  Expanded(
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
                  if (hit.tag != null && hit.tag!.isNotEmpty)
                    _TagChip(hit.tag!),
                ],
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

/// چیپ کوچک «واژهٔ حقوقی» کنار عنوان قانون در نتایج جست‌وجو.
class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip(this.tag);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: drawerCopperSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sell_outlined, size: 10.5, color: drawerCopper),
          const SizedBox(width: 3),
          Text(
            tag,
            style: const TextStyle(
              fontFamily: drawerFont,
              fontSize: 9.5,
              height: 1.2,
              color: drawerCopper,
            ),
          ),
        ],
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
        if (divider)
          const Divider(height: 1, thickness: 1, color: drawerCardBorder),
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
                      color: drawerOffWhite,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        size: 17, color: drawerMuted),
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
                  color: drawerOffWhite, // متن ماده: ساده و سفیدِ گرمیافته
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
