using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Architecture;

/// <summary>
/// Erzwingt die Schnittregeln der Vertical Slices im Backend.
///
/// Jedes Feature liegt unter Features/&lt;Name&gt; und ist in zwei Schichten
/// geteilt:
///
///     Presentation (Controller, DTOs, Hubs, DI)  ──▶  Domain (Logik, Persistenz)
///
/// * Domain ist die innerste Schicht: sie kennt die Presentation ihres eigenen
///   Slices nicht und ist frei von ASP.NET-MVC.
/// * Zwischen Slices ist nur der Weg ueber Domain erlaubt. Der Zugriff auf die
///   Presentation eines fremden Slices koppelt an dessen HTTP-Vertrag -- dann
///   aendert ein neues Feld in einem DTO das Verhalten eines anderen Features.
/// </summary>
public class SliceIsolationTests
{
    /// <summary>
    /// Einzige zugelassene Ausnahme: DevSimulation ist ein reiner
    /// Entwickler-Slice, dessen Zweck es ist, einen Postfach-Eingang
    /// vorzutaeuschen. Damit die App den simulierten Treffer nicht vom echten
    /// unterscheiden kann, muss sie zwangslaeufig ueber denselben SignalR-Hub
    /// und dasselbe DTO gehen wie der MailboxMonitor. Der Slice ist hinter
    /// Simulation:Enabled abgeschaltet und liefert sonst 404.
    /// </summary>
    static readonly (string Von, string Nach)[] ErlaubtePresentationZugriffe =
    [
        ("DevSimulation", "MailboxMonitor")
    ];

    /// <summary>
    /// Bestandsverstoesse, die bei Einfuehrung dieser Regel schon da waren.
    /// Sie stehen hier namentlich, damit die Regel fuer allen neuen Code scharf
    /// bleibt, ohne dass die Altlast als stille Ausnahme verschwindet.
    ///
    /// Beide Faelle sind derselbe: die Domain-Schnittstelle nimmt ein
    /// Presentation-DTO als Parameter (WordReplacementDto bzw. das
    /// Zentralruf-Anfrage-DTO). Damit diktiert der HTTP-Vertrag die Signatur
    /// der Fachlogik, und ein neues Feld im DTO aendert die
    /// Domain-Schnittstelle mit. Aufloesen laesst sich das ueber einen eigenen
    /// Eingabetyp in der Domain, auf den der Controller abbildet -- das
    /// beruehrt den Dokumentenerzeuger, die Browsersteuerung und deren Tests
    /// und ist deshalb ein eigener Arbeitsschritt, kein Nebenbei-Umbau.
    /// </summary>
    static readonly string[] AltlastenDomainNutztPresentation =
    [
        "/Features/WordAutomation/Domain/Services/IWordAutomationService.cs",
        "/Features/WordAutomation/Domain/Services/WordAutomationService.cs",
        "/Features/ZentralrufAutomation/Domain/Services/IZentralrufAutomationService.cs",
        "/Features/ZentralrufAutomation/Domain/Services/ZentralrufAutomationService.cs",
    ];

    [Fact]
    public void Domain_haengt_nicht_von_der_eigenen_Presentation_ab()
    {
        var verstoesse = CsQuelldateien.InFeatures()
            .Where(datei => datei.Schicht == "Domain")
            .Where(datei => !AltlastenDomainNutztPresentation.Contains(datei.RelativerPfad))
            .Where(datei => datei.Usings.Any(u =>
                u.StartsWith($"AutomationService.Features.{datei.Feature}.Presentation", StringComparison.Ordinal)))
            .Select(datei => datei.RelativerPfad)
            .ToList();

        verstoesse.Should().BeEmpty(
            "die Domain-Schicht muss ohne ihre Presentation uebersetzbar und testbar bleiben; " +
            "wird dort etwas aus Presentation gebraucht, gehoert es in die Domain verschoben");
    }

    [Fact]
    public void Die_Altlastenliste_enthaelt_nichts_Erledigtes()
    {
        var dateien = CsQuelldateien.InFeatures();
        var erledigt = new List<string>();

        foreach (var pfad in AltlastenDomainNutztPresentation)
        {
            var datei = dateien.SingleOrDefault(d => d.RelativerPfad == pfad);

            if (datei is null)
            {
                erledigt.Add($"{pfad}: existiert nicht mehr");
                continue;
            }

            var haengtNochAnPresentation = datei.Usings.Any(u =>
                u.StartsWith($"AutomationService.Features.{datei.Feature}.Presentation", StringComparison.Ordinal));

            if (!haengtNochAnPresentation)
            {
                erledigt.Add($"{pfad}: haengt nicht mehr an der Presentation");
            }
        }

        erledigt.Should().BeEmpty(
            "aufgeraeumte Dateien gehoeren aus der Altlastenliste entfernt, sonst " +
            "erlaubt sie stillschweigend, den Verstoss wieder einzufuehren");
    }

    [Fact]
    public void Domain_ist_frei_von_ASP_NET_MVC()
    {
        var verstoesse = CsQuelldateien.InFeatures()
            .Where(datei => datei.Schicht == "Domain")
            .Where(datei => datei.Usings.Any(u =>
                u.StartsWith("Microsoft.AspNetCore.Mvc", StringComparison.Ordinal)))
            .Select(datei => datei.RelativerPfad)
            .ToList();

        verstoesse.Should().BeEmpty(
            "die Fachlogik darf nicht am Web-Framework haengen -- ActionResult, ControllerBase " +
            "und Model-Binding gehoeren ausschliesslich in die Presentation");
    }

    [Fact]
    public void Kein_Slice_greift_auf_die_Presentation_eines_anderen_Slices_zu()
    {
        var verstoesse = new List<string>();

        foreach (var datei in CsQuelldateien.InFeatures())
        {
            foreach (var verwendet in datei.Usings)
            {
                var teile = verwendet.Split('.');
                var istFremdePresentation =
                    teile.Length >= 5 &&
                    teile[0] == "AutomationService" &&
                    teile[1] == "Features" &&
                    teile[3] == "Presentation" &&
                    teile[2] != datei.Feature;

                if (!istFremdePresentation)
                {
                    continue;
                }

                var fremdesFeature = teile[2];
                var erlaubt = ErlaubtePresentationZugriffe.Contains((datei.Feature!, fremdesFeature));
                if (!erlaubt)
                {
                    verstoesse.Add($"{datei.RelativerPfad} -> {fremdesFeature}.Presentation");
                }
            }
        }

        verstoesse.Should().BeEmpty(
            "Slices duerfen sich nur ueber ihre Domain-Schicht kennen; " +
            "der Zugriff auf fremde Controller, DTOs oder Hubs koppelt an deren HTTP-Vertrag. " +
            "Gibt es einen zwingenden Grund, gehoert er in ErlaubtePresentationZugriffe -- " +
            "mit Begruendung, nicht als stille Erweiterung");
    }

    [Fact]
    public void Jeder_Slice_haelt_sich_an_die_Schichten_Domain_und_Presentation()
    {
        var unerwartet = CsQuelldateien.InFeatures()
            .Where(datei => datei.Schicht is not ("Domain" or "Presentation"))
            .Select(datei => datei.RelativerPfad)
            .ToList();

        unerwartet.Should().BeEmpty(
            "unterhalb von Features/<Name>/ sind genau zwei Schichten vorgesehen: " +
            "Domain und Presentation. Ein dritter Ordner umgeht die Schnittregeln, " +
            "weil ihn keine der Regeln oben erfasst");
    }
}
