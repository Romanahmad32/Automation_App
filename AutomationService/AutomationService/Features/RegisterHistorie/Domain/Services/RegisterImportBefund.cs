namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// Das Ergebnis für eine einzelne Zeile der Importdatei.
///
/// <c>Zeile</c> ist die 1-basierte Position <em>innerhalb ihres Jahrgangs</em>,
/// nicht über die ganze Datei: Geprüft und freigegeben wird jahrgangsweise, und
/// die Oberfläche spricht eine Zeile deshalb als (<c>Jahrgang</c>,
/// <c>Zeile</c>) an. Zusammen sind die beiden eindeutig.
///
/// Zwei Listen nebeneinander, und sie stammen von zwei Absendern:
/// <c>Hinweise</c> hat der Erzeuger geschrieben („Sachbestand ohne Datum"),
/// <c>Befunde</c> hat die App gerechnet („Spalte 1 widerspricht der Nummer").
/// Zusammengeworfen wüsste niemand mehr, welcher Satz eine Beobachtung und
/// welcher eine Prüfung ist.
/// </summary>
public sealed record RegisterZeilenBefund(
    int Zeile,
    int Jahrgang,
    int LaufendeNummer,
    string Aktenzeichen,
    string Anzeigetext,
    string Rechtsgebiet,
    string Sicherheit,
    string Art,
    IReadOnlyList<string> Befunde,
    IReadOnlyList<string> Hinweise)
{
    /// <summary>
    /// Ob diese Zeile dem Anwalt vorgelegt werden muss. Die Vorschau filtert
    /// darauf: Bei 200 Zeilen je Jahrgang ist „alles zeigen" dasselbe wie
    /// „nichts prüfen".
    /// </summary>
    public bool ZuPruefen => Sicherheit != RegisterSicherheiten.Hoch || Befunde.Count > 0;
}

/// <summary>
/// Der Befund über einen Jahrgang — die Einheit, in der der Anwalt prüft und
/// freigibt.
///
/// <c>Luecken</c> ist die eine Fehlerklasse, die kein Erzeuger an sich selbst
/// bemerkt: Bricht er nach Nr. 46 ab, sieht die Datei vollständig aus. Gemessen
/// wird gegen Datei <b>und</b> Bestand zusammen, sonst meldete das Einlesen
/// einer Nachlieferung lauter Lücken, die längst gefüllt sind.
/// </summary>
public sealed record JahrgangBefund(
    int Jahrgang,
    int Zeilen,
    IReadOnlyList<int> Luecken,
    IReadOnlyList<int> Doppelte,
    int Neu,
    int Unveraendert,
    int Abgelehnt,
    int ZuPruefen,
    int Abweichungen,
    IReadOnlyList<RegisterZeilenBefund> Eintraege);

/// <summary>
/// Der Bericht über einen Import — bei der Vorschau und beim Übernehmen
/// derselbe Typ mit demselben Inhalt, nur <see cref="Angewendet"/>
/// unterscheidet sie.
/// </summary>
public sealed record RegisterImportBefund(
    IReadOnlyList<JahrgangBefund> Jahrgaenge,
    bool Angewendet);
