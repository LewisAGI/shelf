/// Light transcript tidy: drop spoken fillers and squeeze leftover space.
class FillerCleanup {
  static const defaultFillers = <String>[
    'um',
    'uh',
    'uhm',
    'erm',
    'er',
    'ah',
    'like',
  ];

  /// Removes standalone filler tokens (`um`, `uh`, `like`, …).
  ///
  /// `like` is treated as a filler only when it stands as its own word,
  /// so `likely` and `dislike` are left alone.
  static String clean(String input, {Iterable<String>? fillers}) {
    if (input.trim().isEmpty) {
      return '';
    }

    final tokens = (fillers ?? defaultFillers)
        .map((word) => RegExp.escape(word.trim()))
        .where((word) => word.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return _tidyPunctuation(input.trim());
    }

    final pattern = RegExp(
      r'\b(?:' + tokens.join('|') + r')\b',
      caseSensitive: false,
    );

    var text = input.replaceAll(pattern, ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _tidyPunctuation(text);
  }

  static String _tidyPunctuation(String text) {
    var result = text.replaceAllMapped(
      RegExp(r'\s+([,.;:!?])'),
      (match) => match.group(1)!,
    );
    result = result.replaceAllMapped(
      RegExp(r'([,.;:!?])\1+'),
      (match) => match.group(1)!,
    );
    if (result.isEmpty) {
      return result;
    }
    return result[0].toUpperCase() + result.substring(1);
  }
}
