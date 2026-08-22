using System.Text.RegularExpressions;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Architecture;

/// <summary>
/// Haelt AutomationService/CLAUDE.md an den Bestand gebunden.
///
/// Die Datei ist fuer einen Agenten mit frischem Kontext die einzige
/// Uebersicht ueber die senkrechten Schnitte: sie beschreibt jeden Slice in
/// vier Zeilen und listet die Verdrahtung auf. Beides sind Aufzaehlungen, die
/// beim naechsten neuen Slice geraeuschlos unvollstaendig werden -- und ein
/// Slice, der dort fehlt, existiert fuer einen frischen Agenten nicht.
///
/// Zwei Aufzaehlungen, zwei Tests. Das Zeilenbudget der CLAUDE.md-Dateien
/// prueft die Gegenseite (Frontend, dokumentation_test.dart) fuer alle drei
/// gemeinsam -- eine Regel, ein Ort.
/// </summary>
public class DokumentationTests
{
    static string Wegweiser() => File.ReadAllText(
        Path.Combine(RepoWurzel.Pfad(), "AutomationService", "CLAUDE.md"));

    static HashSet<string> SliceOrdner() =>
        new DirectoryInfo(Path.Combine(CsQuelldateien.ProjektWurzel(), "Features"))
            .GetDirectories()
            .Select(ordner => ordner.Name)
            .ToHashSet();

    [Fact]
    public void Jeder_Slice_hat_einen_Absatz_in_CLAUDE_md()
    {
        var beschrieben = Regex
            .Matches(Wegweiser(), @"^- \*\*(\w+)\*\*", RegexOptions.Multiline)
            .Select(treffer => treffer.Groups[1].Value)
            .ToHashSet();
        var vorhanden = SliceOrdner();

        var abweichungen = vorhanden.Except(beschrieben)
            .Select(name => $"{name}: Slice ohne Absatz in AutomationService/CLAUDE.md")
            .Concat(beschrieben.Except(vorhanden)
                .Select(name => $"{name}: in CLAUDE.md beschrieben, aber kein Ordner unter Features/"))
            .Order()
            .ToList();

        abweichungen.Should().BeEmpty(
            "die Slice-Liste in AutomationService/CLAUDE.md ist der Einstieg in das Backend. " +
            "Ein neuer Slice gehoert mit hoechstens vier Zeilen dazu (Zweck, Besonderheit, " +
            "Fallstrick), ein entfernter wieder heraus");
    }

    static HashSet<string> GueltigeParagraphen()
    {
        var index = File.ReadAllText(
            Path.Combine(RepoWurzel.Pfad(), "docs", "ANFORDERUNGEN_INDEX.md"));
        return Regex.Matches(index, @"^#{2,3} (\d+) ", RegexOptions.Multiline)
            .Concat(Regex.Matches(index, @"^\|\s*(\d+\.\d+)\s*\|", RegexOptions.Multiline))
            .Select(treffer => treffer.Groups[1].Value)
            .ToHashSet();
    }

    [Fact]
    public void Jeder_Paragraphenverweis_steht_im_Anforderungs_Index()
    {
        var gueltig = GueltigeParagraphen();
        gueltig.Count.Should().BeGreaterThan(20,
            "ein leeres Sollverzeichnis wuerde jeden Verweis durchwinken");

        var unbekannt = CsQuelldateien.Alle()
            .SelectMany(datei => Regex
                .Matches(datei.Inhalt, @"§(\d+(?:\.\d+)?)")
                .Select(treffer => $"{datei.RelativerPfad} -> §{treffer.Groups[1].Value}"))
            .Where(verweis => !gueltig.Contains(verweis.Split('§').Last()))
            .Distinct()
            .Order()
            .ToList();

        unbekannt.Should().BeEmpty(
            "diese Paragraphen gibt es in der geltenden Gliederung nicht. Die richtige Nummer " +
            "steht in docs/ANFORDERUNGEN_INDEX.md; ist die Gliederung selbst gewachsen, gehoert " +
            "der Index zuerst nachgezogen. Gesetzesstellen tragen ein Leerzeichen " +
            "(§ 13 RVG) und sind nicht gemeint");
    }

    [Fact]
    public void Kein_Verweis_in_der_alten_Schreibweise()
    {
        var alt = new Regex(@"(Req\.?|Requirement|Anforderung)\s+\d");

        var treffer = CsQuelldateien.Alle()
            .Where(datei => alt.IsMatch(datei.Inhalt))
            .Select(datei => datei.RelativerPfad)
            .ToList();

        treffer.Should().BeEmpty(
            "Anforderungen werden als §4.8 zitiert, nicht in der alten Form " +
            "(\"Req.\" mit Nummer) -- die stammt aus einer frueheren Gliederung und " +
            "laesst sich nicht gegen den Index pruefen");
    }

    [Fact]
    public void Die_Verdrahtung_in_CLAUDE_md_ist_vollstaendig()
    {
        var dokumentiert = Regex
            .Matches(Wegweiser(), @"`(Add\w+Services)`")
            .Select(treffer => treffer.Groups[1].Value)
            .ToHashSet();

        var deklariert = CsQuelldateien.Alle()
            .SelectMany(datei => Regex
                .Matches(datei.Inhalt,
                    @"public static IServiceCollection (Add\w+Services)")
                .Select(treffer => treffer.Groups[1].Value))
            .ToHashSet();

        var abweichungen = deklariert.Except(dokumentiert)
            .Select(name => $"{name}: Erweiterungsmethode ohne Eintrag in AutomationService/CLAUDE.md")
            .Concat(dokumentiert.Except(deklariert)
                .Select(name => $"{name}: in CLAUDE.md genannt, aber nirgends deklariert"))
            .Order()
            .ToList();

        abweichungen.Should().BeEmpty(
            "CLAUDE.md nennt die Add...Services-Methoden als vollstaendige Liste der Verdrahtung. " +
            "Wer sich darauf verlaesst und eine fehlt, haelt einen Slice fuer nicht registriert");
    }
}
