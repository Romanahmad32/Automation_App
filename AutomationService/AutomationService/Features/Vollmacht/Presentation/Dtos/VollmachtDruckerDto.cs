using AutomationService.Features.PdfConversion.Domain.Services;

namespace AutomationService.Features.Vollmacht.Presentation.Dtos;

/// <summary>
/// Antwort auf <c>GET api/Vollmacht/drucker</c>: der Windows-Standarddrucker,
/// an den „Drucken" geht. <see cref="Zustand"/> ist <c>bereit</c>,
/// <c>offline</c>, <c>gestoert</c>, <c>angehalten</c>, <c>keinDrucker</c> oder
/// <c>unbekannt</c>; <see cref="Hinweis"/> sagt es in Worten, außer bei <c>bereit</c>.
/// </summary>
public sealed record VollmachtDruckerDto(string? Name, string Zustand, string? Hinweis)
{
    public static VollmachtDruckerDto From(DruckerLage lage) => lage.Zustand switch
    {
        DruckerZustand.Bereit => new(lage.Name, "bereit", null),
        DruckerZustand.Offline => new(lage.Name, "offline",
            "Windows meldet den Drucker als offline — ist er eingeschaltet und verbunden?"),
        DruckerZustand.Gestoert => new(lage.Name, "gestoert",
            "Der Drucker meldet eine Störung, etwa Papierstau, kein Papier oder Toner."),
        DruckerZustand.Angehalten => new(lage.Name, "angehalten",
            "Die Druckwarteschlange ist angehalten — Aufträge bleiben dort liegen."),
        DruckerZustand.KeinDrucker => new(null, "keinDrucker",
            "In Windows ist kein Standarddrucker eingerichtet."),
        _ => new(lage.Name, "unbekannt",
            "Der Zustand des Druckers ließ sich nicht abfragen."),
    };
}
