using System.Text.RegularExpressions;
using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Vertrag zwischen Dienst, <c>installer/setup.iss</c> und dem
/// Windows-Runner der App (<c>windows/runner/main.cpp</c>, #196). Alle drei
/// sind nur über Zeichenketten verbunden — den Namen der Marke, die das Setup
/// abwartet, den Neustart-Schalter, den Namen des Setup-Mutex und
/// <c>--nach-update</c>. Ein Tippfehler auf einer Seite übersetzt, besteht
/// jeden anderen Test und fällt erst beim Anwalt auf: Das Setup wartet nicht
/// auf die Sicherung, die App startet nach dem Update nicht wieder, oder sie
/// startet mitten in einem laufenden Update.
///
/// Ob Inno das Skript übersetzt, prüft dieser Test nicht — das tut der
/// <c>paket</c>-Job der CI mit ISCC, in jedem Pull Request.
/// </summary>
public sealed class InstallerVertragTests
{
    private static readonly string[] Skript = File.ReadAllLines(
        Path.Combine(RepoWurzel.Pfad(), "installer", "setup.iss"));

    private static readonly string[] Runner = File.ReadAllLines(
        Path.Combine(RepoWurzel.Pfad(), "Automation_App_Frontend", "windows", "runner", "main.cpp"));

    /// <summary>Die Zeilen ohne Kommentare — was dort steht, wirkt.</summary>
    private static List<string> Wirksam => OhneKommentare(Skript, ';');

    private static List<string> RunnerWirksam => OhneKommentare(Runner, '#');

    private static List<string> OhneKommentare(string[] zeilen, char auchKommentar) => zeilen
        .Select(zeile => zeile.Trim())
        .Where(zeile => zeile.Length > 0
            && !zeile.StartsWith(auchKommentar)
            && !zeile.StartsWith("//", StringComparison.Ordinal))
        .ToList();

    /// <summary>Der Name in <c>&lt;konstante&gt; = '…';</c> (Inno) bzw. <c>&lt;konstante&gt;[] = L"…";</c> (C++).</summary>
    private static string NameIn(IEnumerable<string> zeilen, string muster)
    {
        var treffer = zeilen.Select(zeile => Regex.Match(zeile, muster)).Where(t => t.Success).ToList();
        treffer.Should().ContainSingle($"genau eine Zeile passt auf {muster}");
        return treffer[0].Groups[1].Value;
    }

    /// <summary>
    /// Gewartet wird in <c>InitializeSetup</c>, vor jedem Fenster und vor dem
    /// Restart Manager — nicht mehr in <c>PrepareToInstall</c>, wo eine
    /// Warteschleife das offene Setup-Fenster einfrieren ließ.
    /// </summary>
    [Fact]
    public void Das_Setup_wartet_auf_genau_die_Marke_die_der_Dienst_haelt()
    {
        Wirksam.Should().Contain($"DienstMutex = '{DienstLaeuftMarke.Name}';");
        Wirksam.Should().Contain(zeile => zeile.Contains("CheckForMutexes(DienstMutex)", StringComparison.Ordinal));
        Wirksam.Should().Contain("function InitializeSetup(): Boolean;");
        Wirksam.Should().NotContain(zeile => zeile.StartsWith("function PrepareToInstall(", StringComparison.Ordinal));
    }

