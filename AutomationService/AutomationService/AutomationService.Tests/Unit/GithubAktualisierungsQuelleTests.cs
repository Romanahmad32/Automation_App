using System.Net;
using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Features.Aktualisierung.Presentation.DependencyInjection;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die echte Update-Quelle (#196) gegen einen HTTP-Handler, der nie ins Netz
/// geht: was sie fragt, wie sie GitHubs Antwort liest und dass sie eine
/// Fehlerseite nie als Setup-Datei ausgibt. Dazu die Verdrahtung über
/// <see cref="IHttpClientFactory"/> — der Grund, warum der Dienst lädt und
/// nicht das Frontend: nur so gelten System-Proxy und Windows-Zertifikate.
/// </summary>
public sealed class GithubAktualisierungsQuelleTests
{
    private static readonly Uri Latest = new(AktualisierungOptions.VorgabeQuelle);
    private static readonly Uri Asset = new("https://github.com/Romanahmad32/Automation_App/releases/download/v1.4.0/Automation_App_Setup_1.4.0.exe");

    /// <summary>Ein Ausschnitt einer echten Antwort von <c>releases/latest</c>, gekürzt.</summary>
    private const string ReleaseJson = """
        {
          "html_url": "https://github.com/Romanahmad32/Automation_App/releases/tag/v1.4.0",
          "tag_name": "v1.4.0",
          "draft": false,
          "prerelease": false,
          "assets": [
            {
              "name": "Automation_App_Setup_1.4.0.exe",
              "content_type": "application/x-msdownload",
              "size": 88123456,
              "digest": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
              "browser_download_url": "https://github.com/Romanahmad32/Automation_App/releases/download/v1.4.0/Automation_App_Setup_1.4.0.exe"
            }
          ]
        }
        """;

    private static GithubAktualisierungsQuelle Quelle(HttpAttrappe http, string? quelle = null) => new(
        new HttpAttrappenFabrik(http),
        Options.Create(new AktualisierungOptions { Quelle = quelle ?? AktualisierungOptions.VorgabeQuelle }));

    [Fact]
    public async Task Liest_Tag_und_Setup_Datei_aus_releases_latest()
    {
        var http = new HttpAttrappe().AntworteJson(Latest, ReleaseJson);

        var release = await Quelle(http).HoleNeuesteAsync(CancellationToken.None);

        release.TagName.Should().Be("v1.4.0");
        release.Assets.Should().ContainSingle().Which.Should().Be(new ReleaseDatei(
            "Automation_App_Setup_1.4.0.exe",
            88_123_456,
            "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            Asset.AbsoluteUri));
        SetupAuswahl.Waehle(release, "1.3.0").Art.Should().Be(AuswahlArt.Verfuegbar);
    }

    [Fact]
    public async Task Fragt_mit_User_Agent_und_der_API_Fassung()
    {
        var http = new HttpAttrappe().AntworteJson(Latest, ReleaseJson);

        await Quelle(http).HoleNeuesteAsync(CancellationToken.None);

        var anfrage = http.Anfragen.Should().ContainSingle().Subject;
        anfrage.RequestUri.Should().Be(Latest);
        anfrage.Headers.UserAgent.ToString().Should().StartWith("AutomationService/", "ohne User-Agent antwortet GitHub mit 403");
        anfrage.Headers.UserAgent.ToString().Should().NotContain("+", "kein Commit an einen fremden Server");
        anfrage.Headers.Accept.ToString().Should().Be("application/vnd.github+json");
        anfrage.Headers.GetValues("X-GitHub-Api-Version").Should().Equal("2022-11-28");
    }

    [Fact]
    public async Task Fragt_die_eingestellte_Quelle_fuer_die_Abnahme()
    {
        var testRepo = new Uri("https://api.github.com/repos/kanzlei-test/Automation_App/releases/latest");
        var http = new HttpAttrappe().AntworteJson(testRepo, ReleaseJson);

        await Quelle(http, testRepo.AbsoluteUri).HoleNeuesteAsync(CancellationToken.None);

        http.Anfragen.Should().ContainSingle().Which.RequestUri.Should().Be(testRepo);
    }

    [Theory]
    [InlineData(HttpStatusCode.NotFound)]
    [InlineData(HttpStatusCode.Forbidden)]
    [InlineData(HttpStatusCode.InternalServerError)]
    public async Task Eine_Fehlerantwort_wirft(HttpStatusCode status)
    {
        var http = new HttpAttrappe().Antworte(Latest, () => new HttpResponseMessage(status));

        var holen = () => Quelle(http).HoleNeuesteAsync(CancellationToken.None);

        await holen.Should().ThrowAsync<HttpRequestException>();
    }

    /// <summary>
    /// GitHubs Ratenlimit (#199) ist keine fehlende Verbindung: 429 immer, 403 nur mit
    /// den Köpfen, an denen GitHub es kenntlich macht.
    /// </summary>
    [Theory]
    [InlineData(HttpStatusCode.TooManyRequests, null, null)]
    [InlineData(HttpStatusCode.Forbidden, "X-RateLimit-Remaining", "0")]
    [InlineData(HttpStatusCode.Forbidden, "Retry-After", "60")]
    public async Task Ein_Ratenlimit_wirft_eine_eigene_Ursache(HttpStatusCode status, string? kopf, string? wert)
    {
        var http = new HttpAttrappe().Antworte(Latest, () =>
        {
            var antwort = new HttpResponseMessage(status);
            if (kopf is not null)
            {
                antwort.Headers.TryAddWithoutValidation(kopf, wert);
            }

            return antwort;
        });

        var holen = () => Quelle(http).HoleNeuesteAsync(CancellationToken.None);

        (await holen.Should().ThrowAsync<QuelleAusgelastetException>()).Which.StatusCode.Should().Be(status);
    }

    /// <summary>
    /// Ein 403 ohne diese Köpfe kommt auch von einem Kanzlei-Proxy, der GitHub sperrt —
    /// „ausgelastet“ wäre dann falsch.
    /// </summary>
    [Fact]
    public async Task Ein_403_ohne_Ratenlimit_Koepfe_bleibt_eine_gescheiterte_Anfrage()
    {
        var http = new HttpAttrappe().Antworte(Latest, () =>
        {
            var antwort = new HttpResponseMessage(HttpStatusCode.Forbidden);
            antwort.Headers.TryAddWithoutValidation("X-RateLimit-Remaining", "42");
            return antwort;
        });

        var holen = () => Quelle(http).HoleNeuesteAsync(CancellationToken.None);

        (await holen.Should().ThrowAsync<HttpRequestException>()).Which.Should().NotBeOfType<QuelleAusgelastetException>();
    }

    [Fact]
    public async Task Eine_ungueltige_Quelle_wirft_ohne_Anfrage()
    {
        var http = new HttpAttrappe();

        var holen = () => Quelle(http, "kein Pfad").HoleNeuesteAsync(CancellationToken.None);

        await holen.Should().ThrowAsync<InvalidOperationException>();
        http.Anfragen.Should().BeEmpty();
    }

    [Fact]
    public async Task Der_Download_liefert_die_Bytes_der_Setup_Datei()
    {
        byte[] inhalt = [0x4D, 0x5A, 1, 2, 3];
        var http = new HttpAttrappe().AntworteBytes(Asset, inhalt);

        await using var strom = await Quelle(http).OeffneAsync(Asset, CancellationToken.None);
        using var kopie = new MemoryStream();
        await strom.CopyToAsync(kopie);

        kopie.ToArray().Should().Equal(inhalt);
        http.Anfragen.Should().ContainSingle().Which.Headers.Accept.ToString().Should().Be("application/octet-stream");
    }

    [Fact]
    public async Task Eine_Fehlerseite_ist_nie_eine_Setup_Datei()
    {
        var http = new HttpAttrappe().Antworte(Asset, () => new HttpResponseMessage(HttpStatusCode.NotFound)
        {
            Content = new StringContent("<html>Not Found</html>"),
        });

        var oeffnen = () => Quelle(http).OeffneAsync(Asset, CancellationToken.None);

        await oeffnen.Should().ThrowAsync<HttpRequestException>();
    }

    [Fact]
    public void Die_Verdrahtung_laedt_ueber_die_HttpClientFactory_ohne_Gesamtlimit()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        // Im Wirt bringt der Host beide mit; das Herunterfahren nach dem
        // Installer-Start hängt an der Lebensdauer, der Installer-Start an der Umgebung.
        services.AddSingleton<IHostApplicationLifetime, LebensdauerAttrappe>();
        services.AddSingleton<IHostEnvironment>(new FakeHostEnvironment(Path.GetTempPath()) { EnvironmentName = Environments.Production });
        services.AddAktualisierungServices(new ConfigurationBuilder().Build());
        using var anbieter = services.BuildServiceProvider(validateScopes: true);

        anbieter.GetRequiredService<IAktualisierungsQuelle>().Should().BeOfType<GithubAktualisierungsQuelle>();
        anbieter.GetRequiredService<IInstallerStarter>().Should().BeOfType<InstallerStarter>();
        anbieter.GetRequiredService<IHerunterfahrenNachInstallerStart>().Should().BeOfType<GeordnetesHerunterfahren>();
        anbieter.GetRequiredService<IAktualisierungsDienst>()
            .Should().BeSameAs(anbieter.GetRequiredService<IAktualisierungsDienst>(), "der Stand lebt zwischen den Anfragen");
        using var client = anbieter.GetRequiredService<IHttpClientFactory>().CreateClient(GithubAktualisierungsQuelle.ClientName);
        client.Timeout.Should().Be(Timeout.InfiniteTimeSpan, "ein Gesamtlimit bräche einen langsamen, aber laufenden Download ab");
        anbieter.GetRequiredService<IOptions<AktualisierungOptions>>().Value.Quelle
            .Should().Be(AktualisierungOptions.VorgabeQuelle);
    }
}
