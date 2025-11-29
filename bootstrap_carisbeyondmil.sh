#!/usr/bin/env bash
set -euo pipefail

# EDIT ONLY IF YOU WANT TO CHANGE LOCATION
BASE_DIR="/Users/mukhammadnursulaiman/Documents/5_project/3_carisbeyondmil/0-projects"
SOLUTION_NAME="CarisBeyondmil"

echo "Creating CarisBeyondmil solution under: $BASE_DIR"

mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

# Create solution and projects
dotnet new sln -n $SOLUTION_NAME

dotnet new classlib -n ${SOLUTION_NAME}.Core
dotnet sln ${SOLUTION_NAME}.sln add ${SOLUTION_NAME}.Core/${SOLUTION_NAME}.Core.csproj

dotnet new console -n ${SOLUTION_NAME}.ConsoleTest
dotnet sln ${SOLUTION_NAME}.sln add ${SOLUTION_NAME}.ConsoleTest/${SOLUTION_NAME}.ConsoleTest.csproj
dotnet add ${SOLUTION_NAME}.ConsoleTest/${SOLUTION_NAME}.ConsoleTest.csproj reference ${SOLUTION_NAME}.Core/${SOLUTION_NAME}.Core.csproj

dotnet new xunit -n ${SOLUTION_NAME}.Core.Tests
dotnet sln ${SOLUTION_NAME}.sln add ${SOLUTION_NAME}.Core.Tests/${SOLUTION_NAME}.Core.Tests.csproj
dotnet add ${SOLUTION_NAME}.Core.Tests/${SOLUTION_NAME}.Core.Tests.csproj reference ${SOLUTION_NAME}.Core/${SOLUTION_NAME}.Core.csproj

# Replace csproj files with net10.0 content
cat > ${SOLUTION_NAME}.Core/${SOLUTION_NAME}.Core.csproj <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>
</Project>
EOF

cat > ${SOLUTION_NAME}.ConsoleTest/${SOLUTION_NAME}.ConsoleTest.csproj <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\/${SOLUTION_NAME}.Core\/${SOLUTION_NAME}.Core.csproj" />
  </ItemGroup>
</Project>
EOF

cat > ${SOLUTION_NAME}.Core.Tests/${SOLUTION_NAME}.Core.Tests.csproj <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <IsPackable>false</IsPackable>
    <Nullable>enable</Nullable>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="xunit" Version="2.5.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.5.3">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="18.10.1" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\/${SOLUTION_NAME}.Core\/${SOLUTION_NAME}.Core.csproj" />
  </ItemGroup>
</Project>
EOF

# Create core source files
CORE_DIR=${SOLUTION_NAME}.Core
mkdir -p "$CORE_DIR"

cat > ${CORE_DIR}/CarisSettings.cs <<'EOF'
using System;

namespace CarisBeyondmil.Core
{
    /// <summary>
    /// Configurable settings controlling search behaviour for carisbatch.exe and limits.
    /// </summary>
    public class CarisSettings
    {
        /// <summary>
        /// Favorite exact-check paths (ordered).
        /// </summary>
        public string[] FavoritePaths { get; set; } = new[]
        {
            @"C:\Program Files\CARIS\HIPS and SIPS\12.1\bin\carisbatch.exe",
            @"C:\Program Files\CARIS\HIPS and SIPS\11.3\bin\carisbatch.exe"
        };

        /// <summary>Base folder for HIPS and SIPS installations.</summary>
        public string HipsAndSipsBase { get; set; } = @"C:\Program Files\CARIS\HIPS and SIPS";

        /// <summary>Program Files base folder (x64).</summary>
        public string ProgramFilesBase { get; set; } = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);

        /// <summary>Program Files (x86) base folder (may be empty on some systems).</summary>
        public string ProgramFilesX86Base { get; set; } = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);

        /// <summary>Max files to scan during targeted search to avoid long-running scans.</summary>
        public int MaxFilesToCheck { get; set; } = 20000;

        /// <summary>Max directory depth when walking Program Files for safety.</summary>
        public int MaxDirDepth { get; set; } = 4;
    }
}
EOF

