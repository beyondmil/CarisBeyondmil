using System;

namespace CarisBeyondmil.Core
{
    /// <summary>
    /// Configurable settings controlling search behaviour for carisbatch.exe and limits.
    /// </summary>
    public class CarisSettings
    {
        public string[] FavoritePaths { get; set; } = new[]
        {
            @"C:\Program Files\CARIS\HIPS and SIPS\12.1\bin\carisbatch.exe",
            @"C:\Program Files\CARIS\HIPS and SIPS\11.3\bin\carisbatch.exe"
        };

        public string HipsAndSipsBase { get; set; } = @"C:\Program Files\CARIS\HIPS and SIPS";
        public string ProgramFilesBase { get; set; } = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        public string ProgramFilesX86Base { get; set; } = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        public int MaxFilesToCheck { get; set; } = 20000;
        public int MaxDirDepth { get; set; } = 4;
    }
}
