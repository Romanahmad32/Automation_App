using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Features.Aktualisierung.Presentation.HostedServices;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Was der Dienst beim Start über die Update-Quelle protokolliert (#199). Für die
/// Abnahme mit Testversionen wird sie umgelenkt (<c>Aktualisierung__Quelle</c>) —
/// ob das gegriffen hat, soll im Protokoll stehen und nicht erst daran zu erraten
/// sein, welche Version der Dialog anbietet.
/// </summary>
public sealed class AktualisierungStartDienstTests : IDisposable
{
    private const string TestRepo = "https://api.github.com/repos/kanzlei-test/Automation_App/releases/latest";

    private readonly AktualisierungsUmgebung _umgebung = new();
    private readonly ListenLogger<AktualisierungStartDienst> _logger = new();

    public void Dispose() => _umgebung.Dispose();

    [Fact]
    public async Task Eine_umgelenkte_Quelle_steht_einmal_im_Protokoll()
    {
        using var dienst = _umgebung.Dienst();

        await StartDienst(dienst, TestRepo).StartAsync(CancellationToken.None);

        _logger.Nachrichten.Should().ContainSingle(nachricht => nachricht.Contains(TestRepo, StringComparison.Ordinal))
            .Which.Should().Contain(AktualisierungOptions.VorgabeQuelle, "der Vergleich gehört dazu");
    }

    [Fact]
    public async Task Die_Vorgabe_ist_keine_Zeile_wert()
    {
        using var dienst = _umgebung.Dienst();

        await StartDienst(dienst, AktualisierungOptions.VorgabeQuelle).StartAsync(CancellationToken.None);

        _logger.Nachrichten.Should().NotContain(
            nachricht => nachricht.Contains(AktualisierungOptions.VorgabeQuelle, StringComparison.Ordinal),
            "im Betrieb steht dort immer die Vorgabe; eine Zeile bei jedem Start wäre Rauschen");
    }

    private AktualisierungStartDienst StartDienst(IAktualisierungsDienst dienst, string quelle) => new(
        dienst,
        new FakeHostEnvironment(_umgebung.Basis) { EnvironmentName = Environments.Development },
        Options.Create(new AktualisierungOptions { Quelle = quelle }),
        _logger);
}
