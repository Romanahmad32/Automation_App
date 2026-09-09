using AutomationService.Features.Vorgaenge.Presentation.Hubs;
using Microsoft.AspNetCore.SignalR;

namespace AutomationService.Tests.Support;

/// <summary>
/// Nimmt die SignalR-Meldungen des Register-Nachzugs auf, statt sie an
/// Verbindungen zu schicken.
///
/// Von Hand geschrieben, weil das Testprojekt bewusst keine Mock-Bibliothek
/// führt. Zwei Klassen, obwohl es um eine Sache geht: <c>IHubContext</c> hat
/// die Eigenschaften <c>Clients</c> und <c>Groups</c>, <c>IHubClients</c> hat
/// gleichnamige <em>Methoden</em> — beides in einem Typ lässt sich nicht
/// deklarieren.
/// </summary>
public sealed class RegisterHubAttrappe : IHubContext<RegisterHub>
{
    /// <summary>Was gemeldet wurde, in der Reihenfolge der Meldungen.</summary>
    public List<(string Ereignis, object?[] Nutzdaten)> Meldungen { get; } = [];

    /// <summary>Die Nutzdaten der letzten PDF-Meldung, falls eine kam.</summary>
    public RegisterHub.PdfMeldung? LetztePdfMeldung => Meldungen
        .Where(m => m.Ereignis == RegisterHub.PdfFertigEvent)
        .Select(m => m.Nutzdaten.OfType<RegisterHub.PdfMeldung>().FirstOrDefault())
        .LastOrDefault();

    public IHubClients Clients { get; }

    public IGroupManager Groups => throw new NotSupportedException(HubEmpfaengerAttrappe.NichtBenutzt);

    public RegisterHubAttrappe() => Clients = new HubEmpfaengerAttrappe(Meldungen);
}

/// <summary>
/// Die Empfängerseite der Attrappe. Zu tun ist nur eines:
/// <see cref="SendCoreAsync"/> mitschreiben — jeder andere Weg (Gruppen,
/// einzelne Verbindungen, Benutzer) wird vom Register nicht benutzt und wirft
/// deshalb. Ein stiller Rückfall dort hiesse: Wer den Nachzug einmal auf
/// Gruppen umstellt, bekommt einen grünen Test über eine Meldung, die niemand
/// erhält.
/// </summary>
/// <param name="meldungen">Die Liste der Attrappe, in die geschrieben wird.</param>
public sealed class HubEmpfaengerAttrappe(List<(string Ereignis, object?[] Nutzdaten)> meldungen)
    : IHubClients, IClientProxy
{
    internal const string NichtBenutzt =
        "Das Register meldet an alle Verbundenen; ein anderer Weg ist hier nicht vorgesehen.";

    public IClientProxy All => this;

    public Task SendCoreAsync(string method, object?[] args, CancellationToken cancellationToken = default)
    {
        meldungen.Add((method, args));
        return Task.CompletedTask;
    }

    public IClientProxy AllExcept(IReadOnlyList<string> excludedConnectionIds) =>
        throw new NotSupportedException(NichtBenutzt);

    public IClientProxy Client(string connectionId) => throw new NotSupportedException(NichtBenutzt);

    public IClientProxy Clients(IReadOnlyList<string> connectionIds) =>
        throw new NotSupportedException(NichtBenutzt);

    public IClientProxy Group(string groupName) => throw new NotSupportedException(NichtBenutzt);

    public IClientProxy Groups(IReadOnlyList<string> groupNames) =>
        throw new NotSupportedException(NichtBenutzt);

    public IClientProxy GroupExcept(string groupName, IReadOnlyList<string> excludedConnectionIds) =>
        throw new NotSupportedException(NichtBenutzt);

    public IClientProxy User(string userId) => throw new NotSupportedException(NichtBenutzt);

    public IClientProxy Users(IReadOnlyList<string> userIds) =>
        throw new NotSupportedException(NichtBenutzt);
}
