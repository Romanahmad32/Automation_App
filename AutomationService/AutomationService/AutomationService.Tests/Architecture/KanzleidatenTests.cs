using System.Text.RegularExpressions;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Architecture;

/// <summary>
/// Haelt Kanzleidokumente aus dem oeffentlichen Repository.
///
/// Gitleaks (ci.yml, Job geheimnisse) sucht Zugaenge in Textdateien; in eine
/// .docx sieht es nicht hinein. Genau dort stand der Briefkopf der Kanzlei
/// samt Bankverbindung und Steuernummer -- und kam, nachdem er schon einmal
/// aus der Historie entfernt war, ueber einen Zweig von vorher wieder zurueck.
/// .gitignore haelt beides nicht auf: weder `git add -f` noch einen Merge.
///
/// Zwei Regeln. Die erste prueft, was heute versioniert ist, nach dem Ort --
/// eine echte Vollmacht traegt keine IBAN, aber Mandantendaten, die sich nicht
/// an einer Form erkennen lassen. Die zweite prueft jedes Dokument, das je von
/// HEAD aus erreichbar war, nach dem Inhalt: Ein Zweig, der die alte Historie
/// zurueckbraechte, faellt damit vor dem Merge auf.
/// </summary>
public partial class KanzleidatenTests
{
    /// <summary>Dateiarten, in denen eine Kanzlei Schreiben, Vorlagen und Post fuehrt.</summary>
    static readonly string[] Dokumentendungen =
    [
        ".docx", ".docm", ".dotx", ".dotm", ".doc", ".dot", ".rtf", ".odt",
        ".xlsx", ".xlsm", ".xls", ".ods", ".pptx", ".ppt", ".odp",
        ".pdf", ".eml", ".msg",
    ];

    static bool IstDokument(string pfad) =>
        Dokumentendungen.Any(endung => pfad.EndsWith(endung, StringComparison.OrdinalIgnoreCase));

    [Fact]
    public void Dokumente_liegen_nur_als_neutrale_Muster_im_Saatgut()
    {
        var fremd = GitBestand.VersionierteDateien()
            .Where(IstDokument)
            .Where(pfad => !NeutralesMuster().IsMatch(pfad))
            .Order(StringComparer.Ordinal)
            .ToList();

        fremd.Should().BeEmpty(
            "das Repository ist oeffentlich. Versioniert sind nur die neutralen " +
            "Templates/**/Muster_*.docx ohne Kanzleibezug; echte Vorlagen gehoeren in den " +
            "Vorlagenordner des Anwenders, Beispiele bleiben unter Beispiele/ unversioniert. " +
            "Eine Vorlage fuer einen Test legt der Test selbst an (WordVorlagenUmgebung)");
    }

    [Fact]
    public void Kein_Dokument_der_Historie_traegt_Bank_oder_Steuerdaten()
    {
        var dokumente = GitBestand.ObjekteDerHistorie()
            .Where(objekt => IstDokument(objekt.Pfad))
            .ToList();
        dokumente.Should().NotBeEmpty(
            "die neutralen Muster liegen in der Historie; findet die Pruefung keines, " +
            "hat sie nichts gesehen");

        var funde = dokumente
            .Select(objekt => (objekt.Pfad, objekt.Blob,
                Arten: Kanzleidaten.Funde(Dokumentinhalt.Text(GitBestand.Inhalt(objekt.Blob)))))
            .Where(befund => befund.Arten.Count > 0)
            .Select(befund => $"{befund.Pfad} (Blob {befund.Blob[..10]}): {string.Join(", ", befund.Arten)}")
            .Order(StringComparer.Ordinal)
            .ToList();

        funde.Should().BeEmpty(
            "ein Dokument mit Bankverbindung oder Steuerkennung ist eine Kanzleivorlage, kein " +
            "Muster. Steht es nur im Arbeitsbaum, gehoert es aus dem Commit. Steht es in einem " +
            "Commit dieses Zweigs, muss die Historie des Zweigs umgeschrieben werden -- ein " +
            "Loesch-Commit obendrauf veroeffentlicht es trotzdem. Stammt der Zweig von vor einer " +
            "Bereinigung der Historie, wird er auf dem heutigen master neu angelegt, nie " +
            "zurueckgemergt (docs/RELEASE.md, Geheimnisse bleiben draussen)");
    }

    [GeneratedRegex(@"^AutomationService/AutomationService/Templates/(?:[^/]+/)*Muster_[^/]+\.docx$")]
    private static partial Regex NeutralesMuster();
}
