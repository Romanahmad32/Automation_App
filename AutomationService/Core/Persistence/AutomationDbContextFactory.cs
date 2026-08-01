using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace AutomationService.Core.Persistence;

/// <summary>
/// Design-Time-Factory, die ausschließlich die EF-Tools (`dotnet ef migrations`)
/// nutzen, um den Kontext ohne laufende App zu erzeugen. Der Verbindungsstring
/// ist hier irrelevant — es wird keine echte Verbindung geöffnet, nur das Modell
/// zum Generieren der Migration gelesen.
/// </summary>
public class AutomationDbContextFactory : IDesignTimeDbContextFactory<AutomationDbContext>
{
    public AutomationDbContext CreateDbContext(string[] args)
    {
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite("Data Source=automation.db")
            .Options;
        return new AutomationDbContext(options);
    }
}
