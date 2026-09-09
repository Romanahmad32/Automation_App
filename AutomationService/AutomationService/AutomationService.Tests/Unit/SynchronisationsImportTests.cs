using System.IO.Compression;
using System.Text.Json;
using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Features.MailboxMonitor.Domain.Persistence;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

public class SynchronisationsImportTests
{
    [Fact]
    public async Task Mailanhang_kommt_mit_und_verweist_auf_den_Zielrechner()
    {
        using var quelle = new SynchronisationsUmgebung();
        using var ziel = new SynchronisationsUmgebung();
        await quelle.Initialisiere();
        await ziel.Initialisiere();
        var pfad = Path.Combine(quelle.Wurzel, "Anhaenge", "antwort", "Schaden.pdf");
        Directory.CreateDirectory(Path.GetDirectoryName(pfad)!);
        await File.WriteAllTextAsync(pfad, "Anhanginhalt");
        await using (var db = quelle.Kontext())
        {
            db.ReceivedReplies.Add(new ReceivedReplyEntity
            {
                DedupeKey = "antwort-1",
                EmpfangenAm = DateTime.Now,
                AnhaengeJson = JsonSerializer.Serialize(new[] { pfad }),
            });
            await db.SaveChangesAsync();
        }
        var archiv = await quelle.Sicherung.CreateBackupFileAsync();
        try
        {
            await using var strom = File.OpenRead(archiv);
            await ziel.Sicherung.ImportBackupAsync(strom);
            await using var db = ziel.Kontext();
            var antwort = await db.ReceivedReplies.SingleAsync();
            var anhang = JsonSerializer.Deserialize<string[]>(antwort.AnhaengeJson!)!.Single();
            anhang.Should().StartWith(ziel.Wurzel);
            (await File.ReadAllTextAsync(anhang)).Should().Be("Anhanginhalt");
        }
        finally { File.Delete(archiv); }
    }

    [Fact]
    public async Task Falsche_Pruefsumme_laesst_die_vorhandene_Datenbank_unberuehrt()
    {
        using var env = new SynchronisationsUmgebung();
        await env.Initialisiere();
        await File.WriteAllTextAsync(Path.Combine(env.Vorlagen, "Brief.docx"), "Original");
        var archiv = await env.Sicherung.CreateBackupFileAsync();
        try
        {
            using (var zip = ZipFile.Open(archiv, ZipArchiveMode.Update))
            {
                zip.GetEntry("Vorlagen/Brief.docx")!.Delete();
                using var writer = new StreamWriter(zip.CreateEntry("Vorlagen/Brief.docx").Open());
                writer.Write("beschädigt");
            }
            await env.Mandant("Nicht verlieren");
            await using var strom = File.OpenRead(archiv);
            var import = () => env.Sicherung.ImportBackupAsync(strom);
            await import.Should().ThrowAsync<InvalidBackupException>();
            await using var db = env.Kontext();
            (await db.Mandanten.SingleAsync()).Nachname.Should().Be("Nicht verlieren");
        }
        finally { File.Delete(archiv); }
    }

    [Fact]
    public async Task Fehlende_Datei_laesst_keine_unvollstaendige_Sicherung_entstehen()
    {
        using var env = new SynchronisationsUmgebung();
        await env.Initialisiere();
        await using (var db = env.Kontext())
        {
            db.ReceivedReplies.Add(new ReceivedReplyEntity
            {
                DedupeKey = "fehlt",
                EmpfangenAm = DateTime.Now,
                AnhaengeJson = JsonSerializer.Serialize(new[] { Path.Combine(env.Wurzel, "Anhaenge", "fehlt.pdf") }),
            });
            await db.SaveChangesAsync();
        }
        var ergebnis = await env.Automatik.SchreibeAsync();
        ergebnis!.Gelungen.Should().BeFalse();
        Directory.GetFiles(env.Ablage, "*.zip").Should().BeEmpty();
    }

    [Fact]
    public async Task Ein_vor_dem_Import_geladener_Kontext_darf_nicht_danach_speichern()
    {
        using var env = new SynchronisationsUmgebung();
        await env.Initialisiere();
        await env.Mandant("Original");
        var archiv = await env.Sicherung.CreateBackupFileAsync();
        try
        {
            await using var alterKontext = env.Kontext();
            var mandant = await alterKontext.Mandanten.SingleAsync();
            await using var strom = File.OpenRead(archiv);
            await env.Sicherung.ImportBackupAsync(strom);
            mandant.Nachname = "Veraltetes Formular";
            var speichern = () => alterKontext.SaveChangesAsync();
            await speichern.Should().ThrowAsync<InvalidOperationException>();
            await using var neu = env.Kontext();
            (await neu.Mandanten.SingleAsync()).Nachname.Should().Be("Original");
        }
        finally { File.Delete(archiv); }
    }

    [Fact]
    public void Pfade_ausserhalb_des_Archivs_werden_abgewiesen()
    {
        using var env = new SynchronisationsUmgebung();
        var pfad = Path.Combine(env.Wurzel, "boese.zip");
        using (var zip = ZipFile.Open(pfad, ZipArchiveMode.Create))
        {
            using var writer = new StreamWriter(zip.CreateEntry("../ausbruch.txt").Open());
            writer.Write("nicht extrahieren");
        }
        var entpacken = () => ArchivPruefung.EntpackeGeprueft(pfad, Path.Combine(env.Wurzel, "entpackt"));
        entpacken.Should().Throw<InvalidBackupException>();
        File.Exists(Path.Combine(env.Wurzel, "ausbruch.txt")).Should().BeFalse();
    }
}
