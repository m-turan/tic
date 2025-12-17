class Player {
  final String oyuncuAdi;
  final String takim;
  final String milliTakim;
  final String fotografUrl;

  Player({
    required this.oyuncuAdi,
    required this.takim,
    required this.milliTakim,
    required this.fotografUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'oyuncu_adi': oyuncuAdi,
      'takim': takim,
      'milli_takim': milliTakim,
      'fotograf_url': fotografUrl,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      oyuncuAdi: json['oyuncu_adi'] ?? json['oyuncuAdi'] ?? '',
      takim: json['takim'] ?? '',
      milliTakim: json['milli_takim'] ?? json['milliTakim'] ?? '',
      fotografUrl: json['fotograf_url'] ?? json['fotografUrl'] ?? 'Bilinmiyor',
    );
  }

  factory Player.fromDatabase(Map<String, dynamic> map) {
    return Player(
      oyuncuAdi: map['oyuncu_adi'] as String,
      takim: map['takim'] as String,
      milliTakim: map['milli_takim'] as String,
      fotografUrl: map['fotograf_url'] as String,
    );
  }
}

