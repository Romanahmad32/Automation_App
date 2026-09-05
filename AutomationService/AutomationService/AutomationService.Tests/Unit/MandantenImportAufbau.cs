using AutomationService.Core.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using AutomationService.Features.Mandanten.Domain.Services;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Gemeinsamer Aufbau der Importtests: eine echte In-Memory-SQLite, das Register
/// und die Vermerke daneben. Ein Import bewegt beide Tabellen — gegen einen
/// Attrappen-Kontext geprüft bliebe gerade das ungeprüft, worauf es ankommt:
/// dass Zuordnung und Vermerk sich nicht widersprechen.
/// </summary>
public sealed class MandantenImportAufbau : IDisposable
{
    readonly SqliteConnection _verbindung;

    public AutomationDbContext Db { get; }

    public OrdnerStatusRegister OrdnerStatus { get; }

    public MandantenRepository Register { get; }

    /// <summary>
    /// Die Paket-Buchführung an derselben Datenbank. Sie hängt am Import, weil
    /// ein Schreiblauf offene Pakete schließt — geprüft wird das über die
    /// echten Tabellen und nicht über eine Attrappe, denn die Frage lautet
    /// gerade, ob Zuordnung, Vermerk und Paket denselben Ordner meinen.
    /// </summary>
    public ImportPaketBuch PaketBuch { get; }

    public MandantenImport Import { get; }

    public MandantenImportAufbau()
    {
        _verbindung = new SqliteConnection("DataSource=:memory:");
        _verbindung.Open();
        var optionen = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_verbindung)
            .Options;
        Db = new AutomationDbContext(optionen);
        Db.Database.EnsureCreated();
        OrdnerStatus = new OrdnerStatusRegister(Db);
        Register = new MandantenRepository(Db);
        PaketBuch = new ImportPaketBuch(Db, Register, OrdnerStatus);
        Import = new MandantenImport(
            Db, OrdnerStatus, PaketBuch, NullLogger<MandantenImport>.Instance);
    }

    /// <summary>Ein Mandant, der vor dem Import schon im Register steht.</summary>
    public MandantEntity Vorhanden(
        string vorname,
        string nachname,
        string[]? ordner = null,
        string ort = "",
        string strasse = "")
    {
        var mandant = new MandantEntity
        {
            Id = Db.Mandanten.Any() ? Db.Mandanten.Max(m => m.Id) + 1 : 1,
            Vorname = vorname,
            Nachname = nachname,
            Ort = ort,
            StrasseHausnummer = strasse,
            ErstelltAm = new DateTime(2020, 1, 1),
            AktenOrdnernamenJson = MandantListen.Schreib(ordner ?? []),
        };
        Db.Mandanten.Add(mandant);
        Db.SaveChanges();
        return mandant;
    }

    /// <summary>
    /// Eine Zeile der Importdatei. Die 13 Felder einzeln hinzuschreiben würde
    /// jeden Test darüber reden lassen, was er gerade *nicht* prüft.
    /// </summary>
    public static ImportMandant Zeile(
        string vorname,
        string nachname,
        string[]? ordner = null,
        string anrede = "",
        string strasse = "",
        string plz = "",
        string ort = "",
        string email = "",
        string telefon = "",
        string notiz = "",
        string[]? kennzeichen = null,
        string quelle = "",
        string sicherheit = "hoch") =>
        new(anrede, vorname, nachname, strasse, plz, ort, email, telefon, notiz,
            ordner ?? [], kennzeichen ?? [], quelle, sicherheit);

    public Task<MandantenImportBefund> Vorschau(
        IEnumerable<ImportMandant> zeilen,
        string[]? ohneBezug = null) =>
        Import.FuehreAusAsync(new MandantenImportAuftrag(
            [.. zeilen], ohneBezug ?? [], NurPruefen: true));

    public Task<MandantenImportBefund> Uebernimm(
        IEnumerable<ImportMandant> zeilen,
        string[]? ohneBezug = null) =>
        Import.FuehreAusAsync(new MandantenImportAuftrag(
            [.. zeilen], ohneBezug ?? [], NurPruefen: false));

    /// <summary>Die Ordner eines Mandanten, frisch aus der Datenbank gelesen.</summary>
    public List<string> OrdnerVon(string nachname)
    {
        var mandant = Db.Mandanten.AsNoTracking().Single(m => m.Nachname == nachname);
        return MandantListen.Lies(mandant.AktenOrdnernamenJson);
    }

    public void Dispose()
    {
        Db.Dispose();
        _verbindung.Dispose();
    }
}
