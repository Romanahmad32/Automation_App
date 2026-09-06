using AutomationService.Features.Backup.Domain.Services;

namespace AutomationService.Features.Backup.Presentation.Dtos;

/// <summary>
/// Auskunft für den Start der App (§7.2, #39): Gibt es einen neueren Stand am
/// anderen Arbeitsplatz, und wie ist die letzte automatische Sicherung
/// ausgegangen? Beides in einer Abfrage, weil beides an derselben Stelle
/// gezeigt wird — bevor die Oberfläche aufgeht.
/// </summary>
/// <param name="Angebot">Der übernehmbare fremde Stand, sonst <c>null</c>.</param>
/// <param name="EigenerStandGesichertAm">
/// Wann dieser Rechner zuletzt gesichert hat, damit der Bildschirm zeigen kann,
/// was eine Übernahme ersetzen würde. <c>null</c>: noch nie.
/// </param>
/// <param name="LetzteSicherung">Ausgang des letzten automatischen Laufs.</param>
/// <param name="AblageOrdner">Der eingestellte Ordner; leer heißt abgeschaltet.</param>
/// <param name="EigeneArchive">
/// Wie viele Archive dieses Rechners im Ablageordner liegen (#112) — die
/// Auskunft, die aus der gestaffelten Aufbewahrung erst eine überprüfbare macht.
/// </param>
/// <param name="AeltestesArchiv">
/// Wie weit die eigene Historie zurückreicht; <c>null</c>, wenn nichts liegt.
/// </param>
public sealed record UebergabeStandDto(
    UebergabeAngebotDto? Angebot,
    DateTime? EigenerStandGesichertAm,
    LetzteSicherungDto? LetzteSicherung,
    string AblageOrdner,
    int EigeneArchive,
    DateTime? AeltestesArchiv)
{
    public static UebergabeStandDto From(UebergabeStand stand) => new(
        UebergabeAngebotDto.From(stand.Angebot),
        stand.EigenerStand?.GesichertAm,
        LetzteSicherungDto.From(stand.LetzterLauf),
        stand.AblageOrdner,
        stand.Bestand.Anzahl,
        stand.Bestand.Aeltestes);
}

/// <summary>Der Arbeitsplatz, dessen Stand zur Übernahme bereitliegt.</summary>
/// <param name="Rechnername">Steht so im Satz auf dem Bildschirm.</param>
/// <param name="ZuletztGearbeitet">„Zuletzt heute 14:12 auf BUERO-PC gearbeitet."</param>
/// <param name="GesichertAm">Der Stand, der übernommen würde.</param>
/// <param name="Sicherung">Dateiname des Archivs.</param>
/// <param name="Programmfassung">Fassung, die es geschrieben hat.</param>
public sealed record UebergabeAngebotDto(
    string Rechnername,
    DateTime ZuletztGearbeitet,
    DateTime GesichertAm,
    string Sicherung,
    string Programmfassung)
{
    public static UebergabeAngebotDto? From(ArbeitsplatzEintrag? eintrag) =>
        eintrag?.GesichertAm is null
            ? null
            : new UebergabeAngebotDto(
                eintrag.Rechnername,
                eintrag.ZuletztGearbeitet,
                eintrag.GesichertAm.Value,
                eintrag.Sicherung ?? string.Empty,
                eintrag.Programmfassung);
}

/// <summary>
/// Ausgang des letzten automatischen Sicherungslaufs. Trägt zwei Aufgaben:
/// die Zeile „zuletzt gesichert am …" im Reiter Datensicherung und die Meldung
/// beim Start, wenn der Lauf misslungen und noch nicht quittiert ist.
/// </summary>
public sealed record LetzteSicherungDto(
    DateTime Zeitpunkt,
    bool Gelungen,
    string? Datei,
    string? Meldung,
    bool FehlerQuittiert)
{
    public static LetzteSicherungDto? From(LetzteSicherung? stand) =>
        stand is null
            ? null
            : new LetzteSicherungDto(
                stand.Zeitpunkt, stand.Gelungen, stand.Datei, stand.Meldung, stand.FehlerQuittiert);
}
