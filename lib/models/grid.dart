class Grid {
  final List<String> rows; // 3 satır başlığı
  final List<String> cols; // 3 sütun başlığı
  final bool isCountryInRows; // Ülke satırlarda mı?

  Grid({
    required this.rows,
    required this.cols,
    required this.isCountryInRows,
  });

  String? getCountry() {
    // İzin verilen ülkeler listesi
    const allowedCountries = [
      'Germany', 'England', 'Turkey', 'Netherlands', 'Nigeria',
      'France', 'Portugal', 'Spain', 'Argentina', 'Brazil',
      'Arjantin', 'Brazilya'
    ];

    for (var row in rows) {
      if (allowedCountries.contains(row)) {
        return row;
      }
    }
    for (var col in cols) {
      if (allowedCountries.contains(col)) {
        return col;
      }
    }
    return null;
  }

  bool isValidCell(int row, int col) {
    final country = getCountry();
    if (country == null) return false;

    final rowItem = rows[row];
    final colItem = cols[col];

    // Ülke × Ülke geçersiz
    const allowedCountries = [
      'Germany', 'England', 'Turkey', 'Netherlands', 'Nigeria',
      'France', 'Portugal', 'Spain', 'Argentina', 'Brazil',
      'Arjantin', 'Brazilya'
    ];

    if (allowedCountries.contains(rowItem) && allowedCountries.contains(colItem)) {
      return false;
    }

    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'rows': rows,
      'cols': cols,
      'isCountryInRows': isCountryInRows,
    };
  }

  factory Grid.fromJson(Map<String, dynamic> json) {
    return Grid(
      rows: List<String>.from(json['rows'] ?? []),
      cols: List<String>.from(json['cols'] ?? []),
      isCountryInRows: json['isCountryInRows'] ?? false,
    );
  }
}

