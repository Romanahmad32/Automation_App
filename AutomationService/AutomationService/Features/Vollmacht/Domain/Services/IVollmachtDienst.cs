namespace AutomationService.Features.Vollmacht.Domain.Services;

/// <summary>Füllt die Vollmacht zu einem Vorgang und druckt oder öffnet sie (§4.11).</summary>
public interface IVollmachtDienst
{
    /// <summary>
    /// Füllt die Vorlage und schickt sie an den Standarddrucker. Nach dem Druck
    /// ist die Arbeitsdatei gelöscht — abgelegt wird nichts. Scheitert der
    /// Druck, bleibt sie liegen und das Ergebnis nennt ihren Pfad.
    /// </summary>
    Task<VollmachtErgebnis> DruckeAsync(VollmachtAuftrag auftrag, CancellationToken cancellationToken = default);

    /// <summary>Füllt die Vorlage nur aus („In Word öffnen"); die Datei bleibt liegen.</summary>
    VollmachtErgebnis FuelleAus(VollmachtAuftrag auftrag);
}
