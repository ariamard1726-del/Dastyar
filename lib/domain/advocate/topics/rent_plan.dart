part of 'rent.dart';

// نقشهٔ راه: طرحِ دعوا، مدرک، شانس، مهلت و جمع‌بندی.

String _rentPlan(CaseFile f) {
  final sum = _rentSum(f);
  if (f.eq('role', 'landlord')) {
    if (f.eq('aim', 'unpaid')) {
      return rentText('plan0') + moneyForum(sum);
    }
    if (f.eq('aim', 'damage')) {
      return rentText('plan1') + moneyForum(sum);
    }
    if (f.eq('aim', 'breach')) {
      return rentText('plan2');
    }
    if (f.no('ended')) {
      return rentText('plan3');
    }
    return rentText('plan4');
  }
  if (f.eq('matter', 'raise')) {
    return rentText('plan5');
  }
  if (_ordered(f)) {
    return rentText('plan6');
  }
  if (f.eq('matter', 'evict')) {
    return rentText('plan7');
  }
  if (f.eq('matter', 'deliver')) {
    return rentText('plan8') + _rentPeace();
  }
  if (f.eq('matter', 'repair')) {
    return rentText('plan9');
  }
  if (f.eq('matter', 'leave')) {
    return rentText('plan10');
  }
  if (f.no('vacated')) {
    return rentText('plan11');
  }
  return rentText('plan12') + moneyForum(sum);
}

String _rentEvidence(CaseFile f) {
  if (f.eq('role', 'landlord')) {
    return rentText('plan30');
  }
  if (!_rentDeposit(f)) {
    return rentText('plan31');
  }
  final sb = StringBuffer(rentText('plan33'));
  if (f.no('contract')) {
    sb.write(rentText('plan34'));
  }
  return rentText('plan32');
}

String _rentChance(CaseFile f) {
  final lead = rentText('planLead');
  if (f.eq('role', 'landlord')) {
    if (f.eq('aim', 'unpaid')) {
      return lead + rentText('plan19');
    }
    if (f.eq('aim', 'damage')) {
      return lead + rentText('plan20');
    }
    if (f.eq('aim', 'breach')) {
      return lead + rentText('plan21');
    }
    return lead + rentText('plan22');
  }
  if (f.eq('matter', 'raise')) {
    return lead + rentText('plan23');
  }
  if (_ordered(f)) {
    return lead + rentText('plan24');
  }
  if (f.eq('matter', 'evict')) {
    return lead + rentText('plan25');
  }
  if (f.eq('matter', 'deliver')) {
    return lead + rentText('plan26');
  }
  if (f.eq('matter', 'repair')) {
    return lead + rentText('plan27');
  }
  if (f.eq('matter', 'leave')) {
    return lead + rentText('plan28');
  }
  final plus = <String>[];
  final minus = <String>[];
  if (f.yes('vacated')) {
    plus.add('ملک را تحویل داده‌اید و او دیگر دلیلی برای نگه‌داشتن پول ندارد');
  }
  if (f.yes('ended')) plus.add('مدت قرارداد تمام شده است');
  if (f.yes('contract')) plus.add('قرارداد کتبی دارید');
  if (f.no('contract')) {
    minus.add(
        'قرارداد کتبی ندارید و باید پرداخت ودیعه را با رسید، پیام یا شاهد ثابت کنید');
  }
  if (f.no('ended')) minus.add('مدت قرارداد هنوز تمام نشده');
  if (f.covered.contains('damage')) {
    minus.add(
        'او ادعای خسارت دارد که اگر دادخواست بدهد، ممکن است بخشی از پول تا روشن‌شدن آن ادعا نگه داشته شود');
  }
  final sb = StringBuffer(
      'قول قطعی نمی‌دهم (هیچ وکیل درستی نمی‌دهد)، ولی ارزیابی من این است: دعوای استرداد ودیعه از محکم‌ترین دعواهاست، چون قانون صریح است [[landlord_tenant:4]].');
  if (plus.isNotEmpty) sb.write('\nنقاط قوت شما: ${plus.join('؛ ')}.');
  if (minus.isNotEmpty) sb.write('\nنقطهٔ ضعف: ${minus.join('؛ ')}.');
  if (plus.isEmpty && minus.isEmpty) {
    sb.write(
        '\nاگر پرداخت ودیعه و تخلیه را بتوانید نشان دهید، احتمال موفقیت بالاست.');
  }
  return sb.toString();
}

