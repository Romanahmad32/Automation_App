using AutomationService.Core.Ablage;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Der Ordner, in dem der Register-Spiegel <em>gebaut</em> wird, bevor er an
/// seinen Ablageort umzieht.
///
/// Er liegt bewusst außerhalb des Ablageordners. Würde direkt dort gebaut,
/// sähe ein Synchronisierungsdienst die Datei schon halbfertig und begänne sie
/// hochzuladen — auf dem Handy läge dann eine beschädigte .docx. Hier
/// entstehen die Dateien in Ruhe; erst das abschließende Umbenennen
/// (<see cref="AtomareAblage"/>) ist im Zielordner sichtbar, und das ist ein
/// unteilbarer Schritt.
///
/// Jeder Lauf bekommt eigene Namen, damit zwei gleichzeitige Läufe — Knopfdruck
/// und Vorgangsabschluss im selben Moment — sich nicht die halbfertige Datei
/// des jeweils anderen unter den Händen wegziehen.
/// </summary>
/// <param name="wurzel">Basisordner; wird angelegt, falls nötig.</param>
public sealed class RegisterSpiegelBauordner(string wurzel)
{
    public string Wurzel { get; } = Directory.CreateDirectory(wurzel).FullName;

    public string NeueDatei(string endung) =>
        Path.Combine(Wurzel, $"register-{Guid.NewGuid():N}{endung}");

    /// <summary>
    /// Räumt die Zwischenstände weg. Was bereits umgezogen ist, liegt hier
    /// ohnehin nicht mehr; übrig bleibt nur, was ein Fehlschlag hinterlassen
    /// hat.
    /// </summary>
    public void Aufraeumen(params string[] dateien)
    {
        foreach (var datei in dateien)
        {
            try
            {
                if (File.Exists(datei)) File.Delete(datei);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                // Ein liegen gebliebener Zwischenstand kostet Platz, sonst
                // nichts — und darf den eigentlichen Fehler nicht verdecken.
            }
        }
    }
}
