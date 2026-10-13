using System.Globalization;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;

namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// <c>Testmodus\protokoll.jsonl</c> (#168): je Aktion einer Attrappe eine Zeile.
/// Daran prüfen der Agent und die E2E-Suite, was im echten Betrieb nach außen
/// gegangen wäre — auf diese Datei stützen sie sich, nicht auf die Dateinamen.
///
/// Das Format ist ein Vertrag mit den Skripten und der Suite: UTF-8 ohne BOM,
/// eine Zeile je JSON-Objekt, LF, nur angehängt, genau die vier Felder von
/// <see cref="TestmodusProtokollZeile"/>.
///
/// <b>Eine Sperre für alle Schreiber.</b> Der Dienst ist ein Singleton; Versand,
/// Entwurf und Druck können gleichzeitig schreiben, und zwei ungesperrte
/// Anhänge verschränken sich zu einer Zeile, die kein Parser mehr liest.
/// </summary>
public sealed class TestmodusProtokoll(TestmodusOrdner ordner)
{
    public const string Dateiname = "protokoll.jsonl";

    public const string ZentralrufAnfrage = "zentralruf-anfrage";
    public const string Versand = "versand";
    public const string GesendetAblage = "gesendet-ablage";
    public const string Entwurf = "entwurf";
    public const string Druck = "druck";

    /// <summary>
    /// Ohne HTML-Maskierung: Sonst stünde im Zeitstempel <c>+02:00</c> statt
    /// <c>+02:00</c> und in Dateinamen jeder Umlaut als Escape. Die Datei wird
    /// nirgends in HTML eingebettet, nur gelesen.
    /// </summary>
    private static readonly JsonSerializerOptions JsonOptionen = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    private static readonly UTF8Encoding OhneBom = new(encoderShouldEmitUTF8Identifier: false);

    private readonly Lock _sperre = new();

    public string Pfad => Path.Combine(ordner.Wurzel, Dateiname);

    /// <param name="aktion">Eine der Konstanten dieser Klasse.</param>
    /// <param name="referenz">
    /// Der Vorgang — nur die Zentralruf-Anfrage kennt ihn an ihrer Naht, alle
    /// übrigen schreiben <c>null</c>. Die Referenz von Versand und Entwurf steht
    /// im Versandprotokoll der Datenbank, das wie im echten Betrieb entsteht.
    /// </param>
    /// <param name="datei">Relativ zu <see cref="TestmodusOrdner.Wurzel"/>, oder <c>null</c>.</param>
    public void Schreibe(string aktion, string? referenz, string? datei)
    {
        var zeile = JsonSerializer.Serialize(
            new TestmodusProtokollZeile(
                DateTimeOffset.Now.ToString("o", CultureInfo.InvariantCulture),
                aktion,
                referenz,
                datei),
            JsonOptionen);

        lock (_sperre)
        {
            Directory.CreateDirectory(ordner.Wurzel);
            File.AppendAllText(Pfad, zeile + "\n", OhneBom);
        }
    }
}

/// <summary>Eine Zeile von <c>protokoll.jsonl</c>.</summary>
/// <param name="Zeit">Lokaler Zeitpunkt im Roundtrip-Format (<c>o</c>), mit Versatz.</param>
/// <param name="Aktion"><c>zentralruf-anfrage</c>, <c>versand</c>, <c>gesendet-ablage</c>, <c>entwurf</c> oder <c>druck</c>.</param>
/// <param name="Referenz">Der Vorgang, wo die Naht ihn kennt; sonst <c>null</c>.</param>
/// <param name="Datei">Die hinterlassene Datei relativ zum Ordner <c>Testmodus</c>, mit <c>/</c>; sonst <c>null</c>.</param>
public sealed record TestmodusProtokollZeile(string Zeit, string Aktion, string? Referenz, string? Datei);
