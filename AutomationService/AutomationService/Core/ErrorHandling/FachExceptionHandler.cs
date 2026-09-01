using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Features.FormTemplates.Domain.Services;
using AutomationService.Features.Mandanten.Domain.Services;
using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.WordAutomation.Domain.Exceptions;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Core.ErrorHandling;

/// <summary>
/// Bildet die Fach-Ausnahmen, die quer über die Slices geworfen werden, auf
/// ein einziges Antwortformat ab: RFC 7807 <see cref="ProblemDetails"/> mit
/// deutschem <c>title</c> und der Ausnahme-Nachricht als <c>detail</c>.
///
/// Vorher fing jeder Controller "seine" Ausnahme selbst und baute daraus mal
/// einen nackten String, mal ein eigenes DTO — vier Formen für denselben
/// Sachverhalt. Dieser Handler ist die einzige Stelle, die das noch tut; die
/// Controller werfen nur noch weiter.
///
/// Bewusst <em>nicht</em> hier behandelt: die "ok/errorCode"-DTOs von
/// WordAutomation und Zentralruf sind Erfolgs-Antworten mit eingebettetem
/// Fehlerstatus, die das Frontend fachlich auswertet — <see
/// cref="ZieldateiGesperrtException"/> und <see cref="TemplateProcessingException"/>
/// fängt <c>WordAutomationController</c> deshalb weiterhin selbst; sie
/// erreichen diesen Handler nur, falls sie einmal anderswo unbehandelt bleiben.
/// </summary>
public sealed class FachExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var (statusCode, title) = exception switch
        {
            MandantNameConflictException => (StatusCodes.Status409Conflict, "Namenskonflikt"),
            FormTemplateNameConflictException => (StatusCodes.Status409Conflict, "Namenskonflikt"),
            InvalidBackupException => (StatusCodes.Status400BadRequest, "Ungültige Sicherungsdatei"),
            PdfConversionUnavailableException =>
                (StatusCodes.Status503ServiceUnavailable, "PDF-Konvertierung nicht verfügbar"),
            EmailVersandException email => (StatusFuer(email.Grund), "E-Mail-Versand fehlgeschlagen"),
            TemplateProcessingException => (StatusCodes.Status500InternalServerError, "Verarbeitungsfehler"),
            ZieldateiGesperrtException => (StatusCodes.Status409Conflict, "Datei ist gesperrt"),
            _ => (0, string.Empty),
        };

        if (statusCode == 0)
        {
            return false;
        }

        httpContext.Response.StatusCode = statusCode;
        await httpContext.Response.WriteAsJsonAsync(
            new ProblemDetails
            {
                Status = statusCode,
                Title = title,
                Detail = exception.Message,
            },
            cancellationToken);
        return true;
    }

    /// <summary>
    /// Was der Anwalt selbst beheben kann, ist eine 400 — was der Server
    /// verweigert hat, eine 502. Die Unterscheidung entscheidet in der
    /// Oberfläche darüber, ob ein erneuter Versuch überhaupt Sinn hat.
    /// </summary>
    private static int StatusFuer(EmailVersandFehler grund) => grund switch
    {
        EmailVersandFehler.Anmeldung
            or EmailVersandFehler.Server
            or EmailVersandFehler.Entwurf => StatusCodes.Status502BadGateway,
        _ => StatusCodes.Status400BadRequest,
    };
}
