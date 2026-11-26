import 'package:flutter/material.dart';

import 'package:dastyar/ui/chat_models.dart';
import 'package:dastyar/ui/widgets/feedback_bar.dart';
import 'package:dastyar/domain/input_suggestions.dart';
import 'package:dastyar/domain/templates.dart';

part 'user_message_bubble.dart';
part 'bot_message_view.dart';
part 'draft_document_card.dart';
part 'chat_empty_state.dart';
part 'suggestion_bar.dart';
part 'reveal_text.dart';
part 'typing_dots.dart';
part 'chat_input_bar.dart';

// ویجت‌های گفتگو، هر کدام در بخشِ خودش.
//
// این فایل فقط «سرِ کتابخانه» است: واردات‌ها و فهرستِ بخش‌ها. تا وقتی همهٔ
// ویجت‌ها یک فایلِ ۸۱۴ خطی بودند، هر تغییرِ کوچک در یک حباب، کلِ فایل را در
// مرورِ کد جابه‌جا می‌کرد. با `part` هر ویجت فایلِ خودش را دارد و همان
// کتابخانه (و همان API) سرِ جایش است؛ هیچ وارداتی در جای دیگری عوض نمی‌شود.
