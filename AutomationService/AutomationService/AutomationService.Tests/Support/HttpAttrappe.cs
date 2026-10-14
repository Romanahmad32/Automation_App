using System.Net;

namespace AutomationService.Tests.Support;

/// <summary>
/// Ein HTTP-Handler, der nie ins Netz geht (#196): Jede Anfrage bekommt die mit
/// <see cref="Antworte"/> hinterlegte Antwort, und jede wird mitgeschrieben. Unbekannte Adressen
/// enden in 404 statt in einer echten Verbindung — ein Test, der aus Versehen
/// GitHub fragte, schlüge so fehl statt still zu bestehen.
/// </summary>
internal sealed class HttpAttrappe : HttpMessageHandler
{
    private readonly Dictionary<Uri, Func<HttpResponseMessage>> _antworten = [];

    public List<HttpRequestMessage> Anfragen { get; } = [];

    public HttpAttrappe Antworte(Uri adresse, Func<HttpResponseMessage> antwort)
    {
        _antworten[adresse] = antwort;
        return this;
    }

    public HttpAttrappe AntworteJson(Uri adresse, string json) =>
        Antworte(adresse, () => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json"),
        });

    public HttpAttrappe AntworteBytes(Uri adresse, byte[] inhalt) =>
        Antworte(adresse, () => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new ByteArrayContent(inhalt),
        });

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        Anfragen.Add(request);
        var antwort = request.RequestUri is { } adresse && _antworten.TryGetValue(adresse, out var bauen)
            ? bauen()
            : new HttpResponseMessage(HttpStatusCode.NotFound);
        antwort.RequestMessage = request;
        return Task.FromResult(antwort);
    }
}

/// <summary>Gibt für jeden Namen einen Client über derselben <see cref="HttpAttrappe"/> heraus.</summary>
internal sealed class HttpAttrappenFabrik(HttpAttrappe handler) : IHttpClientFactory
{
    public HttpClient CreateClient(string name) => new(handler, disposeHandler: false);
}
