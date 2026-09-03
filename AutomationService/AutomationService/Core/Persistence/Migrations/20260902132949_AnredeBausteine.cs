using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AnredeBausteine : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AnredeBausteine",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    Maennlich = table.Column<string>(type: "TEXT", maxLength: 64, nullable: false),
                    Weiblich = table.Column<string>(type: "TEXT", maxLength: 64, nullable: false),
                    Neutral = table.Column<string>(type: "TEXT", maxLength: 64, nullable: false),
                    Sortierung = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AnredeBausteine", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "AnredeBausteine",
                columns: new[] { "Id", "Maennlich", "Neutral", "Sortierung", "Weiblich" },
                values: new object[,]
                {
                    { 1, "Sehr geehrter", "Sehr geehrte", 10, "Sehr geehrte" },
                    { 2, "Guten Tag", "Guten Tag", 20, "Guten Tag" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_AnredeBausteine_Maennlich_Weiblich_Neutral",
                table: "AnredeBausteine",
                columns: new[] { "Maennlich", "Weiblich", "Neutral" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AnredeBausteine");
        }
    }
}
