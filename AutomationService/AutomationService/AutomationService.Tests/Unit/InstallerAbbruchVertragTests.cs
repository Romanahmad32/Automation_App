using System.Text.RegularExpressions;
using FluentAssertions;
using Xunit;
using static AutomationService.Tests.Support.InstallerSkript;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Was <c>installer/setup.iss</c> samt <c>AppLaeuft.iss</c> tut, wenn etwas
/// nicht glatt geht (#199): Ein stilles Update aus der App scheitert nach
/// <c>InitializeSetup</c> — dann startet <c>DeinitializeSetup</c> die bisherige
/// App wieder. Und die App einer Version ohne Mutex (1.2.0) läuft noch — dann
/// warten Setup und Deinstallation auf ihre Programme im Installationsordner.
///
/// Jede Bedingung hier verhindert einen Fehler, den kein anderer Test sieht und
/// der erst beim Anwalt auffällt: eine verschwundene App, eine zweite neben der
/// ersten, eine Meldung, die beim stillen Update niemand wegklickt.
/// </summary>
public sealed class InstallerAbbruchVertragTests
{
    private static List<string> Deinitialize => Rumpf(Code, "procedure DeinitializeSetup(");

    private static List<string> Initialize => Rumpf(Code, "function InitializeSetup(");

    /// <summary>Die Zeile direkt nach <paramref name="bedingung"/> beendet die Routine.</summary>
    private static void EndetBei(List<string> rumpf, string bedingung, string grund)
    {
        var stelle = rumpf.IndexOf(bedingung);
        stelle.Should().BeGreaterThan(-1, $"„{bedingung}“ fehlt — {grund}");
        rumpf[stelle + 1].Should().Be("Exit;", $"„{bedingung}“ muss beenden — {grund}");
    }

    /// <summary>
    /// Drei Bedingungen, alle vor dem Start: ein stilles Update aus der App, das
    /// wirklich begonnen hat; keine vollständige Installation (sonst lief der
    /// <c>[Run]</c>-Eintrag schon); und kein Dienst läuft mehr — sonst übernähme
    /// die neue App einen, der gerade herunterfährt. Nur der Dienst zählt
    /// (<c>NurDienst</c>): Ein Fenster, das der Restart Manager nicht schließen
    /// konnte, hängt an einem Dienst, der fort ist; zählte es, bliebe dem Anwalt
    /// nur dieses tote Fenster.
    /// </summary>
    [Fact]
    public void Ein_gescheitertes_Update_startet_die_bisherige_App_nur_unter_allen_drei_Bedingungen()
    {
        var rumpf = Deinitialize;
        EndetBei(rumpf, "if not AppUpdateBegonnen then", "sonst startete jeder Doppelklick-Abbruch die App");
        EndetBei(rumpf, "if InstallationVollstaendig then", "sonst liefe die App nach jedem Update zweimal");
        var laeuft = rumpf.IndexOf("if AppLaeuft(Ordner, True) then");
        laeuft.Should().BeGreaterThan(-1, "solange der Dienst läuft, startet keine App — und nur der Dienst zählt");
        rumpf.Skip(laeuft).TakeWhile(zeile => zeile != "end;").Should().Contain("Exit;");

        var start = rumpf.FindIndex(zeile => zeile.StartsWith("if Exec(", StringComparison.Ordinal));
        start.Should().BeGreaterThan(laeuft, "erst prüfen, dann starten");
        rumpf[start].Should().Contain("NachUpdateSchalter").And.Contain("ewNoWait", "das Setup endet, die App bleibt");
    }

    /// <summary>
    /// Nach einem frühen Abbruch steht <c>{app}</c> womöglich nie fest — der
    /// Ordner kommt aus dem Deinstallationsschlüssel, den Inno zur AppId anlegt.
    /// </summary>
    [Fact]
    public void Der_Installationsordner_kommt_aus_dem_Schluessel_der_AppId()
    {
        var appId = NameIn(OhneKommentare(Setup, ';'), @"^AppId=\{(\{[0-9A-F-]+\})$");
        var schluessel = NameIn(Code, @"^DeinstallationsSchluessel = '([^']+)';$");

        schluessel.Should().Be($@"Software\Microsoft\Windows\CurrentVersion\Uninstall\{appId}_is1");
        Rumpf(Code, "function InstallierterOrdner").Should().Contain(zeile =>
            zeile.StartsWith("if RegQueryStringValue(HKA, DeinstallationsSchluessel, 'Inno Setup: App Path',", StringComparison.Ordinal));
        Deinitialize.Should().NotContain(zeile => zeile.Contains("{app}", StringComparison.Ordinal));
    }

