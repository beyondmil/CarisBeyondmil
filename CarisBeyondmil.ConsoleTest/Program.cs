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
