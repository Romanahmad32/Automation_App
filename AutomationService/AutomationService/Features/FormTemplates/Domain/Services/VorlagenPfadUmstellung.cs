using AutomationService.Core.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.FormTemplates.Domain.Services;

/// <summary>
/// Einmalige Umstellung des Bestands, wenn sich der wirksame Vorlagenordner
/// aendert (#33): Absolute Pfade, die im neuen Ordner liegen, werden auf den
/// Rest ab dem Ordner verkuerzt. Aussenliegende bleiben absolut — sie weiter zu
/// benutzen ist richtig, nur mitnehmen auf einen zweiten Rechner laesst sich das
/// nicht (das Hineinholen bietet die Oberflaeche an).
///
/// <para>
/// <b>Der alte Ordner gehoert dazu.</b> Ein Bestandspfad ist in aller Regel
/// schon relativ — gegen den <em>bisherigen</em> Ordner. Wer ihn nur gegen den
/// neuen relativiert, laesst ihn von <c>Path.GetFullPath</c> gegen das
/// Arbeitsverzeichnis des Dienstes aufloesen, findet ihn dort erwartungsgemaess
/// nicht und gibt ihn unveraendert zurueck: Die Verknuepfung zeigt danach in
/// den neuen Ordner, in dem die Datei nie lag. Genau das ist passiert, als der
/// App-Daten-Ordner gesetzt wurde (#103) und damit den Anker verschob — alle
/// vier Vorlagen meldeten „Die verknuepfte Word-Datei wurde nicht gefunden"
/// (#130). Deshalb zuerst gegen den <c>vorher</c>-Ordner aufloesen und erst
/// den absoluten Pfad gegen <c>nachher</c> relativieren: Ein
/// Ordnerwechsel darf bestehende Verknuepfungen nicht entwerten.
/// </para>
/// </summary>
public static class VorlagenPfadUmstellung
{
    /// <summary>
    /// Stellt alle Bestandspfade von <paramref name="vorher"/> auf
    /// <paramref name="nachher"/> um; liefert die Zahl der geaenderten Vorlagen.
    /// </summary>
    public static async Task<int> StelleUmAsync(
        AutomationDbContext db, string vorher, string nachher, CancellationToken cancellationToken)
    {
        var geaendert = 0;
        var vorlagen = await db.FormTemplates.ToListAsync(cancellationToken);
        foreach (var vorlage in vorlagen)
        {
            var ohne = StelleUm(vorher, nachher, vorlage.WordFilePathOhneAuflistung);
            var mit = StelleUm(vorher, nachher, vorlage.WordFilePathMitAuflistung);
            if (ohne == vorlage.WordFilePathOhneAuflistung && mit == vorlage.WordFilePathMitAuflistung)
            {
                continue;
            }

            vorlage.WordFilePathOhneAuflistung = ohne;
            vorlage.WordFilePathMitAuflistung = mit;
            geaendert++;
        }

        if (geaendert > 0)
        {
            await db.SaveChangesAsync(cancellationToken);
        }

        return geaendert;
    }

    /// <summary>
    /// Ein Pfad: gegen den alten Ordner auf seine echte Lage aufgeloest, dann
    /// gegen den neuen gespeichert. Liegt die Datei ausserhalb des neuen
    /// Ordners, bleibt der absolute Pfad stehen — er zeigt weiter auf die
    /// Datei, und das ist mehr wert als eine kurze Schreibweise, die ins Leere
    /// zeigt.
    /// </summary>
    static string? StelleUm(string vorher, string nachher, string? gespeichert) =>
        VorlagenPfad.MacheRelativ(nachher, VorlagenPfad.LoeseAuf(vorher, gespeichert));
}
