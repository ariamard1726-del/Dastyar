// دراور سمتِ راستِ «فهرست قوانین» — ۸۰٪ عرض صفحه، پس‌زمینهٔ تیره، RTL.
//
// * تنها راه باز شدنش دکمهٔ سه‌نقطهٔ (⋮) نوار برنامه است؛ منوی کناریِ
//   موجود در [AppDrawer] کاملاً دست‌نخورده می‌ماند و کاری به آن ندارد.
// * بالا: جست‌وجوی ماده‌ها به‌صورت زنده با دکمهٔ پاک‌کردن.
// * بدنه: فهرست ۲۴ قانون به همان ترتیب `laws_catalog.json` به‌شکل آکاردئون؛
//   کلیک روی عنوان، مواد را نرم باز/بسته می‌کند.
// * کپی: کنار عنوان هر قانونِ بازشده «کپی کل قانون» («کل قانون کپی شد»)،
//   کنار هر ماده «کپی متن ماده»؛ متن‌ها `SelectableText` هستند تا با نگه‌داشتن
//   انگشت قابل‌انتخاب باشند.
//
// ویجت‌های درون‌دراور در `laws_drawer_cards.dart` هستند؛ وضعیت و منطق
// جست‌وجو/کپی همین‌جا زندگی می‌کند.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'package:dastyar/core/legal_disclaimer.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/ui/laws_drawer_articles.dart';
import 'package:dastyar/ui/laws_drawer_cards.dart';
import 'package:dastyar/ui/laws_drawer_theme.dart';
import 'package:dastyar/ui/laws_library.dart';

/// دراور فهرست قوانین را باز می‌کند؛ شیت ۸۰٪ سمت راست، بقیهٔ صفحه کم‌رنگ.
///
/// اگر `legalTerms` داده شود (معمولاً `engine.legalTerms`)، جست‌وجوی
/// ماده‌ها از پیوندهای «واژهٔ حقوقی ↔ ماده» هم استفاده می‌کند.
Future<void> showLawsDrawer(
  BuildContext context, {
  Map<String, dynamic>? legalTerms,
  List<LawEntry>? library,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'بستن فهرست قوانین',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _LawsDrawerPanel(legalTerms: legalTerms, library: library),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        // از سمت راست؛ مستقل از جهت‌چینش (RTL) تا دراور دقیقاً سمت راست بماند.
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(curved),
        child: child,
      );
    },
  );
}

class _LawsDrawerPanel extends StatefulWidget {
  final Map<String, dynamic>? legalTerms;

  /// داده‌های آمادهٔ قانون؛ اگر داده شود، از `LawsLibrary.load()` استفاده
  /// نمی‌شود (برای آزمون‌های Widget که ساعتِ binding شان فِیک است).
  final List<LawEntry>? library;

  const _LawsDrawerPanel({this.legalTerms, this.library});

  @override
  State<_LawsDrawerPanel> createState() => _LawsDrawerPanelState();
}

class _LawsDrawerPanelState extends State<_LawsDrawerPanel> {
  late final Future<List<LawEntry>> _library = widget.library != null
      ? Future<List<LawEntry>>.value(widget.library)
      : LawsLibrary.load();
  late final List<Map<String, dynamic>>? _termEntries = _extractEntries(
    widget.legalTerms,
  );
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _expanded = <String>{};
  String _query = '';

  static List<Map<String, dynamic>>? _extractEntries(
      Map<String, dynamic>? raw) {
    final list = raw?['entries'];
    if (list is! List) return null;
    return list.whereType<Map<String, dynamic>>().toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQuery(String value) => setState(() => _query = value);

  void _clearQuery() {
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  void _toggleLaw(String id) {
    setState(() {
      if (!_expanded.remove(id)) _expanded.add(id);
    });
  }

  Future<void> _copy(String text, String toast) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(toast, style: const TextStyle(fontFamily: drawerFont)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: size.width * 0.8, // دقیقاً ۸۰٪ عرض صفحه
          height: size.height,
          child: DefaultTextStyle(
            style: const TextStyle(fontFamily: drawerFont, color: drawerOffWhite),
            child: ColoredBox(
              color: drawerPanelBg,
              child: SafeArea(
                child: Column(
                  children: [
                    DrawerSearchBar(
                      controller: _searchCtrl,
                      showClear: _query.isNotEmpty,
                      onChanged: _onQuery,
                      onClear: _clearQuery,
                    ),
                    Expanded(child: _buildBody()),
                    const Divider(height: 1, color: drawerCardBorder),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                      child: Text(
                        legalDisclaimer,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: drawerFont,
                          fontSize: 9.5,
                          height: 1.55,
                          color: drawerMuted,
                        ),
                      ),
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

  Widget _buildBody() {
    return FutureBuilder<List<LawEntry>>(
      future: _library,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return DrawerMessage(
            icon: Icons.error_outline,
            title: 'قوانین بار نشدند',
            subtitle: snapshot.error.toString(),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: drawerCopper),
                SizedBox(height: 14),
                Text(
                  'در حال باز کردن قوانین…',
                  style: const TextStyle(color: drawerMuted, fontSize: 13),
                ),
              ],
            ),
          );
        }
        final laws = snapshot.data!;
        final query = _query.trim();
        if (query.isEmpty) return _accordion(laws);
        return _results(laws, query);
      },
    );
  }

  Widget _accordion(List<LawEntry> laws) {
    return Scrollbar(
      scrollbarOrientation: ScrollbarOrientation.left, // اسکرول‌بار در چپ
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 20),
        itemCount: laws.length,
        itemBuilder: (context, i) {
          final law = laws[i];
          final expanded = _expanded.contains(law.id);
          return LawTile(
            law: law,
            expanded: expanded,
            onToggle: () => _toggleLaw(law.id),
            onCopyLaw: () => _copy(law.fullCopyText, 'کل قانون کپی شد'),
            onCopyArticle: (a) => _copy(a.copyText, 'متن ماده کپی شد'),
          );
        },
      ),
    );
  }

  Widget _results(List<LawEntry> laws, String query) {
    final hits = searchLaws(laws, query, legalTerms: _termEntries);
    if (hits.isEmpty) {
      return const DrawerMessage(
        icon: Icons.search_off,
        title: 'نتیجه‌ای یافت نشد',
        subtitle: 'برای مثال بنویسید: ماده ۱۰',
      );
    }
    final exact = hits.where((h) => h.exact).toList();
    final related = hits.where((h) => !h.exact).toList();
    return Scrollbar(
      scrollbarOrientation: ScrollbarOrientation.left,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 2),
            child: Text(
              '${PersianText.toFaDigits(hits.length.toString())} نتیجه برای «$query»',
              style: const TextStyle(
                fontSize: 11.5,
                color: drawerMuted,
              ),
            ),
          ),
          if (exact.isNotEmpty) ...[
            const DrawerSectionLabel('متن دقیق ماده'),
            for (final h in exact)
              ArticleCard(
                hit: h,
                onCopyArticle: (a) => _copy(a.copyText, 'متن ماده کپی شد'),
              ),
          ],
          if (related.isNotEmpty) ...[
            const DrawerSectionLabel('مواد مرتبط'),
            for (final h in related)
              ArticleCard(
                hit: h,
                onCopyArticle: (a) => _copy(a.copyText, 'متن ماده کپی شد'),
              ),
          ],
        ],
      ),
    );
  }
}
