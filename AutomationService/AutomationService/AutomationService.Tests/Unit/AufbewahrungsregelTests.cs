using AutomationService.Features.Backup.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die gestaffelte Aufbewahrung der automatischen Sicherungen (#112).
///
/// Die Regel entscheidet, was von der Historie eines Rechners übrig bleibt —
/// falsch gerechnet, löscht sie genau das Archiv, für das der Anwalt die
/// Sicherung angelegt hat. Sie ist deshalb rein (ohne IO) gebaut, damit sie sich
/// hier mit Hunderten Zeitpunkten durchspielen lässt statt mit Dateien.
/// </summary>
public sealed class AufbewahrungsregelTests
{
    /// <summary>Ein fester Bezugspunkt: Die Staffel rechnet in Kalendertagen.</summary>
    static readonly DateTime Jetzt = new(2026, 6, 30, 12, 0, 0, DateTimeKind.Unspecified);

    /// <summary>
    /// Der Fall aus dem Issue: 90 Tage lang achtmal täglich gesichert.
    ///
    /// Erwartet werden 24 Archive, und zwar nachgerechnet:
    /// 8 von heute (alle) + 7 (je ein Tag der letzten Woche)
    /// + 8 (je ein 7-Tage-Block der acht Wochen davor)
    /// + 1 Monatsvertreter — denn alles jenseits von 63 Tagen (Tag 64 bis 89)
    /// liegt vom 30.06.2026 aus gerechnet im April 2026, also in einem Monat.
    /// </summary>
    [Fact]
    public void Neunzig_Tage_mit_acht_Laeufen_schmelzen_auf_die_Staffel()
    {
        var archive = TaeglicheArchive(tage: 90, jeTag: 8);

        var geloescht = Aufbewahrungsregel.ZuLoeschen(archive, Jetzt);

        (archive.Count - geloescht.Count).Should().Be(8 + 7 + 8 + 1);
        geloescht.Should().NotContain(
            archive[0].Pfad, "das neueste Archiv wird nie gelöscht");
    }

    /// <summary>
    /// Der Deckel auf den Monaten. Ohne ihn wüchse der Ordner Jahr für Jahr
    /// weiter — jedes Archiv trägt die Vorlagen ein weiteres Mal mit.
    /// </summary>
    [Fact]
    public void Aus_dem_Aelteren_bleiben_hoechstens_zwoelf_Monatsvertreter()
    {
        // Je ein Archiv, drei bis 26 Monate zurück: alle jenseits der
        // Wochenstaffel und jedes in einem eigenen Kalendermonat.
        var archive = Enumerable.Range(3, 24)
            .Select(monate => Jetzt.AddMonths(-monate))
            .Select(zeitpunkt => (Pfad: Name(zeitpunkt), Zeitpunkt: zeitpunkt))
            .ToList();

        var geloescht = Aufbewahrungsregel.ZuLoeschen(archive, Jetzt);

        geloescht.Should().HaveCount(
            24 - Aufbewahrungsregel.MonateHoechstens,
            "je Monat bleibt eines, aber nur zwölf Monate weit zurück");
    }

    [Fact]
    public void Vom_selben_alten_Tag_bleibt_nur_das_juengste()
    {
        var tagZuvor = Jetzt.Date.AddDays(-3);
        var frueh = (Name(tagZuvor.AddHours(9)), tagZuvor.AddHours(9));
        var mittags = (Name(tagZuvor.AddHours(12)), tagZuvor.AddHours(12));
        var spaet = (Name(tagZuvor.AddHours(17)), tagZuvor.AddHours(17));
        var heute = (Name(Jetzt), Jetzt);

        var geloescht = Aufbewahrungsregel.ZuLoeschen([heute, frueh, mittags, spaet], Jetzt);

        geloescht.Should().BeEquivalentTo(new[] { frueh.Item1, mittags.Item1 });
    }

    /// <summary>
    /// Ein Archiv, das in der Zukunft datiert ist, kommt von einem Rechner mit
    /// falsch gestellter Uhr. Es zu löschen hiesse, den Fehler des anderen mit
    /// dem Verlust seines Standes zu beantworten.
    /// </summary>
    [Fact]
    public void Ein_Zeitpunkt_in_der_Zukunft_bleibt_liegen()
    {
        var uebermorgen = (Name(Jetzt.AddDays(2)), Jetzt.AddDays(2));
        var morgen = (Name(Jetzt.AddDays(1)), Jetzt.AddDays(1));
        var alt = (Name(Jetzt.AddDays(-100)), Jetzt.AddDays(-100));
        var nochAelter = (Name(Jetzt.AddDays(-101)), Jetzt.AddDays(-101));

        var geloescht = Aufbewahrungsregel.ZuLoeschen(
            [uebermorgen, morgen, alt, nochAelter], Jetzt);

        geloescht.Should().BeEquivalentTo(
            new[] { nochAelter.Item1 },
            "die beiden Zukunftsstände bleiben, aus dem alten Monat bleibt das jüngste");
    }

    [Fact]
    public void Ohne_Archive_gibt_es_nichts_zu_loeschen() =>
        Aufbewahrungsregel.ZuLoeschen([], Jetzt).Should().BeEmpty();

    [Fact]
    public void Ein_einzelnes_uraltes_Archiv_bleibt_liegen()
    {
        var uralt = (Name(Jetzt.AddYears(-5)), Jetzt.AddYears(-5));

        Aufbewahrungsregel.ZuLoeschen([uralt], Jetzt).Should().BeEmpty(
            "ein Ordner ohne die jüngste Sicherung wäre einer ohne Sicherung");
    }

    /// <summary>Absteigend nach Zeit, damit die Tests auf Index 0 zeigen können.</summary>
    static List<(string Pfad, DateTime Zeitpunkt)> TaeglicheArchive(int tage, int jeTag)
    {
        var archive = new List<(string Pfad, DateTime Zeitpunkt)>();
        for (var tag = 0; tag < tage; tag++)
        {
            for (var lauf = jeTag - 1; lauf >= 0; lauf--)
            {
                // Ein Arbeitstag von 08:00 bis 15:00.
                var zeitpunkt = Jetzt.Date.AddDays(-tag).AddHours(8 + lauf);
                archive.Add((Name(zeitpunkt), zeitpunkt));
            }
        }

        return archive;
    }

    static string Name(DateTime zeitpunkt) => SicherungsDateiname.Baue("BUERO-PC", zeitpunkt);
}
