using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace CarisBeyondmil.Core
{
    public class CarisRunResult
    {
        public int ExitCode { get; set; }
        public string StdOut { get; set; } = string.Empty;
        public string StdErr { get; set; } = string.Empty;
    }

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
