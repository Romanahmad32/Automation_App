using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// Outlook im E2E-Testmodus (#168): nicht da. Kein outlook.exe, kein
/// STA-Thread, kein Griff in die Nachricht, die der Anwalt gerade offen hat.
///
/// „Nicht da" statt eines simulierten Outlook-Entwurfs: Der Entwurf nimmt
/// dann den Dateiweg (<see cref="TestmodusEntwurfDatei"/>), und die
/// <c>.eml</c> zeigt, was in Outlook aufgegangen wäre. Die Oberfläche meldet
/// dabei „Outlook war nicht erreichbar … als Datei geöffnet" — der Preis dafür,
/// den Nachrichtenaufbau nicht ein zweites Mal nachzubauen.
/// </summary>
public sealed class TestmodusOutlook : IOutlookVerbindung
{
    public void WaermeVor()
    {
        // Nichts vorzuwärmen: Es gibt kein Outlook, das starten könnte.
    }

    public bool OeffneEntwurf(EmailNachricht nachricht) => false;

    public OutlookAnhaenge AnhaengeDerAuswahl() => OutlookAnhaenge.Unerreichbar;
}
