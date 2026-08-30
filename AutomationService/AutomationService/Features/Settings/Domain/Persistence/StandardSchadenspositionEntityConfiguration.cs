using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.Settings.Domain.Persistence;

/// <summary>
/// Schema-Mapping der Standardpositionen: gewöhnlicher Autoincrement-Schlüssel,
/// gelesen wird immer nach <see cref="StandardSchadenspositionEntity.Reihenfolge"/>.
/// </summary>
public class StandardSchadenspositionEntityConfiguration
    : IEntityTypeConfiguration<StandardSchadenspositionEntity>
{
    public void Configure(EntityTypeBuilder<StandardSchadenspositionEntity> builder)
    {
        builder.Property(p => p.Bezeichnung).IsRequired();
    }
}
