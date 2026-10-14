using System.Globalization;

namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// Der Ordner, in dem die Attrappen des E2E-Testmodus (#168) ihre Spuren
/// hinterlassen: <c>&lt;Datenordner&gt;\Testmodus\</c> mit
/// <see cref="TestmodusProtokoll.Dateiname"/>, <see cref="Versand"/>,
/// <see cref="Entwuerfe"/>, <see cref="Druck"/> und <see cref="Aktualisierung"/>.
///
/// Die Wurzel kommt von außen und nicht aus <c>AppDataPaths</c>: Tests geben
/// jeder Klasse ihren eigenen Ordner und laufen so parallel, ohne sich Dateien
/// wegzuschreiben.
/// </summary>
public sealed class TestmodusOrdner
{
    public const string Versand = "Versand";
    public const string Entwuerfe = "Entwuerfe";
    public const string Druck = "Druck";
    public const string Aktualisierung = "Aktualisierung";

    private readonly TimeProvider _zeit;

    /// <param name="wurzel">Der Ordner <c>Testmodus</c>; wird beim ersten Schreiben angelegt.</param>
    /// <param name="zeit">Uhr für die Dateinamen; ohne Angabe die des Systems.</param>
    public TestmodusOrdner(string wurzel, TimeProvider? zeit = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(wurzel);
        Wurzel = Path.GetFullPath(wurzel);
        _zeit = zeit ?? TimeProvider.System;
    }

    public string Wurzel { get; }

    /// <summary>
    /// Legt eine neue, leere Datei an und gibt ihren vollen Pfad zurück:
    /// <c>&lt;unterordner&gt;\&lt;zeit&gt;[_&lt;zusatz&gt;]&lt;endung&gt;</c>, <c>&lt;zeit&gt;</c>
    /// lokal als <c>yyyyMMdd-HHmmss-fff</c>. Gibt es den Namen schon, hängt
    /// <c>-2</c>, <c>-3</c> … an.
    ///
    /// Angelegt mit <see cref="FileMode.CreateNew"/>, nicht nur ausgedacht: Zwei
    /// Versandvorgänge in derselben Millisekunde bekämen sonst denselben Namen,
    /// und der zweite überschriebe den ersten — genau die Spur, an der ein
    /// Testlauf prüft, was hinausgegangen wäre.
    /// </summary>
    public string NeueDatei(string unterordner, string endung, string? zusatz = null)
    {
        var ordner = Path.Combine(Wurzel, unterordner);
        Directory.CreateDirectory(ordner);

        var stamm = _zeit.GetLocalNow().ToString("yyyyMMdd-HHmmss-fff", CultureInfo.InvariantCulture);
        if (!string.IsNullOrWhiteSpace(zusatz))
        {
            stamm = $"{stamm}_{zusatz.Trim()}";
        }

        for (var nummer = 1; ; nummer++)
        {
            var name = nummer == 1 ? $"{stamm}{endung}" : $"{stamm}-{nummer}{endung}";
            var pfad = Path.Combine(ordner, name);
            try
            {
                File.Open(pfad, FileMode.CreateNew, FileAccess.Write).Dispose();
                return pfad;
            }
            catch (IOException) when (File.Exists(pfad))
            {
                // Vergeben — die nächste Nummer versuchen.
            }
        }
    }

    /// <summary>
    /// Der Pfad relativ zu <see cref="Wurzel"/>, mit <c>/</c> getrennt — so steht
    /// er im Protokoll, unabhängig davon, wo der Testlauf seinen Ordner hat.
    /// </summary>
    public string Relativ(string pfad) =>
        Path.GetRelativePath(Wurzel, pfad).Replace('\\', '/');
}
