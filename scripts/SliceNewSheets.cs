using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

public class SliceNewSheets
{
    struct SheetConfig
    {
        public string SheetKey;
        public string SourcePath;
        public string OutputDir;
        public string[] PoseNames;
    }

    struct HoleSeed
    {
        public int SheetX, SheetY;
        public double MaxDist;
        public int MaxRadius;
        public HoleSeed(int x, int y, double maxDist = 36, int r = 180)
        {
            SheetX = x; SheetY = y; MaxDist = maxDist; MaxRadius = r;
        }
    }

    static double ColorDist(Color a, Color b)
    {
        int dr = a.R - b.R;
        int dg = a.G - b.G;
        int db = a.B - b.B;
        return Math.Sqrt(dr * dr + dg * dg + db * db);
    }

    static double Lum(Color c) { return (c.R + c.G + c.B) / 3.0; }
    static int Chroma(Color c) { return Math.Max(c.R, Math.Max(c.G, c.B)) - Math.Min(c.R, Math.Min(c.G, c.B)); }

    // Finds horizontal DP seam y(x) for x in [0..w-1] within [yMin..yMax]
    static int[] FindHorizontalSeam(Bitmap bmp, Color bg, int yMin, int yMax)
    {
        int w = bmp.Width;
        int span = yMax - yMin + 1;
        double[,] dp = new double[w, span];
        int[,] parent = new int[w, span];

        for (int yi = 0; yi < span; yi++)
        {
            double d = ColorDist(bmp.GetPixel(0, yMin + yi), bg);
            dp[0, yi] = d <= 18 ? 0.0 : d * d;
        }

        for (int x = 1; x < w; x++)
        {
            for (int yi = 0; yi < span; yi++)
            {
                double d = ColorDist(bmp.GetPixel(x, yMin + yi), bg);
                double cost = d <= 18 ? 0.0 : d * d;
                double bestPrev = double.MaxValue;
                int bestPi = yi;
                int lo = Math.Max(0, yi - 4);
                int hi = Math.Min(span - 1, yi + 4);
                for (int pi = lo; pi <= hi; pi++)
                {
                    double cand = dp[x - 1, pi] + Math.Abs(yi - pi) * 0.01;
                    if (cand < bestPrev) { bestPrev = cand; bestPi = pi; }
                }
                dp[x, yi] = bestPrev + cost;
                parent[x, yi] = bestPi;
            }
        }

        double bestEnd = double.MaxValue;
        int endYi = span / 2;
        for (int yi = 0; yi < span; yi++)
        {
            if (dp[w - 1, yi] < bestEnd) { bestEnd = dp[w - 1, yi]; endYi = yi; }
        }

        int[] seam = new int[w];
        int cur = endYi;
        for (int x = w - 1; x >= 0; x--)
        {
            seam[x] = yMin + cur;
            if (x > 0) cur = parent[x, cur];
        }
        return seam;
    }

    // Finds vertical DP seam x(y) for y in [yStart..yEnd-1] within [xMin..xMax]
    static int[] FindVerticalSeam(Bitmap bmp, Color bg, int yStart, int yEnd, int xMin, int xMax)
    {
        int h = bmp.Height;
        int rows = yEnd - yStart;
        int span = xMax - xMin + 1;
        double[,] dp = new double[rows, span];
        int[,] parent = new int[rows, span];

        for (int xi = 0; xi < span; xi++)
        {
            double d = ColorDist(bmp.GetPixel(xMin + xi, yStart), bg);
            dp[0, xi] = d <= 18 ? 0.0 : d * d;
        }

        for (int yi = 1; yi < rows; yi++)
        {
            int y = yStart + yi;
            for (int xi = 0; xi < span; xi++)
            {
                double d = ColorDist(bmp.GetPixel(xMin + xi, y), bg);
                double cost = d <= 18 ? 0.0 : d * d;
                double bestPrev = double.MaxValue;
                int bestPi = xi;
                int lo = Math.Max(0, xi - 5);
                int hi = Math.Min(span - 1, xi + 5);
                for (int pi = lo; pi <= hi; pi++)
                {
                    double cand = dp[yi - 1, pi] + Math.Abs(xi - pi) * 0.01;
                    if (cand < bestPrev) { bestPrev = cand; bestPi = pi; }
                }
                dp[yi, xi] = bestPrev + cost;
                parent[yi, xi] = bestPi;
            }
        }

        double bestEnd = double.MaxValue;
        int endXi = span / 2;
        for (int xi = 0; xi < span; xi++)
        {
            if (dp[rows - 1, xi] < bestEnd) { bestEnd = dp[rows - 1, xi]; endXi = xi; }
        }

        int[] seam = new int[h];
        int cur = endXi;
        for (int yi = rows - 1; yi >= 0; yi--)
        {
            seam[yStart + yi] = xMin + cur;
            if (yi > 0) cur = parent[yi, cur];
        }
        return seam;
    }

    static Color EstimateAverageCornerBg(Bitmap bmp)
    {
        Color[] samples = {
            bmp.GetPixel(6, 6),
            bmp.GetPixel(bmp.Width - 7, 6),
            bmp.GetPixel(6, bmp.Height - 7),
            bmp.GetPixel(bmp.Width - 7, bmp.Height - 7),
            bmp.GetPixel(bmp.Width / 2, 6),
            bmp.GetPixel(bmp.Width / 2, bmp.Height - 7)
        };
        int r = 0, g = 0, b = 0;
        foreach (var c in samples) { r += c.R; g += c.G; b += c.B; }
        return Color.FromArgb(r / samples.Length, g / samples.Length, b / samples.Length);
    }

    static int ClampByte(double v) { return (int)Math.Max(0, Math.Min(255, Math.Round(v))); }

