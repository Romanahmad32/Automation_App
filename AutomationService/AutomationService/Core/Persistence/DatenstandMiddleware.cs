using System.Globalization;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Core.Persistence;

/// <summary>Verhindert, dass ein altes Frontendformular nach einem Import einen neuen HTTP-Schreibauftrag ausführt.</summary>
public sealed class DatenstandMiddleware(RequestDelegate next)
{
    public const string Header = "X-App-Datenstand";

    public async Task InvokeAsync(HttpContext context)
    {
        var pfad = AppDataPaths.DatabaseFilePath();
        var generation = DatenbankWechsel.Generation(pfad).ToString(CultureInfo.InvariantCulture);
        context.Response.OnStarting(() =>
        {
            context.Response.Headers[Header] = DatenbankWechsel.Generation(pfad).ToString(CultureInfo.InvariantCulture);
            return Task.CompletedTask;
        });
        var angefragt = context.Request.Headers[Header].ToString();
        if (angefragt.Length > 0 && angefragt != generation
            && !HttpMethods.IsGet(context.Request.Method) && !HttpMethods.IsHead(context.Request.Method))
        {
            context.Response.StatusCode = StatusCodes.Status409Conflict;
            await context.Response.WriteAsJsonAsync(new ProblemDetails
            {
                Status = StatusCodes.Status409Conflict,
                Title = "Datenstand gewechselt",
                Detail = "Die Ansicht gehört zu einem früheren Datenstand. Bitte nach dem Neuladen erneut prüfen und speichern.",
            }, context.RequestAborted);
            return;
        }
        // Auch ein erst nach dem Import erzeugter DbContext gehört noch zum
        // ursprünglichen HTTP-Auftrag und darf dessen alte Eingaben nicht speichern.
        var vorher = DatenbankWechsel.Auftrag.Value;
        DatenbankWechsel.Auftrag.Value = (pfad, long.Parse(generation, CultureInfo.InvariantCulture));
        try { await next(context); }
        finally { DatenbankWechsel.Auftrag.Value = vorher; }
    }
}
