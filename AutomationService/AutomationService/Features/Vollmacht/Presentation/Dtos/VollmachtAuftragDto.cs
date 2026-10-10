using System.ComponentModel.DataAnnotations;
using AutomationService.Core.ErrorHandling;
using AutomationService.Features.Vollmacht.Domain.Services;

namespace AutomationService.Features.Vollmacht.Presentation.Dtos;

/// <summary>
/// Anfrage an <c>POST api/Vollmacht/drucken|oeffnen</c>: die im Dialog geprüften
/// Kopfdaten (§4.11). <see cref="Art"/> ist einer der Werte aus
/// <see cref="VollmachtArten.Wert"/>.
/// </summary>
public sealed class VollmachtAuftragDto
{
    private const int MaxFeld = 300;

    [Display(Name = "Die Art der Vollmacht")]
    [Required(ErrorMessage = Validierungstexte.Pflicht)]
    public string Art { get; set; } = string.Empty;

    [Display(Name = "Die Referenz des Vorgangs")]
    [MaxLength(260, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Referenz { get; set; } = string.Empty;

    [MaxLength(MaxFeld, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string MandantVorname { get; set; } = string.Empty;

    [MaxLength(MaxFeld, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string MandantNachname { get; set; } = string.Empty;

    [MaxLength(MaxFeld, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string MandantStrasse { get; set; } = string.Empty;

    [MaxLength(MaxFeld, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string MandantPlz { get; set; } = string.Empty;

    [MaxLength(MaxFeld, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string MandantOrt { get; set; } = string.Empty;

    [MaxLength(MaxFeld, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string MandantTelefon { get; set; } = string.Empty;

    [MaxLength(MaxFeld, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string MandantEmail { get; set; } = string.Empty;

    [MaxLength(MaxFeld, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Unfalldatum { get; set; } = string.Empty;

    [MaxLength(MaxFeld, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string InSachen { get; set; } = string.Empty;

    [MaxLength(MaxFeld, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Wegen { get; set; } = string.Empty;

    /// <summary>Der Auftrag der Domain; null, wenn <see cref="Art"/> keine bekannte Art ist.</summary>
    public VollmachtAuftrag? ZuAuftrag() => VollmachtArten.AusWert(Art) is { } art
        ? new VollmachtAuftrag
        {
            Art = art,
            Referenz = Referenz,
            MandantVorname = MandantVorname,
            MandantNachname = MandantNachname,
            MandantStrasse = MandantStrasse,
            MandantPlz = MandantPlz,
            MandantOrt = MandantOrt,
            MandantTelefon = MandantTelefon,
            MandantEmail = MandantEmail,
            Unfalldatum = Unfalldatum,
            InSachen = InSachen,
            Wegen = Wegen,
        }
        : null;
}
