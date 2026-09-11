namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Die Lage eines einzelnen Ordnerfelds (#103): was gespeichert steht, was der
/// Dienst daraus tatsaechlich benutzt, und warum die beiden auseinanderfallen.
///
/// Gebraucht wird das, weil die gespeicherte Form seit #103 nicht mehr der
/// Ordner ist: Sie kann relativ sein, sie kann leer sein und trotzdem einen
/// wirksamen Ordner haben (abgeleitet), und sie kann gesetzt sein, ohne sich
/// auf diesem Rechner aufloesen zu lassen. Ein einzelnes Textfeld in den
/// Einstellungen kann das nicht mehr erzaehlen — ohne diesen Zustand zeigte es
/// im schlechtesten Fall einen Pfad ins Leere.
/// </summary>
/// <param name="Feld">camelCase-Feldname wie im HTTP-Vertrag.</param>
/// <param name="Gespeichert">Speicherform, leer wenn nicht gesetzt.</param>
/// <param name="Wirksam">Der Ordner, den der Dienst nutzt; leer wenn keiner.</param>
/// <param name="Zustand">Einer aus <see cref="OrdnerZustandArten"/>.</param>
/// <param name="Anker">Variablenname bei relativer Speicherung, sonst leer.</param>
/// <param name="WirksamFehlt">
/// Ob es <paramref name="Wirksam"/> auf der Platte gar nicht gibt. Eigenes Feld
/// neben <paramref name="Zustand"/>, weil beides gleichzeitig wahr sein kann:
/// Ein <em>abgeleiteter</em> Vorlagenordner ist abgeleitet — und existiert
/// trotzdem nicht, solange ihn niemand angelegt hat. Genau diese Lage hat 2026
/// alle vier Vorlagen ins Leere zeigen lassen, ohne dass die Einstellungsseite
/// ein Wort dazu sagte (#130): Sie meldete „abgeleitet" und war damit im Recht.
/// </param>
public sealed record OrdnerZustand(
    string Feld,
    string Gespeichert,
    string Wirksam,
    string Zustand,
    string Anker,
    bool WirksamFehlt = false);
