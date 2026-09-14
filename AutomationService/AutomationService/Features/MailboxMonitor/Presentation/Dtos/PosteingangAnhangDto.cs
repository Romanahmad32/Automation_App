using AutomationService.Features.MailboxMonitor.Domain.Services;

namespace AutomationService.Features.MailboxMonitor.Presentation.Dtos;

/// <summary>
/// Ein Anhang, wie ihn die Nachrichtenstruktur beschreibt — noch nicht geladen.
/// </summary>
/// <param name="Id">
/// Der IMAP-Teilbezeichner (<c>"2"</c>, <c>"2.1"</c>). Damit fordert die
/// Oberfläche genau diesen Anhang an; er gilt nur innerhalb dieser Nachricht.
/// </param>
/// <param name="Dateiname">Der Name, unter dem er in der Mail steht.</param>
/// <param name="Groesse">Größe in Bytes aus der Struktur — ohne Abruf.</param>
/// <param name="Medientyp">Etwa <c>application/pdf</c>; bestimmt das Symbol in der Liste.</param>
public sealed record PosteingangAnhangDto(string Id, string Dateiname, long Groesse, string Medientyp)
{
    public static PosteingangAnhangDto From(PosteingangAnhang anhang) =>
        new(anhang.Id, anhang.Dateiname, anhang.Groesse, anhang.Medientyp);
}

/// <summary>
/// Eine ins Zwischenlager geholte Datei. Zurück geht der <b>Pfad</b> und nicht
/// der Inhalt: Öffnen, Anhängen beim Versand und Ablegen in die Akte arbeiten
/// in dieser App durchweg mit lokalen Pfaden, und Frontend wie Backend laufen
/// auf demselben Rechner.
/// </summary>
public sealed record PosteingangAnhangAblageDto(string Dateiname, string Pfad, long Groesse)
{
    public static PosteingangAnhangAblageDto From(PosteingangAnhangAblage ablage) =>
        new(ablage.Dateiname, ablage.Pfad, ablage.Groesse);
}
