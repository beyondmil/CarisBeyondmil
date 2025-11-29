using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace CarisBeyondmil.Core
{
    public class CarisFinder
    {
        private readonly CarisSettings _settings;

        public CarisFinder(CarisSettings? settings = null)
        {
            _settings = settings ?? new CarisSettings();
        }

        public string? FindCarisBatch()
        {
            foreach (var fav in _settings.FavoritePaths)
            {
                if (File.Exists(fav)) return fav;
            }

            var hips = SearchHipsAndSips();
            if (!string.IsNullOrEmpty(hips)) return hips;

            var pf = LimitedProgramFilesSearch(_settings.ProgramFilesBase);
            if (!string.IsNullOrEmpty(pf)) return pf;

            if (!string.IsNullOrWhiteSpace(_settings.ProgramFilesX86Base))
            {
                var pfx = LimitedProgramFilesSearch(_settings.ProgramFilesX86Base);
                if (!string.IsNullOrEmpty(pfx)) return pfx;
            }

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
