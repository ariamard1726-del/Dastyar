part of 'rent.dart';

// متنِ پاسخِ موضوع‌های اجاره — سمتِ مستأجر و متن‌های مشترک.
// متنهای ثابت از `rent_texts.json` میآیند (`rentText(id)`)؛ تابعهایی که
// پرونده را میخوانند، جملهٔ مناسب را از همانجا میگیرند و با وضعیت پرونده
// ترکیب میکنند. هیچ تصمیمی اینجا گرفته نمیشود. متنهای سمتِ موجر در
// `rent_bodies_landlord.dart`اند.

String _rentPeace() => rentText('rentPeace');

String _rentDepositLaw() => rentText('rentDepositLaw');

String _rentRaiseBody(CaseFile f) {
  final base = rentText('bodyRaiseBase');
  if (f.no('ended')) {
    return base + rentText('bodyRaiseRet00');
  }
  final after = rentText('bodyRaiseAfter');
  if (f.yes('ended')) {
    return rentText('bodyRaiseRet10') + after + rentText('bodyRaiseRet11');
  }
  return base + rentText('bodyRaiseRet20') + after;
}

String _rentRepairBody() => rentText('rentRepairBody');

String _rentDamageBody(CaseFile f) {
  final tail = f.yes('vacated') ? rentText('bodyDamageVacated') : rentText('bodyDamageAccess');
  // «این حرف را زیاد می‌شنوم؛ خوشبختانه…»: دستیار تجربهٔ زیسته ندارد که
  // «زیاد بشنود»، و «خوشبختانه» برای کسی که پولش را نگه داشته‌اند دلداریِ
  // دروغ است. جای هر دو، گفتنِ همان چیزی است که واقعاً می‌دانیم.
  return rentText('bodyDamageRet0') + tail;
}

String _rentEvictBody() => rentText('rentEvictBody');

String _rentOrderBody(CaseFile f) {
  final lead = f.no('ended') ? rentText('bodyOrderNotEnded') : rentText('bodyOrderEnded');
  return lead + rentText('bodyOrderRet0');
}

String _rentOrderDepositBody() => rentText('rentOrderDepositBody');

String _rentAccessBody() => rentText('rentAccessBody');

String _rentSelfRepairBody() => rentText('rentSelfRepairBody');

String _rentDefectBody() => rentText('rentDefectBody');

String _rentGuaranteeBody() => rentText('rentGuaranteeBody');

String _rentBillsBody() => rentText('rentBillsBody');

String _rentLateBody() => rentText('rentLateBody');

String _rentLeaveBody() => rentText('rentLeaveBody');

String _rentRenewBody() => rentText('rentRenewBody');

String _rentHandoverBody() => rentText('rentHandoverBody');

String _rentUnpaidBody(CaseFile f) {
  if (f.eq('aim', 'evict')) {
    return 'دو خواستهٔ جدا دارید که می‌شود هم‌زمان پیش برد:\n'
        '• تخلیه: اگر مدت تمام شده، «دستور تخلیه» بگیرید؛ سریع‌ترین راه است [[landlord_tenant:3]].\n'
        '• اجاره‌های نپرداخته: پرداخت اجاره در موعد تعهد قانونی اوست [[civil:490]]. دادخواست مطالبه بدهید و گواهی ثبتش را به اجرا ببرید تا به همان اندازه از ودیعه نگه داشته شود [[landlord_tenant:4]].\n'
        'از ودیعه سرِ خود کم نکنید؛ فقط از همین راه.';
  }
  return 'پرداخت اجاره در موعد، تعهد قانونی مستأجر است [[civil:490]]. راه شما:\n'
      '• با اظهارنامه اجاره‌های عقب‌افتاده را مطالبه کنید و مهلت بدهید [[civil_procedure:156]].\n'
      '• اگر نداد، دادخواست مطالبهٔ اجاره‌بها بدهید. هنگام تخلیه، با گواهی ثبت همین دادخواست می‌شود به همان اندازه از ودیعه نگه داشت [[landlord_tenant:4]]؛ سرِ خود نه.\n'
      '• برای بلندکردنش پیش از پایان مدت، باید در اجاره‌نامه برای نپرداختن اجاره حق فسخ گذاشته باشید [[civil:496]]؛ بعد از پایان مدت، دستور تخلیه کافی است [[landlord_tenant:3]].';
}

String _rentEarlyBody() => rentText('rentEarlyBody');

String _rentGoneBody() => rentText('rentGoneBody');

String _rentNoMoneyBody(CaseFile f) {
  final key = f.yes('vacated')
      ? ''
      : '\n• تا ودیعه را نگرفته‌اید کلید را بدون رسید تحویل ندهید؛ تحویل ملک و پس‌دادن ودیعه باید هم‌زمان باشد [[landlord_tenant:4]].';
  return 'نداشتنِ پول، تعهد موجر را برنمی‌دارد: ودیعه باید هم‌زمان با تخلیه برگردد و قانون برایش مهلتی نگذاشته است [[landlord_tenant:4]].\n'
      '• او نمی‌تواند شما را به قسطی‌گرفتن وادار کند؛ مهلت یا قسط‌بندی را فقط دادگاه، آن هم با دیدن وضع بدهکار، می‌دهد [[civil:277]].\n'
      '• اگر خودتان می‌خواهید کنار بیایید، توافق را کتبی کنید: مبلغ هر قسط، تاریخ‌ها، و اینکه با نپرداختن یک قسط همهٔ بدهی یک‌جا قابل مطالبه می‌شود. همین نوشته اقرار او به بدهی است.\n'
      '• اگر نمی‌خواهید صبر کنید، با اظهارنامه مطالبه کنید [[civil_procedure:156]] و بعد دادخواست مطالبهٔ ودیعه بدهید. خسارت تأخیر را هم می‌شود خواست؛ دادگاه وقتی آن را می‌دهد که مطالبه کرده باشید و او با داشتنِ توان نپرداخته باشد [[civil_procedure:522]].$key';
}

