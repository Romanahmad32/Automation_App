using AutomationService.Features.Mandanten.Domain.Persistence;

namespace AutomationService.Features.Mandanten.Presentation.Dtos;

/// <summary>
/// Übertragungsformat eines Mandanten. PascalCase-Properties werden als camelCase
/// serialisiert und passen damit 1:1 zum JSON der Flutter-Entität <c>Mandant</c>.
/// Die in der DB als JSON-Spalte abgelegten Listen werden hier in echte Arrays
/// übersetzt.
/// </summary>
public sealed record MandantDto(
    int Id,
    string Anrede,
    string Vorname,
    string Nachname,
    string StrasseHausnummer,
    string Postleitzahl,
    string Ort,
    string EmailAdresse,
    string Telefonnummer,
    string Notiz,
    string PersoenlicheGrussformel,
    IReadOnlyList<string> AktenOrdnernamen,
    IReadOnlyList<string> Kennzeichen,
    DateTime ErstelltAm)
{
    public static MandantDto From(MandantEntity e) => new(
        e.Id,
        e.Anrede,
        e.Vorname,
        e.Nachname,
        e.StrasseHausnummer,
        e.Postleitzahl,
        e.Ort,
        e.EmailAdresse,
        e.Telefonnummer,
        e.Notiz,
        e.PersoenlicheGrussformel,
        MandantListen.Lies(e.AktenOrdnernamenJson),
        MandantListen.Lies(e.KennzeichenJson),
        e.ErstelltAm);
}
