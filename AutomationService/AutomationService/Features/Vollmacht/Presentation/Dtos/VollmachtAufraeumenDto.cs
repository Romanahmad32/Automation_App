using System.ComponentModel.DataAnnotations;
using AutomationService.Core.ErrorHandling;

namespace AutomationService.Features.Vollmacht.Presentation.Dtos;

/// <summary>
/// Anfrage an <c>POST api/Vollmacht/aufraeumen</c> (#174): zu welchem Vorgang die
/// Vollmachtdateien im Arbeitsordner gelöscht werden sollen.
/// </summary>
public sealed class VollmachtAufraeumenDto
{
    /// <summary>
    /// Pflicht: Ohne Referenz zeigte der Arbeitsordner auf „Ohne Vorgang", den
    /// sich alle frei erfassten Schreiben teilen.
    /// </summary>
    [Display(Name = "Die Referenz des Vorgangs")]
    [Required(ErrorMessage = Validierungstexte.Pflicht)]
    [MaxLength(260, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Referenz { get; set; } = string.Empty;
}
