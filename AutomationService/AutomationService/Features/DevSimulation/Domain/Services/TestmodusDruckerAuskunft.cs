using AutomationService.Features.PdfConversion.Domain.Services;

namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// Standarddrucker im E2E-Testmodus (#168). Ohne diese Attrappe nennte der
/// Vollmacht-Dialog vor dem Druck den echten Windows-Standarddrucker — und
/// spräche damit von einem Gerät, das im Testmodus nie ein Blatt bekommt.
/// </summary>
public sealed class TestmodusDruckerAuskunft : IDruckerAuskunft
{
    public DruckerLage Standarddrucker() =>
        new(TestmodusWordDrucker.Druckername, DruckerZustand.Bereit);
}
