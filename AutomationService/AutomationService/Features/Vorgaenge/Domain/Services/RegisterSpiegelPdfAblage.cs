using AutomationService.Core.Ablage;
using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.WordAutomation.Domain.Exceptions;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Die PDF-Fassung des Register-Spiegels: erzeugen, ablegen — und die alte
/// wegräumen, wenn keine neue entstand.
///
/// Eigene Klasse, weil hier eine eigene Zusicherung hängt: Im Ablageordner
/// dürfen .docx und .pdf nie Verschiedenes sagen. Die .docx ist die
/// verbindliche Fassung, das PDF die bequeme — und unterwegs liest man das
/// PDF. Ein PDF von gestern neben einer .docx von heute ist deshalb schlimmer
/// als gar keins: Es sieht vollständig aus und ist es nicht.
///
/// Kein Schritt hier lässt den ganzen Lauf scheitern. Die .docx liegt zu
/// diesem Zeitpunkt schon richtig; den Lauf als gescheitert zu melden hiesse,
/// etwas anderes zu sagen, als auf der Platte steht. Gemeldet wird deshalb
/// genau das, was fehlt — als Satz, nicht als Ausnahme.
/// </summary>
/// <param name="pdf">Wandelt die fertige .docx; fehlt Word, bleibt es bei der .docx.</param>
/// <param name="logger">Protokolliert, was nicht ging.</param>
public sealed class RegisterSpiegelPdfAblage(IPdfConversionService pdf, ILogger logger)
{
    /// <summary>
    /// Wandelt die .docx und legt das Ergebnis im Bauordner ab. Gibt den Grund
    /// zurück, wenn es nicht ging — auf einem Rechner ohne Word ist das
    /// erwartbar und kein Fehlschlag des Spiegels.
    /// </summary>
    /// <returns>Der Grund, warum kein PDF entstand, oder null.</returns>
    public async Task<string?> ErzeugeAsync(string bauDocx, string bauPdf, CancellationToken cancellationToken)
    {
        try
        {
            var bytes = await pdf.ConvertDocxToPdfAsync(bauDocx);
            await File.WriteAllBytesAsync(bauPdf, bytes, cancellationToken);
            return null;
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogWarning(ex, "Register-Spiegel: PDF-Fassung konnte nicht erzeugt werden.");
            return "Die PDF-Fassung konnte nicht erzeugt werden "
                   + $"({ex.Message}). Die Word-Datei ist geschrieben.";
        }
    }

    /// <summary>
    /// Legt die PDF-Fassung an ihren Zielort — oder räumt die alte weg, wenn
    /// keine entstand.
    ///
    /// Das Wegräumen ist der eigentliche Punkt: Bliebe das alte PDF liegen,
    /// hielte der Stand den Lauf zudem für erledigt, und der Spiegel käme aus
    /// diesem Zustand nie wieder heraus.
    /// </summary>
    /// <returns>Der Grund, warum kein PDF liegt, oder null.</returns>
    public string? Ablegen(
        RegisterSpiegelAblage ablage,
        string bauPdf,
        string? pdfFehler,
        RegisterSpiegelStand.Eintrag? letzter)
    {
        ArgumentNullException.ThrowIfNull(ablage);

        if (pdfFehler is not null)
        {
            VeraltetesWegraeumen(ablage, letzter);
            return pdfFehler;
        }

        try
        {
            AtomareAblage.Ersetze(bauPdf, ablage.Pdf);
            AtomareAblage.SchreibschutzSetzen(ablage.Pdf);
            return null;
        }
        catch (Exception ex)
            when (ex is ZieldateiGesperrtException or IOException or UnauthorizedAccessException)
        {
            logger.LogWarning(ex, "Register-Spiegel: PDF-Fassung konnte nicht abgelegt werden.");
            VeraltetesWegraeumen(ablage, letzter);
            return $"Die PDF-Fassung konnte nicht abgelegt werden ({ex.Message}). "
                   + "Die Word-Datei ist geschrieben.";
        }
    }

    /// <summary>
    /// Entfernt die PDF-Fassung des vorigen Laufs. Angefasst wird nur, was der
    /// Spiegel selbst dort abgelegt hat — der Stand führt dasselbe Ziel und
    /// weiß, dass damals ein PDF entstand. Alles andere im Ordner geht ihn
    /// nichts an.
    /// </summary>
    static void VeraltetesWegraeumen(RegisterSpiegelAblage ablage, RegisterSpiegelStand.Eintrag? letzter)
    {
        if (letzter is null
            || !letzter.PdfGeschrieben
            || !string.Equals(letzter.Ziel, ablage.Docx, StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        AtomareAblage.SchreibschutzLoesen(ablage.Pdf);
        try
        {
            if (File.Exists(ablage.Pdf)) File.Delete(ablage.Pdf);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // Bleibt es liegen, sieht der nächste Lauf den Ordner als verändert
            // an und schreibt neu — besser, als deswegen den bereits
            // geschriebenen Spiegel zu verwerfen.
        }
    }
}