    static void FloodEraseHole(Bitmap bmp, int ox, int oy, HoleSeed hs, Color bg)
    {
        int sx = hs.SheetX - ox;
        int sy = hs.SheetY - oy;
        int w = bmp.Width, h = bmp.Height;
        if (sx < 0 || sx >= w || sy < 0 || sy >= h) return;

        // Snap within tiny 5x5 neighborhood in case seed sits on slight jpeg edge
        int bestX = -1, bestY = -1;
        double bestDist = double.MaxValue;
        for (int dy = -2; dy <= 2; dy++)
        {
            for (int dx = -2; dx <= 2; dx++)
            {
                int px = sx + dx, py = sy + dy;
                if (px < 0 || px >= w || py < 0 || py >= h) continue;
                Color c = bmp.GetPixel(px, py);
                if (c.A == 0) continue;
                double d = ColorDist(c, bg);
                if (d < bestDist) { bestDist = d; bestX = px; bestY = py; }
            }
        }
        if (bestX < 0 || bestDist > hs.MaxDist) return;

        bool[,] visited = new bool[w, h];
        Queue<Point> q = new Queue<Point>();
        q.Enqueue(new Point(bestX, bestY));
        visited[bestX, bestY] = true;
        int[] dxs = { 0, 0, 1, -1 };
        int[] dys = { 1, -1, 0, 0 };

        while (q.Count > 0)
        {
            Point cur = q.Dequeue();
            bmp.SetPixel(cur.X, cur.Y, Color.Transparent);
            for (int i = 0; i < 4; i++)
            {
                int nx = cur.X + dxs[i], ny = cur.Y + dys[i];
                if (nx >= 0 && nx < w && ny >= 0 && ny < h && !visited[nx, ny])
                {
                    if (Math.Abs(nx - bestX) > hs.MaxRadius || Math.Abs(ny - bestY) > hs.MaxRadius) continue;
                    Color np = bmp.GetPixel(nx, ny);
                    if (np.A == 0) continue;
                    if (ColorDist(np, bg) <= hs.MaxDist && Lum(np) >= 185)
                    {
                        visited[nx, ny] = true;
                        q.Enqueue(new Point(nx, ny));
                    }
                }
            }
        }
    }