cat > ${CORE_DIR}/CarisFinder.cs <<'EOF'
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace CarisBeyondmil.Core
{
    /// <summary>
    /// Locates carisbatch.exe following a safe ordered search.
    /// </summary>
    public class CarisFinder
    {
        private readonly CarisSettings _settings;

        public CarisFinder(CarisSettings? settings = null)
        {
            _settings = settings ?? new CarisSettings();
        }

        /// <summary>
        /// Returns full path to carisbatch.exe if found, otherwise null.
        /// Search order:
        ///  1) Favorite exact paths (ordered)
        ///  2) Search version subfolders under HIPS and SIPS base
        ///  3) Targeted limited search under Program Files (both x64 and x86)
        /// </summary>
        public string? FindCarisBatch()
        {
            // 1) Exact favorites
            foreach (var fav in _settings.FavoritePaths)
            {
                if (File.Exists(fav)) return fav;
            }

            // 2) HIPS and SIPS version folders
            var hips = SearchHipsAndSips();
            if (!string.IsNullOrEmpty(hips)) return hips;

            // 3) Targeted Program Files search (x64)
            var pf = LimitedProgramFilesSearch(_settings.ProgramFilesBase);
            if (!string.IsNullOrEmpty(pf)) return pf;

            // 4) Program Files (x86)
            if (!string.IsNullOrWhiteSpace(_settings.ProgramFilesX86Base))
            {
                var pfx = LimitedProgramFilesSearch(_settings.ProgramFilesX86Base);
                if (!string.IsNullOrEmpty(pfx)) return pfx;
            }

            // not found
            return null;
        }

        private string? SearchHipsAndSips()
        {
            try
            {
                var baseDir = _settings.HipsAndSipsBase;
                if (!Directory.Exists(baseDir)) return null;

                var candidates = Directory.EnumerateDirectories(baseDir)
                    .Select(d => Path.Combine(d, "bin", "carisbatch.exe"))
                    .Where(File.Exists)
                    .ToList();

                if (!candidates.Any()) return null;

                // Prefer higher version-like folder names (lexicographic reverse)
                candidates.Sort((a, b) =>
                {
                    var pa = new DirectoryInfo(Path.GetDirectoryName(Path.GetDirectoryName(a)) ?? "").Name;
                    var pb = new DirectoryInfo(Path.GetDirectoryName(Path.GetDirectoryName(b)) ?? "").Name;
                    return string.Compare(pb, pa, StringComparison.OrdinalIgnoreCase);
                });

                return candidates.FirstOrDefault();
            }
            catch
            {
                return null;
            }
        }

        private string? LimitedProgramFilesSearch(string root)
        {
            if (string.IsNullOrWhiteSpace(root)) return null;
            if (!Directory.Exists(root)) return null;

            int checkedCount = 0;
            var queue = new Queue<(string path, int depth)>();
            queue.Enqueue((root, 0));

            while (queue.Count > 0)
            {
                var (dir, depth) = queue.Dequeue();
                if (depth > _settings.MaxDirDepth) continue;

                string[] files;
                string[] subdirs;
                try
                {
                    files = Directory.GetFiles(dir);
                    subdirs = Directory.GetDirectories(dir);
                }
                catch
                {
                    continue;
                }

                foreach (var f in files)
                {
                    checkedCount++;
                    if (checkedCount > _settings.MaxFilesToCheck) return null;
                    if (string.Equals(Path.GetFileName(f), "carisbatch.exe", StringComparison.OrdinalIgnoreCase))
                    {
                        if (File.Exists(f)) return f;
                    }
                }

                foreach (var sd in subdirs)
                {
                    queue.Enqueue((sd, depth + 1));
                }
            }

            return null;
        }
    }
}
EOF

cat > ${CORE_DIR}/EpsgService.cs <<'EOF'
using System;

namespace CarisBeyondmil.Core
{
    /// <summary>
    /// Small utility for EPSG selection: lon/lat -> WGS84 UTM EPSG code.
    /// Returns 326## for northern hemisphere and 327## for southern.
    /// </summary>
    public static class EpsgService
    {
        public static int LonLatToUtmEpsg(double lon, double lat)
        {
            if (lon < -180 || lon > 180) throw new ArgumentOutOfRangeException(nameof(lon));
            if (lat < -90 || lat > 90) throw new ArgumentOutOfRangeException(nameof(lat));

            int zone = (int)Math.Floor((lon + 180.0) / 6.0) + 1;
            if (zone < 1) zone = 1;
            if (zone > 60) zone = 60;
            return (lat >= 0) ? 32600 + zone : 32700 + zone;
        }
    }
}
EOF

