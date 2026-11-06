import 'package:dastyar/domain/drafting.dart';

const String docDisclaimer =
    'این متن فقط پیش‌نویس است و جایگزین مشاورهٔ وکیل نیست. پیش از ثبت، آن را با یک کارشناس حقوقی یا مرکز مشاورهٔ رایگان بررسی کنید و به مهلت‌های قانونی دقت کنید.';

class ChatMessage {
  String text;
  final bool fromUser;
  final bool sensitive;
  final bool isDoc;
  final String docTitle;
  final bool docReviewed;
  final String docReviewNote;
  final String note;
  final List<LawText> laws;
  final int lawRefsTotal;
  List<String> chips;
  List<String> conflictChains;

  /// آیا نمایش تدریجی (حالت تایپ) این پیام تمام شده است؟ پیام‌های بازیابی‌شده
  /// از تاریخچه از ابتدا `true` هستند تا دوباره تایپ نشوند.
  bool revealed;

  ChatMessage(
    this.text,
    this.fromUser, {
    this.sensitive = false,
    this.isDoc = false,
    this.docTitle = '',
    this.docReviewed = true,
    this.docReviewNote = '',
    this.note = '',
    this.laws = const [],
    this.lawRefsTotal = 0,
    this.chips = const [],
    this.conflictChains = const [],
    this.revealed = false,
  });
}