    static void ProcessRegion(
        Bitmap sheet,
        Color bg,
        int col,
        int row,
        int[] sepY,
        int[] leftSeam,
        int[] rightSeam,
        string poseName,
        string outPath,
        Dictionary<string, HoleSeed[]> holeMap,
        bool scanHoles)
    {
        int sw = sheet.Width, sh = sheet.Height;

        // Compute tight sheet-space bounding rect of this polygon region
        int minY = row == 0 ? 0 : sh;
        int maxY = row == 0 ? 0 : sh - 1;
        if (row == 0)
        {
            minY = 0;
            maxY = 0;
            for (int x = 0; x < sw; x++) if (sepY[x] > maxY) maxY = sepY[x];
        }
        else
        {
            minY = sh;
            for (int x = 0; x < sw; x++) if (sepY[x] < minY) minY = sepY[x];
            maxY = sh - 1;
        }

        int minX = sw, maxX = 0;
        for (int y = minY; y <= maxY; y++)
        {
            int lx = col == 0 ? 0 : leftSeam[y];
            int rx = col == 2 ? sw - 1 : rightSeam[y];
            if (lx < minX) minX = lx;
            if (rx > maxX) maxX = rx;
        }

        // Pad polygon bbox by 2px cream border on all sides so outer flood flows freely around everything
        int padBorder = 2;
        int ox = minX - padBorder;
        int oy = minY - padBorder;
        int cw = (maxX - minX + 1) + padBorder * 2;
        int ch = (maxY - minY + 1) + padBorder * 2;

        using (Bitmap cell = new Bitmap(cw, ch, PixelFormat.Format32bppArgb))
        {
            for (int y = 0; y < ch; y++)
            {
                int sy = oy + y;
                for (int x = 0; x < cw; x++)
                {
                    int sx = ox + x;
                    bool inside = false;
                    if (sx >= 0 && sx < sw && sy >= 0 && sy < sh)
                    {
                        bool inRow = row == 0 ? (sy < sepY[sx]) : (sy >= sepY[sx]);
                        if (inRow)
                        {
                            int lx = col == 0 ? 0 : leftSeam[sy];
                            int rx = col == 2 ? sw : rightSeam[sy];
                            inside = (sx >= lx && sx < rx);
                        }
                    }
                    cell.SetPixel(x, y, inside ? sheet.GetPixel(sx, sy) : bg);
                }
            }

            // 1. Exterior Hard Background Erase (dist <= 20 && chroma <= 26)
            bool[,] isExtBg = new bool[cw, ch];
            bool[,] visited = new bool[cw, ch];
            Queue<Point> q = new Queue<Point>();
            q.Enqueue(new Point(0, 0));
            visited[0, 0] = true;

            int[] dx = { 0, 0, 1, -1 };
            int[] dy = { 1, -1, 0, 0 };

            while (q.Count > 0)
            {
                Point cur = q.Dequeue();
                isExtBg[cur.X, cur.Y] = true;
                cell.SetPixel(cur.X, cur.Y, Color.Transparent);

                for (int d = 0; d < 4; d++)
                {
                    int nx = cur.X + dx[d], ny = cur.Y + dy[d];
                    if (nx >= 0 && nx < cw && ny >= 0 && ny < ch && !visited[nx, ny])
                    {
                        Color np = cell.GetPixel(nx, ny);
                        double dist = ColorDist(np, bg);
                        int chroma = Chroma(np);
                        if (dist <= 20.0 && chroma <= 26)
                        {
                            visited[nx, ny] = true;
                            q.Enqueue(new Point(nx, ny));
                        }
                    }
                }
            }

            // Optional diagnostic scan of enclosed cream pockets inside dark bounds
            if (scanHoles)
            {
                bool[,] seenPocket = new bool[cw, ch];
                Console.WriteLine("  [HoleScan] " + poseName + " (ox=" + ox + ", oy=" + oy + "):");
                for (int y = 2; y < ch - 2; y++)
                {
                    for (int x = 2; x < cw - 2; x++)
                    {
                        if (isExtBg[x, y] || seenPocket[x, y]) continue;
                        Color p = cell.GetPixel(x, y);
                        if (ColorDist(p, bg) <= 22.0 && Lum(p) >= 210)
                        {
                            var pts = new List<Point>();
                            var pq = new Queue<Point>();
                            pq.Enqueue(new Point(x, y));
                            seenPocket[x, y] = true;
                            double sumX = 0, sumY = 0;
                            while (pq.Count > 0)
                            {
                                var cur = pq.Dequeue();
                                pts.Add(cur);
                                sumX += cur.X; sumY += cur.Y;
                                for (int d = 0; d < 4; d++)
                                {
                                    int nx = cur.X + dx[d], ny = cur.Y + dy[d];
                                    if (nx >= 0 && nx < cw && ny >= 0 && ny < ch && !isExtBg[nx, ny] && !seenPocket[nx, ny])
                                    {
                                        Color np = cell.GetPixel(nx, ny);
                                        if (ColorDist(np, bg) <= 26.0 && Lum(np) >= 205)
                                        {
                                            seenPocket[nx, ny] = true;
                                            pq.Enqueue(new Point(nx, ny));
                                        }
                                    }
                                }
                            }
                            if (pts.Count >= 20)
                            {
                                int cx = (int)(sumX / pts.Count) + ox;
                                int cy = (int)(sumY / pts.Count) + oy;
                                Console.WriteLine("    pocket size=" + pts.Count + " sheetSeed=(" + cx + "," + cy + ")");
                            }
                        }
                    }
                }
                return;
            }

            // 2. Clear Verified Enclosed Holes (only true background gaps, preserving dials/papers!)
            if (holeMap.ContainsKey(poseName))
            {
                foreach (var hs in holeMap[poseName])
                {
                    FloodEraseHole(cell, ox, oy, hs, bg);
                }
            }

            // 3. Exterior Soft Glow / Halo Feathering (multi-ring outward BFS into soft light glows)
            // Soft warm/lavender glows sit OUTSIDE dark outlines (lum >= 182, 20 < dist < 80).
            bool[,] glowVisited = new bool[cw, ch];
            Queue<Point> gq = new Queue<Point>();
            for (int y = 1; y < ch - 1; y++)
            {
                for (int x = 1; x < cw - 1; x++)
                {
                    if (cell.GetPixel(x, y).A > 0)
                    {
                        bool touchesZero = cell.GetPixel(x - 1, y).A == 0 || cell.GetPixel(x + 1, y).A == 0 ||
                                           cell.GetPixel(x, y - 1).A == 0 || cell.GetPixel(x, y + 1).A == 0;
                        if (touchesZero)
                        {
                            Color p = cell.GetPixel(x, y);
                            double d = ColorDist(p, bg);
                            if (Lum(p) >= 185 && d < 78.0)
                            {
                                gq.Enqueue(new Point(x, y));
                                glowVisited[x, y] = true;
                            }
                        }
                    }
                }
            }

            while (gq.Count > 0)
            {
                Point cur = gq.Dequeue();
                Color p = cell.GetPixel(cur.X, cur.Y);
                double dist = ColorDist(p, bg);
                double lum = Lum(p);

                // Never erode solid high-contrast strokes or opaque non-halo elements
                if (lum >= 185 && dist < 78.0)
                {
                    double t = Math.Max(0.0, Math.Min(1.0, (dist - 16.0) / (78.0 - 16.0)));
                    double alphaNorm = t * t * (3.0 - 2.0 * t); // smoothstep falloff
                    int newA = ClampByte(alphaNorm * 255.0);
                    if (newA < 10)
                    {
                        cell.SetPixel(cur.X, cur.Y, Color.Transparent);
                    }
                    else
                    {
                        double effA = Math.Max(0.15, alphaNorm);
                        int nr = ClampByte((p.R - (1.0 - alphaNorm) * bg.R) / effA);
                        int ng = ClampByte((p.G - (1.0 - alphaNorm) * bg.G) / effA);
                        int nb = ClampByte((p.B - (1.0 - alphaNorm) * bg.B) / effA);
                        cell.SetPixel(cur.X, cur.Y, Color.FromArgb(newA, nr, ng, nb));
                    }

                    for (int d = 0; d < 4; d++)
                    {
                        int nx = cur.X + dx[d], ny = cur.Y + dy[d];
                        if (nx >= 0 && nx < cw && ny >= 0 && ny < ch && !glowVisited[nx, ny])
                        {
                            Color np = cell.GetPixel(nx, ny);
                            if (np.A > 0 && Lum(np) >= 185 && ColorDist(np, bg) < 78.0)
                            {
                                glowVisited[nx, ny] = true;
                                gq.Enqueue(new Point(nx, ny));
                            }
                        }
                    }
                }
            }

            // 4. Clean tiny neutral background specks (<= 16px, low chroma)
            bool[,] seenDust = new bool[cw, ch];
            for (int y = 0; y < ch; y++)
            {
                for (int x = 0; x < cw; x++)
                {
                    if (cell.GetPixel(x, y).A > 0 && !seenDust[x, y])
                    {
                        var island = new List<Point>();
                        var dq = new Queue<Point>();
                        dq.Enqueue(new Point(x, y));
                        seenDust[x, y] = true;
                        int maxC = 0;
                        while (dq.Count > 0)
                        {
                            var cur = dq.Dequeue();
                            island.Add(cur);
                            int c = Chroma(cell.GetPixel(cur.X, cur.Y));
                            if (c > maxC) maxC = c;
                            for (int d = 0; d < 4; d++)
                            {
                                int nx = cur.X + dx[d], ny = cur.Y + dy[d];
                                if (nx >= 0 && nx < cw && ny >= 0 && ny < ch && !seenDust[nx, ny] && cell.GetPixel(nx, ny).A > 0)
                                {
                                    seenDust[nx, ny] = true;
                                    dq.Enqueue(new Point(nx, ny));
                                }
                            }
                        }
                        if ((island.Count <= 14 && maxC <= 30) ||
                            (poseName == "geofence_radar_pulse" && island.Count <= 60 && island[0].Y < ch / 2))
                        {
                            foreach (var pt in island) cell.SetPixel(pt.X, pt.Y, Color.Transparent);
                        }
                    }
                }
            }

            // 5. Two-pass Dark Outline Anti-Aliasing & Cream Rim Decontamination
            for (int pass = 0; pass < 2; pass++)
            {
                bool[,] isBorder = new bool[cw, ch];
                for (int y = 1; y < ch - 1; y++)
                {
                    for (int x = 1; x < cw - 1; x++)
                    {
                        if (cell.GetPixel(x, y).A > 0)
                        {
                            if (cell.GetPixel(x - 1, y).A <= 16 || cell.GetPixel(x + 1, y).A <= 16 ||
                                cell.GetPixel(x, y - 1).A <= 16 || cell.GetPixel(x, y + 1).A <= 16)
                            {
                                isBorder[x, y] = true;
                            }
                        }
                    }
                }

                for (int y = 1; y < ch - 1; y++)
                {
                    for (int x = 1; x < cw - 1; x++)
                    {
                        if (!isBorder[x, y]) continue;
                        Color p = cell.GetPixel(x, y);
                        if (p.A < 180) continue;

                        int chroma = Chroma(p);
                        double lum = Lum(p);
                        if ((chroma <= 30 && lum >= 100) || (chroma <= 24 && lum >= 72))
                        {
                            int darkMin = 255;
                            Color darkN = p;
                            for (int oy2 = -1; oy2 <= 1; oy2++)
                            {
                                for (int ox2 = -1; ox2 <= 1; ox2++)
                                {
                                    Color np = cell.GetPixel(x + ox2, y + oy2);
                                    if (np.A >= 180 && !isBorder[x + ox2, y + oy2])
                                    {
                                        int nl = (int)Lum(np);
                                        if (nl < darkMin) { darkMin = nl; darkN = np; }
                                    }
                                }
                            }
                            int darkLimit = lum >= 100 ? 140 : 68;
                            if (darkMin < darkLimit)
                            {
                                double bgEst = Lum(bg);
                                double denom = Math.Max(15.0, bgEst - darkMin);
                                double cov = Math.Max(0.0, Math.Min(1.0, (bgEst - lum) / denom));
                                int newA = ClampByte(cov * p.A);
                                if (newA < 36)
                                    cell.SetPixel(x, y, Color.Transparent);
                                else
                                    cell.SetPixel(x, y, Color.FromArgb(newA, darkN.R, darkN.G, darkN.B));
                            }
                        }
                    }
                }
            }

            // 6. Tight Bounding-Box Crop with 6px Transparent Padding
            int cMinX = cw, cMaxX = 0, cMinY = ch, cMaxY = 0;
            bool hasPixels = false;
            for (int y = 0; y < ch; y++)
            {
                for (int x = 0; x < cw; x++)
                {
                    if (cell.GetPixel(x, y).A > 15)
                    {
                        hasPixels = true;
                        if (x < cMinX) cMinX = x;
                        if (x > cMaxX) cMaxX = x;
                        if (y < cMinY) cMinY = y;
                        if (y > cMaxY) cMaxY = y;
                    }
                }
            }

            if (hasPixels && cMaxX > cMinX && cMaxY > cMinY)
            {
                int pad = 6;
                int cropX = Math.Max(0, cMinX - pad);
                int cropY = Math.Max(0, cMinY - pad);
                int cropW = Math.Min(cw - cropX, (cMaxX - cMinX + 1) + pad * 2);
                int cropH = Math.Min(ch - cropY, (cMaxY - cMinY + 1) + pad * 2);

                using (Bitmap cropped = new Bitmap(cropW, cropH, PixelFormat.Format32bppArgb))
                {
                    using (Graphics cg = Graphics.FromImage(cropped))
                    {
                        cg.DrawImage(cell, new Rectangle(0, 0, cropW, cropH), new Rectangle(cropX, cropY, cropW, cropH), GraphicsUnit.Pixel);
                    }
                    cropped.Save(outPath, ImageFormat.Png);
                    Console.WriteLine("  Sliced -> " + Path.GetFileName(outPath) + " (" + cropW + "x" + cropH + ")");
                }
            }
        }
    }

