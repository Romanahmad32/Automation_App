using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.FormTemplates.Domain.Persistence;

/// <summary>Schema-Mapping der Formularvorlage (Feldliste als JSON-Spalte, Default "[]").</summary>
public class FormTemplateEntityConfiguration : IEntityTypeConfiguration<FormTemplateEntity>
{
    public void Configure(EntityTypeBuilder<FormTemplateEntity> builder)
    {
        builder.Property(t => t.FieldsJson).HasDefaultValue("[]");
    }
}
