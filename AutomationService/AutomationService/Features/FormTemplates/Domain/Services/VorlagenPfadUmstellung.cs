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
/// (#130).
/// </para>
///
/// <para>
/// <b>Welcher der beiden gilt, entscheidet die Platte.</b> Ein relativer
/// Bestandspfad meint zwei verschiedene Dateien, je nachdem gegen welchen
/// Ordner man ihn liest, und die Datenbank sagt nicht, welche gemeint war:
/// Der Anwalt kann den Anker verschoben haben (die Dateien liegen weiter in
/// <c>vorher</c>) oder seine Vorlagen mitgenommen haben (sie liegen jetzt in
/// <c>nachher</c>). Deshalb wird nachgesehen. Liegt die Datei im neuen Ordner,
/// <b>bleibt der Pfad relativ</b> — ihn dann gegen den alten Ordner absolut zu
/// machen, machte aus einer mitnehmbaren Verknuepfung wieder ein
/// <c>C:\Users\&lt;Name&gt;\…</c>, das auf dem zweiten Arbeitsplatz ins Leere
/// zeigt, und damit #33 rueckgaengig. Nur wenn sie dort fehlt und im alten
/// Ordner liegt, wird der absolute Pfad daraus: Er zeigt weiter auf die Datei,
/// und das ist mehr wert als eine kurze Schreibweise ins Nichts.
/// </para>
/// </summary>
public static class VorlagenPfadUmstellung
{
    /// <inheritdoc cref="StelleUmAsync(AutomationDbContext, string, string, Func{string, bool}, CancellationToken)"/>
    public static Task<int> StelleUmAsync(
        AutomationDbContext db, string vorher, string nachher, CancellationToken cancellationToken) =>
        StelleUmAsync(db, vorher, nachher, File.Exists, cancellationToken);

    /// <summary>
    /// Stellt alle Bestandspfade von <paramref name="vorher"/> auf
    /// <paramref name="nachher"/> um; liefert die Zahl der geaenderten Vorlagen.
    ///
    /// <paramref name="existiert"/> ist die einzige IO dieser Klasse und
    /// deshalb injizierbar — wie bei <c>OrdnerZustaende</c>: Ein Test, der
    /// echte Dateien anlegen muesste, um eine Fallunterscheidung zu pruefen,
    /// prueft am Ende das Dateisystem.
    /// </summary>
    public static async Task<int> StelleUmAsync(
        AutomationDbContext db,
        string vorher,
        string nachher,
        Func<string, bool> existiert,
        CancellationToken cancellationToken)
    {
        var geaendert = 0;
        var vorlagen = await db.FormTemplates.ToListAsync(cancellationToken);
        foreach (var vorlage in vorlagen)
        {
            var ohne = StelleUm(vorher, nachher, vorlage.WordFilePathOhneAuflistung, existiert);
            var mit = StelleUm(vorher, nachher, vorlage.WordFilePathMitAuflistung, existiert);
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
    /// Ein Pfad. Ein absoluter wird gegen den neuen Ordner gespeichert — liegt
    /// er ausserhalb, bleibt er stehen. Ein relativer bleibt relativ, solange
    /// die Datei im neuen Ordner liegt; nur wenn sie dort fehlt und im alten zu
    /// finden ist, wird er gegen den alten aufgeloest (siehe Klassenkommentar).
    /// Ist sie in beiden nicht zu finden, ist nichts zu entscheiden: Dann
    /// bleibt die kurze, mitnehmbare Schreibweise stehen.
    /// </summary>
    static string? StelleUm(
        string vorher, string nachher, string? gespeichert, Func<string, bool> existiert)
    {
        if (string.IsNullOrWhiteSpace(gespeichert))
        {
            return gespeichert;
        }

        if (Path.IsPathRooted(gespeichert.Trim()))
        {
            return VorlagenPfad.MacheRelativ(nachher, gespeichert);
        }

        var imNeuen = VorlagenPfad.LoeseAuf(nachher, gespeichert);
        var imAlten = VorlagenPfad.LoeseAuf(vorher, gespeichert);
        if (imNeuen is null || imAlten is null || existiert(imNeuen) || !existiert(imAlten))
        {
            return gespeichert;
        }

        return VorlagenPfad.MacheRelativ(nachher, imAlten);
    }
}