    /// <summary>
    /// Inno legt einen <c>SetupMutex=</c> erst <i>nach</i> dem Skript-<c>InitializeSetup</c>
    /// an — nach dem Warten auf den Dienst. Deshalb legt das Skript seinen Mutex
    /// selbst an, bevor es wartet, und die Direktive fehlt: Sie fände danach den
    /// eigenen Mutex und bräche ab.
    /// </summary>
    [Fact]
    public void Das_Setup_haelt_seinen_Mutex_schon_waehrend_es_auf_den_Dienst_wartet()
    {
        var zeilen = Wirksam;
        NameIn(zeilen, @"^SetupLaeuftMutex = '([^']+)';$").Should().NotBeNullOrWhiteSpace();
        zeilen.Should().NotContain(zeile => zeile.StartsWith("SetupMutex=", StringComparison.OrdinalIgnoreCase));

        var start = zeilen.IndexOf("function InitializeSetup(): Boolean;");
        var anlegen = zeilen.IndexOf("CreateMutex(SetupLaeuftMutex);");
        var warten = zeilen.FindIndex(start + 1, zeile => zeile.Contains("WarteAufDienstende", StringComparison.Ordinal));
        start.Should().BeGreaterThan(-1);
        anlegen.Should().BeGreaterThan(start, "angelegt wird in InitializeSetup");
        warten.Should().BeGreaterThan(anlegen, "vor dem Warten auf den Dienst — gerade dann startet ein Doppelklick die App");
    }

    /// <summary>
    /// Zuerst die Frage nach einem anderen Setup, dann der eigene Mutex, dann
    /// das Warten auf den Dienst. Vertauscht, fände das Setup seinen eigenen
    /// Mutex und bräche ab, oder ein zweites liefe unbemerkt mit.
    /// </summary>
    [Fact]
    public void InitializeSetup_fragt_erst_nach_einem_anderen_Setup_legt_dann_den_Mutex_an_und_wartet_zuletzt()
    {
        var zeilen = Wirksam;
        var start = zeilen.IndexOf("function InitializeSetup(): Boolean;");
        start.Should().BeGreaterThan(-1);
        var rumpf = zeilen.Skip(start + 1).ToList();

        var fragen = rumpf.FindIndex(zeile => zeile.Contains("KeinAnderesSetup", StringComparison.Ordinal));
        var anlegen = rumpf.FindIndex(zeile => zeile.Contains("CreateMutex(SetupLaeuftMutex)", StringComparison.Ordinal));
        var warten = rumpf.FindIndex(zeile => zeile.Contains("WarteAufDienstende", StringComparison.Ordinal));

        fragen.Should().BeGreaterThan(-1, "InitializeSetup ruft KeinAnderesSetup auf");
        anlegen.Should().BeGreaterThan(fragen, "der eigene Mutex käme sonst vor der Frage und würde selbst gefunden");
        warten.Should().BeGreaterThan(anlegen, "das Warten kommt erst, wenn das Update als laufend gilt");
    }

    /// <summary>
    /// Die App zeigt den Hinweis nur, wenn sie nicht vom Setup selbst gestartet
    /// wurde und ein Setup läuft. Fiele <c>!nach_update</c> weg, startete sie
    /// nach dem Update nie wieder; fiele <c>SetupLaeuft()</c> weg, nie mehr.
    /// </summary>
    [Fact]
    public void Die_App_bricht_nur_ab_wenn_sie_nicht_nach_dem_Update_startet_und_ein_Setup_laeuft()
    {
        var runner = string.Join(' ', RunnerWirksam);

        Regex.IsMatch(runner, @"if\s*\(\s*!\s*nach_update\s*&&\s*SetupLaeuft\s*\(\s*\)\s*\)")
            .Should().BeTrue("die Bedingung muss genau so lauten: !nach_update && SetupLaeuft()");
    }

    [Fact]
    public void Die_App_fragt_beim_Start_denselben_Setup_Mutex_ab()
    {
        var imSkript = NameIn(Wirksam, @"^SetupLaeuftMutex = '([^']+)';$");
        var imRunner = NameIn(RunnerWirksam, @"^constexpr wchar_t kSetupLaeuftMutex\[\] = L""([^""]+)"";$");

        imRunner.Should().Be(imSkript);
        RunnerWirksam.Should().Contain(zeile => zeile.Contains("OpenMutexW(SYNCHRONIZE, FALSE, kSetupLaeuftMutex)", StringComparison.Ordinal));
    }

