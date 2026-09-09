using AutomationService.Core.Persistence;
using AutomationService.Features.RegisterHistorie.Domain.Persistence;
using AutomationService.Features.RegisterHistorie.Domain.Services;
using AutomationService.Features.Sachgebiete.Domain.Services;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Gemeinsamer Aufbau der Registerimport-Tests: eine echte In-Memory-SQLite mit
/// dem geseedeten Sachgebietskatalog daneben.
///
/// Echt und nicht nachgebildet, weil der Import an beidem hängt — am
/// Unique-Index über (Jahr, laufende Nummer) und am Katalogabgleich. Gegen eine
/// Attrappe geprüft bliebe gerade das ungeprüft, worauf es ankommt: dass ein
/// zweiter Lauf desselben Jahrgangs die Nacharbeit des Anwalts nicht zerstört.
/// </summary>
public sealed class RegisterImportAufbau : IDisposable
{
    readonly SqliteConnection _verbindung;

    public AutomationDbContext Db { get; }

    public SachgebietKatalog Katalog { get; }

    public RegisterImport Import { get; }

    public RegisterHistorie Historie { get; }

    public RegisterImportAufbau()
    {
        _verbindung = new SqliteConnection("DataSource=:memory:");
        _verbindung.Open();
        var optionen = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_verbindung)
            .Options;
        Db = new AutomationDbContext(optionen);
        // Legt das Schema an und spielt den Katalog-Seed (HasData) mit ein.
        Db.Database.EnsureCreated();
        Katalog = new SachgebietKatalog(Db);
        Import = new RegisterImport(Db, Katalog);
        Historie = new RegisterHistorie(Db, Katalog);
    }

    /// <summary>
    /// Eine Zeile der Importdatei. Die fünfzehn Felder einzeln hinzuschreiben
    /// würde jeden Test darüber reden lassen, was er gerade <em>nicht</em>
    /// prüft. Vorbelegt ist eine vollständige Form A aus dem Verkehrsrecht.
    /// </summary>
    public static ImportRegisterZeile Zeile(
        int nummer,
        string abteilung = "C03",
        string rechtsgebiet = "Verkehrsrecht",
        string? spalte1 = null,
        string nummerZusatz = "",
        string sachart = "",
        string mandant = "Max Mustermann",
        string gegner = "HUK",
        string sachbestand = "Unfall",
        string unfalldatum = "01.01.20",
        string sicherheit = "hoch",
        string[]? hinweise = null,
        string jahr = "20") =>
        new(
            nummer,
            nummerZusatz,
            spalte1 ?? nummer.ToString("00", System.Globalization.CultureInfo.InvariantCulture),
            $"{nummer:00}/{jahr}{nummerZusatz}",
            abteilung,
            abteilung,
            sachart,
            mandant,
            gegner,
            sachbestand,
            unfalldatum,
            rechtsgebiet,
            $"{nummer:00}/{jahr} {abteilung} {mandant}",
            sicherheit,
            hinweise ?? []);

    public Task<RegisterImportBefund> Vorschau(int jahrgang, params ImportRegisterZeile[] zeilen) =>
        Import.FuehreAusAsync(new RegisterImportAuftrag(
            [new ImportJahrgang(jahrgang, zeilen)], NurPruefen: true));

    public Task<RegisterImportBefund> Uebernimm(int jahrgang, params ImportRegisterZeile[] zeilen) =>
        Import.FuehreAusAsync(new RegisterImportAuftrag(
            [new ImportJahrgang(jahrgang, zeilen)], NurPruefen: false));

    public Task<RegisterImportBefund> Uebernimm(params ImportJahrgang[] jahrgaenge) =>
        Import.FuehreAusAsync(new RegisterImportAuftrag(jahrgaenge, NurPruefen: false));

    /// <summary>
    /// Eine gespeicherte Zeile, frisch aus der Datenbank gelesen. Angesprochen
    /// über den natürlichen Schlüssel samt Zusatz — „10/19" und „10/19-I" sind
    /// zwei Akten.
    /// </summary>
    public RegisterHistorieEntity Gespeichert(int jahr, int nummer, string zusatz = "") => Db.RegisterHistorie
        .AsNoTracking()
        .Single(zeile => zeile.Jahr == jahr && zeile.LaufendeNummer == nummer && zeile.NummerZusatz == zusatz);

    public void Dispose()
    {
        Db.Dispose();
        _verbindung.Dispose();
    }
}
