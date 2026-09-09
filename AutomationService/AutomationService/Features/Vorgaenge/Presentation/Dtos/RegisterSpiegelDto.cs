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
///
/// <c>PdfLaeuft</c> sagt, dass gerade eine PDF-Fassung entsteht (§6.2 „Dass ein
/// PDF gerade entsteht, ist an der Oberfläche ablesbar"). Es steht in beiden
/// Antworten: in der auf <c>export</c> — direkt danach ist <c>pdfPfad</c>
/// deshalb regelmäßig leer, <em>ohne</em> dass ein <c>pdfFehler</c> daneben
/// steht — und in der auf <c>stand</c>, damit die Registerseite den laufenden
/// Lauf nach einem Fensterwechsel noch erkennt. Fertig meldet der Hub
/// <c>/hubs/register</c> mit <c>registerPdfFertig</c>.
/// </summary>
public sealed record RegisterSpiegelDto(
    bool Geschrieben,
    string? Grund,
    string? Fehler,
    string? DocxPfad,
    string? PdfPfad,
    string? PdfFehler,
    bool PdfLaeuft,
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
        e.PdfLaeuft,
        e.Zeilen,
        e.GeschriebenAm,
        e.Konfliktkopien);
}
