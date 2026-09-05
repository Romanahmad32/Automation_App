using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Arbeitspakete : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Arbeitspakete",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    Nummer = table.Column<int>(type: "INTEGER", nullable: false),
                    GeholtAm = table.Column<DateTime>(type: "TEXT", nullable: false),
                    OrdnernamenJson = table.Column<string>(type: "TEXT", nullable: false),
                    EingelesenAm = table.Column<DateTime>(type: "TEXT", nullable: true),
                    ErledigtAnzahl = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Arbeitspakete", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Arbeitspakete_Nummer",
                table: "Arbeitspakete",
                column: "Nummer",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Arbeitspakete");
        }
    }
}
