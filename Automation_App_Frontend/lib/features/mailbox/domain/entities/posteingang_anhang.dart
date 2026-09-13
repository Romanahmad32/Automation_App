/// Ein Anhang einer Posteingangsnachricht, so wie ihn die Struktur der Mail
/// (BODYSTRUCTURE) beschreibt: Name, Größe und Medientyp stehen fest, **ohne**
/// dass auch nur ein Byte der Datei geladen wurde.
///
/// Geholt wird die Datei erst auf Zuruf über
/// `PosteingangRepository.ladeAnhang` — der Posteingang lädt nie ungefragt
/// Anhänge (§4.3).
class PosteingangAnhang {
  /// Die Adresse des Anhangs **innerhalb** der Mail (`"2"`, `"2.1"`) — der
  /// Abschnittsbezeichner der IMAP-Struktur. Weder Dateiname noch laufende
  /// Nummer: nur damit findet der Dienst den Teil beim Nachladen wieder.
  final String id;

  final String dateiname;

  /// Größe in Bytes, aus der Struktur gelesen. 0, wenn der Server sie nicht
  /// nennt.
  final int groesse;

  /// Der Medientyp, z. B. `application/pdf`. Leer, wenn unbekannt.
  final String medientyp;

  const PosteingangAnhang({
    required this.id,
    required this.dateiname,
    this.groesse = 0,
    this.medientyp = '',
  });

  factory PosteingangAnhang.fromJson(Map<String, dynamic> json) =>
      PosteingangAnhang(
        id: json['id'] as String,
        dateiname: json['dateiname'] as String? ?? 'Anhang',
        groesse: (json['groesse'] as num?)?.toInt() ?? 0,
        medientyp: json['medientyp'] as String? ?? '',
      );
}

/// Eine vom Dienst ins Zwischenlager geholte Datei — ein Anhang oder die
/// ganze Nachricht als `.eml`.
///
/// Zurück kommt ein **Pfad und keine Bytes**: Öffnen, Ablegen in der Akte und
/// Anhängen an eine ausgehende Mail arbeiten in dieser App durchweg mit
/// lokalen Pfaden. Das Zwischenlager räumt sich nach 14 Tagen selbst auf.
class PosteingangAnhangAblage {
  final String dateiname;

  /// Vollständiger Pfad im Zwischenlager des Dienstes.
  final String pfad;

  final int groesse;

  const PosteingangAnhangAblage({
    required this.dateiname,
    required this.pfad,
    this.groesse = 0,
  });

  factory PosteingangAnhangAblage.fromJson(Map<String, dynamic> json) =>
      PosteingangAnhangAblage(
        dateiname: json['dateiname'] as String? ?? '',
        pfad: json['pfad'] as String,
        groesse: (json['groesse'] as num?)?.toInt() ?? 0,
      );
}
