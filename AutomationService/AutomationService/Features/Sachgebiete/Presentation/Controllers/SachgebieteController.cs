using AutomationService.Features.Sachgebiete.Domain.Services;
using AutomationService.Features.Sachgebiete.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Sachgebiete.Presentation.Controllers;

/// <summary>
/// Lesezugriff auf den Sachgebietskatalog (§7.1). Bewusst nur GET: Der Katalog
/// kommt aus dem Seed; die Pflege in der App ist §7.1 [S] und bekommt ihre
/// Schreib-Endpunkte erst mit diesem Schnitt.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class SachgebieteController(ISachgebietKatalog katalog) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<SachgebietDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<SachgebietDto>>> GetAll(
        CancellationToken cancellationToken)
    {
        var eintraege = await katalog.GetAllAsync(cancellationToken);
        return Ok(eintraege.Select(SachgebietDto.From).ToList());
    }
}
