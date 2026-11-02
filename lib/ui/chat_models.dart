import 'package:dastyar/domain/drafting.dart';

const String docDisclaimer =
    'این متن فقط پیش‌نویس است و جایگزین مشاورهٔ وکیل نیست. پیش از ثبت، آن را با یک کارشناس حقوقی یا مرکز مشاورهٔ رایگان بررسی کنید و به مهلت‌های قانونی دقت کنید.';

/// یک گزینه‌ کوچک در نوار بالای فیلد تایپ. [label] همان متن کوتاهی است که
/// دیده می‌شود و [value] متنی است که با لمس شدن به‌عنوان پیام فرستاده
/// می‌شود (مثلاً عنوان کامل یک قالب، نه برچسب کوتاهش).
class ChatSuggestion {
  final String label;
  final String value;

  const ChatSuggestion(this.label, this.value);
}

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
  });
}