    public static void Main(string[] args)
    {
        bool scanMode = args.Length > 0 && args[0] == "--scan";

        var holeMap = new Dictionary<string, HoleSeed[]>
        {
            // Verified true enclosed cream holes (never touching dials/papers/eyes)
            { "focus_lock_padlock", new[] {
                new HoleSeed(863, 245, 30, 30)  // inside padlock metal shackle arch
            } },
            { "memory_grid_master", new[] {
                new HoleSeed(600, 760, 32, 45)  // trapezoid between Roo's legs
            } },
            { "headphones_bliss", new[] {
                new HoleSeed(231, 72, 28, 45)   // crescent between headband arch and head
            } },
            { "storyteller_lantern", new[] {
                new HoleSeed(769, 654, 42, 16)  // inside top lantern brass ring
            } },
            { "duo_roo_scout_dawn_handoff", new[] {
                new HoleSeed(236, 288, 28, 25)  // inside lanyard loop under baton
            } },
            { "duo_roo_seren_morning_peace", new[] {
                new HoleSeed(682, 269, 32, 16)  // tiny gap under teapot handle
            } },
            { "duo_seren_echo_evening_sanctuary", new[] {
                // strips between Seren's harp strings & pillar (height ~108px -> radius 70, dist up to 38)
                new HoleSeed(878, 262, 40, 70),
                new HoleSeed(880, 219, 38, 30),
                new HoleSeed(888, 223, 38, 30),
                new HoleSeed(895, 227, 38, 30),
                new HoleSeed(901, 229, 38, 30),
                new HoleSeed(907, 229, 38, 30),
                new HoleSeed(912, 228, 38, 30),
                new HoleSeed(917, 227, 40, 30),
                new HoleSeed(921, 223, 38, 20),
                new HoleSeed(928, 224, 38, 20),
                new HoleSeed(933, 217, 40, 20),
                new HoleSeed(892, 281, 38, 35),
                new HoleSeed(898, 280, 38, 30),
                new HoleSeed(903, 277, 38, 20),
                new HoleSeed(1168, 296, 32, 20) // lantern top brass ring
            } },
            { "duo_scout_twill_packing_departure", new[] {
                new HoleSeed(600, 760, 32, 45)  // trapezoid between Twill's apron & legs
            } },
            { "duo_pippin_twill_dream_jar", new[] {
                new HoleSeed(939, 755, 32, 40), // pocket between Pippin's ankles
                new HoleSeed(975, 745, 32, 35)  // pocket between Pippin's front ankle & piggy bank
            } },
            { "trio_morning_awakening_squad", new[] {
                new HoleSeed(251, 326, 32, 30)  // pocket between Scout's legs & umbrella
            } },
            { "trio_evening_wind_down_crew", new[] {
                new HoleSeed(585, 135, 44, 20), // left pegboard carabiner loop
                new HoleSeed(621, 140, 34, 20), // right pegboard whistle lanyard loop
                new HoleSeed(725, 319, 34, 15)  // teacup handle inner D-loop
            } },
            { "trio_inspiration_quote_atelier", new[] {
                new HoleSeed(276, 671, 28, 22), // crescent between canvas right edge & Pippin
                new HoleSeed(177, 750, 28, 22), // easel left inner frame triangle
                new HoleSeed(202, 752, 28, 22), // easel right inner frame triangle
                new HoleSeed(94, 774, 32, 35)   // triangle between Echo's ankles
            } },
            { "quartet_quick_capture_express", new[] {
                new HoleSeed(624, 673, 28, 45), // enclosed pocket above signpost between Roo & Twill
                new HoleSeed(674, 741, 28, 30), // pocket between signpost post, Twill & Echo
                new HoleSeed(706, 556, 26, 30), // gap above Twill near Roo wingtip
                new HoleSeed(489, 776, 32, 30), // pocket between Pippin's ankle & signpost grass
                new HoleSeed(734, 776, 32, 30)  // pocket between Echo's ankles
            } },
            { "quartet_cross_module_web", new[] {
                new HoleSeed(1008, 601, 30, 180), // main loop enclosed by golden web lines
                new HoleSeed(967, 752, 28, 25),   // lower thread pocket between Roo & Twill
                new HoleSeed(1066, 757, 28, 25)   // lower thread pocket between Seren & Echo
            } },
            { "typing_keyboard_dash", new[] {
                new HoleSeed(933, 277, 26, 22)    // small pocket between Roo's wrist & keyboard
            } },
            { "subtask_ladder", new[] {
                new HoleSeed(724, 756, 26, 65),   // main lower A-frame ladder opening
                new HoleSeed(639, 780, 26, 35),   // lower-left ladder foot gap
                new HoleSeed(658, 738, 26, 30),   // middle-left ladder step gap
                new HoleSeed(592, 752, 26, 25),   // gap between Roo's right ankle & ladder leg
                new HoleSeed(692, 703, 26, 25)    // upper ladder rung opening
            } },
            { "undo_lasso", new[] {
                new HoleSeed(986, 498, 26, 180),  // top spinning golden lasso oval
                new HoleSeed(930, 586, 26, 90),   // left loop between rope, Roo wing & top oval
                new HoleSeed(931, 705, 26, 55),   // lower-left rope coil beside bell card
                new HoleSeed(1064, 752, 24, 45)   // lower-right rope loop between hand & leg
            } },
            { "book_finished_star", new[] {
                new HoleSeed(609, 786, 28, 40)    // gap between Pippin's ankles
            } },
            { "monthly_chart_easel", new[] {
                new HoleSeed(603, 771, 28, 45),   // gap between Twill's ankles
                new HoleSeed(730, 757, 28, 35)    // pocket between wooden easel legs
            } },
            { "quote_painter_beret", new[] {
                new HoleSeed(670, 769, 28, 45),   // lower easel opening beneath canvas shelf
                new HoleSeed(713, 759, 28, 25),   // lower-right easel crossbar pocket
                new HoleSeed(741, 761, 28, 25),   // outer-right easel leg pocket
                new HoleSeed(608, 786, 28, 35)    // pocket between Echo's ankles
            } },
            { "duo_twill_echo_annual_archive", new[] {
                new HoleSeed(917, 754, 28, 35),   // pocket between Twill's ankles
                new HoleSeed(944, 749, 28, 30),   // gap between Twill & stacked books
                new HoleSeed(1100, 748, 28, 35)   // pocket between Echo's ankles
            } },
            { "geofence_radar_pulse", new[] {
                new HoleSeed(982, 252, 28, 25)    // pocket between Scout's talons & map pin
            } },
            { "seren_comfort_kit_treasure_box", new[] {
                new HoleSeed(234, 268, 28, 35)    // pocket between Seren's ankles & treasure box
            } },
            { "roo_seren_calm_ritual_tea", new[] {
                new HoleSeed(309, 757, 28, 35)    // pocket between Roo's ankles
            } },
            { "seren_scout_crisis_lighthouse", new[] {
                new HoleSeed(964, 742, 28, 55),   // pocket between Seren's ankles & lighthouse base
                new HoleSeed(1032, 743, 28, 55)   // pocket between lighthouse base & Scout's ankles
            } },
            { "flock_healthy_living_compass", new[] {
                new HoleSeed(359, 374, 28, 35),   // pocket between Scout's ankles
                new HoleSeed(140, 381, 28, 35)    // pocket between Twill's ankles
            } },
            { "echo_seren_encrypted_vault_key", new[] {
                new HoleSeed(577, 336, 28, 45)    // pocket between Echo's right talon & lockbox
            } },
            { "seren_strict_sanctuary_gate", new[] {
                // diamond lattice openings in woven wooden garden gate
                new HoleSeed(740, 657, 28, 30),
                new HoleSeed(770, 657, 28, 30),
                new HoleSeed(533, 663, 28, 30),
                new HoleSeed(756, 670, 28, 35),
                new HoleSeed(720, 673, 28, 35),
                new HoleSeed(785, 669, 28, 30),
                new HoleSeed(514, 676, 28, 35),
                new HoleSeed(486, 678, 28, 30),
                new HoleSeed(774, 688, 28, 35),
                new HoleSeed(738, 691, 28, 35),
                new HoleSeed(703, 693, 28, 35),
                new HoleSeed(493, 699, 28, 30),
                new HoleSeed(757, 709, 28, 35),
                new HoleSeed(721, 710, 28, 35),
                new HoleSeed(686, 712, 28, 35),
                new HoleSeed(785, 707, 28, 30),
                new HoleSeed(515, 716, 28, 35),
                new HoleSeed(551, 715, 28, 35),
                new HoleSeed(585, 715, 28, 35),
                new HoleSeed(486, 716, 28, 30),
                new HoleSeed(777, 721, 28, 30),
                new HoleSeed(703, 726, 28, 30),
                new HoleSeed(569, 732, 28, 35),
                new HoleSeed(500, 733, 28, 35),
                new HoleSeed(534, 733, 28, 35),
                new HoleSeed(598, 730, 28, 30),
                new HoleSeed(586, 743, 28, 30),
                new HoleSeed(516, 747, 28, 30),
                new HoleSeed(551, 746, 28, 30),
                new HoleSeed(487, 750, 28, 30)
            } },
            { "duo_seren_scout_shield_ready", new[] {
                new HoleSeed(1095, 670, 28, 30)   // pocket between Seren's wing & signpost
            } },
        };

        var configs = new[]
        {
            new SheetConfig
            {
                SheetKey = "roo4",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\roo_expressions_4.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\roo",
                PoseNames = new[] { "app_fast_shield", "app_fast_victory_crown", "focus_lock_padlock", "usage_limit_hourglass", "memory_grid_master", "custom_tone_vinyl" }
            },
            new SheetConfig
            {
                SheetKey = "roo5",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\roo_expressions_5.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\roo",
                PoseNames = new[] { "app_fast_broken_compassion", "shield_interceptor_stop", "typing_keyboard_dash", "nlp_magic_calendar", "subtask_ladder", "undo_lasso" }
            },
            new SheetConfig
            {
                SheetKey = "seren4",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\seren_expressions_4.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\seren",
                PoseNames = new[] { "headphones_bliss", "spatial_conductor", "custom_mix_jar", "window_rain_gaze", "storyteller_lantern", "timer_sandglass_fade" }
            },
            new SheetConfig
            {
                SheetKey = "scout4",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\scout_expressions_4.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\scout",
                PoseNames = new[] { "cold_scarf_jacket", "heavy_storm_raincoat", "geofence_radar_pulse", "all_ready_salute", "phone_mode_sliders", "oem_knight_armor" }
            },
            new SheetConfig
            {
                SheetKey = "pippin4",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\pippin_expressions_4.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\pippin",
                PoseNames = new[] { "seedling_spark", "artisan_chisel", "virtuoso_conductor", "reading_streak_lantern", "book_finished_star", "bucket_globe_pin" }
            },
            new SheetConfig
            {
                SheetKey = "twill4",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\twill_expressions_4.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\twill",
                PoseNames = new[] { "ledger_quill_entry", "wallet_trio_organizer", "internal_transfer_bridge", "budget_shield_green", "monthly_chart_easel", "markdown_blocks" }
            },
            new SheetConfig
            {
                SheetKey = "echo4",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\echo_expressions_4.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\echo",
                PoseNames = new[] { "gratitude_jar_shake", "tough_day_lantern_hug", "seren_pebble_catch", "custom_pin_vault", "quote_painter_beret", "paper_plane_submit" }
            },
            new SheetConfig
            {
                SheetKey = "duos1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_duos_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\duos",
                PoseNames = new[] { "duo_roo_scout_dawn_handoff", "duo_roo_seren_morning_peace", "duo_seren_echo_evening_sanctuary", "duo_pippin_echo_bucket_memory", "duo_scout_twill_packing_departure", "duo_pippin_twill_dream_jar" }
            },
            new SheetConfig
            {
                SheetKey = "duos3",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_duos_3.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\duos",
                PoseNames = new[] { "duo_scout_pippin_adventure_pin", "duo_scout_pippin_weather_outing", "duo_scout_seren_sleep_shield", "duo_seren_echo_tough_day_comfort", "duo_pippin_echo_book_quote_vault", "duo_twill_echo_annual_archive" }
            },
            new SheetConfig
            {
                SheetKey = "trios1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_trios_quartets_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\ensembles",
                PoseNames = new[] { "trio_morning_awakening_squad", "trio_evening_wind_down_crew", "trio_travel_adventure_packers", "trio_inspiration_quote_atelier", "quartet_quick_capture_express", "quartet_cross_module_web" }
            },
            new SheetConfig
            {
                SheetKey = "seren5",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\seren_expressions_5.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\seren",
                PoseNames = new[] { "breath_inhale_expand", "breath_exhale_settle", "body_scan_feather", "caffeine_herbal_swap", "pill_refill_alert", "walking_shoes_step" }
            },
            new SheetConfig
            {
                SheetKey = "seren6",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\seren_expressions_6.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\seren",
                PoseNames = new[] { "breath_hold_still", "low_motion_stillness", "tts_whisper_duck", "morning_sun_tea", "warmth_dial", "cozy_book_lantern" }
            },
            new SheetConfig
            {
                SheetKey = "seren7",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\seren_expressions_7.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\seren",
                PoseNames = new[] { "seamless_ribbon", "headphone_unplug_pause", "bluetooth_sleep_pause", "lock_screen_transport", "caffeine_clear_sleep", "sleep_debt_blanket" }
            },
            new SheetConfig
            {
                SheetKey = "seren_mental1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\seren_mental_wellness_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\seren",
                PoseNames = new[] { "open_arms_welcome", "grounding_pebble_feather", "mindful_doorway_lantern", "urge_wave_breath", "compassionate_tea_reset", "capsule_open_bloom" }
            },
            new SheetConfig
            {
                SheetKey = "seren_sound1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\seren_soundscapes_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\seren",
                PoseNames = new[] { "singing_bowl", "soft_kalimba", "warm_cello", "monsoon_courtyard_tea", "alpine_meadow_breeze", "bamboo_rain_lantern" }
            },
            new SheetConfig
            {
                SheetKey = "scout5",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\scout_expressions_5.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\scout",
                PoseNames = new[] { "snooze_pocketwatch", "state_restored_rewind", "automation_gears", "permission_inspector", "cross_link_chain", "guest_cloud_bridge" }
            },
            new SheetConfig
            {
                SheetKey = "pippin5",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\pippin_expressions_5.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\pippin",
                PoseNames = new[] { "reading_spectacles_stack", "curious_magnifying_glass", "aquascape_planting", "sketchbook_watercolor", "eureka_match_reveal", "coding_laptop" }
            },
            new SheetConfig
            {
                SheetKey = "twill5",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\twill_expressions_5.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\twill",
                PoseNames = new[] { "budget_caution_amber", "budget_overflow_patch", "recurring_calendar_stamp", "inline_check_tap", "unpack_reset_suitcase", "wishlist_star_scale" }
            },
            new SheetConfig
            {
                SheetKey = "echo5",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\echo_expressions_5.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\echo",
                PoseNames = new[] { "clue_whisper_scroll", "prompt_dice_shuffle", "offline_draft_quill", "dawn_quote_bell", "scholar_scroll", "rubik_constellation_cube" }
            },
            new SheetConfig
            {
                SheetKey = "echo_ka1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\echo_knowledge_arena_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\echo",
                PoseNames = new[] { "knowledge_lantern", "lantern_eureka", "curiosity_globe", "fibonacci_pinecone_spiral", "ink_quill_smile", "wax_seal_capsule" }
            },
            new SheetConfig
            {
                SheetKey = "roo_handoff1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\roo_handoff_focus_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\roo",
                PoseNames = new[] { "sunrise_baton_handoff", "starter_session_stopwatch", "pomodoro_warmup_whistle", "weekend_calendar_pin", "ultradian_conductor", "shrinking_snooze_tap" }
            },
            new SheetConfig
            {
                SheetKey = "duos2",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_duos_2.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\duos",
                PoseNames = new[] { "duo_roo_scout_focus_mode_shield", "duo_roo_seren_pomodoro_hydrate", "duo_roo_twill_recurring_sync", "duo_roo_twill_task_blueprint", "duo_scout_twill_backup_vault", "duo_scout_twill_market_geofence" }
            },
            new SheetConfig
            {
                SheetKey = "duos4",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_duos_4.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\duos",
                PoseNames = new[] { "duo_pippin_echo_bucket_memory", "duo_scout_twill_packing_departure", "duo_pippin_twill_dream_jar", "duo_scout_seren_audio_guard", "duo_echo_roo_focus_relay", "duo_pippin_seren_book_tea" }
            },
            new SheetConfig
            {
                SheetKey = "trios2",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_trios_quartets_2.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "trio_weekend_life_reset", "trio_device_reliability_guard", "trio_mindful_study_sanctuary", "trio_wishlist_occasion_planners", "seren_vitals_stethoscope", "seren_wearable_watch_sync" }
            },
            new SheetConfig
            {
                SheetKey = "story1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\story_anthology_expressions_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "seren_reading_lantern", "seren_rainy_window", "seren_starlight_blanket", "seren_moonflower_calm", "pippin_train_window", "pippin_canal_skiff" }
            },
            new SheetConfig
            {
                SheetKey = "misc1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\misc_expressions_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "echo_brass_compass", "echo_observatory_perch", "seren_med_snooze_pillow", "seren_headset_remote_click", "roo_discipline_streak_proud", "pippin_gardening_trowel" }
            },
            new SheetConfig
            {
                SheetKey = "scout_twill1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\scout_twill_weekend_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "scout_weekend_compass_map", "scout_weekend_picnic_basket", "scout_night_watch_shield", "scout_focus_gatekeeper", "twill_starter_kit_blueprint", "twill_weekend_budget_coin_pouch" }
            },
            new SheetConfig
            {
                SheetKey = "pippin_disc1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\pippin_discover_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "pippin_book_bookmark_wing", "pippin_sketchbook_easel", "pippin_aesthetic_frame", "pippin_forked_trail_sign", "twill_piggybank_abacus_estimate", "twill_palette_swatches" }
            },
            new SheetConfig
            {
                SheetKey = "backlog3",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_backlog_3.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "twill_envelope_organizer", "roo_sunday_ledger_bell", "roo_usage_hourglass_wait", "scout_capability_radar_scan", "echo_strength_keepsake_stamp", "echo_journal_quill_insight" }
            },
            new SheetConfig
            {
                SheetKey = "duos5",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_duos_5.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\duos",
                PoseNames = new[] { "duo_roo_seren_dawn_duet", "duo_seren_pippin_nylon_guitar", "duo_pippin_echo_stepping_stones", "duo_roo_seren_rhythm_balance", "duo_scout_pippin_doorstep_compass", "duo_seren_echo_unsent_letter" }
            },
            new SheetConfig
            {
                SheetKey = "seren_b2",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\seren_backlog_2.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "seren_morning_sunrise_stretch", "seren_gentle_breath_lotus", "seren_forest_stream_tea", "seren_moonlight_hourglass", "seren_harbor_mist_scarf", "duo_seren_pippin_healthy_spark" }
            },
            new SheetConfig
            {
                SheetKey = "qa_polish1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_qa_polish_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "trio_device_reliability_guard", "roo_app_fast_victory_crown", "roo_discipline_streak_proud", "echo_lantern_strength_mirror", "flock_season_fireside_recap", "flock_tab_glide_transition" }
            },
            new SheetConfig
            {
                SheetKey = "seasonal1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_seasonal_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "roo_dawn_lantern_stretch", "scout_rainy_umbrella_puddle", "seren_autumn_maple_tea", "pippin_winter_snow_scarf", "twill_spring_blossom_basket", "echo_midnight_crescent_book" }
            },
            new SheetConfig
            {
                SheetKey = "seasonal2",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_seasonal_2.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "roo_new_year_sparkler", "seren_eid_crescent_lantern", "pippin_summer_sunhat_compass", "twill_winter_cocoa_scarf", "echo_autumn_moon_lantern", "scout_birthday_gift_balloon" }
            },
            new SheetConfig
            {
                SheetKey = "empty1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_empty_states_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "roo_empty_tasks_coffee", "scout_empty_places_binoculars", "seren_empty_journal_tea", "pippin_empty_bookshelf_feather", "twill_empty_wallet_jar", "echo_empty_memories_camera" }
            },
            new SheetConfig
            {
                SheetKey = "milestones1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_milestones_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "roo_streak_100_flame", "scout_geofence_home_welcome", "seren_breath_100_lotus", "pippin_reading_10_books", "twill_savings_goal_confetti", "echo_diary_30_days_star" }
            },
            new SheetConfig
            {
                SheetKey = "everyday1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_everyday_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "roo_morning_coffee_sunrise", "scout_commute_train_map", "seren_rainy_tea_cozy", "pippin_stargazing_telescope", "twill_grocery_basket_list", "echo_midnight_candle_diary" }
            },
            new SheetConfig
            {
                SheetKey = "hobbies2",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_hobbies_2.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "pippin_origami_crane", "pippin_ukulele_melody", "twill_receipt_folder_tidy", "scout_flashlight_path", "roo_stretching_warmup", "echo_vinyl_chill" }
            },
            new SheetConfig
            {
                SheetKey = "duos6",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_duos_6.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\duos",
                PoseNames = new[] { "duo_roo_echo_study_timer", "duo_twill_seren_budget_calm", "duo_pippin_twill_travel_map", "duo_scout_echo_night_patrol", "duo_roo_twill_habit_ledger", "duo_pippin_scout_trail_hike" }
            },
            new SheetConfig
            {
                SheetKey = "duos7",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_duos_7.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\duos",
                PoseNames = new[] { "duo_roo_pippin_morning_walk", "duo_seren_twill_evening_plan", "duo_scout_roo_morning_brief", "duo_echo_twill_memory_ledger", "duo_pippin_roo_hobby_sprint", "duo_seren_scout_calm_commute" }
            },
            new SheetConfig
            {
                SheetKey = "seren_mental2",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\seren_mental_wellness_2.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "seren_comfort_kit_treasure_box", "scout_seren_trusted_messenger", "echo_seren_voice_memo_feather", "roo_seren_calm_ritual_tea", "seren_echo_library_lantern", "seren_scout_crisis_lighthouse" }
            },
            new SheetConfig
            {
                SheetKey = "seren_mental3",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\seren_mental_wellness_3.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\_mixed",
                PoseNames = new[] { "flock_healthy_living_compass", "echo_seren_encrypted_vault_key", "seren_launcher_moment_badge", "seren_mindful_doorway_hourglass", "seren_strict_sanctuary_gate", "duo_seren_scout_shield_ready" }
            }
        };

        HashSet<string> filterKeys = null;
        foreach (var a in args)
        {
            if (a.StartsWith("--filter="))
            {
                filterKeys = new HashSet<string>(a.Substring(9).Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries));
            }
        }

        foreach (var cfg in configs)
        {
            if (filterKeys != null && !filterKeys.Contains(cfg.SheetKey)) continue;
            if (!File.Exists(cfg.SourcePath)) continue;
            if (!Directory.Exists(cfg.OutputDir)) Directory.CreateDirectory(cfg.OutputDir);

            Console.WriteLine("Processing " + Path.GetFileName(cfg.SourcePath));
            using (Bitmap sheet = (Bitmap)Image.FromFile(cfg.SourcePath))
            {
                Color bg = EstimateAverageCornerBg(sheet);
                int yMin = (int)Math.Round(sheet.Height * (350.0 / 896.0));
                int yMax = (int)Math.Round(sheet.Height * (510.0 / 896.0));
                int[] sepY = FindHorizontalSeam(sheet, bg, yMin, yMax);

                int minSepY = sheet.Height, maxSepY = 0;
                for (int x = 0; x < sheet.Width; x++)
                {
                    if (sepY[x] < minSepY) minSepY = sepY[x];
                    if (sepY[x] > maxSepY) maxSepY = sepY[x];
                }

                int x0Lo = (int)Math.Round(sheet.Width * (330.0 / 1200.0));
                int x0Hi = (int)Math.Round(sheet.Width * (480.0 / 1200.0));
                int x1Lo = (int)Math.Round(sheet.Width * (730.0 / 1200.0));
                int x1Hi = (int)Math.Round(sheet.Width * (880.0 / 1200.0));

                int[] r0Seam01 = FindVerticalSeam(sheet, bg, 0, Math.Min(sheet.Height, maxSepY + 1), x0Lo, x0Hi);
                int[] r0Seam12 = FindVerticalSeam(sheet, bg, 0, Math.Min(sheet.Height, maxSepY + 1), x1Lo, x1Hi);
                int[] r1Seam01 = FindVerticalSeam(sheet, bg, minSepY, sheet.Height, x0Lo, x0Hi);
                int[] r1Seam12 = FindVerticalSeam(sheet, bg, minSepY, sheet.Height, x1Lo, x1Hi);

                for (int i = 0; i < 6; i++)
                {
                    int r = i / 3;
                    int c = i % 3;
                    int[] s01 = r == 0 ? r0Seam01 : r1Seam01;
                    int[] s12 = r == 0 ? r0Seam12 : r1Seam12;
                    int[] colLeft = c == 0 ? null : (c == 1 ? s01 : s12);
                    int[] colRight = c == 2 ? null : (c == 0 ? s01 : s12);
                    string pose = cfg.PoseNames[i];
                    string outPath = Path.Combine(cfg.OutputDir, pose + ".png");
                    ProcessRegion(sheet, bg, c, r, sepY, colLeft, colRight, pose, outPath, holeMap, scanMode);
                }
            }
        }
    }
}
