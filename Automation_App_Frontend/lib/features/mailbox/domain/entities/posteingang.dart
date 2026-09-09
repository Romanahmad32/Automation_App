class PosteingangEintrag {
  final String id;
  final String betreff;
  final String absender;
  final DateTime? datum;
  final bool gelesen;
  final int groesse;

  const PosteingangEintrag({
    required this.id,
    required this.betreff,
    required this.absender,
    this.datum,
    this.gelesen = false,
    this.groesse = 0,
  });

  factory PosteingangEintrag.fromJson(Map<String, dynamic> json) =>
      PosteingangEintrag(
        id: json['id'] as String,
        betreff: json['betreff'] as String,
        absender: json['absender'] as String,
        datum: DateTime.tryParse(json['datum'] as String? ?? '')?.toLocal(),
        gelesen: json['gelesen'] as bool,
        groesse: json['groesse'] as int,
      );
}

class PosteingangSeite {
  final List<PosteingangEintrag> nachrichten;
  final String? naechsteSeite;
  final int gesamt;
  const PosteingangSeite(this.nachrichten, this.naechsteSeite, this.gesamt);

  factory PosteingangSeite.fromJson(Map<String, dynamic> json) =>
      PosteingangSeite(
        (json['nachrichten'] as List)
            .map(
              (item) =>
                  PosteingangEintrag.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        json['naechsteSeite'] as String?,
        json['gesamt'] as int,
      );
}

class PosteingangInhalt {
  final String text;
  final bool gekuerzt;
  final List<String> anhaenge;
  const PosteingangInhalt(this.text, this.gekuerzt, this.anhaenge);

  factory PosteingangInhalt.fromJson(Map<String, dynamic> json) =>
      PosteingangInhalt(
        json['text'] as String,
        json['gekuerzt'] as bool,
        (json['anhaenge'] as List).cast<String>(),
      );
}
