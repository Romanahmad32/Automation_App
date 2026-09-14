using System.Reflection;
using AutomationService.Features.MailboxMonitor.Domain.Services;
using AutomationService.Features.MailboxMonitor.Presentation.Controllers;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Das Auffangnetz des Controllers (§4.3, Review): Ein lokaler Schreibfehler
/// im Zwischenlager wird bereits in der Domäne in eine <c>PosteingangException</c>
/// übersetzt (siehe <c>PosteingangAnhaengeTests</c>). Bleibt ausnahmsweise eine
/// rohe <see cref="UnauthorizedAccessException"/> übrig — etwa aus einem
/// unbedachten Pfad —, darf daraus trotzdem keine 500-Antwort mit Stacktrace
/// werden, sondern eine deutsche Meldung.
///
/// Getestet wird die private <c>AusfuehrenAsync</c>-Zuordnung direkt statt über
/// einen echten <see cref="PosteingangDienst"/>: Der hängt an einer echten
/// IMAP-Verbindung, die dieser Test gerade nicht braucht.
/// </summary>
public sealed class PosteingangControllerTests
{
    [Fact]
    public async Task UnauthorizedAccessException_ErgibtDeutscheMeldungStatt500MitStacktrace()
    {
        var controller = NeuerController();

        var ergebnis = await AusfuehrenAsync(
            controller, () => throw new UnauthorizedAccessException("Zugriff verweigert"));

        var objekt = ergebnis.Result.Should().BeOfType<ObjectResult>().Subject;
        var problem = objekt.Value.Should().BeOfType<ProblemDetails>().Subject;
        problem.Status.Should().Be(StatusCodes.Status500InternalServerError);
        problem.Detail.Should().Contain("Zugriffsrechte");
    }

    private static PosteingangController NeuerController()
    {
        var dienstleistungen = new ServiceCollection();
        dienstleistungen.AddMvcCore();
        var anbieter = dienstleistungen.BuildServiceProvider();
        return new PosteingangController(null!)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { RequestServices = anbieter },
            },
        };
    }

    /// <summary>Ruft die private generische Fehlerzuordnung des Controllers über Reflection auf.</summary>
    private static async Task<ActionResult<string>> AusfuehrenAsync(
        PosteingangController controller, Func<Task<string>> aktion)
    {
        var methode = typeof(PosteingangController)
            .GetMethod("AusfuehrenAsync", BindingFlags.NonPublic | BindingFlags.Instance)!
            .MakeGenericMethod(typeof(string));
        return await (Task<ActionResult<string>>)methode.Invoke(controller, [aktion, CancellationToken.None])!;
    }
}
