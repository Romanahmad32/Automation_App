using AutomationService.Features.RegisterHistorie.Domain.Services;

namespace AutomationService.Features.RegisterHistorie.Presentation.Dtos;

/// <summary>
/// Eine Registerimportdatei. Der Rumpf der Anfrage ist Zeichen für Zeichen die
/// Datei, die außerhalb der App entsteht — kein Umschlag, keine zusätzlichen
/// Felder. Nur deshalb kann derselbe Inhalt geprüft, übernommen und aufgehoben
/// werden, ohne dass jemand ihn dazwischen umformt.
///
/// <c>Version</c> ist die Format-Fassung, derzeit 1; fehlt sie, wird 1
/// angenommen, eine andere wird abgelehnt statt halb gelesen.
///
/// Zwei Schreibweisen, damit die Jahrgangs-Anleitung an den Erzeuger kurz
/// bleibt: die Langform mit <c>jahrgaenge</c> und die Kurzform mit
/// <c>jahrgang</c> und <c>zeilen</c> auf oberster Ebene für die übliche Datei
/// mit genau einem Jahrgang. Stehen beide darin, gilt die Langform — sie ist
/// die vollständigere Aussage.
/// </summary>
public sealed record RegisterImportDto(
    int? Version,
    int? Jahrgang,
    IReadOnlyList<ImportRegisterZeileDto>? Zeilen,
    IReadOnlyList<ImportJahrgangDto>? Jahrgaenge)
{
    public IReadOnlyList<ImportJahrgang> ZuDomaene()
    {
        if (Jahrgaenge is { Count: > 0 }) return [.. Jahrgaenge.Select(jahrgang => jahrgang.ZuDomaene())];
        if (Jahrgang is null && Zeilen is null) return [];
        return [new ImportJahrgang(Jahrgang ?? 0, [.. (Zeilen ?? []).Select(zeile => zeile.ZuDomaene())])];
    }
}

/// <summary>Ein Jahrgang in der Langform der Datei.</summary>
public sealed record ImportJahrgangDto(int? Jahrgang, IReadOnlyList<ImportRegisterZeileDto>? Zeilen)
{
    public ImportJahrgang ZuDomaene() =>
        new(Jahrgang ?? 0, [.. (Zeilen ?? []).Select(zeile => zeile.ZuDomaene())]);
}

/// <summary>
/// Eine Zeile in der Importdatei. Alles ist freiwillig: Was in der
/// Freitextzelle nicht auffindbar war, bleibt leer, statt geraten zu werden —
/// ein Erzeuger, der eine Lücke füllt, um das Feld zu belegen, ist genau das,
/// wovor die Sicherheitsstufen schützen sollen.
/// </summary>
public sealed record ImportRegisterZeileDto(
    int? LaufendeNummer,
    string? NummerZusatz,
    string? Spalte1,
    string? Aktenzeichen,
    string? Abteilung,
    string? AbteilungRoh,
    string? Sachart,
    string? Mandant,
    string? Gegner,
    string? Sachbestand,
    string? Unfalldatum,
    string? Rechtsgebiet,
    string? Freitext,
    string? Sicherheit,
    IReadOnlyList<string>? Hinweise)
{
    public ImportRegisterZeile ZuDomaene() => new(
        LaufendeNummer ?? 0,
        NummerZusatz ?? string.Empty,
        Spalte1 ?? string.Empty,
        Aktenzeichen ?? string.Empty,
        Abteilung ?? string.Empty,
        AbteilungRoh ?? string.Empty,
        Sachart ?? string.Empty,
        Mandant ?? string.Empty,
        Gegner ?? string.Empty,
        Sachbestand ?? string.Empty,
        Unfalldatum ?? string.Empty,
        Rechtsgebiet ?? string.Empty,
        Freitext ?? string.Empty,
        Sicherheit ?? string.Empty,
        Hinweise ?? []);
}
