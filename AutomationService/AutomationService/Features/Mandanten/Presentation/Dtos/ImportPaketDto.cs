using AutomationService.Features.Mandanten.Domain.Services;

namespace AutomationService.Features.Mandanten.Presentation.Dtos;

/// <summary>
/// Ein herausgegebenes Arbeitspaket, wie es die Übersicht zeigt.
///
/// Die Ordnernamen selbst fehlen bewusst: Sie sind mit 200 Einträgen je Paket
/// der weitaus größte Teil der Zeile und stehen in keiner Spalte, die der
/// Anwalt liest. Was er wissen will, ist <see cref="Erledigt"/> von
/// <see cref="AnzahlOrdner"/> — und das ist gerechnet und nicht gespeichert.
/// </summary>
public sealed record ImportPaketDto(
    int Nummer,
    DateTime GeholtAm,
    int AnzahlOrdner,
    int Erledigt,
    DateTime? EingelesenAm,
    int? Zeilen)
{
    public static ImportPaketDto From(ImportPaketStand stand) => new(
        stand.Paket.Nummer,
        stand.Paket.GeholtAm,
        stand.Paket.AnzahlOrdner,
        stand.Erledigt,
        stand.Paket.EingelesenAm,
        stand.Paket.Zeilen);
}
