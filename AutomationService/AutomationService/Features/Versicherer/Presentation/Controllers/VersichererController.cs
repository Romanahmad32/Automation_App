using AutomationService.Features.Versicherer.Domain.Services;
using AutomationService.Features.Versicherer.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Versicherer.Presentation.Controllers;

/// <summary>
/// Lesezugriff auf die Versicherer-Wissensbasis. Bewusst nur GET: das Register
/// wird ausschließlich automatisch aus Zentralruf-Antworten befüllt, eine
/// Verwaltungsoberfläche gibt es nicht.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class VersichererController(IVersichererWissen versichererWissen) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<VersichererDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<VersichererDto>>> GetAll(CancellationToken cancellationToken)
    {
        var eintraege = await versichererWissen.GetAllAsync(cancellationToken);
        return Ok(eintraege.Select(VersichererDto.From).ToList());
    }
}
