import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';

class PosteingangState {
  final PosteingangSeite? seite;
  final PosteingangEintrag? auswahl;
  final PosteingangInhalt? inhalt;
  final bool laedt;
  final bool inhaltLaedt;
  final bool neueNachrichten;
  final int seitennummer;
  final String? fehler;
  final String? inhaltFehler;

  const PosteingangState({
    this.seite,
    this.auswahl,
    this.inhalt,
    this.laedt = false,
    this.inhaltLaedt = false,
    this.neueNachrichten = false,
    this.seitennummer = 1,
    this.fehler,
    this.inhaltFehler,
  });

  PosteingangState copyWith({
    PosteingangSeite? seite,
    PosteingangEintrag? auswahl,
    PosteingangInhalt? inhalt,
    bool? laedt,
    bool? inhaltLaedt,
    bool? neueNachrichten,
    int? seitennummer,
    String? fehler,
    String? inhaltFehler,
    bool leereAuswahl = false,
    bool leereFehler = false,
    bool leereInhalt = false,
  }) => PosteingangState(
    seite: seite ?? this.seite,
    auswahl: leereAuswahl ? null : auswahl ?? this.auswahl,
    inhalt: leereAuswahl || leereInhalt ? null : inhalt ?? this.inhalt,
    laedt: laedt ?? this.laedt,
    inhaltLaedt: inhaltLaedt ?? this.inhaltLaedt,
    neueNachrichten: neueNachrichten ?? this.neueNachrichten,
    seitennummer: seitennummer ?? this.seitennummer,
    fehler: leereFehler ? null : fehler ?? this.fehler,
    inhaltFehler: leereAuswahl || leereInhalt
        ? null
        : inhaltFehler ?? this.inhaltFehler,
  );
}
