using AutomationService.Core.Ablage;
using AutomationService.Core.Persistence;
using AutomationService.Features.RegisterHistorie.Domain.Persistence;
using AutomationService.Features.Sachgebiete.Domain.Services;
using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Features.Vorgaenge.Presentation.HostedServices;
using RegisterHistorieDienst = AutomationService.Features.RegisterHistorie.Domain.Services.RegisterHistorie;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace AutomationService.Tests.Support;

/// <summary>
/// Die Umgebung, in der der Register-Spiegel geprüft wird: eine echte
/// In-Memory-SQLite, ein echter Ablageordner, ein echter Bauordner.
///
/// Echt und nicht nachgebildet, weil die Zusicherungen des Spiegels am
/// Dateisystem hängen — atomares Ersetzen, Schreibschutz, „kein Zwischenstand
/// im Ablageordner". Gegen eine Dateisystem-Attrappe geprüft, bewiese der Test
/// nur, dass die Attrappe tut, was der Test erwartet.
///
/// Herausgelöst, als die PDF-Fälle eine eigene Testklasse bekamen: Zwei
/// Fassungen desselben Aufbaus hätten sich beim ersten Nachbessern
/// auseinanderentwickelt.
///
/// Seit §6.2 („Word sofort, PDF nachgezogen") sind es <b>zwei</b> Schritte:
/// <c>Dienst().SchreibeAsync()</c> schreibt die .docx und reiht die Wandlung
/// ein, <see cref="PdfNachziehenAsync"/> arbeitet sie ab. Der
/// Hintergrunddienst wird hier absichtlich nicht gestartet — nur so lässt sich
/// der Zwischenzustand prüfen, und nur so wartet kein Test auf einen Planer.
/// Wer die Ausgangslage „vollständiger Spiegel" braucht, nimmt
/// <see cref="VollstaendigSchreibenAsync"/>.
/// </summary>
public sealed class RegisterSpiegelUmgebung : IDisposable
{
    /// <summary>
    /// Hält die In-Memory-Datenbank am Leben. Sie verschwindet, sobald die
    /// letzte Verbindung zu ihr schliesst — und da jeder Dienst hier seine
    /// eigene bekommt, muss eine offen bleiben, die niemand sonst anfasst.
    /// </summary>
    readonly SqliteConnection _dauerhaft;

    readonly string _verbindungstext;

    /// <summary>Die Contexts der Dienste, damit sie am Ende zugehen.</summary>
    readonly List<AutomationDbContext> _contexts = [];

    public RegisterSpiegelUmgebung()
    {
        _verbindungstext = $"DataSource=register-{Guid.NewGuid():N};Mode=Memory;Cache=Shared";
        _dauerhaft = new SqliteConnection(_verbindungstext);
        _dauerhaft.Open();

        Db = NeuerContext();
        Db.Database.EnsureCreated();
        StandDatei = Path.Combine(Bau, "stand.json");

        // Stand und Bauordner sind im Betrieb Singletons und werden hier
        // genauso gehalten: Der Stand trägt ein Schloss, das nur schützt, wenn
        // sich alle Läufe dasselbe Exemplar teilen.
        Stand = new RegisterSpiegelStand(StandDatei);
        Bauordner = new RegisterSpiegelBauordner(Bau);
        Bremse = new WarteschlangeMitBremse(Warteschlange);
        Nachzug = new RegisterPdfNachzug(
            Warteschlange,
            Pdf,
            Stand,
            Bauordner,
            Hub,
            NullLogger<RegisterPdfNachzug>.Instance);
    }

    /// <summary>Zum Einrichten der Ausgangslage — nicht der Context der Dienste.</summary>
    public AutomationDbContext Db { get; }

    public PdfAttrappe Pdf { get; } = new();

    public string Ablage { get; } = Directory.CreateTempSubdirectory("register-ablage").FullName;

    /// <summary>
    /// Liegt bewusst außerhalb von <see cref="Ablage"/> — genau wie im Betrieb,
    /// wo ein Synchronisierungsdienst sonst die halbfertige Datei sähe.
    /// </summary>
    public string Bau { get; } = Directory.CreateTempSubdirectory("register-bau").FullName;

    /// <summary>Die Merkdatei; liegt beim Bauordner und nicht in der Ablage.</summary>
    public string StandDatei { get; }

    public string DocxPfad => Path.Combine(Ablage, $"{RegisterSpiegelVorgabe.Dateiname}.docx");

    public string PdfPfad => Path.Combine(Ablage, $"{RegisterSpiegelVorgabe.Dateiname}.pdf");

    /// <summary>
    /// Die Schleuse ist im Betrieb ein Singleton — sonst schleust sie nichts.
    /// Deshalb hält die Umgebung eine und gibt sie jedem Dienst mit.
    /// </summary>
    public RegisterSpiegelSchleuse Schleuse { get; } = new();

    /// <summary>
    /// Die echte Warteschlange. Ein Singleton wie im Betrieb: Ein zweites
    /// Exemplar hiesse, in den einen Kanal einzureihen und aus dem anderen
    /// abzuarbeiten.
    /// </summary>
    public RegisterPdfWarteschlange Warteschlange { get; } = new();

    /// <summary>
    /// Der Weg, den die Dienste nehmen — die echte Warteschlange hinter einer
    /// Bremse, die im Regelfall nichts bremst (siehe
    /// <see cref="WarteschlangeMitBremse"/>).
    /// </summary>
    public WarteschlangeMitBremse Bremse { get; }

    public RegisterHubAttrappe Hub { get; } = new();

    public RegisterSpiegelStand Stand { get; }

    public RegisterSpiegelBauordner Bauordner { get; }

