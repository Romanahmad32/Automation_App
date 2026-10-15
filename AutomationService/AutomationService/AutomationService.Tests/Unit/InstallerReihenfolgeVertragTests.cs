using System.Text.RegularExpressions;
using FluentAssertions;
using Xunit;
using static AutomationService.Tests.Support.InstallerSkript;

namespace AutomationService.Tests.Unit;

/// <summary>
/// In welcher Reihenfolge <c>installer/setup.iss</c> die Dateien ersetzt (#199).
/// Inno ersetzt sie in der Reihenfolge der <c>[Files]</c>-Einträge (issrc,
/// <c>Setup.Install.pas</c>, <c>CopyFiles</c>), innerhalb eines Platzhalters nach
/// Ordner und Name sortiert (<c>Compiler.SetupCompiler.pas</c>, <c>SortFileList</c>).
///
/// Bricht ein stilles Update ab, soll immer der alte Dienst zurückbleiben: Meldete
/// er schon die Zielversion, hielte die Merkdatei das Scheitern für Erfolg, und
/// „Erneut versuchen“ böte nichts an. Und Engine und AOT-Code der Oberfläche
/// sollen nicht weit auseinanderliegen — sie passen nur zueinander, wenn sie aus
/// derselben Flutter-Fassung stammen.
/// </summary>
public sealed class InstallerReihenfolgeVertragTests
{
    private const string Paket = "{#SourceDir}";
    private const string Dienst = Paket + @"\backend\";

    /// <summary>
    /// Was zuletzt kommt, in dieser Reihenfolge: die Laufzeit, die genau
    /// zusammenpassen muss, dann die Beschreibung des Dienstes und als
    /// allerletztes die DLL, aus der <c>Programmfassung.Aktuell</c> die Version liest.
    /// </summary>
    private static readonly string[] Kern =
    [
        "hostfxr.dll", "hostpolicy.dll", "coreclr.dll", "clrjit.dll", "System.Private.CoreLib.dll",
        "AutomationService.deps.json", "AutomationService.runtimeconfig.json", "AutomationService.dll",
    ];

    /// <summary>
    /// Engine, ICU-Daten und AOT-Code, in dieser Reihenfolge direkt nach dem
    /// Wurzelordner: Sie passen nur zusammen, wenn sie aus derselben
    /// Flutter-Fassung stammen.
    /// </summary>
    private static readonly string[] Oberflaechenkern =
        [Paket + @"\flutter_windows.dll", Paket + @"\data\icudtl.dat", Paket + @"\data\app.so"];

