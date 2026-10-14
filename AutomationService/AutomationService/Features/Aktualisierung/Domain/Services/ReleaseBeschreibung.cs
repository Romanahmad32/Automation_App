using System.Text.Json.Serialization;

namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Der Ausschnitt von <c>GET …/releases/latest</c> der GitHub-API, auf den es
/// hier ankommt. Alles nullbar: Was fehlt, entscheidet
/// <see cref="SetupAuswahl"/> — nicht der JSON-Leser mit einer Ausnahme.
///
/// <c>releases/latest</c> lässt Entwürfe und Vorabversionen von sich aus weg;
/// gemeldet wird also nur, was wirklich veröffentlicht ist.
/// </summary>
public sealed record ReleaseBeschreibung(
    [property: JsonPropertyName("tag_name")] string? TagName,
    [property: JsonPropertyName("assets")] IReadOnlyList<ReleaseDatei>? Assets);

/// <summary>Eine an das Release gehängte Datei.</summary>
/// <param name="Name">Dateiname, z. B. <c>Automation_App_Setup_1.3.0.exe</c>.</param>
/// <param name="Size">Größe in Bytes.</param>
/// <param name="Digest">
/// <c>sha256:&lt;hex&gt;</c> — von GitHub beim Hochladen berechnet. Die
/// Echtheitsprüfung hängt daran (keine Authenticode-Signatur, #196).
/// </param>
/// <param name="BrowserDownloadUrl">Der direkte Download; auch der Rückfallweg „Lieber selbst herunterladen".</param>
public sealed record ReleaseDatei(
    [property: JsonPropertyName("name")] string? Name,
    [property: JsonPropertyName("size")] long? Size,
    [property: JsonPropertyName("digest")] string? Digest,
    [property: JsonPropertyName("browser_download_url")] string? BrowserDownloadUrl);
