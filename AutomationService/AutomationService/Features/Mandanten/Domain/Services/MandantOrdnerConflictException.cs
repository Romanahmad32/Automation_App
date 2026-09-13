namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Wird geworfen, wenn ein Akten-Ordner einem anderen Mandanten zugeordnet
/// werden soll, obwohl er schon einem Mandanten gehört. Der Controller
/// übersetzt das in 409 Conflict — dieselbe Fachregel, die der Import
/// (<see cref="MandantenImportLauf"/>) schon kennt, jetzt auch auf dem
/// Einzelweg über Create/Update.
/// </summary>
public sealed class MandantOrdnerConflictException(string message) : Exception(message);