    /// <summary>
    /// Der Nachzug, der die eingereihten PDF-Aufträge abarbeitet — hier
    /// <b>nicht</b> als Hintergrunddienst gestartet, sondern von Hand
    /// ausgelöst (<see cref="PdfNachziehenAsync"/>). Nur so lässt sich der
    /// Zwischenzustand prüfen, um den es in §6.2 geht: die .docx liegt, das PDF
    /// noch nicht.
    /// </summary>
    public RegisterPdfNachzug Nachzug { get; }

    /// <summary>
    /// Arbeitet ab, was gerade eingereiht ist — der Ersatz für das Warten auf
    /// einen Hintergrunddienst.
    /// </summary>
    /// <returns>Wie viele PDF-Aufträge abgearbeitet wurden.</returns>
    public Task<int> PdfNachziehenAsync() => Nachzug.AlleAbarbeitenAsync();

    /// <summary>
    /// Schreiben <em>und</em> die PDF-Fassung nachziehen — der Zustand, den ein
    /// Test als Ausgangslage meint, wenn er „es liegt ein vollständiger
    /// Spiegel" braucht. Seit §6.2 sind das zwei Schritte, und wer nur den
    /// ersten macht, richtet eine Ausgangslage ohne PDF ein.
    /// </summary>
    public async Task<RegisterSpiegelErgebnis> VollstaendigSchreibenAsync(bool erzwingen = false)
    {
        var ergebnis = await Dienst().SchreibeAsync(erzwingen);
        await PdfNachziehenAsync();
        return ergebnis;
    }

    /// <summary>
    /// Ein frischer Dienst je Aufruf, mit einem <b>eigenen</b> DbContext — wie
    /// im Betrieb, wo er je Anfrage neu gebaut wird und der Context am
    /// Anfrage-Scope hängt.
    ///
    /// Der eigene Context ist nicht Ordnungsliebe, sondern Voraussetzung: Zwei
    /// Läufe über denselben Context scheitern schon an EF Core („A second
    /// operation was started on this context instance"), lange bevor sie sich
    /// am Zielort treffen könnten. Die Nebenläufigkeitstests prüften dann eine
    /// Kollision, die es im Betrieb gar nicht gibt.
    /// </summary>
    public RegisterSpiegelService Dienst()
    {
        var context = NeuerContext();
        _contexts.Add(context);
        return new RegisterSpiegelService(
            context,
            Bremse,
            new RegisterHistorieDienst(context, new SachgebietKatalog(context)),
            Stand,
            Bauordner,
            Schleuse,
            NullLogger<RegisterSpiegelService>.Instance);
    }

    public async Task EinstellungenAnlegen(string? ordner = null, string filter = "alle")
    {
        var einstellungen = KanzleiSettingsRepository.CreateDefault();
        einstellungen.RegisterAblageOrdner = ordner ?? Ablage;
        einstellungen.RegisterExportFilter = filter;
        Db.KanzleiSettings.Add(einstellungen);
        await Db.SaveChangesAsync();
    }

    public async Task VorgangAnlegen(string referenz, int nummer, string status = "versendet")
    {
        Db.Vorgaenge.Add(new VorgangEntity
        {
            Referenz = referenz,
            Status = status,
            Rechtsgebiet = "verkehrsrecht",
            LaufendeNummer = nummer,
            Jahr = "26",
            Abteilung = "C03",
            MandantName = "Mustermann",
            Gegner = "HUK",
            AngefragtAm = new DateTime(2026, 1, 5),
        });
        await Db.SaveChangesAsync();
    }

    /// <summary>
    /// Eine übernommene Zeile des gewachsenen Kanzleiregisters — die zweite
    /// Quelle des Spiegels (§6.2). Sie zählt immer mit: Eine historische Zeile
    /// ist per Herkunft abgeschlossen und fällt unter keinen Dateifilter.
    /// </summary>
    public async Task HistorieAnlegen(int jahr, int nummer)
    {
        Db.RegisterHistorie.Add(new RegisterHistorieEntity
        {
            Kennung = Guid.NewGuid().ToString(),
            Jahr = jahr,
            LaufendeNummer = nummer,
            Aktenzeichen = $"{nummer:00}/{jahr % 100:00}",
            Abteilung = "C03",
            AbteilungRoh = "C03",
            Mandant = "Mustermann",
            Gegner = "HUK",
            Rechtsgebiet = "Verkehrsrecht",
            Sicherheit = "hoch",
            ImportiertAm = new DateTime(2026, 1, 5),
        });
        await Db.SaveChangesAsync();
    }

    /// <summary>
    /// Nimmt der Datenschicht den Boden weg — jeder Zugriff auf die Vorgänge
    /// scheitert danach. Steht für alles, womit beim Schreiben nicht gerechnet
    /// wurde; geprüft wird nicht der einzelne Auslöser, sondern dass keiner als
    /// Ausnahme nach oben durchschlägt.
    /// </summary>
    public Task DatenschichtAusfallenLassen() =>
        Db.Database.ExecuteSqlRawAsync("DROP TABLE Vorgaenge");

    AutomationDbContext NeuerContext() => new(
        new DbContextOptionsBuilder<AutomationDbContext>().UseSqlite(_verbindungstext).Options);

    public void Dispose()
    {
        foreach (var context in _contexts) context.Dispose();
        Db.Dispose();
        _dauerhaft.Dispose();
        Schleuse.Dispose();
        // Der Spiegel setzt seine Dateien schreibgeschützt; ohne das Zurücknehmen
        // scheitert das Aufräumen an der eigenen Vorsichtsmassnahme.
        foreach (var datei in Directory.EnumerateFiles(Ablage)) AtomareAblage.SchreibschutzLoesen(datei);
        Directory.Delete(Ablage, recursive: true);
        Directory.Delete(Bau, recursive: true);
    }
}