String _rentWhere(CaseFile f) {
  if (f.eq('role', 'landlord')) {
    if (f.eq('aim', 'unpaid') || f.eq('aim', 'damage')) {
      return moneyForum(_rentSum(f));
    }
    return 'درخواست تخلیه را از طریق دفتر خدمات الکترونیک قضایی ثبت می‌کنید و مرجع رسیدگی «دادگاه صلحِ» محل ملک است [[dispute_councils:12]].';
  }
  if (_shop(f) && f.covered.contains('goodwill')) {
    return 'دعوای سرقفلی و حق کسب و پیشه از صلاحیت دادگاه صلح بیرون است و در «دادگاه عمومی حقوقیِ» محل ملک رسیدگی می‌شود [[dispute_councils:12]]؛ ثبتش از طریق دفتر خدمات الکترونیک قضایی است.';
  }
  return _rentDeposit(f) ? moneyForum(f.n('amount')) : _rentPeace();
}

String _rentDeadline(CaseFile f) {
  if (_ordered(f)) {
    return rentText('plan13');
  }
  if (f.eq('role', 'landlord')) {
    return rentText('plan14');
  }
  return rentText('plan15');
}

String _rentRefuse(CaseFile f) {
  if (f.eq('role', 'landlord')) {
    if (f.eq('aim', 'unpaid') || f.eq('aim', 'damage')) {
      return rentText('plan16');
    }
    return rentText('plan17');
  }
  if (!_rentDeposit(f)) {
    return rentText('plan35_a') + _rentPeace() + rentText('plan35_b');
  }
  return rentText('plan18');
}

// ============================================================ برداشت وکیل

List<String> rentRecap(CaseFile f) {
  final tenant = f.eq('role', 'tenant');
  final landlord = f.eq('role', 'landlord');
  final sum = _rentSum(f);
  return [
    if (landlord) 'موجر (صاحب ملک) هستید',
    if (tenant) 'مستأجر هستید',
    if (_shop(f)) 'ملک تجاری است',
    if (_matter(f, 'deposit')) 'موجر پول پیش را پس نمی‌دهد',
    if (_matter(f, 'raise')) 'موجر می‌خواهد اجاره را بالا ببرد',
    if (_matter(f, 'evict')) 'موجر می‌خواهد شما را از خانه بیرون کند',
    if (_matter(f, 'order')) 'برگهٔ رسمی تخلیه به دستتان رسیده',
    if (_matter(f, 'repair')) 'خانه خرابی دارد و موجر تعمیرش نمی‌کند',
    if (_matter(f, 'leave')) 'می‌خواهید پیش از پایان مدت بلند شوید',
    if (_matter(f, 'deliver')) 'موجر ملک را تحویلتان نمی‌دهد',
    if (_matter(f, 'evict') && f.yes('official')) 'برگهٔ رسمی تخلیه هم آمده',
    if (_matter(f, 'evict') && f.no('official'))
      'هنوز برگهٔ رسمی تخلیه نیامده',
    if (_aim(f, 'evict')) 'مستأجر ملک را تخلیه نمی‌کند',
    if (_aim(f, 'evict') && f.yes('owes')) 'اجاره را هم نمی‌پردازد',
    if (_aim(f, 'unpaid')) 'مستأجر اجاره را نمی‌پردازد',
    if (_aim(f, 'damage')) 'مستأجر به ملک خسارت زده',
    if (_aim(f, 'breach')) 'مستأجر از شرط‌های قرارداد تخلف کرده',
    if (f.yes('ended')) 'مدت اجاره تمام شده',
    if (f.no('ended')) 'مدت اجاره هنوز تمام نشده',
    if (!landlord && f.yes('vacated')) 'ملک تخلیه و تحویل شده',
    if (!landlord && f.no('vacated')) 'ملک هنوز تخلیه نشده',
    if (!landlord && f.n('amount') != null)
      'ودیعه ${Sense.toman(f.n('amount')!)} است',
    if (landlord && sum != null) 'مبلغ مورد بحث ${Sense.toman(sum)} است',
    if (f.yes('contract')) 'اجاره‌نامهٔ کتبی دارید',
    if (f.no('contract')) 'اجاره‌نامهٔ کتبی ندارید',
    if (landlord && f.yes('witness')) 'اجاره‌نامه شاهد یا کد رهگیری دارد',
    if (landlord && f.no('witness')) 'اجاره‌نامه شاهد ندارد',
    if (landlord && f.yes('clause')) 'در اجاره‌نامه حق فسخ دارید',
    if (landlord && f.no('clause')) 'در اجاره‌نامه حق فسخ ندارید',
    if (landlord && f.has('aim') && f.yes('proof')) 'از تخلف یا خرابی مدرک دارید',
    if (landlord && f.has('aim') && f.no('proof'))
      'از تخلف یا خرابی مدرکی ندارید',
    if (_matter(f, 'repair') && f.yes('told'))
      'خرابی را کتبی به موجر خبر داده‌اید',
    if (_matter(f, 'repair') && f.no('told'))
      'هنوز خرابی را کتبی به موجر خبر نداده‌اید',
    if (_matter(f, 'leave') && f.yes('consent')) 'موجر با زودتر رفتن موافق است',
    if (_matter(f, 'leave') && f.no('consent'))
      'موجر با زودتر رفتن موافق نیست',
  ];
}

// ================================================================ ادعاها
