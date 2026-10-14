using System.Globalization;
using System.Text.RegularExpressions;
using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Nach dem Start des echten Installers fährt der Dienst selbst geordnet
/// herunter (#196) — über <c>StopApplication</c> wie beim Wächter auf die App,
/// aber erst nach <see cref="GeordnetesHerunterfahren.Verzoegerung"/>, damit
/// die Antwort beim Frontend ist und es seinen Abschied (2e) zeigen kann.
/// Uhr und Lebensdauer sind Attrappen: Gewartet wird nicht, beendet nichts.
/// </summary>
public sealed class GeordnetesHerunterfahrenTests : IDisposable
{
    private readonly HandUhr _uhr = new();
    private readonly LebensdauerAttrappe _lebensdauer = new();

    public void Dispose() => _lebensdauer.Dispose();

    private GeordnetesHerunterfahren Herunterfahren() =>
        new(_lebensdauer, NullLogger<GeordnetesHerunterfahren>.Instance, _uhr);

    [Fact]
    public async Task Stoesst_den_Stop_erst_nach_der_Verzoegerung_an()
    {
        Herunterfahren().StoesseAn();

        _lebensdauer.Stopps.Should().Be(0, "die Antwort auf „installieren“ ist noch unterwegs");
        _uhr.Vorstellen(GeordnetesHerunterfahren.Verzoegerung - TimeSpan.FromMilliseconds(1));
        _lebensdauer.Stopps.Should().Be(0, "das Frontend zeigt noch 2e");

        _uhr.Vorstellen(TimeSpan.FromMilliseconds(1));

        await _lebensdauer.Gestoppt.WaitAsync(TimeSpan.FromSeconds(10));
        _lebensdauer.Stopps.Should().Be(1);
    }

    /// <summary>
    /// Drei Zahlen an drei Orten, nur über diesen Test verbunden: wie lange das
    /// Frontend 2e zeigt, wie lange das Herunterfahren dauern darf und wie lange
    /// das Setup auf den Dienst wartet. Ändert sich eine, soll es hier auffallen
    /// statt beim Anwalt.
    /// </summary>
    [Fact]
    public void Die_Verzoegerung_liegt_hinter_dem_Abschied_des_Frontends_und_vor_der_Wartegrenze_des_Setups()
    {
        var wurzel = RepoWurzel.Pfad();
        var abschied = TimeSpan.FromSeconds(Zahl(
            Path.Combine(wurzel, "Automation_App_Frontend", "lib", "core", "aktualisierung", "presentation", "cubit", "aktualisierung_cubit.dart"),
            @"schliessPause\s*=\s*Duration\(seconds:\s*(\d+)\)"));
        var herunterfahren = TimeSpan.FromSeconds(Zahl(
            Path.Combine(wurzel, "AutomationService", "AutomationService", "Program.cs"),
            @"ShutdownTimeout\s*=\s*TimeSpan\.FromSeconds\((\d+)\)"));
        var wartegrenze = TimeSpan.FromMilliseconds(Zahl(
            Path.Combine(wurzel, "installer", "setup.iss"),
            @"WarteGrenzeMs\s*=\s*(\d+);"));

        GeordnetesHerunterfahren.Verzoegerung.Should().BeGreaterThan(abschied, "sonst sähe der Anwalt statt 2e den Startfehler der App");
        (GeordnetesHerunterfahren.Verzoegerung + herunterfahren).Should().BeLessThan(
            wartegrenze, "sonst überließe das Setup den Dienst mitten in der Sicherung dem Restart Manager");
    }

    private static int Zahl(string datei, string muster)
    {
        var treffer = Regex.Match(File.ReadAllText(datei), muster);
        treffer.Success.Should().BeTrue($"{Path.GetFileName(datei)} sollte „{muster}“ enthalten");
        return int.Parse(treffer.Groups[1].Value, CultureInfo.InvariantCulture);
    }

    /// <summary>
    /// Hat der Dienst einen Wächter, ist die App nach 2 s zu und er fährt schon
    /// herunter, bevor die Verzögerung abläuft. Dann bleibt es beim einen Stop.
    /// </summary>
    [Fact]
    public void Faehrt_der_Dienst_schon_herunter_bleibt_es_beim_ersten_Stop()
    {
        Herunterfahren().StoesseAn();
        _lebensdauer.StopApplication();

        _uhr.Vorstellen(TimeSpan.FromMinutes(1));

        _lebensdauer.Stopps.Should().Be(1);
    }

    [Fact]
    public void Ein_Anstoss_waehrend_des_Herunterfahrens_tut_nichts()
    {
        _lebensdauer.StopApplication();

        Herunterfahren().StoesseAn();
        _uhr.Vorstellen(TimeSpan.FromMinutes(1));

        _lebensdauer.Stopps.Should().Be(1);
    }
}
