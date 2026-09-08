using System.Text.Json;
using AutomationService.Features.RegisterHistorie.Domain.Services;
using AutomationService.Features.RegisterHistorie.Presentation.Dtos;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die anonymisierte Kurzfassung des Kanzleiregisters läuft vollständig durch
/// die Vorschau (§6.2).
///
/// Der Sinn dieses Tests ist nicht eine weitere Regel, sondern die
/// <em>echte</em> Form: 27 Zeilen aus neun Jahrgängen mit allem, woran ein
/// Parser scheitert — Abteilung mal mit und mal ohne Leerzeichen, ein
/// Nummernzusatz, ein Rechtsgebiet ohne Kürzel, zwei Mandanten in einer Zelle,
/// ein Tippfehler („v. v.") und drei Zeilen, deren Spalte 3 der Abteilung
/// widerspricht. Die Fixture trägt ausschließlich erfundene Namen; das
/// Repository ist öffentlich.
///
/// Erwartet wird kein grüner Bericht, sondern <b>genau dieser</b>: Was der
/// Bestand an Widersprüchen hat, muss auftauchen, und was keiner ist, darf
/// nicht auftauchen. Ein Bericht, in dem alles auffällt, zeigt nichts.
/// </summary>
public sealed class RegisterKurzfassungTests : IDisposable
{
    static readonly JsonSerializerOptions Wie_Der_Dienst =
        new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase, PropertyNameCaseInsensitive = true };

    readonly RegisterImportAufbau _aufbau = new();

    static RegisterImportDto Kurzfassung()
    {
        var pfad = Path.Combine(AppContext.BaseDirectory, "Fixtures", "register-kurzfassung.json");
        File.Exists(pfad).Should().BeTrue(
            "die Fixture muss neben der Test-Assembly liegen (Content-Eintrag in der .csproj)");
        return JsonSerializer.Deserialize<RegisterImportDto>(File.ReadAllText(pfad), Wie_Der_Dienst)!;
    }

    async Task<RegisterImportBefund> Vorschau()
    {
        var datei = Kurzfassung();
        datei.Version.Should().Be(1);
        return await _aufbau.Import.FuehreAusAsync(
            new RegisterImportAuftrag(datei.ZuDomaene(), NurPruefen: true));
    }

    [Fact]
    public async Task Die_Kurzfassung_laeuft_vollstaendig_durch_die_Vorschau()
    {
        var befund = await Vorschau();

        befund.Angewendet.Should().BeFalse();
        befund.Jahrgaenge.Select(jahrgang => jahrgang.Jahrgang)
            .Should().Equal(2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026);
        befund.Jahrgaenge.Sum(jahrgang => jahrgang.Zeilen).Should().Be(27);
        befund.Jahrgaenge.Sum(jahrgang => jahrgang.Neu).Should().Be(27);
        befund.Jahrgaenge.Sum(jahrgang => jahrgang.Abgelehnt).Should().Be(0);
        befund.Jahrgaenge.Should().OnlyContain(jahrgang => jahrgang.Doppelte.Count == 0);
    }

    /// <summary>
    /// Die Kurzfassung ist ein Auszug: Sie zeigt je Jahrgang drei Zeilen, nicht
    /// alle. Die Lückenprüfung muss das melden — täte sie es nicht, wäre sie
    /// auch bei der Vollfassung blind.
    /// </summary>
    [Fact]
    public async Task Jeder_Jahrgang_des_Auszugs_meldet_seine_Luecken()
    {
        var befund = await Vorschau();

        befund.Jahrgaenge.Should().OnlyContain(jahrgang => jahrgang.Luecken.Count > 0);
        Jahrgang(befund, 2018).Luecken.Should().Equal(2, 3, 4, 5, 7, 8);
        Jahrgang(befund, 2025).Luecken.Should().Equal(2, 3, 4, 5, 6, 8, 9);
    }

    /// <summary>
    /// Die vollständige Liste der Zeilen mit Befund — als Liste und nicht als
    /// Zahl, damit ein zusätzlicher Fehlalarm den Test rot macht und nicht nur
    /// eine Summe verschiebt.
    /// </summary>
    [Fact]
    public async Task Genau_sechs_Zeilen_tragen_einen_Befund()
    {
        var befund = await Vorschau();

        Mit(befund, eintrag => eintrag.Befunde.Count > 0)
            .Should().Equal("01/18", "10/19-I", "16/20", "06/22", "16/23", "18/26");
    }

    [Fact]
    public async Task Nur_die_drei_widerspruechlichen_Zeilen_zaehlen_als_Abweichung()
    {
        var befund = await Vorschau();

        befund.Jahrgaenge.Sum(jahrgang => jahrgang.Abweichungen).Should().Be(3);
        Mit(befund, eintrag => eintrag.Befunde.Any(satz => satz.Contains("widerspricht Spalte 3")))
            .Should().Equal("06/22", "16/23", "18/26");
    }

    /// <summary>
    /// Die acht Bußgeldsachen des Auszugs stehen unter „C03o" und in Spalte 3
    /// unter „Verkehrsrecht". Das ist die Schreibweise der Kanzlei und kein
    /// Widerspruch — meldete die Prüfung sie, wäre der Bericht unbrauchbar.
    /// </summary>
    [Fact]
    public async Task Eine_Bussgeldsache_im_Verkehrsrecht_ist_kein_Widerspruch()
    {
        var befund = await Vorschau();

        foreach (var aktenzeichen in new[] { "06/18", "13/19", "18/20", "14/21", "13/23", "34/24", "07/25", "05/26" })
        {
            Eintrag(befund, aktenzeichen).Befunde.Should().BeEmpty(
                "„{0}“ ist eine Bußgeldsache (C03o) im Verkehrsrecht", aktenzeichen);
        }
    }

    [Fact]
    public async Task Die_einzelnen_Befunde_stehen_an_der_richtigen_Zeile()
    {
        var befund = await Vorschau();

        Eintrag(befund, "01/18").Befunde.Should().Contain("Ohne Abteilung.");
        Eintrag(befund, "10/19-I").Befunde.Should().Contain("Nummer trägt den Zusatz „-I“.");
        Eintrag(befund, "16/20").Befunde.Should()
            .Contain("Rechtsgebiet „Vertragsrecht“ steht nicht im Sachgebietskatalog.");
        Eintrag(befund, "16/23").Befunde.Should()
            .ContainMatch("Abteilung C01a (Arbeitsrecht) widerspricht Spalte 3 „Verkehrsrecht“*");
    }

    /// <summary>
    /// Was der Anwalt am Ende ansehen muss: alles, was nicht „hoch" ist, plus
    /// alles mit Befund. Zwei Drittel des Auszugs — bei der Vollfassung ist
    /// genau diese Zahl der Unterschied zwischen einer Prüfung und einer
    /// Unterschrift ins Blaue.
    /// </summary>
    [Fact]
    public async Task Achtzehn_der_siebenundzwanzig_Zeilen_gehen_auf_die_Pruefliste()
    {
        var befund = await Vorschau();

        befund.Jahrgaenge.Sum(jahrgang => jahrgang.ZuPruefen).Should().Be(18);
    }

    static JahrgangBefund Jahrgang(RegisterImportBefund befund, int jahr) =>
        befund.Jahrgaenge.Single(eintrag => eintrag.Jahrgang == jahr);

    static RegisterZeilenBefund Eintrag(RegisterImportBefund befund, string aktenzeichen) =>
        befund.Jahrgaenge.SelectMany(jahrgang => jahrgang.Eintraege)
            .Single(eintrag => eintrag.Aktenzeichen == aktenzeichen);

    static List<string> Mit(RegisterImportBefund befund, Func<RegisterZeilenBefund, bool> bedingung) =>
        [.. befund.Jahrgaenge.SelectMany(jahrgang => jahrgang.Eintraege)
            .Where(bedingung)
            .Select(eintrag => eintrag.Aktenzeichen)];

    public void Dispose() => _aufbau.Dispose();
}