    /// <summary>
    /// Die drei Platzhalter in dieser Reihenfolge, jeder mit genau diesen
    /// Ausnahmen — eine fehlende brächte einen Kern zu früh, eine zusätzliche
    /// ließe eine Datei ganz weg.
    /// </summary>
    private static readonly (string Quelle, string[] Ausnahmen)[] Platzhalter =
    [
        (Dienst + "*", Kern.Select(name => @"\" + name).ToArray()),
        (Paket + @"\data\*", new[] { @"\icudtl.dat", @"\app.so" }),
        (Paket + @"\*", new[] { @"\backend", @"\data", @"\flutter_windows.dll" }),
    ];

    private static List<DateiEintrag> Eintraege => OhneKommentare(Setup, ';')
        .Where(zeile => zeile.StartsWith("Source:", StringComparison.Ordinal))
        .Select(DateiEintrag.Lies)
        .ToList();

    [Fact]
    public void Waehrend_der_Installation_laesst_sich_das_Update_nicht_abbrechen()
    {
        OhneKommentare(Setup, ';').Should().Contain(
            "AllowCancelDuringInstall=no", "Inno stellt ersetzte Dateien bei einem Abbruch nicht wieder her");
    }

    [Fact]
    public void Der_Kern_des_Dienstes_kommt_zuletzt_und_seine_DLL_als_allerletzte_Datei()
    {
        var eintraege = Eintraege;

        eintraege.TakeLast(Kern.Length).Select(e => e.Quelle)
            .Should().Equal(Kern.Select(name => Dienst + name), "der alte Dienst muss jeden Abbruch überstehen");
        eintraege[^1].Quelle.Should().Be(Dienst + "AutomationService.dll");
    }

    /// <summary>
    /// Ein Platzhalter, der einen Kern mitnähme, brächte ihn wieder nach vorn —
    /// <c>AutomationService.dll</c> sortiert früh. Jeder Platzhalter muss also
    /// bekannt sein und genau seine Kerne ausschließen; die Platzhalter kommen
    /// zuerst: Dienst, Daten, Wurzelordner.
    /// </summary>
    [Fact]
    public void Die_Platzhalter_kommen_zuerst_und_schliessen_genau_ihre_Kerne_aus()
    {
        var eintraege = Eintraege;
        var erwartet = Platzhalter.Select(p => p.Quelle).ToList();

        eintraege.Where(e => e.Quelle.EndsWith('*')).Select(e => e.Quelle)
            .Should().Equal(erwartet, "ein neuer Platzhalter gehört hier geprüft");
        eintraege.Take(erwartet.Count).Select(e => e.Quelle).Should().Equal(erwartet);
        foreach (var (quelle, ausnahmen) in Platzhalter)
        {
            eintraege.Single(e => e.Quelle == quelle).Ausnahmen.Should().BeEquivalentTo(ausnahmen, quelle);
        }
    }

    /// <summary>
    /// Jede Kerndatei steht genau einmal als eigener Eintrag da — und nur sie:
    /// Doppelt ersetzte Inno sie zweimal, ganz fehlte sie im Paket.
    /// </summary>
    [Fact]
    public void Jede_Kerndatei_ist_genau_einmal_ein_eigener_Eintrag()
    {
        var einzeln = Eintraege.Where(e => !e.Quelle.EndsWith('*')).Select(e => e.Quelle).ToList();

        einzeln.Should().OnlyHaveUniqueItems()
            .And.BeEquivalentTo(Oberflaechenkern.Concat(Kern.Select(name => Dienst + name)));
    }

    /// <summary>
    /// Erst der Wurzelordner — dort liegt, was ein offenes Fenster sperren kann
    /// (<c>automation_app.exe</c>) —, dann Engine, ICU-Daten und AOT-Code direkt
    /// hintereinander, dann der Kern des Dienstes. So trifft jede Sperre im
    /// Wurzelordner, bevor Engine oder AOT-Code ersetzt sind.
    /// </summary>
    [Fact]
    public void Engine_ICU_und_AOT_Code_folgen_direkt_auf_den_Wurzelordner_und_vor_dem_Dienstkern()
    {
        var quellen = Eintraege.Select(e => e.Quelle).ToList();
        var wurzel = quellen.IndexOf(Paket + @"\*");

        wurzel.Should().BeGreaterThan(-1);
        quellen.Skip(wurzel + 1).Take(Oberflaechenkern.Length + 1)
            .Should().Equal(Oberflaechenkern.Append(Dienst + Kern[0]));
    }

    /// <summary>
    /// Aufgeteilt wurde nur der Reihenfolge wegen: Jede Datei landet wie mit dem
    /// einen Eintrag vorher — im selben Ordner, ohne Versionsvergleich, mit allen
    /// Unterordnern.
    /// </summary>
    [Fact]
    public void Jeder_Eintrag_ersetzt_wie_der_eine_vorher()
    {
        foreach (var eintrag in Eintraege)
        {
            var relativ = eintrag.Quelle[Paket.Length..];
            eintrag.Ziel.Should().Be("{app}" + relativ[..relativ.LastIndexOf('\\')], eintrag.Quelle);
            eintrag.Flags.Should().Contain("ignoreversion", eintrag.Quelle);
            if (eintrag.Quelle.EndsWith('*'))
            {
                eintrag.Flags.Should().Contain("recursesubdirs").And.Contain("createallsubdirs", eintrag.Quelle);
            }
        }
    }

    /// <summary>Eine Zeile aus <c>[Files]</c>.</summary>
    private sealed record DateiEintrag(string Quelle, string Ziel, string[] Ausnahmen, string Flags)
    {
        public static DateiEintrag Lies(string zeile) => new(
            Wert(zeile, "Source") ?? "",
            Wert(zeile, "DestDir") ?? "",
            Wert(zeile, "Excludes")?.Split(',') ?? [],
            Regex.Match(zeile, "Flags: ([^;]+)").Groups[1].Value.Trim());

        private static string? Wert(string zeile, string name)
        {
            var treffer = Regex.Match(zeile, name + ": \"([^\"]*)\"");
            return treffer.Success ? treffer.Groups[1].Value : null;
        }
    }
}
