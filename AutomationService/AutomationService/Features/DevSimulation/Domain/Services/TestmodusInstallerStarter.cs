using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using AutomationService.Features.Aktualisierung.Domain.Services;

namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// Installer-Start im E2E-Testmodus (#196): startet nichts. Er legt den Aufruf,
/// der hinausgegangen wäre, als <c>Testmodus\Aktualisierung\&lt;zeit&gt;_installer.json</c>
/// ab (<see cref="InstallerAufruf"/>: Setup-Pfad, Argumente, Arbeitsordner,
/// Zielversion) und schreibt dazu eine Zeile <c>aktualisierung-installer</c> ins
/// <see cref="TestmodusProtokoll"/>, deren <c>datei</c> auf diese Ablage zeigt.
///
/// Die Angaben stehen in der Ablage und nicht in der Zeile selbst: Das
/// Protokoll hat genau vier Felder, und auf die verlassen sich Skripte und Suite.
///
/// Gesperrt ist er nie (kein <see cref="Sperrgrund"/>), und sein „Setup" gilt
/// als laufend, ohne dass jemand die Anlauffrist abwartet — der Testmodus geht
/// den Weg bis zum Ende, ohne Sekunden zu verlieren.
/// </summary>
public sealed class TestmodusInstallerStarter(TestmodusOrdner ordner, TestmodusProtokoll protokoll) : IInstallerStarter
{
    private static readonly JsonSerializerOptions JsonOptionen = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
        WriteIndented = true,
    };

    public string? Sperrgrund => null;

    public IInstallerLauf Starte(InstallerAufruf aufruf)
    {
        ArgumentNullException.ThrowIfNull(aufruf);

        var pfad = ordner.NeueDatei(TestmodusOrdner.Aktualisierung, ".json", zusatz: "installer");
        File.WriteAllText(pfad, JsonSerializer.Serialize(aufruf, JsonOptionen), new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
        protokoll.Schreibe(TestmodusProtokoll.AktualisierungInstaller, referenz: null, ordner.Relativ(pfad));
        return new LaeuftWeiter();
    }

    /// <summary>Das nie gestartete Setup: läuft aus Sicht des Dienstes weiter, sofort.</summary>
    private sealed class LaeuftWeiter : IInstallerLauf
    {
        public int? WarteAufEnde(TimeSpan frist) => null;

        public void Dispose()
        {
        }
    }
}
