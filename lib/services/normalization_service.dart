class NormalizationService {
  static final NormalizationService _instance = NormalizationService._internal();
  factory NormalizationService() => _instance;
  NormalizationService._internal();

  // Ülke eşleştirmeleri
  static const Map<String, String> _countryMappings = {
    'Türkiye': 'Turkey',
    'Arjantin': 'Argentina',
    'Brazilya': 'Brazil',
  };

  String normalize(String text) {
    if (text.isEmpty) return '';

    // 1. Boşluk normalize
    text = text.trim().replaceAll(RegExp(r'\s+'), ' ');

    // 2. Ülke mapping (diacritics temizlenmeden önce!)
    if (_countryMappings.containsKey(text)) {
      text = _countryMappings[text]!;
    }

    // 3. Diacritics temizle (büyük ve küçük harfler)
    text = text
        .replaceAll('á', 'a').replaceAll('Á', 'a')
        .replaceAll('é', 'e').replaceAll('É', 'e')
        .replaceAll('í', 'i').replaceAll('Í', 'i')
        .replaceAll('ó', 'o').replaceAll('Ó', 'o')
        .replaceAll('ú', 'u').replaceAll('Ú', 'u')
        .replaceAll('ñ', 'n').replaceAll('Ñ', 'n')
        .replaceAll('ç', 'c').replaceAll('Ç', 'c')
        .replaceAll('ş', 's').replaceAll('Ş', 's')
        .replaceAll('ğ', 'g').replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u').replaceAll('Ü', 'u')
        .replaceAll('ö', 'o').replaceAll('Ö', 'o')
        .replaceAll('ı', 'i').replaceAll('I', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('à', 'a').replaceAll('À', 'a')
        .replaceAll('è', 'e').replaceAll('È', 'e')
        .replaceAll('ì', 'i').replaceAll('Ì', 'i')
        .replaceAll('ò', 'o').replaceAll('Ò', 'o')
        .replaceAll('ù', 'u').replaceAll('Ù', 'u')
        .replaceAll('â', 'a').replaceAll('Â', 'a')
        .replaceAll('ê', 'e').replaceAll('Ê', 'e')
        .replaceAll('î', 'i').replaceAll('Î', 'i')
        .replaceAll('ô', 'o').replaceAll('Ô', 'o')
        .replaceAll('û', 'u').replaceAll('Û', 'u');

    // 4. Küçük harfe çevir
    text = text.toLowerCase();

    // 5. Boşluk normalize (tekrar)
    text = text.trim().replaceAll(RegExp(r'\s+'), ' ');

    return text;
  }

  String slugify(String text) {
    return normalize(text).replaceAll(' ', '_');
  }

  bool matches(String text1, String text2) {
    return normalize(text1) == normalize(text2);
  }

  bool contains(String text, String query) {
    final normalizedText = normalize(text);
    final normalizedQuery = normalize(query);
    return normalizedText.contains(normalizedQuery);
  }

  double similarity(String text1, String text2) {
    final s1 = normalize(text1);
    final s2 = normalize(text2);

    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // Levenshtein distance
    final distance = _levenshteinDistance(s1, s2);
    final maxLen = s1.length > s2.length ? s1.length : s2.length;
    return 1.0 - (distance / maxLen);
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }
}

