using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Features.Vorgaenge.Presentation.Hubs;
using Microsoft.AspNetCore.SignalR;

namespace AutomationService.Features.Vorgaenge.Presentation.HostedServices;

/// <summary>
/// Zieht die PDF-Fassung des Register-Spiegels nach, nachdem die .docx längst
/// liegt (§6.2 „Word sofort, PDF nachgezogen").
///
/// <para>
/// <b>Warum ein Hintergrunddienst und kein <c>Task.Run</c>.</b> Der Auftrag
/// entsteht in einer HTTP-Anfrage, deren Scoped-<c>DbContext</c> mit der
/// Antwort stirbt. Eine abgesetzte Aufgabe müsste sich also entweder einen
/// eigenen Scope holen oder ganz ohne Datenbank auskommen — hier gilt das
/// Zweite: Im <see cref="RegisterPdfAuftrag"/> stehen nur Pfade. Damit hängt
/// der Nachzug an nichts, was zwischen Annahme und Ausführung weggeräumt wird,
/// und die Wandlung läuft in einem Dienst, der beim Herunterfahren geordnet
/// endet, statt in einer Aufgabe, die niemand mehr kennt.
/// </para>
///
/// <para>
/// <b>Lebensdauern.</b> <see cref="IPdfConversionService"/> ist ein Singleton
/// (<c>CompositePdfConversionService</c> mit dem Word-COM-Stack auf einem
/// dauerhaften STA-Thread) — deshalb wird er direkt genommen und nicht über
/// eine <c>IServiceScopeFactory</c> aufgelöst. Wäre er Scoped, wäre das der
/// Weg; ein Singleton, der einen Scoped-Dienst im Konstruktor nimmt, hielte
/// den ersten Scope für die Laufzeit der App fest.
/// </para>
///
/// <para>
/// <b>Wirft nie</b> (§1.3). Eine Ausnahme, die bis in die Schleife der
/// Warteschlange käme, beendete sie — und danach entstünde still kein PDF
/// mehr, bis die App neu startet.
/// </para>
/// </summary>
/// <param name="warteschlange">Liefert die Aufträge; hält den Zähler für „läuft".</param>
/// <param name="pdf">Wandelt die .docx; fehlt Word, bleibt es bei der .docx.</param>
/// <param name="stand">
/// Sagt, welcher Bestand im Ablageordner liegt — und wird nach dem Ablegen
/// nachgeführt, damit der nächste Lauf denselben Bestand nicht erneut schreibt.
/// </param>
/// <param name="bauordner">Räumt die Zwischenstände des Auftrags weg.</param>
/// <param name="hub">Weckt die Oberfläche, sobald die Fassung fertig ist.</param>
/// <param name="logger">Protokolliert, was nicht ging.</param>
public sealed class RegisterPdfNachzug(
    RegisterPdfWarteschlange warteschlange,
    IPdfConversionService pdf,
    RegisterSpiegelStand stand,
    RegisterSpiegelBauordner bauordner,
    IHubContext<RegisterHub> hub,
    ILogger<RegisterPdfNachzug> logger) : BackgroundService
{
    /// <summary>
    /// Arbeitet ab, was gerade eingereiht ist — der Weg für Tests, die den
    /// Zeitpunkt prüfen, statt auf den Dienst zu warten.
    /// </summary>
    /// <returns>Wie viele Aufträge abgearbeitet wurden.</returns>
    public Task<int> AlleAbarbeitenAsync() => warteschlange.AlleAbarbeitenAsync(NachziehenAsync);

    protected override Task ExecuteAsync(CancellationToken stoppingToken) =>
        warteschlange.AbarbeitenAsync(auftrag => NachziehenAsync(auftrag, stoppingToken), stoppingToken);

    Task NachziehenAsync(RegisterPdfAuftrag auftrag) =>
        NachziehenAsync(auftrag, CancellationToken.None);

    async Task NachziehenAsync(RegisterPdfAuftrag auftrag, CancellationToken cancellationToken)
    {
        var ablage = new RegisterSpiegelPdfAblage(pdf, logger);
        try
        {
            if (Ueberholt(auftrag)) return;

            // Der Abbruch beim Herunterfahren wird durchgelassen und nicht
            // ausgesessen: Die .docx ist die verbindliche Fassung und liegt
            // schon, ein veraltetes PDF liegt nicht mehr daneben — die App auf
            // eine Nebensache zwanzig Sekunden warten zu lassen, wäre der
            // schlechtere Tausch. Zurück holt die Fassung dann „Jetzt neu
            // schreiben".
            var fehler = await ablage.ErzeugeAsync(auftrag.QuellDocx, auftrag.BauPdf, cancellationToken);

            // Zweites Mal fragen: Während der Wandlung kann ein neuer Lauf die
            // .docx im Ablageordner ersetzt haben. Dieses PDF wäre dann genau
            // die Fassung von gestern, die §6.2 verbietet.
            if (Ueberholt(auftrag)) return;

            fehler = ablage.Ablegen(auftrag.Ablage, auftrag.BauPdf, fehler, auftrag.Stand);
            if (fehler is null) stand.Schreiben(auftrag.Stand with { PdfGeschrieben = true });

            await MeldeAsync(auftrag, fehler, cancellationToken);
        }
        catch (OperationCanceledException)
        {
            logger.LogInformation("Register-Spiegel: PDF-Fassung beim Herunterfahren abgebrochen.");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Register-Spiegel: PDF-Fassung unerwartet fehlgeschlagen.");
        }
        finally
        {
            bauordner.Aufraeumen(auftrag.QuellDocx, auftrag.BauPdf);
        }
    }

    /// <summary>
    /// Ob ein neuerer Lauf den Bestand im Ablageordner schon ersetzt hat.
    ///
    /// Verglichen werden Fingerabdruck und Ziel und <em>nicht</em> der
    /// Zeitpunkt: Zwei erzwungene Läufe über denselben Bestand schreiben
    /// dieselbe Datei, und dann ist jedes der beiden PDFs richtig.
    ///
    /// Ein Stand, der gar nicht gelesen werden kann, gilt <b>nicht</b> als
    /// überholt. Er ist eine Merkdatei, kein Nachweis — sie kann verloren
    /// gegangen sein (neuer Rechner, eingespielte Sicherung) oder gerade nicht
    /// beschreibbar gewesen sein. Daran das PDF scheitern zu lassen, wäre die
    /// unnötigere Richtung: Ein PDF zu viel neben der eigenen .docx ist
    /// harmlos, ein fehlendes nicht.
    /// </summary>
    bool Ueberholt(RegisterPdfAuftrag auftrag)
    {
        var letzter = stand.Lesen();
        if (letzter is null) return false;

        var ueberholt = letzter.Fingerabdruck != auftrag.Stand.Fingerabdruck
            || !string.Equals(letzter.Ziel, auftrag.Stand.Ziel, StringComparison.OrdinalIgnoreCase);
        if (ueberholt)
        {
            logger.LogInformation(
                "Register-Spiegel: PDF-Auftrag übersprungen, ein neuerer Lauf hat den Bestand ersetzt.");
        }

        return ueberholt;
    }

    /// <summary>
    /// Weckt die Oberfläche. Best effort wie beim Postfach: Schlägt der Push
    /// fehl, ist die Datei trotzdem geschrieben — die Seite sieht es beim
    /// nächsten Öffnen.
    /// </summary>
    async Task MeldeAsync(RegisterPdfAuftrag auftrag, string? fehler, CancellationToken cancellationToken)
    {
        var meldung = new RegisterHub.PdfMeldung(
            Fertig: fehler is null,
            PdfPfad: fehler is null ? auftrag.Ablage.Pdf : null,
            Fehler: fehler);

        try
        {
            await hub.Clients.All.SendAsync(RegisterHub.PdfFertigEvent, meldung, cancellationToken);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogDebug(ex, "SignalR-Push '{Ereignis}' fehlgeschlagen (unkritisch).", RegisterHub.PdfFertigEvent);
        }
    }
}
