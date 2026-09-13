// Der Inhalt einer geöffneten Nachricht liegt seit #134 in einer eigenen Datei
// (Dateilänge). Er wird hier weiter mitgereicht, damit jede Stelle, die „den
// Posteingang" importiert, unverändert an `PosteingangInhalt` kommt.
export 'package:automation_app/features/mailbox/domain/entities/posteingang_inhalt.dart';

/// Eine Zeile des Posteingangs — reine Kopfdaten. Der Mailtext wird hier nie
/// mitgeladen (§4.3); was die Liste über Anhänge weiß, stammt allein aus der
/// Struktur der Mail und kostet keinen Inhaltsabruf.
class PosteingangEintrag {
  /// Die Blätterkennung des Dienstes (Base64Url über Konto, UIDVALIDITY und
  /// UID) — **kein** dauerhafter Bezeichner: nach einem Kontowechsel oder
  /// einem Neuaufbau des Ordners zeigt sie ins Leere.
  final String id;

  final String betreff;

  /// Der Absender als eine Zeichenkette, wie der Server ihn nennt
  /// (`"Max Muster" <max@x.de>`). Bleibt der Rückfall, wenn [absenderName]
  /// und [absenderAdresse] fehlen.
  final String absender;

  /// Der Klarname des Absenders, getrennt ausgelesen — null, wenn die Mail
  /// nur eine Adresse trägt.
  final String? absenderName;

  /// Die reine Adresse des Absenders. Sie trägt die Vermutungsregel des
  /// `VorgangsbezugErkenner` (Absender ist Mandant oder Versicherer).
  final String? absenderAdresse;

  /// Empfänger und Kopie, je Eintrag `Name <adresse>` bzw. nur die Adresse.
  final List<String> an;
  final List<String> cc;

  /// Die RFC-Message-Id ohne spitze Klammern. Sie ist die Brücke zu einer
  /// bereits erfassten Zentralruf-Antwort (`ReceivedReply.mailSchluessel`) —
  /// die [id] taugt dafür nicht, weil sie ans Konto gebunden ist.
  final String? messageId;

  final DateTime? datum;
  final bool gelesen;
  final int groesse;

  /// Ob die Mail Anhänge hat und wie viele — für die Büroklammer in der Zeile.
  final bool hatAnhaenge;
  final int anzahlAnhaenge;

  const PosteingangEintrag({
    required this.id,
    required this.betreff,
    required this.absender,
    this.absenderName,
    this.absenderAdresse,
    this.an = const [],
    this.cc = const [],
    this.messageId,
    this.datum,
    this.gelesen = false,
    this.groesse = 0,
    this.hatAnhaenge = false,
    this.anzahlAnhaenge = 0,
  });

  factory PosteingangEintrag.fromJson(Map<String, dynamic> json) =>
      PosteingangEintrag(
        id: json['id'] as String,
        betreff: json['betreff'] as String,
        absender: json['absender'] as String,
        absenderName: json['absenderName'] as String?,
        absenderAdresse: json['absenderAdresse'] as String?,
        an: List<String>.from(json['an'] as List? ?? const []),
        cc: List<String>.from(json['cc'] as List? ?? const []),
        messageId: json['messageId'] as String?,
        datum: DateTime.tryParse(json['datum'] as String? ?? '')?.toLocal(),
        gelesen: json['gelesen'] as bool? ?? false,
        groesse: (json['groesse'] as num?)?.toInt() ?? 0,
        hatAnhaenge: json['hatAnhaenge'] as bool? ?? false,
        anzahlAnhaenge: (json['anzahlAnhaenge'] as num?)?.toInt() ?? 0,
      );
}

/// Eine geladene Seite des Posteingangs samt Blätterkennung der nächsten Seite
/// und der Gesamtzahl im Ordner.
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
