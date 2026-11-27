part of 'advocate.dart';

// ---- ثابت‌ها و نشانه‌های مشترک

/// سقف طول متنِ هر پاسخ (بدون پرسشِ پایانی)؛ بقیه با «ادامه بده» می‌آید.
const int _budget = 380;

const int _roomyBudget = 760;

List<String> get _yesNo => yesNoChips;

List<String> get _replyChips => advocateTextSeq('constReplyChip', 4);

List<String> get _goalChips => advocateTextSeq('constGoalChip', 2);

/// کاربر خودش گفته دنبال چیست؛ دیگر نمی‌پرسم.
const String _goalSaid =
    '(?:میخوام|میخواهم|ترجیح|دوست دارم|دنبال|بهتره|حاضرم) (?:[^ ]+ ){0,5}(?:توافق|سازش|صلح|دوستانه|مسالمت|کنار بیا)'
    '|(?:توافق|سازش|صلح)[^ ]* (?:[^ ]+ ){0,2}(?:تموم|تمام|حل) (?:بشه|شه|شود|کنیم)'
    '|(?:میخوام|میخواهم) (?:[^ ]+ ){0,3}(?:شکایت کنم|تا (?:آخر|اخر|ته)|برم دادگاه)|کوتاه نمیام';

/// کاربر خودش گفته طرف مقابل چه برخوردی داشته؛ دیگر نمی‌پرسم.
const String _replySaid =
    ' میگه | میگن | میگوید | میگویند | گفته | گفت |جواب(?:م| منو| تلفن)?(?: رو)? نمیده|بلاک|زیر بار نمیره|قبول نمیکنه|قبول نمیکند|قبول نکرد|راضی نمیشه|راضی نمیشود|انکار میکنه|حاشا|امروز و فردا|امروز فردا|قول داده|تهدید(?:م)? (?:کرد|میکنه)';

/// موضوع‌هایی که طرف مقابلِ مشخصی دارند و «او چه می‌گوید؟» معنا دارد.
const Set<String> _adversarial = {
  'rent', 'cheque', 'debt', 'labor', 'family', 'partner', 'neighbor',
  'consumer', 'guarantee', 'property', 'inherit', 'child',
};

/// نشانه‌های اینکه کاربر خودش دارد موضوع را عوض می‌کند.
const String _newMatter =
    ' راستی | در ضمن | ضمنا | (?:یه|یک) (?:مشکل|سوال|موضوع|مورد|چیز|گرفتاری) (?:دیگه|دیگر|دیگه ای|دیگری) | (?:مشکل|سوال|موضوع|مورد) (?:دیگه|دیگر) ';

String get _dontKnowChip => advocateText('constDontKnowChip');

Map<String, String> get _followChips => {
      'next': advocateText('constFollowChip_next'),
      'evidence': advocateText('constFollowChip_evidence'),
      'cost': advocateText('constFollowChip_cost'),
      'chance': advocateText('constFollowChip_chance'),
      'time': advocateText('constFollowChip_time'),
    };
