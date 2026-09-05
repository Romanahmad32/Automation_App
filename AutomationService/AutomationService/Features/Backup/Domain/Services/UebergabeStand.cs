namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Was der Start über die Sicherungsablage wissen muss (§7.2, #39) — in einer
/// Auskunft, weil beides an derselben Stelle gezeigt wird: die Frage nach der
/// Übernahme und die Meldung über eine misslungene Sicherung.
/// </summary>
/// <param name="Angebot">
/// Der Arbeitsplatz, dessen Stand neuer ist als der eigene und als Archiv
/// bereitliegt — oder <c>null</c>, wenn es nichts zu übernehmen gibt.
/// </param>
/// <param name="EigenerStand">
/// Die eigene Akte, damit der Bildschirm zeigen kann, <em>was</em> ersetzt
/// würde. Ein Angebot ohne diesen Vergleich wäre eine Frage ohne die Hälfte der
/// Antwort.
/// </param>
/// <param name="LetzterLauf">Ergebnis der letzten automatischen Sicherung.</param>
/// <param name="AblageOrdner">
/// Der eingestellte Ordner, leer wenn abgeschaltet. Steht in der Auskunft, weil
/// eine Fehlermeldung über einen Ordner ohne dessen Namen nicht zu gebrauchen ist.
/// </param>
/// <param name="Bestand">
/// Wie viele eigene Archive liegen und wie weit sie zurückreichen (#112). Gehört
/// in dieselbe Auskunft, weil es an derselben Stelle gezeigt wird: „zuletzt
/// gesichert am …" allein sagt nicht, ob man auf vorgestern zurückkann.
/// </param>
public sealed record UebergabeStand(
    ArbeitsplatzEintrag? Angebot,
    ArbeitsplatzEintrag? EigenerStand,
    LetzteSicherung? LetzterLauf,
    string AblageOrdner,
    SicherungsBestand Bestand);
