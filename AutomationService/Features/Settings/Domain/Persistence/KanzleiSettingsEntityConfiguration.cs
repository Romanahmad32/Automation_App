using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.Settings.Domain.Persistence;

/// <summary>
/// Schema-Mapping der Einstellungen: Single-Row mit festem Primärschlüssel
/// (kein Autoincrement — es gibt genau die eine Zeile Id=1).
/// </summary>
public class KanzleiSettingsEntityConfiguration : IEntityTypeConfiguration<KanzleiSettingsEntity>
{
    public void Configure(EntityTypeBuilder<KanzleiSettingsEntity> builder)
    {
        builder.Property(s => s.Id).ValueGeneratedNever();
    }
}
