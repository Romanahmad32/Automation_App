using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Services;
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
/// </summary>
public sealed class RegisterSpiegelUmgebung : IDisposable
{
    readonly SqliteConnection _verbindung;

    public RegisterSpiegelUmgebung()
    {
        _verbindung = new SqliteConnection("DataSource=:memory:");
        _verbindung.Open();
        Db = new AutomationDbContext(new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_verbindung).Options);
        Db.Database.EnsureCreated();
        StandDatei = Path.Combine(Bau, "stand.json");
    }

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
    /// Ein frischer Dienst je Aufruf — der Betrieb baut ihn je Anfrage neu, und
    /// ein zwischen zwei Läufen weitergereichter Zustand würde hier stillschweigend
    /// etwas prüfen, das es im Dienst nicht gibt.
    /// </summary>
    public RegisterSpiegelService Dienst() => new(
        Db,
        Pdf,
        new RegisterSpiegelStand(StandDatei),
        new RegisterSpiegelBauordner(Bau),
        NullLogger<RegisterSpiegelService>.Instance);

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

    public void Dispose()
    {
        Db.Dispose();
        _verbindung.Dispose();
        // Der Spiegel setzt seine Dateien schreibgeschützt; ohne das Zurücknehmen
        // scheitert das Aufräumen an der eigenen Vorsichtsmassnahme.
        foreach (var datei in Directory.EnumerateFiles(Ablage)) AtomareAblage.SchreibschutzLoesen(datei);
        Directory.Delete(Ablage, recursive: true);
        Directory.Delete(Bau, recursive: true);
    }
}
