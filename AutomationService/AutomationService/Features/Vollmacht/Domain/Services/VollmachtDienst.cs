using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.WordAutomation.Domain.Exceptions;
using AutomationService.Features.WordAutomation.Domain.Services;

namespace AutomationService.Features.Vollmacht.Domain.Services;

/// <summary>
/// Die Vollmacht zum Vorgang (§4.11): Vorlage aus dem Unterordner
/// <c>Vollmacht/</c> füllen — mit demselben Ausfüller wie die
/// Anspruchsschreiben —, dann drucken oder zum Öffnen bereitlegen.
///
/// Die Datei entsteht im Arbeitsordner des Vorgangs, neben einem vielleicht
/// gerade angefangenen Anspruchsschreiben. Deshalb löscht der Druck nur die
/// eine Vollmachtdatei und nie den Ordner (<c>ArbeitsVerzeichnis.Aufraeumen</c>
/// nähme das Schreiben mit); nur ein danach leerer Ordner geht mit.
/// </summary>
public sealed class VollmachtDienst(
    IWordAutomationService ausfueller,
    IWordDrucker drucker,
    VollmachtVorlagenOrdner vorlagen,
    ILogger<VollmachtDienst> logger) : IVollmachtDienst
{
    public async Task<VollmachtErgebnis> DruckeAsync(
        VollmachtAuftrag auftrag,
        CancellationToken cancellationToken = default)
    {
        var ausgefuellt = FuelleAus(auftrag);
        if (ausgefuellt.Art != VollmachtErgebnisArt.Ausgefuellt)
        {
            return ausgefuellt;
        }

        try
        {
            await drucker.DruckeAsync(ausgefuellt.Pfad!, cancellationToken);
        }
        catch (Exception exception) when (!cancellationToken.IsCancellationRequested)
        {
            // Jeder Fehler hier hat dieselbe Antwort: Die ausgefüllte Datei ist
            // da, der Anwalt druckt sie selbst. Welcher Fehler es war, gehört
            // ins Protokoll, nicht in den Weg des Anwalts.
            logger.LogWarning(exception, "Vollmacht konnte nicht gedruckt werden: {Datei}", ausgefuellt.Pfad);
            return ausgefuellt with
            {
                Art = VollmachtErgebnisArt.DruckFehlgeschlagen,
                Meldung = "Die Vollmacht konnte nicht an den Drucker gegeben werden "
                    + "(Word nicht erreichbar oder Druck abgebrochen). Sie wird zum Drucken in Word geöffnet.",
            };
        }

        LoescheArbeitsdatei(ausgefuellt.Pfad!);
        return ausgefuellt with { Art = VollmachtErgebnisArt.Gedruckt, Pfad = null };
    }

    public VollmachtErgebnis FuelleAus(VollmachtAuftrag auftrag)
    {
        var vorlage = vorlagen.PfadFuer(auftrag.Art);
        if (!File.Exists(vorlage))
        {
            return new VollmachtErgebnis(
                VollmachtErgebnisArt.VorlageFehlt,
                null,
                $"Die Vorlage „{Path.GetFileName(vorlage)}“ liegt nicht im Ordner {vorlagen.Pfad}.",
                []);
        }

        try
        {
            var ergebnis = ausfueller.GenerateReplacedDocument(new WordReplacementRequest
            {
                TemplateFilePath = vorlage,
                ReplacePatterns = auftrag.Platzhalter(),
                OutputFileName = Path.GetFileNameWithoutExtension(vorlage),
                VorgangSchluessel = auftrag.Referenz,
            });
            return new VollmachtErgebnis(
                VollmachtErgebnisArt.Ausgefuellt,
                ergebnis.OutputFilePath,
                null,
                ergebnis.Warnings);
        }
        catch (Exception exception) when (exception is ZieldateiGesperrtException or IOException)
        {
            logger.LogWarning(exception, "Vollmacht konnte nicht ausgefüllt werden: {Vorlage}", vorlage);
            var meldung = exception is ZieldateiGesperrtException
                ? exception.Message
                : "Die Vorlage konnte nicht gelesen werden — ist sie gerade in Word geöffnet?";
            return new VollmachtErgebnis(VollmachtErgebnisArt.Fehler, null, meldung, []);
        }
    }

    private void LoescheArbeitsdatei(string pfad)
    {
        try
        {
            File.Delete(pfad);
            var ordner = Path.GetDirectoryName(pfad);
            if (ordner is not null && !Directory.EnumerateFileSystemEntries(ordner).Any())
            {
                Directory.Delete(ordner);
            }
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            // Word hält die Datei nach dem Druck gelegentlich noch einen Moment.
            // Liegen bleibt sie dann bis zur Startaufräumung (14 Tage) — kein
            // Grund, dem Anwalt einen gelungenen Druck als Fehler zu melden.
            logger.LogInformation(exception, "Arbeitsdatei der Vollmacht bleibt vorerst liegen: {Datei}", pfad);
        }
    }
}
