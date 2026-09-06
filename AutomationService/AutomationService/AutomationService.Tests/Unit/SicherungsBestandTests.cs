using AutomationService.Features.Backup.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Auskunft über die eigenen Archive im Ablageordner (#112) — „27
/// Sicherungen dieses Rechners, älteste vom 12.03.2026".
///
/// Gezählt wird über den Dateinamen und nicht über das Änderungsdatum: Der
/// Synchronisierungsdienst setzt dieses beim Herunterladen neu, und die Anzeige
/// soll denselben Zeitpunkt nennen, nach dem auch aufgeräumt wird.
/// </summary>
public sealed class SicherungsBestandTests : IDisposable
{
    const string Rechner = "BUERO-PC";

    readonly string _ordner;

    public SicherungsBestandTests()
    {
        _ordner = Path.Combine(Path.GetTempPath(), "bestand-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_ordner);
    }

    [Fact]
    public void Gezaehlt_werden_nur_die_eigenen_lesbaren_Archive()
    {
        Lege("automation-BUERO-PC-20260301-080000.zip");
        Lege("automation-BUERO-PC-20260315-093000.zip");
        Lege("automation-BUERO-PC-20260320-171500.zip");
        Lege("automation-LAPTOP-20260325-120000.zip");
        Lege("automation-BUERO-PC-20260318-120000 - Kopie.zip");

        var bestand = SicherungsBestand.Lies(_ordner, Rechner);

        bestand.Anzahl.Should().Be(3, "das fremde und das umbenannte Archiv zählen nicht mit");
        bestand.Aeltestes.Should().Be(new DateTime(2026, 3, 1, 8, 0, 0, DateTimeKind.Unspecified));
        bestand.Neuestes.Should().Be(new DateTime(2026, 3, 20, 17, 15, 0, DateTimeKind.Unspecified));
    }

    [Fact]
    public void Ein_leerer_Ordner_meldet_den_leeren_Bestand() =>
        SicherungsBestand.Lies(_ordner, Rechner).Should().Be(SicherungsBestand.Leer);

    /// <summary>
    /// Der Ablageordner liegt im OneDrive des Anwalts und kann getrennt oder
    /// umbenannt sein. Eine Auskunft, die dann wirft, nähme dem Reiter
    /// „Datensicherung" auch die Meldung, warum die Sicherung scheitert.
    /// </summary>
    [Fact]
    public void Ein_fehlender_Ordner_wirft_nicht()
    {
        var weg = Path.Combine(_ordner, "nicht-da");

        SicherungsBestand.Lies(weg, Rechner).Should().Be(SicherungsBestand.Leer);
    }

    [Fact]
    public void Ohne_eingestellten_Ordner_bleibt_der_Bestand_leer() =>
        SicherungsBestand.Lies(string.Empty, Rechner).Should().Be(SicherungsBestand.Leer);

    /// <summary>
    /// Dieselbe Liste ist die Vorlage für das Aufräumen — sie muss deshalb den
    /// vollen Pfad tragen, nicht nur den Namen.
    /// </summary>
    [Fact]
    public void Die_Archivliste_traegt_Pfad_und_Zeitpunkt()
    {
        Lege("automation-BUERO-PC-20260301-080000.zip");

        var archive = SicherungsBestand.Archive(_ordner, Rechner);

        archive.Should().ContainSingle();
        archive[0].Pfad.Should().Be(
            Path.Combine(_ordner, "automation-BUERO-PC-20260301-080000.zip"));
        archive[0].Zeitpunkt.Should().Be(new DateTime(2026, 3, 1, 8, 0, 0, DateTimeKind.Unspecified));
    }

    void Lege(string dateiname) =>
        File.WriteAllText(Path.Combine(_ordner, dateiname), "Archiv");

    public void Dispose()
    {
        try
        {
            Directory.Delete(_ordner, recursive: true);
        }
        catch (IOException)
        {
            // Aufraeumen ist best effort.
        }
    }
}