    /// <summary>
    /// Das Setup startet die App, solange es selbst noch läuft und den Mutex
    /// hält. Ohne <c>--nach-update</c> hielte die App ihren eigenen Neustart für
    /// ein laufendes Update und beendete sich mit einem Hinweis.
    /// </summary>
    [Fact]
    public void Beide_Run_Eintraege_starten_die_App_mit_nach_update()
    {
        var schalter = NameIn(RunnerWirksam, @"^constexpr char kNachUpdate\[\] = ""([^""]+)"";$");
        schalter.Should().Be("--nach-update");

        Wirksam.Where(zeile => zeile.StartsWith("Filename: \"{app}\\{#MyAppExeName}\"", StringComparison.Ordinal))
            .Should().HaveCount(2, "der interaktive postinstall-Eintrag und der stille Neustart")
            .And.OnlyContain(zeile => zeile.Contains($"Parameters: \"{schalter}\"", StringComparison.Ordinal));
    }

    [Fact]
    public void Der_Neustart_Schalter_ist_auf_beiden_Seiten_derselbe()
    {
        var schalter = Regex.Match(InstallerAufruf.NeustartSchalter, @"^/(\w+)=1$");
        schalter.Success.Should().BeTrue();

        Wirksam.Should().Contain(zeile => zeile.Contains($"{{param:{schalter.Groups[1].Value}|0}}", StringComparison.Ordinal));
    }

    /// <summary>
    /// Der Neustart läuft ohne <c>postinstall</c>, also mit den Rechten des
    /// Setups. Das ist nur deshalb der Anwender selbst, weil je Benutzer
    /// installiert wird — mit Administratorrechten liefe die App danach erhöht.
    /// </summary>
    [Fact]
    public void Nach_einem_stillen_Update_startet_die_App_wieder_als_Anwender()
    {
        Wirksam.Should().Contain(zeile =>
            zeile.StartsWith("Filename: \"{app}\\{#MyAppExeName}\"", StringComparison.Ordinal)
            && zeile.Contains("skipifnotsilent", StringComparison.Ordinal)
            && zeile.Contains("Check: NeustartGewuenscht", StringComparison.Ordinal));
        Wirksam.Should().Contain("PrivilegesRequired=lowest");
    }

    [Fact]
    public void Kein_Setup_beendet_Anwendungen_mit_Gewalt()
    {
        Wirksam.Should().NotContain(zeile => zeile.Contains("FORCECLOSEAPPLICATIONS", StringComparison.OrdinalIgnoreCase));
        Wirksam.Should().Contain("CloseApplications=yes", "„force“ beendete auch ein Word mit ungespeichertem Schriftsatz");
    }

    [Theory]
    [InlineData("Production", DienstLaeuftMarke.Name)]
    [InlineData("Development", null)]
    [InlineData("E2E", null)]
    [InlineData("Staging", null)]
    public void Nur_die_installierte_App_haelt_die_Marke(string umgebung, string? name)
    {
        var host = new FakeHostEnvironment(Path.GetTempPath()) { EnvironmentName = umgebung };

        DienstLaeuftMarke.NameFuer(host).Should().Be(
            name,
            "ein Entwicklungs- oder Testmodus-Dienst hielte ein echtes Update sonst bis zum Zeitlimit auf");
    }

    [Fact]
    public void Die_Marke_besteht_nach_dem_Halten()
    {
        var name = $"AutomationService.Tests.{Guid.NewGuid():N}";

        DienstLaeuftMarke.Halte(name, NullLogger.Instance).Should().BeTrue();
        DienstLaeuftMarke.Halte(name, NullLogger.Instance).Should().BeTrue("mehrfach halten ist harmlos");

        Mutex.TryOpenExisting(name, out var geoeffnet).Should().BeTrue("Inno fragt nur, ob es sie gibt");
        geoeffnet!.Dispose();
    }
}
