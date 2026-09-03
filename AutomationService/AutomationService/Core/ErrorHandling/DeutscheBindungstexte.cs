using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Core.ErrorHandling;

/// <summary>
/// Die deutschen Meldungen fuer die Fehler, die *vor* den DTO-Schranken
/// entstehen: beim Binden der Anfrage an das Modell.
///
/// <see cref="Validierungstexte"/> deckt ab, was ein Attribut prueft — hier
/// geht es um die Stufe davor, wenn ein Wert gar nicht erst ankommt oder in
/// einer Form ankommt, die sich nicht in den Zieltyp bringen laesst. Diese
/// Texte kommen aus dem Rahmenwerk und sind englisch; sie lassen sich nur hier
/// austauschen, nicht am Attribut.
///
/// Ein Anwalt kann keinen davon selbst verursachen: den Anfragerumpf baut die
/// App. Sie sind trotzdem deutsch, weil sie sonst genau dann englisch auf dem
/// Bildschirm stehen, wenn etwas kaputt ist — und der Anwalt in dem Moment
/// entscheiden muss, ob er weiterarbeiten kann.
/// </summary>
public static class DeutscheBindungstexte
{
    public static void Setzen(MvcOptions options)
    {
        var texte = options.ModelBindingMessageProvider;

        texte.SetMissingBindRequiredValueAccessor(
            feld => $"Für {feld} wurde kein Wert übermittelt.");
        texte.SetMissingKeyOrValueAccessor(
            () => "Hier wird ein Wert erwartet.");
        texte.SetMissingRequestBodyRequiredValueAccessor(
            () => "Die Anfrage kam ohne Inhalt an.");
        texte.SetValueMustNotBeNullAccessor(
            wert => $"„{wert}“ ist hier kein zulässiger Wert.");
        texte.SetAttemptedValueIsInvalidAccessor(
            (wert, feld) => $"„{wert}“ ist kein zulässiger Wert für {feld}.");
        texte.SetNonPropertyAttemptedValueIsInvalidAccessor(
            wert => $"„{wert}“ ist kein zulässiger Wert.");
        texte.SetUnknownValueIsInvalidAccessor(
            feld => $"Der übermittelte Wert für {feld} ist unzulässig.");
        texte.SetNonPropertyUnknownValueIsInvalidAccessor(
            () => "Der übermittelte Wert ist unzulässig.");
        texte.SetValueIsInvalidAccessor(
            wert => $"„{wert}“ ist unzulässig.");
        texte.SetValueMustBeANumberAccessor(
            feld => $"{feld} muss eine Zahl sein.");
        texte.SetNonPropertyValueMustBeANumberAccessor(
            () => "Hier wird eine Zahl erwartet.");
    }
}
