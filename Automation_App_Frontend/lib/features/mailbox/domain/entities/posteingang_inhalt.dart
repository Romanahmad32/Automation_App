import 'package:automation_app/features/mailbox/domain/entities/posteingang_anhang.dart';

/// Der geöffnete Inhalt einer Posteingangsnachricht — erst beim Anklicken
/// geladen, nie zusammen mit der Liste.
///
/// Der Dienst liefert beide Fassungen getrennt: [text] als Nur-Text (aus HTML
/// gewandelt, wenn es die Mail nur formatiert gibt) und [html] als gefilterte
/// Anzeigefassung ohne aktive Inhalte und ohne nachladende Verweise. Welche
/// gezeigt wird, entscheidet der Anwalt im Umschalter „Formatiert | Text".
///
/// Steht in einer eigenen Datei neben `posteingang.dart`, weil beide Seiten
/// mit dem erweiterten Vertrag (§5.1) sonst zusammen die Dateilänge sprengen.
class PosteingangInhalt {
  final String text;

  /// True, wenn der Textteil über der Grenze des Dienstes lag und deshalb
  /// **nicht** geholt wurde — [text] trägt dann nur den Hinweis darauf.
  final bool gekuerzt;

  /// Die gefilterte HTML-Fassung, oder null, wenn die Mail keine hat.
  final String? html;

  /// True, wenn der HTML-Teil über der Grenze lag und übersprungen wurde.
  final bool htmlGekuerzt;

  /// True, wenn der Dienst mindestens einen nachladenden Verweis im HTML
  /// blockiert hat (`PosteingangHtmlFilter.FuerAnzeige`, Backend) — ein
  /// eigenes Feld statt einer Textsuche im gelieferten HTML, damit die
  /// Anzeigeschicht das Merkmal (`data-blockiert`) nicht kennen muss.
  final bool bilderBlockiert;

  /// Kopfdaten der Mail. Sie stehen zwar schon im Listeneintrag, kommen aber
  /// beim Öffnen noch einmal mit: Das Detail darf sich auf den geladenen
  /// Inhalt stützen und nicht auf die Zeile, aus der es aufgerufen wurde.
  final String? absenderName;
  final String? absenderAdresse;
  final List<String> an;
  final List<String> cc;
  final DateTime? datum;

  /// Die RFC-Message-Id ohne spitze Klammern — die Brücke zu einer bereits
  /// erfassten Zentralruf-Antwort (`ReceivedReply.mailSchluessel`).
  final String? messageId;

  /// Die Anhänge mit Kennung, Größe und Medientyp — beschrieben, nicht
  /// geladen.
  final List<PosteingangAnhang> anhaenge;

  const PosteingangInhalt({
    required this.text,
    this.gekuerzt = false,
    this.html,
    this.htmlGekuerzt = false,
    this.bilderBlockiert = false,
    this.absenderName,
    this.absenderAdresse,
    this.an = const [],
    this.cc = const [],
    this.datum,
    this.messageId,
    this.anhaenge = const [],
  });

  /// Ob eine formatierte Fassung überhaupt vorliegt — die Frage des
  /// Ansichtsumschalters.
  bool get hatHtml => (html ?? '').trim().isNotEmpty;

  factory PosteingangInhalt.fromJson(Map<String, dynamic> json) =>
      PosteingangInhalt(
        text: json['text'] as String? ?? '',
        gekuerzt: json['gekuerzt'] as bool? ?? false,
        html: json['html'] as String?,
        htmlGekuerzt: json['htmlGekuerzt'] as bool? ?? false,
        bilderBlockiert: json['bilderBlockiert'] as bool? ?? false,
        absenderName: json['absenderName'] as String?,
        absenderAdresse: json['absenderAdresse'] as String?,
        an: List<String>.from(json['an'] as List? ?? const []),
        cc: List<String>.from(json['cc'] as List? ?? const []),
        datum: DateTime.tryParse(json['datum'] as String? ?? '')?.toLocal(),
        messageId: json['messageId'] as String?,
        anhaenge: (json['anhaenge'] as List? ?? const [])
            .map(
              (item) =>
                  PosteingangAnhang.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}
