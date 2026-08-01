namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// Baut für die Entwickler-Simulation den Rohtext einer Zentralruf-Antwortmail
/// nach dem festen, maschinellen Aufbau der echten Antworten (siehe
/// Beispiele/Anwortemail von Zentralruf.txt). Der Text läuft anschließend durch
/// den <b>echten</b> Parser — die Simulation testet damit denselben Weg, den
/// eine echte Mail nimmt, nicht eine Abkürzung daran vorbei.
/// </summary>
public static class ZentralrufAntwortMailBuilder
{
    public static string Build(
        string referenz,
        string kennzeichen,
        string unfallDatum,
        string anfrageDatum,
        string versichererName,
        SimulationAntwortTyp typ)
    {
        var kopf = $"""
            Ihre Anfrage vom {anfrageDatum}
            Ihr Zeichen: {referenz}
            Angefragtes Kennzeichen: {kennzeichen}
            Nationalitätskennzeichen: D

            Sehr geehrte Damen und Herren,

            """;

        var kern = typ switch
        {
            SimulationAntwortTyp.KeinVersicherer => $"""
                zu dem Kennzeichen {kennzeichen} konnte kein Versicherer zum Unfalldatum {unfallDatum} ermittelt werden.

                """,
            SimulationAntwortTyp.Zwischennachricht => $"""
                eine automatische Zuordnung war für das Kennzeichen {kennzeichen} zum Schadentag {unfallDatum} leider nicht sofort möglich.

                Ihre Anfrage wurde an die zuständige Fachabteilung zur manuellen Überprüfung weitergeleitet. Wir melden uns unaufgefordert, sobald uns das Ergebnis vorliegt.

                """,
            _ => $"""
                zu dem Kennzeichen {kennzeichen} konnte folgender Versicherer zum Unfalldatum {unfallDatum} ermittelt werden:

                {versichererName}
                Lyoner Str. 10
                60524 Frankfurt
                Tel.: 0800/248544533
                Fax: 0800-2485329
                E-Mail: info@versicherer-simulation.de
                Versicherungsschein-Nr.: 999/123456-X
                Versicherungsbeginn: 07.10.2015

                """,
        };

        var fuss = """
            Unseren Auskünften liegen Daten zugrunde, die in regelmäßigen Abständen aktualisiert werden. Die Angaben erfolgen ohne Gewähr.

            Vielen Dank für Ihre Anfrage.

            Mit freundlichen Grüßen
            Ihr Zentralruf der Autoversicherer (SIMULIERTE ANTWORT — Entwicklermodus)
            """;

        return kopf + kern + fuss;
    }
}
