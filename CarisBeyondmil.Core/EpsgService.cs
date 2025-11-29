using System;

namespace CarisBeyondmil.Core
{
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
