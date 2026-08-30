using AutomationService.Features.Vorgaenge.Domain.Services;

namespace AutomationService.Features.Vorgaenge.Presentation.Dtos;

/// <summary>
/// Übertragungsformat für den Zustand des Register-Spiegels (§6.2).
///
/// Die Oberfläche zeigt daraus einen einzigen Satz an: geschrieben, übersprungen
/// oder gescheitert — und im letzten Fall den Klartext, der sagt, was zu tun
/// ist. <see cref="Konfliktkopien"/> ist der Sonderfall, der eine eigene
/// Warnung verdient: Er heißt, dass jemand den Spiegel unterwegs bearbeitet hat
/// und es ab jetzt zwei Register gäbe.
/// </summary>
public sealed record RegisterSpiegelDto(
    bool Geschrieben,
    string? Grund,
    string? Fehler,
    string? DocxPfad,
    string? PdfPfad,
    string? PdfFehler,
    int Zeilen,
    DateTime? GeschriebenAm,
    IReadOnlyList<string> Konfliktkopien)
{
    public static RegisterSpiegelDto From(RegisterSpiegelErgebnis e) => new(
        e.Geschrieben,
        e.Grund,
        e.Fehler,
        e.DocxPfad,
        e.PdfPfad,
        e.PdfFehler,
        e.Zeilen,
        e.GeschriebenAm,
        e.Konfliktkopien);
}
