using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Sachgebietskatalog : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Sachgebiete",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    Kuerzel = table.Column<string>(type: "TEXT", maxLength: 16, nullable: false),
                    Name = table.Column<string>(type: "TEXT", maxLength: 128, nullable: false),
                    RechtsgebietVorschlag = table.Column<string>(type: "TEXT", maxLength: 128, nullable: false),
                    Sortierung = table.Column<int>(type: "INTEGER", nullable: false),
                    Aktiv = table.Column<bool>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Sachgebiete", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "Sachgebiete",
                columns: new[] { "Id", "Aktiv", "Kuerzel", "Name", "RechtsgebietVorschlag", "Sortierung" },
                values: new object[,]
                {
                    { 1, true, "C01", "Zivilrecht (allgemein)", "Zivilrecht", 10 },
                    { 2, true, "C01a", "Arbeitsrecht", "Arbeitsrecht", 20 },
                    { 3, true, "C02", "Familienrecht", "Familienrecht", 30 },
                    { 4, true, "C03", "Verkehrsrecht", "Verkehrsrecht", 40 },
                    { 5, true, "C03o", "Ordnungswidrigkeitssache", "Ordnungswidrigkeitssache", 50 },
                    { 6, true, "C04", "Verkehrsstrafrecht", "Verkehrsstrafrecht", 60 },
                    { 7, true, "C05", "Strafrecht", "Strafrecht", 70 },
                    { 8, true, "C06", "Verwaltungsrecht", "Verwaltungsrecht", 80 },
                    { 9, true, "C06a", "Ausländer- und Asylrecht", "Ausländer- und Asylrecht", 90 },
                    { 10, true, "C06s", "Sozialrecht", "Sozialrecht", 100 },
                    { 11, true, "C07", "Sonstiges", "Sonstiges", 110 },
                    { 12, true, "C07m", "Markenrecht", "Markenrecht", 120 }
                });

            migrationBuilder.CreateIndex(
                name: "IX_Sachgebiete_Kuerzel",
                table: "Sachgebiete",
                column: "Kuerzel",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Sachgebiete");
        }
    }
}