String _rentBeforeEnd() => rentText('rentBeforeEnd');

String _rentAfterEnd() => rentText('rentAfterEnd');

String _rentFixSelfBody() => rentText('rentFixSelfBody');

String _rentBlameBody() => rentText('rentBlameBody');

String _rentImproveBody() => rentText('rentImproveBody');

String _rentPartialBody() => rentText('rentPartialBody');

String _rentDeliverBody() => rentText('rentDeliverBody');

String _rentThirdBody() => rentText('rentThirdBody');

String _rentPenaltyBody(CaseFile f) {
  const base =
      'مبلغی که در خودِ اجاره‌نامه برای تخلف نوشته‌اید (مثلاً «روزی فلان‌قدر» برای دیر تخلیه‌کردن یا دیر پس‌دادن ودیعه) همان‌طور که نوشته شده قابل مطالبه است و دادگاه کم و زیادش نمی‌کند [[civil:230]]. برای گرفتنش لازم نیست ثابت کنید چقدر ضرر کرده‌اید؛ کافی است تخلف و تاریخش روشن باشد.';
  const none =
      'اگر چنین بندی در اجاره‌نامه نیست، فقط همان چیزی را می‌شود خواست که قانون گفته: اجرت‌المثلِ روزهای ماندن بعد از پایان مدت [[civil:494]] یا خسارت تأخیرِ پول از روز مطالبه [[civil_procedure:522]].';
  return f.eq('role', 'landlord')
      ? '$base\n'
          '• جریمهٔ دیر تخلیه‌کردن را از روز پایان مدت تا روز تحویل حساب کنید و با دادخواست بخواهید؛ با گواهی ثبت همان دادخواست، به همان اندازه از ودیعه نگه داشته می‌شود. سرِ خود کم نکنید [[landlord_tenant:4]].\n'
          '• اگر برای دیر پس‌دادن ودیعه هم جریمه نوشته شده، همین قاعده علیه شما کار می‌کند؛ پس ودیعه را روز تخلیه آماده داشته باشید.\n'
          '$none'
      : '$base\n'
          '• به نفع شما: اگر برای دیر پس‌دادن ودیعه جریمه نوشته شده، آن را همراه خودِ ودیعه در یک دادخواست بخواهید. روز تحویل کلید را با رسید یا صورت‌جلسه ثابت کنید، چون شمارش از همان روز است.\n'
          '• علیه شما: اگر برای دیر تخلیه‌کردن جریمه نوشته شده، هر روز ماندن بعد از پایان مدت حساب می‌شود؛ ولی موجر هم سرِ خود نمی‌تواند آن را از ودیعه بردارد و باید دادخواست بدهد [[landlord_tenant:4]].\n'
          '$none';
}

Prompt? _rentAskReply(CaseFile f) {
  // برگهٔ دادگاه آمده؛ حرفِ موجر دیگر چیزی را عوض نمی‌کند.
  if (_ordered(f)) return Prompt.none;
  if (f.eq('role', 'tenant')) {
    if (f.eq('matter', 'deposit')) {
      return const Prompt('موجر برای پس‌ندادن ودیعه چه می‌گوید؟', [
        'می‌گوید پول ندارم',
        'می‌گوید صبر کن مستأجر جدید بیاید',
        'می‌گوید خانه را خراب کرده‌ای',
        'جواب نمی‌دهد',
      ]);
    }
    if (f.eq('matter', 'evict')) {
      return const Prompt('موجر برای بلندکردن شما چه دلیلی می‌آورد؟', [
        'می‌گوید خودم می‌خواهم بنشینم',
        'می‌گوید خانه را فروخته‌ام',
        'می‌گوید اجاره را زیاد کن یا برو',
        'دلیلی نمی‌گوید',
      ]);
    }
    if (f.eq('matter', 'repair')) {
      return const Prompt('موجر دربارهٔ تعمیر چه می‌گوید؟', [
        'می‌گوید خودت درست کن',
        'می‌گوید تقصیر خودت است',
        'جواب نمی‌دهد',
      ]);
    }
    // در بالابردن اجاره و زودتر رفتن، حرفِ موجر خودِ ماجراست و پرسیده شده.
    if (f.eq('matter', 'raise') || f.eq('matter', 'leave')) return Prompt.none;
    return null;
  }
  if (f.eq('aim', 'evict')) {
    return const Prompt('مستأجر برای نرفتن چه می‌گوید؟', [
      'می‌گوید جا پیدا نکرده‌ام',
      'می‌گوید اول پول پیشم را بده',
      'می‌گوید قرارداد تمدید شده',
      'جواب نمی‌دهد',
    ]);
  }
  if (f.eq('aim', 'unpaid')) {
    return const Prompt('مستأجر برای ندادن اجاره چه می‌گوید؟', [
      'می‌گوید ندارم',
      'می‌گوید از پول پیش کم کن',
      'می‌گوید پرداخت کرده‌ام',
      'جواب نمی‌دهد',
    ]);
  }
  if (f.eq('aim', 'damage')) {
    return const Prompt('مستأجر دربارهٔ خسارت چه می‌گوید؟', [
      'می‌گوید از اول خراب بود',
      'می‌گوید از پول پیش کم کن',
      'جواب نمی‌دهد',
    ]);
  }
  return null;
}
