using System.Text.Json;
using AutomationService.Core.Lifetime;
using Microsoft.Extensions.Options;

namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Die echte Quelle: GitHubs öffentliche Release-API und der Download dahinter
/// (#196). Über <see cref="IHttpClientFactory"/>, damit System-Proxy und
/// Windows-Zertifikatsspeicher von selbst gelten — der Grund, warum der Dienst
/// lädt und nicht das Frontend (Darts <c>HttpClient</c> kennt keinen Proxy).
///
/// Ohne Zeitlimit am Client (<see cref="Timeout.InfiniteTimeSpan"/> in der
/// Verdrahtung): Die Prüfung begrenzt <see cref="AktualisierungsDienst"/> selbst,
/// den Download der Leerlauf in <see cref="SetupDownload"/>. Ein Gesamtlimit
/// bräche einen langsamen, aber laufenden Download ab.
/// </summary>
public sealed class GithubAktualisierungsQuelle(
    IHttpClientFactory clientFabrik,
    IOptions<AktualisierungOptions> optionen) : IAktualisierungsQuelle
{
    public const string ClientName = "Aktualisierung";

    /// <summary>
    /// Ohne User-Agent weist GitHub jede Anfrage mit 403 ab. Die Version darin
    /// ohne Commit-Anhang — sie geht an einen fremden Server.
    /// </summary>
    public static string UserAgent { get; } =
        $"AutomationService/{Versionsnummer.Lies(Programmfassung.Aktuell)?.ToString() ?? Programmfassung.Unbekannt}";

    public async Task<ReleaseBeschreibung> HoleNeuesteAsync(CancellationToken cancellationToken)
    {
        if (!Uri.TryCreate(optionen.Value.Quelle, UriKind.Absolute, out var quelle))
        {
            throw new InvalidOperationException(
                $"„{AktualisierungOptions.SectionName}:Quelle“ ist keine gültige Adresse: {optionen.Value.Quelle}");
        }

        using var anfrage = Anfrage(quelle, "application/vnd.github+json");
        anfrage.Headers.TryAddWithoutValidation("X-GitHub-Api-Version", "2022-11-28");

        using var antwort = await clientFabrik.CreateClient(ClientName)
            .SendAsync(anfrage, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        antwort.EnsureSuccessStatusCode();

        return await antwort.Content.ReadFromJsonAsync<ReleaseBeschreibung>(cancellationToken)
            ?? throw new JsonException("Die Release-Auskunft war leer.");
    }

    public async Task<Stream> OeffneAsync(Uri adresse, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(adresse);

        using var anfrage = Anfrage(adresse, "application/octet-stream");
        var antwort = await clientFabrik.CreateClient(ClientName)
            .SendAsync(anfrage, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        try
        {
            // Eine Fehlerseite ist kein Setup — auch wenn die Prüfsumme sie
            // später ohnehin verwürfe, soll der Anwender „Download gescheitert"
            // lesen und nicht „Datei verändert".
            antwort.EnsureSuccessStatusCode();
            return await antwort.Content.ReadAsStreamAsync(cancellationToken);
        }
        catch
        {
            antwort.Dispose();
            throw;
        }
    }

    private static HttpRequestMessage Anfrage(Uri adresse, string annahme)
    {
        var anfrage = new HttpRequestMessage(HttpMethod.Get, adresse);
        anfrage.Headers.TryAddWithoutValidation("User-Agent", UserAgent);
        anfrage.Headers.TryAddWithoutValidation("Accept", annahme);
        return anfrage;
    }
}
