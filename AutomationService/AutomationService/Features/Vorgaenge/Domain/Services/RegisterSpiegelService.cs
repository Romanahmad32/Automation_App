using AutomationService.Core.Ablage;
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
/// <param name="schleuse">Lässt immer nur einen Schreiblauf durch.</param>
/// <param name="logger">Protokolliert Lauf und Fehlschlag.</param>
public sealed class RegisterSpiegelService(
    AutomationDbContext db,
    IPdfConversionService pdf,
    RegisterSpiegelStand stand,
    RegisterSpiegelBauordner bauordner,
    RegisterSpiegelSchleuse schleuse,
    ILogger<RegisterSpiegelService> logger) : IRegisterSpiegelService
{
    /// <summary>
    /// Alles rund um die PDF-Fassung — erzeugen, ablegen, die veraltete
    /// wegräumen. Steht in einer eigenen Klasse, weil daran eine eigene
    /// Zusicherung hängt: .docx und .pdf im Ablageordner dürfen nie
    /// Verschiedenes sagen.
    /// </summary>
    readonly RegisterSpiegelPdfAblage pdfAblage = new(pdf, logger);

    public async Task<RegisterSpiegelErgebnis> StandAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            return await StandInternAsync(cancellationToken);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            return Unerwartet(ex);
        }
    }

    public async Task<RegisterSpiegelErgebnis> SchreibeAsync(
        bool erzwingen = false,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Nur einer schreibt. Warum das kein Sonderfall ist, steht an
            // RegisterSpiegelSchleuse.
            return await schleuse.NacheinanderAsync(
                () => SchreibeInternAsync(erzwingen, cancellationToken), cancellationToken);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            return Unerwartet(ex);
        }
    }

    /// <summary>
    /// Das Netz unter beiden Wegen. Der Controller sichert zu, dass er immer
    /// mit 200 und einem Ergebnis antwortet — ohne dieses Netz gilt das nur für
    /// die Fehlschläge, an die beim Schreiben gedacht wurde.
    ///
    /// Daneben gibt es genug andere: ein Ablageordner, den jemand über
    /// <c>PUT api/Settings/kanzlei</c> auf einen unmöglichen Pfad gestellt hat,
    /// eine Merkdatei, die als halbe JSON auf der Platte liegt, alles, was
    /// Xceed beim Bauen der .docx werfen kann. Die kämen als 500 an, und die
    /// Oberfläche zeigte statt eines Satzes einen Verbindungsfehler — obwohl
    /// der Dienst läuft und die Lage behebbar ist.
    ///
    /// <see cref="OperationCanceledException"/> bleibt ausgenommen: Ein
    /// abgebrochener Aufruf ist kein Ergebnis, das jemand lesen will.
    /// </summary>
    RegisterSpiegelErgebnis Unerwartet(Exception ex)
    {
        logger.LogError(ex, "Register-Spiegel: unerwarteter Fehlschlag.");
        return RegisterSpiegelErgebnis.Gescheitert(
            $"Der Register-Spiegel ist unerwartet gescheitert: {ex.Message}",
            zeilen: 0,
            zuletzt: null);
    }

    async Task<RegisterSpiegelErgebnis> StandInternAsync(CancellationToken cancellationToken)
    {
        var (einstellungen, zeilen) = await UeberblickAsync(cancellationToken);
        var letzter = stand.Lesen();

        // Der Ordner kommt seit #103 aus der Vorgabe und nicht mehr aus dem
        // Feld: Er kann relativ gespeichert sein (%OneDriveCommercial%\...) und
        // er kann aus dem App-Daten-Ordner abgeleitet sein, ohne dass im
        // Registerfeld etwas steht. Wer hier das rohe Feld laese, schriebe den
        // Spiegel entweder gar nicht oder in einen Ordner namens "%OneDrive%".
        var ordner = RegisterAblageVorgabe.Ermittle(db);
        if (ordner.Length == 0)
            return RegisterSpiegelErgebnis.Uebersprungen(KeinOrdner, zeilen, letzter?.GeschriebenAm);

        var ablage = new RegisterSpiegelAblage(ordner, einstellungen.RegisterDateiname);

        // Schon beim Öffnen der Seite melden und nicht erst beim Schreiben:
        // Der Lauf nach dem Vorgangsabschluss meldet nur ins Protokoll, der
        // Anwalt saehe die Lage sonst nirgends.
        if (FremdeZieldatei(letzter, ablage))
        {
            return RegisterSpiegelErgebnis.Gescheitert(
                FremdeDatei(ablage), zeilen, letzter?.GeschriebenAm, ablage.Konfliktkopien());
        }

        return new RegisterSpiegelErgebnis(
            Geschrieben: false,
            Grund: null,
            Fehler: null,
            DocxPfad: File.Exists(ablage.Docx) ? ablage.Docx : null,
            PdfPfad: File.Exists(ablage.Pdf) ? ablage.Pdf : null,
            PdfFehler: null,
            Zeilen: zeilen,
            GeschriebenAm: letzter?.GeschriebenAm,
            Konfliktkopien: ablage.Konfliktkopien());
    }

    async Task<RegisterSpiegelErgebnis> SchreibeInternAsync(
        bool erzwingen,
        CancellationToken cancellationToken)
    {
        var (einstellungen, zeilen) = await LadeAsync(cancellationToken);
        var letzter = stand.Lesen();

        var ordner = RegisterAblageVorgabe.Ermittle(db);
        if (ordner.Length == 0)
            return RegisterSpiegelErgebnis.Uebersprungen(KeinOrdner, zeilen.Count, letzter?.GeschriebenAm);

        var ablage = new RegisterSpiegelAblage(ordner, einstellungen.RegisterDateiname);

        if (FremdeZieldatei(letzter, ablage))
        {
            logger.LogWarning("Register-Spiegel: Zieldatei stammt nicht von der App: {Ziel}", ablage.Docx);
            return RegisterSpiegelErgebnis.Gescheitert(
                FremdeDatei(ablage), zeilen.Count, letzter?.GeschriebenAm, ablage.Konfliktkopien());
        }

        var nurAbgeschlossene = RegisterSpiegelVorgabe.NurAbgeschlossene(einstellungen.RegisterExportFilter);
        var abdruck = RegisterSpiegelStand.Fingerabdruck(zeilen, nurAbgeschlossene);

        if (!erzwingen && Unveraendert(letzter, abdruck, ablage))
        {
            return RegisterSpiegelErgebnis.Uebersprungen(
                Unveraendert_, zeilen.Count, letzter?.GeschriebenAm, ablage.Konfliktkopien());
        }

        try
        {
            return await SchreibeDateienAsync(
                ablage, zeilen, nurAbgeschlossene, abdruck, letzter, cancellationToken);
        }
        catch (ZieldateiGesperrtException ex)
        {
            logger.LogWarning(ex, "Register-Spiegel: Zieldatei gesperrt.");
            return RegisterSpiegelErgebnis.Gescheitert(
                ex.Message, zeilen.Count, letzter?.GeschriebenAm, ablage.Konfliktkopien());
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            logger.LogWarning(ex, "Register-Spiegel: Ablage nicht beschreibbar.");
            return RegisterSpiegelErgebnis.Gescheitert(
                $"Der Register-Ordner \"{ablage.Ordner}\" ist nicht beschreibbar: {ex.Message}",
                zeilen.Count,
                letzter?.GeschriebenAm,
                ablage.Konfliktkopien());
        }
    }

    const string KeinOrdner =
        "Es ist kein Ablageordner für das Register eingestellt — der Spiegel wird nicht geschrieben.";

    const string Unveraendert_ =
        "Der Bestand hat sich seit dem letzten Schreiben nicht geändert.";

    static string FremdeDatei(RegisterSpiegelAblage ablage) =>
        $"Im Ablageordner liegt bereits \"{ablage.Basisname}.docx\", die nicht von der App stammt. "
        + "Der Spiegel würde sie beim Schreiben ersetzen und lässt sie deshalb unangetastet — bitte "
        + "die Datei umbenennen oder in den Einstellungen einen anderen Dateinamen wählen.";

    /// <summary>
    /// Ob am Zielort schon eine Datei liegt, die der Spiegel nicht geschrieben
    /// hat.
    ///
    /// Das ist der Schutz für das gewachsene Kanzleidokument. Der Dateiname ist
    /// einstellbar, und „so heißen wie immer" ist der naheliegendste Wunsch —
    /// ohne diese Prüfung wären die 93 Seiten Handarbeit beim nächsten
    /// Vorgangsabschluss ersetzt, ungefragt und ohne Sicherung.
    ///
    /// Erkannt wird das eigene Werk am Stand und <em>nicht</em> am Inhalt der
    /// Datei: Ein Blick hinein löste bei „Dateien bei Bedarf" einen Download
    /// aus, und der Spiegel liest den Zielordner grundsätzlich nicht. Der Preis
    /// ist ein Fehlalarm, wenn die Merkdatei verloren ging (neuer Rechner,
    /// eingespielte Sicherung) — dann sagt die Meldung, was zu tun ist, und
    /// eine zu viel geschützte Datei ist die harmlosere Richtung.
    /// </summary>
    static bool FremdeZieldatei(RegisterSpiegelStand.Eintrag? letzter, RegisterSpiegelAblage ablage) =>
        File.Exists(ablage.Docx)
        && !(letzter is not null
             && string.Equals(letzter.Ziel, ablage.Docx, StringComparison.OrdinalIgnoreCase));

    /// <summary>
    /// Unverändert heißt: gleicher Fingerabdruck, gleiches Ziel <em>und</em>
    /// der Ablageordner sieht noch so aus, wie der letzte Lauf ihn verlassen
    /// hat. Die letzte Bedingung ist der Grund, warum eine von Hand gelöschte
    /// Datei beim nächsten Abschluss von selbst zurückkommt.
    ///
    /// Beim PDF wird auf <em>Gleichheit</em> geprüft, nicht auf Vorhandensein:
    /// Ein Lauf ohne Word hinterlässt bewusst keins, und dann ist „da liegt
    /// keins" der erwartete Zustand. Mit <c>File.Exists</c> allein wäre er nie
    /// erreicht, und der Spiegel schriebe auf einem Rechner ohne Word bei
    /// jedem Abschluss dieselbe .docx neu.
    /// </summary>
    static bool Unveraendert(RegisterSpiegelStand.Eintrag? letzter, string abdruck, RegisterSpiegelAblage ablage) =>
        letzter is not null
        && letzter.Fingerabdruck == abdruck
        && string.Equals(letzter.Ziel, ablage.Docx, StringComparison.OrdinalIgnoreCase)
        && File.Exists(ablage.Docx)
        && letzter.PdfGeschrieben == File.Exists(ablage.Pdf);

    async Task<RegisterSpiegelErgebnis> SchreibeDateienAsync(
        RegisterSpiegelAblage ablage,
        IReadOnlyList<RegisterZeile> zeilen,
        bool nurAbgeschlossene,
        string abdruck,
        RegisterSpiegelStand.Eintrag? letzter,
        CancellationToken cancellationToken)
    {
        var jetzt = DateTime.Now;
        var bauDocx = bauordner.NeueDatei(".docx");
        var bauPdf = bauordner.NeueDatei(".pdf");

        try
        {
            RegisterDokument.Schreibe(bauDocx, zeilen, jetzt, nurAbgeschlossene);

            // Erst wandeln, dann umziehen: Was scheitert, scheitert damit,
            // bevor der Ablageordner angefasst wird.
            var pdfFehler = await pdfAblage.ErzeugeAsync(bauDocx, bauPdf, cancellationToken);

            AtomareAblage.Ersetze(bauDocx, ablage.Docx);
            AtomareAblage.SchreibschutzSetzen(ablage.Docx);

            pdfFehler = pdfAblage.Ablegen(ablage, bauPdf, pdfFehler, letzter);
            var pdfPfad = pdfFehler is null ? ablage.Pdf : null;

            stand.Schreiben(new RegisterSpiegelStand.Eintrag(
                abdruck, ablage.Docx, jetzt, PdfGeschrieben: pdfFehler is null));
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
    /// Der volle Bestand — für das Schreiben, das jede Zeile braucht.
    /// </summary>
    async Task<(KanzleiSettingsEntity Einstellungen, IReadOnlyList<RegisterZeile> Zeilen)> LadeAsync(
        CancellationToken cancellationToken)
    {
        var einstellungen = await EinstellungenAsync(cancellationToken);

        var vorgaenge = await db.Vorgaenge.AsNoTracking().ToListAsync(cancellationToken);
        var zeilen = RegisterZeilenBau.Aus(
            vorgaenge,
            RegisterSpiegelVorgabe.NurAbgeschlossene(einstellungen.RegisterExportFilter));

        return (einstellungen, zeilen);
    }

    /// <summary>
    /// Nur die Anzahl — für <see cref="StandAsync"/>, das beim Öffnen der
    /// Registerseite läuft und keine einzige Zeile anzeigt.
    ///
    /// Vorher lief auch dieser Weg über <see cref="LadeAsync"/>: jeder Vorgang
    /// aus der Datenbank in den Speicher, jede Zeile gebaut (samt Parsen des
    /// AntwortJson) und sortiert — um am Ende <c>.Count</c> zu lesen. Bei den
    /// rund 4000 Akten, um die es in diesem Register geht, ist das der
    /// Unterschied zwischen einem Tabwechsel und einer Gedenksekunde, und zwar
    /// bei jedem Öffnen.
    /// </summary>
    async Task<(KanzleiSettingsEntity Einstellungen, int Zeilen)> UeberblickAsync(
        CancellationToken cancellationToken)
    {
        var einstellungen = await EinstellungenAsync(cancellationToken);

        var zeilen = await db.Vorgaenge
            .AsNoTracking()
            .CountAsync(
                RegisterZeilenBau.Dateifilter(
                    RegisterSpiegelVorgabe.NurAbgeschlossene(einstellungen.RegisterExportFilter)),
                cancellationToken);

        return (einstellungen, zeilen);
    }

    async Task<KanzleiSettingsEntity> EinstellungenAsync(CancellationToken cancellationToken) =>
        await db.KanzleiSettings
            .AsNoTracking()
            .FirstOrDefaultAsync(s => s.Id == KanzleiSettingsEntity.SingletonId, cancellationToken)
        ?? KanzleiSettingsRepository.CreateDefault();
}