    /// <summary>
    /// Der Merker steht erst nach der Frage nach einem anderen Setup und nach dem
    /// eigenen Mutex. <c>DeinitializeSetup</c> läuft auch, wenn <c>InitializeSetup</c>
    /// <c>False</c> liefert — stünde er davor, startete ein Setup, das nur wegen
    /// eines anderen endete, die App neben dem anderen.
    /// </summary>
    [Fact]
    public void Begonnen_ist_ein_Update_erst_nach_der_Frage_nach_einem_anderen_Setup_und_dem_eigenen_Mutex()
    {
        var rumpf = Initialize;
        var fragen = rumpf.FindIndex(zeile => zeile.Contains("KeinAnderesSetup", StringComparison.Ordinal));
        var anlegen = rumpf.IndexOf("CreateMutex(SetupLaeuftMutex);");
        var merken = rumpf.IndexOf("AppUpdateBegonnen := IstUpdateAusDerApp;");

        fragen.Should().BeGreaterThan(-1);
        anlegen.Should().BeGreaterThan(fragen);
        merken.Should().BeGreaterThan(anlegen, "erst ab dem eigenen Mutex ist es dieses Update");
        Code.Count(zeile => zeile.StartsWith("AppUpdateBegonnen :=", StringComparison.Ordinal))
            .Should().Be(1, "gesetzt wird nur dort");
    }

    /// <summary>
    /// Ein Update aus der App erkennt das Setup wie sein zweiter <c>[Run]</c>-Eintrag:
    /// still und mit <c>/NEUSTART=1</c> (<c>InstallerAufruf</c>). Ein Doppelklick
    /// oder eine Verteilung per Skript ist keins und startet nichts.
    /// </summary>
    [Fact]
    public void Ein_Update_aus_der_App_ist_still_und_mit_Neustart_Schalter_wie_im_Run_Eintrag()
    {
        Rumpf(Code, "function IstUpdateAusDerApp").Should().Contain("Result := WizardSilent and NeustartGewuenscht;");
        OhneKommentare(Setup, ';').Should().Contain(zeile =>
            zeile.Contains("skipifnotsilent", StringComparison.Ordinal)
            && zeile.Contains("Check: NeustartGewuenscht", StringComparison.Ordinal));
    }

    /// <summary>
    /// Bei Erfolg kommt <c>ssPostInstall</c> erst nach den <c>[Run]</c>-Einträgen
    /// (issrc, <c>TMainForm.Install</c>), bei einem Fehlschlag gar nicht. Ein
    /// früherer Schritt (<c>ssInstall</c>) hieße „vollständig“, bevor eine Datei
    /// ersetzt ist.
    /// </summary>
    [Fact]
    public void Vollstaendig_ist_eine_Installation_erst_bei_ssPostInstall()
    {
        var rumpf = Rumpf(Code, "procedure CurStepChanged(");
        var schritt = rumpf.IndexOf("if CurStep = ssPostInstall then");

        schritt.Should().BeGreaterThan(-1);
        rumpf[schritt + 1].Should().Be("InstallationVollstaendig := True;");
        Code.Count(zeile => zeile.StartsWith("InstallationVollstaendig :=", StringComparison.Ordinal))
            .Should().Be(1, "gesetzt wird nur dort");
    }

    /// <summary>
    /// Der Neustart geschieht, solange das Setup noch seinen Mutex hält — ohne
    /// <c>--nach-update</c> hielte die App das für ein laufendes Update und endete.
    /// </summary>
    [Fact]
    public void Der_Neustart_uebergibt_denselben_Schalter_wie_der_Runner_erwartet()
    {
        var imRunner = NameIn(OhneKommentare(Runner, '#'), @"^constexpr char kNachUpdate\[\] = ""([^""]+)"";$");

        NameIn(Code, @"^NachUpdateSchalter = '([^']+)';$").Should().Be(imRunner);
    }

    /// <summary>
    /// Inno unterdrückt eine <c>MsgBox</c> im <c>[Code]</c> auch mit
    /// <c>/SUPPRESSMSGBOXES</c> nicht. Beim Update aus der App sähe sie niemand,
    /// und das Setup stünde. Deshalb geht jeder Meldung eine Frage nach dem
    /// stillen Lauf voraus, die die Routine beendet.
    /// </summary>
    [Fact]
    public void Im_stillen_Lauf_erscheint_keine_Meldung()
    {
        var mitMeldung = Routinen(Code).Where(r => r.Rumpf.Exists(z => z.Contains("MsgBox(", StringComparison.Ordinal))).ToList();
        mitMeldung.Select(r => r.Kopf).Should().Contain(kopf => kopf.StartsWith("function KeinAnderesSetup", StringComparison.Ordinal))
            .And.Contain(kopf => kopf.StartsWith("function AppGeschlossen(", StringComparison.Ordinal));

        foreach (var (kopf, rumpf) in mitMeldung)
        {
            var meldung = rumpf.FindIndex(z => z.Contains("MsgBox(", StringComparison.Ordinal));
            var still = rumpf.FindIndex(z => Regex.IsMatch(z, @"^if (WizardSilent|UninstallSilent|Still) then$"));
            still.Should().BeInRange(0, meldung - 1, $"{kopf}: vor der Meldung steht die Frage nach dem stillen Lauf");
            rumpf.GetRange(still, meldung - still).Should().Contain("Exit;", $"{kopf}: still endet die Routine vor der Meldung");
        }

        Initialize.Should().Contain(zeile =>
            zeile.StartsWith("Result := AppGeschlossen(InstallierterOrdner, WizardSilent,", StringComparison.Ordinal));
        Rumpf(Code, "function InitializeUninstall(").Should().Contain(zeile =>
            zeile.StartsWith("Result := AppGeschlossen(InstallierterOrdner, UninstallSilent,", StringComparison.Ordinal));
    }

