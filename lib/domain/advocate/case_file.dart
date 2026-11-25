// دروازهٔ پروندهٔ وکیل: فقط دو `export`.
//
// `CaseFile` (وضعیت + JSON) در `case_state.dart` است و مدل‌های زبانِ موضوع در
// `case_model.dart`. این فایل همان `case_file.dart` پیشین است تا چهل مسیرِ
// `import` در `lib/` و آزمون‌ها دست‌نخورده بمانند؛ کدِ تازه این‌جا نوشته
// نمی‌شود و نگهبان (`tests/python/test_case_model_shape.py`) همین را می‌سنجد.

export 'case_model.dart';
export 'case_state.dart';
