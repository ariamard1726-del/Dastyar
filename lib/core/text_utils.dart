import 'package:dastyar/persian_text.dart';

class TextUtils {
  static String normalize(String s) => PersianText.normalize(s);
  static String collapse(String s) => PersianText.collapse(s);
  static List<String> tokenizeIndex(String s) => PersianText.tokenizeIndex(s);
  static List<String> tokenize(String s) => PersianText.tokenize(s);
}