    /// <summary>
    /// Still wartet das Setup nur auf den Dienst. Ein Fenster, das danach noch
    /// offen ist — etwa eine zweite Instanz, die den Dienst nur mitbenutzt hat —,
    /// schließt der Restart Manager wie vor #199. Zählte es mit, wartete das Setup
    /// 93 s darauf und gäbe auf, und <c>DeinitializeSetup</c> startete nichts.
    /// Die Deinstallation hat keinen Restart Manager und wartet auf beide.
    /// </summary>
    [Fact]
    public void Still_wartet_das_Setup_nur_auf_den_Dienst_und_ueberlaesst_Fenster_dem_Restart_Manager()
    {
        Initialize.Should().Contain("Result := AppGeschlossen(InstallierterOrdner, WizardSilent, WizardSilent);");
        Rumpf(Code, "function InitializeUninstall(").Should()
            .Contain("Result := AppGeschlossen(InstallierterOrdner, UninstallSilent, False);");

        var einstellungen = OhneKommentare(Setup, ';');
        einstellungen.Should().Contain("CloseApplications=yes", "still schließt Inno die Fenster ohne Rückfrage")
            .And.Contain("RestartApplications=no", "neu gestartet wird nur über [Run], mit --nach-update");
        einstellungen.Where(zeile => zeile.StartsWith("CloseApplicationsFilter", StringComparison.OrdinalIgnoreCase))
            .Should().OnlyContain(zeile => zeile.Contains("*.exe", StringComparison.Ordinal), "automation_app.exe muss geprüft werden");

        Rumpf(Code, "function AppLaeuft(").Should().Contain("Result := ProgrammLaeuft(Ordner, not NurDienst);");
        var suche = Rumpf(Code, "function ProgrammLaeuft(");
        var fenster = suche.FindIndex(zeile => zeile.Contains("AppExe", StringComparison.Ordinal));
        fenster.Should().BeGreaterThan(0);
        suche[fenster - 1].Should().Be("if AuchFenster then", "das Fenster zählt nur, wenn danach gefragt ist");
        suche.Count(zeile => zeile.Contains("AppExe", StringComparison.Ordinal)).Should().Be(1);
    }

    /// <summary>
    /// 1.2.0 hält keinen Mutex. Setup und Deinstallation warten deshalb auch auf
    /// <c>AutomationService.exe</c> aus dem Installationsordner, interaktiv und
    /// bei der Deinstallation auch auf <c>automation_app.exe</c> — erst wenn das
    /// Update als laufend gilt und der Dienst-Mutex abgewartet ist.
    /// </summary>
    [Fact]
    public void Setup_und_Deinstallation_warten_auf_die_Programme_aus_dem_Installationsordner()
    {
        var rumpf = Initialize;
        var anlegen = rumpf.IndexOf("CreateMutex(SetupLaeuftMutex);");
        var dienst = rumpf.FindIndex(zeile => zeile.Contains("WarteAufDienstende", StringComparison.Ordinal));
        var programme = rumpf.FindIndex(zeile => zeile.Contains("AppGeschlossen(", StringComparison.Ordinal));
        dienst.Should().BeGreaterThan(anlegen);
        programme.Should().BeGreaterThan(dienst, "die Programme zuletzt — der Dienst-Mutex ist feiner getaktet");
        Rumpf(Code, "function InitializeUninstall(").Should().Contain(
            zeile => zeile.StartsWith("Result := AppGeschlossen(", StringComparison.Ordinal),
            "auch die Deinstallation entfernt sonst Dateien unter einem Dienst, der noch sichert");

        Rumpf(Code, "function AppLaeuft(").Should().Contain("Result := CheckForMutexes(DienstMutex);");
        var suche = Rumpf(Code, "function ProgrammLaeuft(");
        suche.Should().Contain(zeile => zeile.Contains("FROM Win32_Process", StringComparison.Ordinal) && zeile.Contains("DienstExe", StringComparison.Ordinal))
            .And.Contain("Praefix := AnsiUpperCase(AddBackslash(Ordner));", "der Benutzername im Pfad darf Umlaute tragen")
            .And.Contain("Result := (Pos(Praefix, AnsiUpperCase(PfadText)) = 1);", "der Pfad zählt, nicht nur der Name");
        suche.SkipWhile(zeile => zeile != "except").Should().Contain("Result := False;", "ein WMI-Fehler blockiert nie");
    }

    /// <summary>Gesucht wird nach genau den Programmen, die das Paket mitbringt.</summary>
    [Fact]
    public void Gesucht_wird_nach_den_Programmen_der_App()
    {
        NameIn(Code, @"^DienstExe = '([^']+)';$").Should().Be($"{typeof(Program).Assembly.GetName().Name}.exe");
        NameIn(Code, @"^AppExe = '([^']+)';$").Should().Be("{#MyAppExeName}");
    }
}
