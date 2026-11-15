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
                        if (island.Count <= 14 && maxC <= 30)
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
                SheetKey = "seren4",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\seren_expressions_4.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\seren",
                PoseNames = new[] { "headphones_bliss", "spatial_conductor", "custom_mix_jar", "window_rain_gaze", "storyteller_lantern", "timer_sandglass_fade" }
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
                SheetKey = "trios1",
                SourcePath = @"apps\mobile\source_art\mascots\sheets\flock_trios_quartets_1.jpg",
                OutputDir = @"apps\mobile\assets\mascots\sprites\ensembles",
                PoseNames = new[] { "trio_morning_awakening_squad", "trio_evening_wind_down_crew", "trio_travel_adventure_packers", "trio_inspiration_quote_atelier", "quartet_quick_capture_express", "quartet_cross_module_web" }
            }
        };

        foreach (var cfg in configs)
        {
            if (!File.Exists(cfg.SourcePath)) continue;
            if (!Directory.Exists(cfg.OutputDir)) Directory.CreateDirectory(cfg.OutputDir);

            Console.WriteLine("Processing " + Path.GetFileName(cfg.SourcePath));
            using (Bitmap sheet = (Bitmap)Image.FromFile(cfg.SourcePath))
            {
                Color bg = EstimateAverageCornerBg(sheet);
                int[] sepY = FindHorizontalSeam(sheet, bg, 350, 510);

                int minSepY = sheet.Height, maxSepY = 0;
                for (int x = 0; x < sheet.Width; x++)
                {
                    if (sepY[x] < minSepY) minSepY = sepY[x];
                    if (sepY[x] > maxSepY) maxSepY = sepY[x];
                }

                int[] r0Seam01 = FindVerticalSeam(sheet, bg, 0, Math.Min(sheet.Height, maxSepY + 1), 330, 480);
                int[] r0Seam12 = FindVerticalSeam(sheet, bg, 0, Math.Min(sheet.Height, maxSepY + 1), 730, 880);
                int[] r1Seam01 = FindVerticalSeam(sheet, bg, minSepY, sheet.Height, 330, 480);
                int[] r1Seam12 = FindVerticalSeam(sheet, bg, minSepY, sheet.Height, 730, 880);

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
