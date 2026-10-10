namespace AutomationService.Features.PdfConversion.Domain.Services;

/// <summary>Was Windows über einen Drucker meldet — grob genug, um es dem Anwalt zu sagen.</summary>
public enum DruckerZustand
{
    /// <summary>Kein Fehler gemeldet. Ob wirklich Papier kommt, weiß Windows nicht.</summary>
    Bereit,

    /// <summary>Offline, oder „Drucker offline verwenden" ist eingeschaltet.</summary>
    Offline,

    /// <summary>Papierstau, kein Papier, kein Toner, Klappe offen, Eingriff nötig.</summary>
    Gestoert,

    /// <summary>Die Warteschlange ist angehalten.</summary>
    Angehalten,

    /// <summary>Kein Standarddrucker eingerichtet.</summary>
    KeinDrucker,

    /// <summary>Der Drucker ließ sich nicht abfragen.</summary>
    Unbekannt,
}

/// <param name="Name">Der Windows-Standarddrucker; <c>null</c> bei <see cref="DruckerZustand.KeinDrucker"/>.</param>
/// <param name="Zustand">Was Windows über ihn meldet.</param>
public sealed record DruckerLage(string? Name, DruckerZustand Zustand);

/// <summary>
/// Der Windows-Standarddrucker und sein gemeldeter Zustand (§4.11) — damit der
/// Anwalt vor dem Druck sieht, wohin das Blatt geht, und ein offline
/// gemeldeter Drucker nicht erst am leeren Ausgabefach auffällt.
///
/// Nur lesend. Eine Auswahl gibt es bewusst nicht: Ein Drucker, den die App in
/// Word setzt (<c>ActivePrinter</c>), wird damit zum Standarddrucker von
/// Windows — für alle Programme. Hinter einer Schnittstelle, damit die Tests
/// ohne Drucker laufen.
/// </summary>
public interface IDruckerAuskunft
{
    DruckerLage Standarddrucker();
}
