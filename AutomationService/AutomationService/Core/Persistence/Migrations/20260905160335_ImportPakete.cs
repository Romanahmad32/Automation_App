using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ImportPakete : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ImportPakete",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    Nummer = table.Column<int>(type: "INTEGER", nullable: false),
                    GeholtAm = table.Column<DateTime>(type: "TEXT", nullable: false),
                    AnzahlOrdner = table.Column<int>(type: "INTEGER", nullable: false),
                    OrdnernamenJson = table.Column<string>(type: "TEXT", nullable: false, defaultValue: "[]"),
                    EingelesenAm = table.Column<DateTime>(type: "TEXT", nullable: true),
                    Zeilen = table.Column<int>(type: "INTEGER", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ImportPakete", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ImportPakete_Nummer",
                table: "ImportPakete",
                column: "Nummer",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ImportPakete");
        }
    }
}
