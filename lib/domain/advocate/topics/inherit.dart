// موضوع: ارث.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic inheritTopic = Topic.dsl(
  id: 'inherit',
  title: topicText('inherit_0'),
  cues: {
    'ارث|ارثیه|ماترک|ترکه|انحصار وراثت|حصر وراثت|وراث|ورثه|سهم ?الارث': 4,
    '(?:پدر|مادر|بابا|مامان|همسر|شوهر|برادر|خواهر|پدربزرگ|مادربزرگ)(?:م|مون)? (?:فوت|مرد|مرده|از دنیا|تازه فوت)|مرحوم|خدابیامرز': 2,
    'وصیت|وصیت ?نامه': 3,
    '(?:خونه|ملک|زمین|اموال|مال|حساب|ماشین|مغازه)(?:ش| اش)? (?:[^ ]+ ){0,2}(?:مونده|به جا|باقی)|تقسیم|نمیفروش|بدهی داشت|طلبکار': 2,
  },
  anti: 'طلاق|مهریه(?:م| ام| من)',
  recap: const [
    RecapItem(when: FactEq('rel', 'child'), text: Tx('inherit_1')),
    RecapItem(when: FactEq('rel', 'wife'), text: Tx('inherit_2')),
    RecapItem(when: FactEq('rel', 'husband'), text: Tx('inherit_3')),
    RecapItem(when: FactEq('rel', 'other'), text: Tx('inherit_4')),
    RecapItem(when: FactYes('cert'), text: Tx('inherit_5')),
    RecapItem(when: FactNo('cert'), text: Tx('inherit_6')),
    RecapItem(when: FactYes('agree'), text: Tx('inherit_7')),
    RecapItem(when: FactNo('agree'), text: Tx('inherit_8')),
  ],
  claims: [
    Claim.dsl(
      goal: topicText('inherit_9'),
      elements: [
        Element.dsl(
          topicText('inherit_10'),
          const FactTriIf(
            FactAll([FactHas('rel'), FactNot(FactEq('rel', 'other'))]),
            true,
          ),
        ),
        Element.dsl(
          topicText('inherit_11'),
          const FactTri('cert'),
          ifNo: topicText('inherit_12'),
        ),
        Element.dsl(
          topicText('inherit_13'),
          const FactConst(null),
        ),
      ],
      win: const Tx('inherit_14'),
      counter: const Tx('inherit_15'),
    ),
  ],
  slots: [
    Slot.dsl(
      id: 'rel',
      ask: topicText('inherit_16'),
      why: topicText('inherit_17'),
      options: [topicText('inherit_18'), topicText('inherit_19'), topicText('inherit_20'), topicText('inherit_21')],
      yesValue: '',
      noValue: '',
      read: const ReadCases([
        ReadCase('شوهرم (?:[^ ]+ ){0,2}(?:فوت|مرد|از دنیا)|زنش (?:هستم|بودم)|خانمش (?:هستم|بودم)|ارث شوهرم', 'wife'),
        ReadCase('(?:زنم|خانمم) (?:[^ ]+ ){0,2}(?:فوت|مرد|از دنیا)|شوهرش (?:هستم|بودم)|ارث (?:زنم|خانمم)', 'husband'),
        ReadCase('(?:پدر|مادر|بابا|مامان)(?:م|مون) (?:[^ ]+ ){0,2}(?:فوت|مرد|از دنیا|مرحوم)|مرحوم (?:پدر|مادر)|(?:پدر|مادر|بابا|مامان)(?:م|مون) خدا ?بیامرز|ارث (?:پدر|مادر|بابا|مامان)|فرزند(?:ش)? (?:هستم|ام)|پسرش (?:هستم|ام)|دخترش (?:هستم|ام)|بچه(?: ?ش| اش) (?:هستم|ام)', 'child'),
        ReadCase('(?:برادر|خواهر|عمو|دایی|خاله|عمه|پدربزرگ|مادربزرگ)(?:م|مون) (?:[^ ]+ ){0,2}(?:فوت|مرد|از دنیا)|(?:برادر|خواهر|نوه|برادرزاده|خواهرزاده)(?:ش| اش) (?:هستم|ام)|نسبت دیگ', 'other'),
      ]),
      effect: const TxSwitch(
        'rel',
        {
          'child': Tx('inherit_22'),
          'wife': Tx('inherit_23'),
          'husband': Tx('inherit_24'),
        },
        fallback: Tx('inherit_25'),
      ),
    ),
    Slot.dsl(
      id: 'cert',
      ask: topicText('inherit_26'),
      why: topicText('inherit_27'),
      options: [topicText('inherit_28'), topicText('inherit_29')],
      read: const ReadYn(
        '(?:حصر|انحصار) وراثت (?:گرفتیم|گرفتم|داریم|دارم|شده)|گواهی(?:ش)? (?:رو )?گرفتیم',
        '(?:حصر|انحصار) وراثت (?:نگرفتیم|نگرفتم|نداریم|ندارم|نشده)|هنوز (?:نگرفتیم|هیچ کاری)',
      ),
      effect: const TxCond(
          FactYes('cert'), Tx('inherit_30'), Tx('inherit_31')),
    ),
    Slot.dsl(
      id: 'agree',
      ask: topicText('inherit_32'),
      why: topicText('inherit_33'),
      options: [topicText('inherit_34'), topicText('inherit_35')],
      read: const ReadYn(
        'توافق (?:داریم|کردیم|هست)|مشکلی نداریم|همه راضی',
        'توافق (?:نداریم|نمیکن|نیست)|همراهی نمیکن|کارشکنی|نمیذاره|سهم(?: ارث)?(?:م| من| ما|مون)?[^ ]* (?:رو |را )?نمید|زیر بار نمیر|تصرف کرده|نشسته (?:توش|تو خونه)|اختلاف|دعوا|راضی نمیش|نمیفروش',
      ),
      effect: const TxCond(
          FactYes('agree'), Tx('inherit_36'), Tx('inherit_37')),
    ),
  ],
  opening: const Tx('inherit_38'),
  issues: [
    Issue.dsl(
      id: 'share',
      chip: topicText('inherit_39'),
      cues: 'سهم (?:هر|من|ما|دختر|پسر|زن|همسر)|چقدر (?:میرسه|میبر)|چند درصد|دختر و پسر|نصف پسر|یک ?هشتم|تقسیم (?:میشه|چطور)',
      body: const Tx('inherit_40'),
    ),
    Issue.dsl(
      id: 'debt',
      chip: topicText('inherit_41'),
      cues: 'بدهی|بدهکار بود|قرض داشت|طلبکار|وام داشت|مهریه (?:مادر|زنش)',
      body: const Tx('inherit_42'),
    ),
    Issue.dsl(
      id: 'tax',
      chip: topicText('inherit_43'),
      cues: 'مالیات|اظهارنامه|دارایی',
      body: const Tx('inherit_44'),
    ),
  ],
  follow: const {
    'next': Tx('inherit_45'),
    'where': Tx('inherit_46'),
    'evidence': Tx('inherit_47'),
    'cost': Tx('inherit_48'),
    'time': Tx('inherit_49'),
    'chance': Tx('inherit_50'),
  },
  drafts: const DraftRule.fixed(['formal_notice']),
);
