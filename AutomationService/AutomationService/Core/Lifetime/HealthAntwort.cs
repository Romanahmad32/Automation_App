namespace AutomationService.Core.Lifetime;

/// <summary>
/// Antwort von <c>GET /health</c>. Vertrag mit dem Frontend, das den Dienst
/// startet und auf seine Bereitschaft wartet.
/// </summary>
/// <param name="Status">
/// <c>bereit</c>, wenn der Start vollstaendig durchgelaufen ist, sonst
/// <c>startet</c>. Der Statuscode sagt dasselbe (200 bzw. 503); das Feld ist
/// fuer den Menschen im Log und im Browser da.
/// </param>
/// <param name="Version">
/// Version der Assembly. Wird spaeter fuer die Update-Pruefung gebraucht und
/// beantwortet beim Support die erste Frage ("welcher Stand laeuft da?").
/// </param>
/// <param name="Testmodus">
/// True, wenn der Dienst im E2E-Testmodus laeuft (#168): umgelenkter
/// Datenordner, und Zentralruf, Versand, Entwurf und Druck sind durch
/// Attrappen ersetzt. Immer vorhanden (JSON <c>testmodus</c>). Eine App, die
/// einen Testmodus erwartet, uebernimmt keinen Dienst, der hier <c>false</c>
/// meldet — sonst bediente ein Testlauf die echten Daten der Kanzlei.
/// </param>
public sealed record HealthAntwort(string Status, string Version, bool Testmodus);
