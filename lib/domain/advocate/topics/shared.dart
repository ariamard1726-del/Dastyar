// تکه‌های مشترک بین چند موضوع (مرجع صالح، هزینه، زمان).
//
// قرارداد نگارش همهٔ فایل‌های این پوشه:
//  • استناد قانونی همیشه به‌صورت [[شناسهٔ‌قانون:شمارهٔ‌ماده]] پس از جمله
//    می‌آید؛ نمایش‌دهنده فقط اگر متن ماده واقعاً در بانک قوانین باشد آن را
//    «(مادهٔ … قانون …)» می‌نویسد، وگرنه حذفش می‌کند.
//  • الگوها روی متنِ Sense.norm نوشته شده‌اند (بدون نیم‌فاصله، «خونه»).
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

/// مرجع صالح دعوای مالی بر پایهٔ مبلغ.
String moneyForum(int? toman) {
  final tail = ' ' + topicText('sharedForumTail');
  if (toman == null) {
    return topicText('sharedForumUnknown') + tail;
  }
  if (toman <= 100000000) {
    return topicText('sharedForumPeaceA') + ' ' + Sense.toman(toman) + ' ' + topicText('sharedForumPeaceB') + tail;
  }
  return topicText('sharedForumPublicA') + ' ' + Sense.toman(toman) + ' ' + topicText('sharedForumPublicB') + tail;
}

String get moneyCost =>
    topicText('shared_0');

String get moneyTime =>
    topicText('shared_1');

String get anyLawyer =>
    topicText('shared_2');
