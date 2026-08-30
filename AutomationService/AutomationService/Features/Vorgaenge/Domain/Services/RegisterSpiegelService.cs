using AutomationService.Core.Persistence;
using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Features.WordAutomation.Domain.Exceptions;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Schreibt den Register-Spiegel (§6.2, #40): Zeilen aus der Datenbank, .docx
/// über <see cref="RegisterDokument"/>, PDF über den PdfConversion-Slice, und
/// beides atomar in den eingestellten Ablageordner.
///
/// Der Ablauf ist so gebaut, dass im Ablageordner nur zwei Dinge geschehen
/// können: nichts, oder eine vollständige neue Fassung. Gebaut wird im
/// Arbeitsverzeichnis; erst der letzte Schritt fasst das Ziel an (siehe
/// <see cref="AtomareAblage"/>).
/// </summary>
/// <param name="db">Vorgänge und Einstellungen.</param>
/// <param name="pdf">Wandelt die fertige .docx; fehlt Word, bleibt es bei der .docx.</param>
/// <param name="stand">Der Fingerabdruck des zuletzt geschriebenen Bestands.</param>
/// <param name="bauordner">Wo die Dateien entstehen, bevor sie umziehen.</param>
/// <param name="logger">Protokolliert Lauf und Fehlschlag.</param>
public sealed class RegisterSpiegelService(
    AutomationDbContext db,
    IPdfConversionService pdf,
    RegisterSpiegelStand stand,
    RegisterSpiegelBauordner bauordner,
    ILogger<RegisterSpiegelService> logger) : IRegisterSpiegelService
{
    public async Task<RegisterSpiegelErgebnis> StandAsync(CancellationToken cancellationToken = default)
    {
        var (einstellungen, zeilen) = await LadeAsync(cancellationToken);
        var letzter = stand.Lesen();
        if (string.IsNullOrWhiteSpace(einstellungen.RegisterAblageOrdner))
            return RegisterSpiegelErgebnis.Uebersprungen(KeinOrdner, zeilen.Count, letzter?.GeschriebenAm);

        var ablage = AblageFuer(einstellungen);
        return new RegisterSpiegelErgebnis(
            Geschrieben: false,
            Grund: null,
            Fehler: null,
            DocxPfad: File.Exists(ablage.Docx) ? ablage.Docx : null,
            PdfPfad: File.Exists(ablage.Pdf) ? ablage.Pdf : null,
            PdfFehler: null,
            Zeilen: zeilen.Count,
            GeschriebenAm: letzter?.GeschriebenAm,
            Konfliktkopien: ablage.Konfliktkopien());
    }

    public async Task<RegisterSpiegelErgebnis> SchreibeAsync(
        bool erzwingen = false,
        CancellationToken cancellationToken = default)
    {
        var (einstellungen, zeilen) = await LadeAsync(cancellationToken);
        var letzter = stand.Lesen();

        if (string.IsNullOrWhiteSpace(einstellungen.RegisterAblageOrdner))
            return RegisterSpiegelErgebnis.Uebersprungen(KeinOrdner, zeilen.Count, letzter?.GeschriebenAm);

        var ablage = AblageFuer(einstellungen);
        var nurAbgeschlossene = RegisterSpiegelVorgabe.NurAbgeschlossene(einstellungen.RegisterExportFilter);
        var abdruck = RegisterSpiegelStand.Fingerabdruck(zeilen, nurAbgeschlossene);

        if (!erzwingen && Unveraendert(letzter, abdruck, ablage))
            return RegisterSpiegelErgebnis.Uebersprungen(Unveraendert_, zeilen.Count, letzter?.GeschriebenAm);

        try
        {
            return await SchreibeDateienAsync(ablage, zeilen, nurAbgeschlossene, abdruck, cancellationToken);
        }
        catch (ZieldateiGesperrtException ex)
        {
            logger.LogWarning(ex, "Register-Spiegel: Zieldatei gesperrt.");
            return RegisterSpiegelErgebnis.Gescheitert(ex.Message, zeilen.Count, letzter?.GeschriebenAm);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            logger.LogWarning(ex, "Register-Spiegel: Ablage nicht beschreibbar.");
            return RegisterSpiegelErgebnis.Gescheitert(
                $"Der Register-Ordner \"{ablage.Ordner}\" ist nicht beschreibbar: {ex.Message}",
                zeilen.Count,
                letzter?.GeschriebenAm);
        }
    }

    const string KeinOrdner =
        "Es ist kein Ablageordner für das Register eingestellt — der Spiegel wird nicht geschrieben.";

    const string Unveraendert_ =
        "Der Bestand hat sich seit dem letzten Schreiben nicht geändert.";

    /// <summary>
    /// Unverändert heißt: gleicher Fingerabdruck, gleiches Ziel <em>und</em>
    /// die Dateien liegen noch dort. Die letzte Bedingung ist der Grund, warum
    /// eine von Hand gelöschte Datei beim nächsten Abschluss von selbst
    /// zurückkommt.
    /// </summary>
    static bool Unveraendert(RegisterSpiegelStand.Eintrag? letzter, string abdruck, RegisterSpiegelAblage ablage) =>
        letzter is not null
        && letzter.Fingerabdruck == abdruck
        && string.Equals(letzter.Ziel, ablage.Docx, StringComparison.OrdinalIgnoreCase)
        && File.Exists(ablage.Docx)
        && File.Exists(ablage.Pdf);

    async Task<RegisterSpiegelErgebnis> SchreibeDateienAsync(
        RegisterSpiegelAblage ablage,
        IReadOnlyList<RegisterZeile> zeilen,
        bool nurAbgeschlossene,
        string abdruck,
        CancellationToken cancellationToken)
    {
        var jetzt = DateTime.Now;
        var bauDocx = bauordner.NeueDatei(".docx");
        var bauPdf = bauordner.NeueDatei(".pdf");

        try
        {
            RegisterDokument.Schreibe(bauDocx, zeilen, jetzt, nurAbgeschlossene);

            // Erst wandeln, dann umziehen: Scheitert die Wandlung, liegt im
            // Ablageordner weiterhin die alte, in sich stimmige Fassung —
            // besser als eine neue .docx neben einem veralteten PDF.
            var pdfFehler = await PdfSchreibenAsync(bauDocx, bauPdf, cancellationToken);

            AtomareAblage.Ersetze(bauDocx, ablage.Docx);
            AtomareAblage.SchreibschutzSetzen(ablage.Docx);

            string? pdfPfad = null;
            if (pdfFehler is null)
            {
                AtomareAblage.Ersetze(bauPdf, ablage.Pdf);
                AtomareAblage.SchreibschutzSetzen(ablage.Pdf);
                pdfPfad = ablage.Pdf;
            }

            stand.Schreiben(new RegisterSpiegelStand.Eintrag(abdruck, ablage.Docx, jetzt));
            logger.LogInformation(
                "Register-Spiegel geschrieben: {Zeilen} Zeilen nach {Ziel}.", zeilen.Count, ablage.Docx);

            return new RegisterSpiegelErgebnis(
                Geschrieben: true,
                Grund: null,
                Fehler: null,
                DocxPfad: ablage.Docx,
                PdfPfad: pdfPfad,
                PdfFehler: pdfFehler,
                Zeilen: zeilen.Count,
                GeschriebenAm: jetzt,
                Konfliktkopien: ablage.Konfliktkopien());
        }
        finally
        {
            bauordner.Aufraeumen(bauDocx, bauPdf);
        }
    }

    /// <summary>
    /// Wandelt die .docx und legt das Ergebnis neben ihr ab. Gibt den Grund
    /// zurück, wenn es nicht ging — auf einem Rechner ohne Word ist das
    /// erwartbar und kein Fehlschlag des Spiegels: Die .docx ist die
    /// verbindliche Fassung, das PDF die bequeme.
    /// </summary>
    async Task<string?> PdfSchreibenAsync(string bauDocx, string bauPdf, CancellationToken cancellationToken)
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

    async Task<(KanzleiSettingsEntity Einstellungen, IReadOnlyList<RegisterZeile> Zeilen)> LadeAsync(
        CancellationToken cancellationToken)
    {
        var einstellungen = await db.KanzleiSettings
            .AsNoTracking()
            .FirstOrDefaultAsync(s => s.Id == KanzleiSettingsEntity.SingletonId, cancellationToken)
            ?? KanzleiSettingsRepository.CreateDefault();

        var vorgaenge = await db.Vorgaenge.AsNoTracking().ToListAsync(cancellationToken);
        var zeilen = RegisterZeilenBau.Aus(
            vorgaenge,
            RegisterSpiegelVorgabe.NurAbgeschlossene(einstellungen.RegisterExportFilter));

        return (einstellungen, zeilen);
    }

    static RegisterSpiegelAblage AblageFuer(KanzleiSettingsEntity einstellungen) =>
        new(einstellungen.RegisterAblageOrdner.Trim(), einstellungen.RegisterDateiname);
}
