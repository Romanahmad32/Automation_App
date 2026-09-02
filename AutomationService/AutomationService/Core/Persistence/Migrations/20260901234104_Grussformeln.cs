using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Grussformeln : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Grussformeln",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    Text = table.Column<string>(type: "TEXT", maxLength: 128, nullable: false),
                    Sortierung = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Grussformeln", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "Grussformeln",
                columns: new[] { "Id", "Sortierung", "Text" },
                values: new object[,]
                {
                    { 1, 10, "Salamu aleikum" },
                    { 2, 20, "Sat Sri Akal" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_Grussformeln_Text",
                table: "Grussformeln",
                column: "Text",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Grussformeln");
        }
    }
}
