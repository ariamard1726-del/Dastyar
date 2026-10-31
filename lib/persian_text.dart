class PersianText {
  static String normalize(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll(RegExp(r'[\u064A]'), '\u06CC')
        .replaceAll(RegExp(r'[\u0643]'), '\u06A9')
        .replaceAllMapped(
            RegExp(r'[\u0660-\u0669]'),
            (m) => String.fromCharCode(
                m.group(0)!.codeUnitAt(0) - 0x0660 + 0x30))
        .replaceAllMapped(
            RegExp(r'[\u06F0-\u06F9]'),
            (m) => String.fromCharCode(
                m.group(0)!.codeUnitAt(0) - 0x06F0 + 0x30))
        .replaceAll(RegExp(r'\u200C+'), '\u200C')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
  }

  static String phrase(String text) {
    return normalize(text)
        .replaceAll(RegExp(r'[\p{P}]', unicode: true), '')
        .replaceAll('\u200C', '')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
  }

  static String collapse(String text) {
    return normalize(text).replaceAll(RegExp(r'[\s\u200C]'), '');
  }

  static List<String> tokenizeIndex(String text) {
    final normalized = normalize(text);
    final tokens = normalized.split(RegExp(r'[\s\u200C\p{P}]+', unicode: true));
    return tokens.where((t) => t.isNotEmpty && t != 'ای').toList();
  }

  static List<String> tokenize(String text) {
    return normalize(text).split(RegExp(r'[\s\u200C]+'));
  }

  static String stemIndex(String word) {
    return word.replaceAll(RegExp(r'[ای]$'), '');
  }

  static String stemQuery(String word) {
    return word.replaceAll(RegExp(r'[ایها]$'), '');
  }
}
