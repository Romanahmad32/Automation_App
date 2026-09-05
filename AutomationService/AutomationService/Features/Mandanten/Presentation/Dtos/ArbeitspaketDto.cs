using AutomationService.Features.Mandanten.Domain.Persistence;

namespace AutomationService.Features.Mandanten.Presentation.Dtos;

/// <summary>
/// Die Anfrage nach dem nächsten Arbeitspaket. <see cref="Ordnernamen"/> ist der
/// Bestand, den das Frontend im Akten-Stammordner gefunden hat: das Backend
/// kennt ihn nicht — dort liegen nur die Zustände (zugeordnet, vermerkt), und
/// erst aus beidem zusammen ergibt sich, was offen ist.
/// </summary>
public sealed record ArbeitspaketAnfrageDto(IReadOnlyList<string>? Ordnernamen, int? Anzahl)
{
    /// <summary>
    /// Paketgröße, wenn der Aufrufer keine nennt — etwa so viele Zeilen, wie
    /// eine Vorschau noch prüfbar hält (200 statt 4040 sind der Unterschied
    /// zwischen Durchsehen und Durchscrollen).
    /// </summary>
    public const int VorgabeAnzahl = 200;

    /// <summary>Fehlende oder unsinnige Angabe wird zur Vorgabe.</summary>
    public int Groesse() => Anzahl is > 0 ? Anzahl.Value : VorgabeAnzahl;
}

/// <summary>
/// Ein Paket im Buch. <see cref="OrdnerAnzahl"/> steht neben
/// <see cref="Ordnernamen"/>, damit die Übersicht die Zahl zeigen kann, ohne
/// jedes Mal die ganze Liste zu zählen.
/// </summary>
public sealed record ArbeitspaketDto(
    int Nummer,
    DateTime GeholtAm,
    DateTime? EingelesenAm,
    int OrdnerAnzahl,
    int ErledigtAnzahl,
    IReadOnlyList<string> Ordnernamen)
{
    public static ArbeitspaketDto From(ArbeitspaketEntity entity)
    {
        var ordnernamen = MandantListen.Lies(entity.OrdnernamenJson);
        return new ArbeitspaketDto(
            entity.Nummer,
            entity.GeholtAm,
            entity.EingelesenAm,
            ordnernamen.Count,
            entity.ErledigtAnzahl,
            ordnernamen);
    }
}
