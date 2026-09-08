namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// Was von einem Jahrgang übernommen ist (§6.2).
///
/// <c>Luecken</c> und <c>MitBefund</c> stehen hier, weil der Stand die einzige
/// Stelle ist, an der der Anwalt sie noch sieht: Nach dem Übernehmen ist der
/// Bericht des Imports weg, die offene Lücke bleibt.
/// </summary>
public sealed record JahrgangStand(
    int Jahrgang,
    int Zeilen,
    int HoechsteNummer,
    IReadOnlyList<int> Luecken,
    int MitBefund,
    DateTime ZuletztImportiertAm);

/// <summary>
/// Der Stand der Übernahme über alle Jahrgänge — die eine Stelle, an der steht,
/// was noch fehlt. Der Anwalt soll sehen, dass 2021 fehlt, <em>bevor</em> er
/// 2022 einliest.
///
/// <see cref="FehlendeJahrgaenge"/> sind die Löcher <em>zwischen</em> dem
/// kleinsten und dem größten übernommenen Jahrgang. Bewusst kein festes
/// Startjahr: Wie weit das Register der Kanzlei zurückreicht, sagt der Bestand
/// und nicht eine Zahl im Code — und ein Jahrgang vor dem ersten übernommenen
/// fehlt nicht, er ist nur noch nicht an der Reihe.
/// </summary>
public sealed record RegisterHistorieStand(
    IReadOnlyList<JahrgangStand> Jahrgaenge,
    IReadOnlyList<int> FehlendeJahrgaenge);

/// <summary>
/// Die Felder, die der Anwalt an einer historischen Zeile ändern darf.
///
/// Bewusst nicht Jahr und laufende Nummer: Die beiden sind der natürliche
/// Schlüssel des Registers. Wären sie änderbar, könnte eine Berichtigung eine
/// zweite Zeile überschreiben oder eine Lücke aufreißen, die vorher keine war.
/// </summary>
public sealed record RegisterHistorieAenderung(
    string Abteilung,
    string Sachart,
    string Mandant,
    string Gegner,
    string Sachbestand,
    string Unfalldatum,
    string Rechtsgebiet);
