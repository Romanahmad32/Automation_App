/// Warum die Anrede einer Mail **neutral** ausfällt, obwohl der Anwalt das
/// nicht so gewählt hat (§4.7, ergänzt am 02.09.2026).
///
/// **Der Mangel, der diese Datei trägt:** Über Mails stand „Sehr geehrte Damen
/// und Herren", ohne dass jemand diese Anrede angelegt hatte, und ein Klick
/// auf die Anredeart änderte daran nichts. Beides war für sich richtig — die
/// neutrale Zeile hat kein Geschlecht, das sich beugen liesse — aber der Grund
/// war **nicht zu sehen**. Die App kannte ihn und behielt ihn für sich; der
/// Anwalt sah eine Anrede, die er nicht erklärt bekam und nicht loswurde.
///
/// **Die Reihenfolge ist Absicht: erst der Empfängerkreis, dann die
/// Datenlücken.** Geht die Mail an die Versicherung, ist die neutrale Anrede
/// richtig, und ein Hinweis auf den fehlenden Nachnamen des Mandanten wäre
/// Lärm an einer Mail, die stimmt. Umgekehrt ist eine Lücke im Register eine
/// Aufgabe — deshalb sagt [istLuecke], welcher Art der Grund ist.
///
/// Nur der **nicht gewählte** Grund steht hier: Hat der Anwalt „neutral
/// anreden" selbst angehakt, erklärt das Häkchen sich schon.
enum AnredeNeutralGrund {
  /// Neben dem Mandanten steht noch jemand im Feld „An" oder in Kopie. Eine
  /// Mail an zwei Empfänger kann nur eine Anrede haben.
  mitleser(
    'Neutral, weil neben dem Mandanten noch jemand im Feld „An" oder in Kopie '
    'steht — eine Mail kann nur eine Anrede haben.',
  ),

  /// Im Feld „An" steht noch niemand. Kein Mangel, sondern der Anfang: Sobald
  /// die Adresse des Mandanten dort steht, wird die Anrede namentlich.
  keinEmpfaenger('Neutral, weil im Feld „An" noch niemand steht.'),

  /// Zum Vorgang steht kein Mandant im Register — dann ist niemand da, den man
  /// namentlich anreden könnte.
  keinMandant(
    'Neutral, weil zu diesem Vorgang kein Mandant im Register steht.',
    istLuecke: true,
  ),

  /// Der Mandant ist bekannt, hat aber keine E-Mail-Adresse. Die App erkennt
  /// ihn im Feld „An" nur an der Adresse; eine von Hand eingetippte gehört für
  /// sie zu einem Fremden.
  keineAdresse(
    'Neutral, weil am Mandanten keine E-Mail-Adresse hinterlegt ist — im Feld '
    '„An" erkennt die App ihn nur daran.',
    istLuecke: true,
  ),

  /// Ohne Nachnamen fehlt die Angabe, die eine namentliche Anrede erst trägt.
  keinNachname(
    'Neutral, weil am Mandanten kein Nachname hinterlegt ist.',
    istLuecke: true,
  ),

  /// Weder im Register noch für diese Mail ist eine Anredeart angegeben. Es
  /// wird nicht geraten (§1.3) — aber ein Klick auf „Herr" oder „Frau" oben
  /// behebt es sofort.
  keineAnredeart(
    'Neutral, weil keine Anredeart vorliegt — mit „Herr" oder „Frau" oben wird '
    'die Anrede namentlich.',
    istLuecke: true,
  );

  /// Der Satz, der unter der Chipreihe steht. Er beginnt mit „Neutral, weil",
  /// damit die Auskunft auch beim Überfliegen an der Zeile klebt, die sie
  /// erklärt.
  final String hinweis;

  /// Ob der Grund eine **Lücke** ist (im Register nachzupflegen) und nicht
  /// bloss die Folge des Empfängerkreises. Nur die Lücke ist eine Aufgabe.
  final bool istLuecke;

  const AnredeNeutralGrund(this.hinweis, {this.istLuecke = false});
}
