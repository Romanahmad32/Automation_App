using System.Text.Json.Nodes;
using AutomationService.Features.FormTemplates.Domain.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Core.Persistence.HostedServices;

/// <summary>
/// Einmaliger Übergangsimport: liest die früheren JSON-Speicher der Flutter-App
/// (kanzlei_settings, mandanten, form_templates, zentralruf_vorgaenge) in die
/// SQLite-Datenbank ein. Läuft nach dem Migrationsdienst beim Start.
///
/// Doppelt abgesichert idempotent: pro Tabelle nur, wenn sie noch leer ist, und
/// die Quelldatei wird nach Erfolg zu <c>*.imported.bak</c> umbenannt (nie
/// gelöscht — die Altdaten bleiben als Sicherung erhalten). Ein zweiter Start
/// findet weder leere Tabellen noch die Quelldateien und tut nichts.
///
/// Bewusst hier in Core/Persistence statt in den Feature-Slices: die Kenntnis
/// der alten JSON-Schemata ist eine vorübergehende Migrationssache, die nach dem
/// Umstieg gelöscht wird — sie soll die sauberen Feature-Slices nicht belasten.
/// </summary>
public sealed class LegacyJsonImportService(
    IServiceScopeFactory scopeFactory,
    IConfiguration configuration,
    ILogger<LegacyJsonImportService> logger) : IHostedService
{
    public async Task StartAsync(CancellationToken cancellationToken)
    {
        // Bewusst per Default AUS: Solange das Frontend noch aus den JSON-Dateien
        // liest (Umstellung der Datasources steht noch aus), würde ein Import die
        // Live-Daten zu *.imported.bak umbenennen und dem Frontend den Stand
        // entziehen. Erst beim Cutover (Frontend liest nur noch über HTTP) wird
        // LegacyImport:Enabled=true gesetzt; danach läuft der Import genau einmal.
        if (!configuration.GetValue("LegacyImport:Enabled", false))
        {
            logger.LogInformation("Legacy-Import deaktiviert (LegacyImport:Enabled=false).");
            return;
        }

        var sourceDirectory = ResolveSourceDirectory();
        if (!Directory.Exists(sourceDirectory))
        {
            logger.LogInformation(
                "Kein Alt-Datenstand unter {Dir} — Import übersprungen.", sourceDirectory);
            return;
        }

        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AutomationDbContext>();

        try
        {
            await ImportSettingsAsync(db, sourceDirectory, cancellationToken);
            await ImportMandantenAsync(db, sourceDirectory, cancellationToken);
            await ImportFormTemplatesAsync(db, sourceDirectory, cancellationToken);
            await ImportVorgaengeAsync(db, sourceDirectory, cancellationToken);
        }
        catch (Exception exception)
        {
            // Der Import darf den Start nicht blockieren: Fehlschlag wird geloggt,
            // die Altdateien bleiben unangetastet und der Anwalt kann die Daten
            // notfalls neu erfassen.
            logger.LogError(exception, "Legacy-Import fehlgeschlagen (unkritisch für den Start).");
        }
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    /// <summary>Quellordner der Alt-JSONs: konfigurierbar, sonst der Flutter-Standardpfad.</summary>
    string ResolveSourceDirectory()
    {
        var configured = configuration["LegacyImport:SourceDirectory"];
        if (!string.IsNullOrWhiteSpace(configured)) return configured;

        // path_provider (Windows) legt unter <Roaming>\<Company>\<Product> ab;
        // die Flutter-App nutzt die Default-Kennung com.example\automation_app.
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "com.example", "automation_app");
    }

    async Task ImportSettingsAsync(AutomationDbContext db, string dir, CancellationToken ct)
    {
        if (await db.KanzleiSettings.AnyAsync(ct)) return;
        if (ReadJson(dir, "kanzlei_settings.json") is not JsonObject obj) return;

        db.KanzleiSettings.Add(new KanzleiSettingsEntity
        {
            Id = KanzleiSettingsEntity.SingletonId,
            Personentyp = (string?)obj["personentyp"] ?? string.Empty,
            Name = (string?)obj["name"] ?? string.Empty,
            StrasseHausnummer = (string?)obj["strasseHausnummer"] ?? string.Empty,
            Postleitzahl = (string?)obj["postleitzahl"] ?? string.Empty,
            Ort = (string?)obj["ort"] ?? string.Empty,
            EmailAdresse = (string?)obj["emailAdresse"] ?? string.Empty,
            Telefonnummer = (string?)obj["telefonnummer"] ?? string.Empty,
            LaufendeAuftragsnummer = (int?)obj["laufendeAuftragsnummer"] ?? 1,
            Abteilung = (string?)obj["abteilung"] ?? string.Empty,
            TabellenkopfFarbeHex = (string?)obj["tabellenkopfFarbeHex"] ?? string.Empty,
            AktenStammordner = (string?)obj["aktenStammordner"] ?? string.Empty,
        });
        await db.SaveChangesAsync(ct);
        Archive(dir, "kanzlei_settings.json");
        logger.LogInformation("Kanzlei-Einstellungen importiert.");
    }

    async Task ImportMandantenAsync(AutomationDbContext db, string dir, CancellationToken ct)
    {
        if (await db.Mandanten.AnyAsync(ct)) return;
        if (ReadJson(dir, "mandanten.json") is not JsonArray array) return;

        foreach (var node in array.OfType<JsonObject>())
        {
            db.Mandanten.Add(new MandantEntity
            {
                Id = (int?)node["id"] ?? 0,
                Anrede = (string?)node["anrede"] ?? string.Empty,
                Vorname = (string?)node["vorname"] ?? string.Empty,
                Nachname = (string?)node["nachname"] ?? string.Empty,
                StrasseHausnummer = (string?)node["strasseHausnummer"] ?? string.Empty,
                Postleitzahl = (string?)node["postleitzahl"] ?? string.Empty,
                Ort = (string?)node["ort"] ?? string.Empty,
                EmailAdresse = (string?)node["emailAdresse"] ?? string.Empty,
                Telefonnummer = (string?)node["telefonnummer"] ?? string.Empty,
                Notiz = (string?)node["notiz"] ?? string.Empty,
                ErstelltAm = ParseDate(node["erstelltAm"]) ?? DateTime.UnixEpoch,
                AktenOrdnernamenJson = node["aktenOrdnernamen"]?.ToJsonString() ?? "[]",
                KennzeichenJson = node["kennzeichen"]?.ToJsonString() ?? "[]",
            });
        }
        await db.SaveChangesAsync(ct);
        Archive(dir, "mandanten.json");
        logger.LogInformation("{Count} Mandanten importiert.", array.Count);
    }

    async Task ImportFormTemplatesAsync(AutomationDbContext db, string dir, CancellationToken ct)
    {
        if (await db.FormTemplates.AnyAsync(ct)) return;
        if (ReadJson(dir, "form_templates.json") is not JsonArray array) return;

        foreach (var node in array.OfType<JsonObject>())
        {
            db.FormTemplates.Add(new FormTemplateEntity
            {
                Id = (int?)node["id"] ?? 0,
                TemplateName = (string?)node["templateName"] ?? string.Empty,
                FieldsJson = node["fields"]?.ToJsonString() ?? "[]",
                WordFilePathOhneAuflistung = (string?)node["wordFilePathOhneAuflistung"],
                WordFilePathMitAuflistung = (string?)node["wordFilePathMitAuflistung"],
            });
        }
        await db.SaveChangesAsync(ct);
        Archive(dir, "form_templates.json");
        logger.LogInformation("{Count} Formularvorlagen importiert.", array.Count);
    }

    async Task ImportVorgaengeAsync(AutomationDbContext db, string dir, CancellationToken ct)
    {
        if (await db.Vorgaenge.AnyAsync(ct)) return;
        if (ReadJson(dir, "zentralruf_vorgaenge.json") is not JsonObject store) return;

        // Bevorzugt das bereits migrierte `vorgaenge`-Array; fehlt es (sehr alter
        // Stand), werden minimale Vorgänge aus den offenen Anfragen abgeleitet.
        var liste = store["vorgaenge"] as JsonArray;
        if (liste is { Count: > 0 })
        {
            foreach (var node in liste.OfType<JsonObject>())
            {
                db.Vorgaenge.Add(MapVorgang(node));
            }
        }
        else if (store["offeneAnfragen"] is JsonArray offene)
        {
            foreach (var node in offene.OfType<JsonObject>())
            {
                db.Vorgaenge.Add(new VorgangEntity
                {
                    Referenz = (string?)node["referenz"] ?? string.Empty,
                    AngefragtAm = ParseDate(node["angefragtAm"]) ?? DateTime.UnixEpoch,
                    Status = "angefragt",
                    Rechtsgebiet = "verkehrsrecht",
                });
            }
        }

        await db.SaveChangesAsync(ct);
        Archive(dir, "zentralruf_vorgaenge.json");
        logger.LogInformation("{Count} Vorgänge importiert.", await db.Vorgaenge.CountAsync(ct));
    }

    static VorgangEntity MapVorgang(JsonObject node) => new()
    {
        Referenz = (string?)node["referenz"] ?? string.Empty,
        AngefragtAm = ParseDate(node["angefragtAm"]) ?? DateTime.UnixEpoch,
        Status = (string?)node["status"] ?? "angefragt",
        Rechtsgebiet = (string?)node["rechtsgebiet"] ?? "verkehrsrecht",
        LaufendeNummer = (int?)node["laufendeNummer"],
        Jahr = (string?)node["jahr"],
        Abteilung = (string?)node["abteilung"],
        Kennzeichen = (string?)node["kennzeichen"],
        MandantId = (int?)node["mandantId"],
        MandantName = (string?)node["mandantName"],
        Gegner = (string?)node["gegner"],
        UnfallDatum = (string?)node["unfallDatum"],
        GeschaedigtenKennzeichen = (string?)node["geschaedigtenKennzeichen"],
        Unfallort = (string?)node["unfallort"],
        Unfalluhrzeit = (string?)node["unfalluhrzeit"],
        PolizeiVorgangsnummer = (string?)node["polizeiVorgangsnummer"],
        AntwortJson = node["antwort"] is JsonObject antwort ? antwort.ToJsonString() : null,
        DokumentPfad = (string?)node["dokumentPfad"],
        AktenOrdner = (string?)node["aktenOrdner"],
        AbgeschlossenAm = ParseDate(node["abgeschlossenAm"]),
    };

    static JsonNode? ReadJson(string dir, string fileName)
    {
        var path = Path.Combine(dir, fileName);
        if (!File.Exists(path)) return null;
        try
        {
            return JsonNode.Parse(File.ReadAllText(path));
        }
        catch
        {
            return null;
        }
    }

    static DateTime? ParseDate(JsonNode? node)
    {
        var text = (string?)node;
        return DateTime.TryParse(text, out var value) ? value : null;
    }

    static void Archive(string dir, string fileName)
    {
        var path = Path.Combine(dir, fileName);
        if (!File.Exists(path)) return;
        var destination = path + ".imported.bak";
        if (File.Exists(destination)) File.Delete(destination);
        File.Move(path, destination);
    }
}