cat > ${CORE_DIR}/CarisRunner.cs <<'EOF'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace CarisBeyondmil.Core
{
    /// <summary>
    /// Result object for carisbatch runs.
    /// </summary>
    public class CarisRunResult
    {
        public int ExitCode { get; set; }
        public string StdOut { get; set; } = string.Empty;
        public string StdErr { get; set; } = string.Empty;
    }

    /// <summary>
    /// Wrapper to run carisbatch CombineToRaster and stream logs.
    /// </summary>
    public class CarisRunner
    {
        private readonly string _carisBatchPath;

        public CarisRunner(string carisBatchPath)
        {
            _carisBatchPath = carisBatchPath ?? throw new ArgumentNullException(nameof(carisBatchPath));
        }

        public async Task<CarisRunResult> RunCombineToRasterAsync(
            string inputDir,
            string outputPath,
            int epsg,
            double cellSize = 2.0,
            string outputFormat = "GeoTIFF",
            CancellationToken cancellation = default,
            IProgress<string>? progress = null)
        {
            var args = new List<string>
            {
                "CombineToRaster",
                $"--input=\"{inputDir}\"",
                $"--output=\"{outputPath}\"",
                $"--output-format={outputFormat}",
                $"--crs=EPSG:{epsg}",
                $"--cellsize={cellSize}",
                "--overwrite"
            };

            var psi = new ProcessStartInfo
            {
                FileName = _carisBatchPath,
                Arguments = string.Join(' ', args),
                CreateNoWindow = true,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                StandardOutputEncoding = Encoding.UTF8,
                StandardErrorEncoding = Encoding.UTF8
            };

            var sbOut = new StringBuilder();
            var sbErr = new StringBuilder();

            using (var proc = new Process { StartInfo = psi, EnableRaisingEvents = true })
            {
                proc.OutputDataReceived += (s, e) =>
                {
                    if (e.Data == null) return;
                    sbOut.AppendLine(e.Data);
                    progress?.Report(e.Data);
                };
                proc.ErrorDataReceived += (s, e) =>
                {
                    if (e.Data == null) return;
                    sbErr.AppendLine(e.Data);
                    progress?.Report("[ERR] " + e.Data);
                };

                proc.Start();
                proc.BeginOutputReadLine();
                proc.BeginErrorReadLine();

                while (!proc.WaitForExit(200))
                {
                    if (cancellation.IsCancellationRequested)
                    {
                        try { proc.Kill(); } catch { }
                        cancellation.ThrowIfCancellationRequested();
                    }
                }

                return new CarisRunResult
                {
                    ExitCode = proc.ExitCode,
                    StdOut = sbOut.ToString(),
                    StdErr = sbErr.ToString()
                };
            }
        }
    }
}
EOF

# Create console test harness
CT_DIR=${SOLUTION_NAME}.ConsoleTest
mkdir -p "$CT_DIR"

cat > ${CT_DIR}/Program.cs <<'EOF'
using System;
using System.Threading;
using System.Threading.Tasks;
using CarisBeyondmil.Core;

namespace CarisBeyondmil.ConsoleTest
{
    class Program
    {
        static async Task Main(string[] args)
        {
            Console.WriteLine("CarisBeyondmil — Core test harness");

            var settings = new CarisSettings();
            var finder = new CarisFinder(settings);
            var found = finder.FindCarisBatch();
            Console.WriteLine("carisbatch found: " + (found ?? "<not found on this machine>"));

            // EPSG test
            var epsg = EpsgService.LonLatToUtmEpsg(106.8, -6.0);
            Console.WriteLine($"EPSG for lon=106.8 lat=-6.0 -> {epsg}");

            if (!string.IsNullOrEmpty(found))
            {
                var runner = new CarisRunner(found);
                Console.WriteLine("Attempting CombineToRaster (this will run carisbatch if present)...");
                try
                {
                    using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
                    var progress = new Progress<string>(s => Console.WriteLine("[caris] " + s));
                    var result = await runner.RunCombineToRasterAsync(@"C:\data\csar_inputs", @"C:\data\outputs\merged.tif", epsg, 2.0, "GeoTIFF", cts.Token, progress);
                    Console.WriteLine($"Exit code: {result.ExitCode}");
                    if (!string.IsNullOrWhiteSpace(result.StdErr)) Console.WriteLine("STDERR: " + result.StdErr);
                }
                catch (Exception ex)
                {
                    Console.WriteLine("RunCombineToRaster failed (expected on non-Windows): " + ex.Message);
                }
            }
            else
            {
                Console.WriteLine("No carisbatch located — to test runner, run this on Windows with CARIS installed.");
            }
        }
    }
}
EOF

# Create tests
TEST_DIR=${SOLUTION_NAME}.Core.Tests
mkdir -p "$TEST_DIR"

cat > ${TEST_DIR}/EpsgTests.cs <<'EOF'
using Xunit;
using CarisBeyondmil.Core;

namespace CarisBeyondmil.Core.Tests
{
    public class EpsgTests
    {
        [Theory]
        [InlineData(0.0, 0.0, 32631)]
        [InlineData(106.8, -6.0, 32748)]
        public void LonLatToUtm_ReturnsExpected(double lon, double lat, int expected)
        {
            var epsg = EpsgService.LonLatToUtmEpsg(lon, lat);
            Assert.Equal(expected, epsg);
        }
    }
}
EOF

# .gitignore and README
cat > .gitignore <<'EOF'
bin/
obj/
.vscode/
*.user*
*.suo
publish/
*.log
EOF

cat > README.md <<'EOF'
# CarisBeyondmil

Starter solution for CarisBeyondmil — a CARIS carisbatch orchestration backend (CombineToRaster).
Projects:
- CarisBeyondmil.Core : core library (search carisbatch, EPSG helper, runner)
- CarisBeyondmil.ConsoleTest : console harness for local testing
- CarisBeyondmil.Core.Tests : unit tests (xUnit)

Prerequisites:
- .NET 10 SDK
- (Windows) Visual Studio + WinUI for UI integration later.

Build & test:
```bash
dotnet restore
dotnet build -c Release
dotnet test
dotnet run --project CarisBeyondmil.ConsoleTest
