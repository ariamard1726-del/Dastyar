import 'package:dastyar/persian_text.dart';

class TextUtils {
  TextUtils._();

  static String normalize(String s) => PersianText.normalize(s);
  static String collapse(String s) => PersianText.collapse(s);
  static String truncate(String s, int maxRunes, {String ellipsis = ''}) =>
      PersianText.truncate(s, maxRunes, ellipsis: ellipsis);
  static String phrase(String s) => PersianText.phrase(s);
  static String toFaDigits(String s) => PersianText.toFaDigits(s);
  static String asciiDigits(String s) => PersianText.asciiDigits(s);
  static List<String> tokenizeIndex(String s) => PersianText.tokenizeIndex(s);
  static List<String> tokenize(String s) => PersianText.tokenize(s);
}
