namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// Was eine übernommene Registerzeile braucht, wenn sie aus einem gelöschten
/// Vorgang entsteht (§6.3) — bewusst schlanker als
/// <see cref="Persistence.RegisterHistorieEntity"/>: nur die Felder, die ein
/// Vorgang tatsächlich hergibt. Was das Register sonst noch führt
/// (Unfalldatum getrennt vom Sachbestand, Sachart, Sicherheit, Freitext …)
/// hat bei einem Vorgang der App kein Gegenstück — er wurde nie aus einer
/// Freitextzelle zerlegt, sondern von Anfang an in eigenen Feldern geführt.
/// </summary>
/// <param name="Jahr">Vierstelliger Jahrgang, wie <c>RegisterZeilenBau.Jahrgang</c> ihn ableitet.</param>
/// <param name="LaufendeNummer">Die laufende Nummer des Vorgangs im Jahrgang.</param>
/// <param name="NummerZusatz">
/// Immer leer: Der Zusatz ("-I") gehört zur gewachsenen Kanzleidatei, ein
/// Vorgang der App kennt ihn nicht. Bleibt trotzdem Teil des natürlichen
/// Schlüssels, gegen den geprüft wird.
/// </param>
/// <param name="Spalte1">
/// Wie der Import sie füllt: die laufende Nummer als Text, wörtlich wie
/// Spalte 2 — sonst würde die Nachprüfung einen Widerspruch melden, den es
/// nie gab.
/// </param>
/// <param name="Abteilung">Abteilungskürzel des Vorgangs, z. B. "C03" (§7.1).</param>
/// <param name="Parteien">
/// Die fertige Parteienspalte ("Mandant ./. Gegner"), bereits aus
/// <c>RegisterZeilenBau.Zeile</c> — eine zweite Ableitung wäre genau die
/// Duplizierung, die jene Klasse verhindern soll.
/// </param>
/// <param name="Sachbestand">
/// Die fertige Sachbestandsspalte samt Datum ("Sachverhalt v. 28.12.2025"),
/// ebenfalls aus <c>RegisterZeilenBau.Zeile</c>.
/// </param>
/// <param name="Rechtsgebiet">Anzeigename des Sachgebiets, z. B. "Verkehrsrecht".</param>
public sealed record RegisterHistorieUebernahme(
    int Jahr,
    int LaufendeNummer,
    string NummerZusatz,
    string Spalte1,
    string Abteilung,
    string Parteien,
    string Sachbestand,
    string Rechtsgebiet);
