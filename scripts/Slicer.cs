using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

class CleanSheet3
{
    struct HoleSeed
    {
        public int X, Y;
        public int MaxRadius;
        public HoleSeed(int x, int y, int r = 60) { X = x; Y = y; MaxRadius = r; }
    }

    struct SheetSpec
    {
        public string Bird;
        public string SheetPath;
        public int[] SepX0;
        public int[] SepX1;
        public int SepY;
        public string[] Poses;
        public int[] ForcedMaxCutY; // fallback or cap for bottom caption removal
        public bool IsDieCutSticker;
        public bool HasSpeechBubbles;
        public Rectangle[] BubbleZones;
    }

    static double ColorDist(Color a, Color b)
    {
        int dr = a.R - b.R;
        int dg = a.G - b.G;
        int db = a.B - b.B;
        return Math.Sqrt(dr * dr + dg * dg + db * db);
    }

    static void FloodEraseHole(Bitmap bmp, int seedX, int seedY, Color bg, bool isEcho, int maxBoxRadius = 70)
    {
        int w = bmp.Width, h = bmp.Height;
        // Search tiny 7x7 neighborhood around seed for best neutral bg/shadow/white pixel
        int sx = -1, sy = -1;
        double bestScore = double.MaxValue;
        for (int oy = -4; oy <= 4; oy++)
        {
            for (int ox = -4; ox <= 4; ox++)
            {
                int px = seedX + ox, py = seedY + oy;
                if (px < 0 || px >= w || py < 0 || py >= h) continue;
                Color p = bmp.GetPixel(px, py);
                if (p.A == 0) continue;
                int maxC = Math.Max(p.R, Math.Max(p.G, p.B));
                int minC = Math.Min(p.R, Math.Min(p.G, p.B));
                int chroma = maxC - minC;
                double d = ColorDist(p, bg);
                if (chroma <= 24 && (d < 50 || minC >= 135))
                {
                    double score = d + chroma * 0.5;
                    if (score < bestScore) { bestScore = score; sx = px; sy = py; }
                }
            }
        }
        if (sx < 0) return;

        bool[,] visited = new bool[w, h];
        var q = new Queue<Point>();
        q.Enqueue(new Point(sx, sy));
        visited[sx, sy] = true;
        int[] dx = { 1, -1, 0, 0 };
        int[] dy = { 0, 0, 1, -1 };

        while (q.Count > 0)
        {
            var cur = q.Dequeue();
            bmp.SetPixel(cur.X, cur.Y, Color.Transparent);
            for (int d = 0; d < 4; d++)
            {
                int nx = cur.X + dx[d], ny = cur.Y + dy[d];
                if (nx >= 0 && nx < w && ny >= 0 && ny < h && !visited[nx, ny])
                {
                    if (Math.Abs(nx - seedX) > maxBoxRadius || Math.Abs(ny - seedY) > maxBoxRadius) continue;
                    Color np = bmp.GetPixel(nx, ny);
                    if (np.A == 0) continue;
                    int maxC = Math.Max(np.R, Math.Max(np.G, np.B));
                    int minC = Math.Min(np.R, Math.Min(np.G, np.B));
                    int chroma = maxC - minC;
                    double dist = ColorDist(np, bg);
                    bool match = dist < 38 || (isEcho ? (chroma <= 24 && minC >= 120) : (chroma <= 20 && minC >= 175));
                    if (match)
                    {
                        visited[nx, ny] = true;
                        q.Enqueue(new Point(nx, ny));
                    }
                }
            }
        }
    }

    static void Main()
    {
        var specs = new[]
        {
            new SheetSpec
            {
                Bird = "echo",
                SheetPath = @"apps\mobile\source_art\mascots\sheets\echo_expressions_3.jpg",
                SepX0 = new[] { 0, 373, 794, 1200 },
                SepX1 = new[] { 0, 418, 779, 1200 },
                SepY = 445,
                Poses = new[] { "bookmark", "candlelight", "scrapbook", "stargazing", "wisdom", "audio_memo" },
                // Exact caption gap Y checked from coords_echo.png:
                // Row0 figures end <= 388, captions below 390. Row1 figures end <= 376 (445+376=821), captions below 378.
                ForcedMaxCutY = new[] { 389, 389, 389, 376, 376, 376 },
                IsDieCutSticker = true,
                HasSpeechBubbles = false,
                BubbleZones = null
            },
            new SheetSpec
            {
                Bird = "pippin",
                SheetPath = @"apps\mobile\source_art\mascots\sheets\pippin_expressions_3.jpg",
                SepX0 = new[] { 0, 394, 787, 1200 },
                SepX1 = new[] { 0, 397, 777, 1200 },
                SepY = 445,
                Poses = new[] { "compass", "trophy", "backpacking", "butterfly", "curious", "treasure_map" },
                ForcedMaxCutY = new[] { 392, 392, 392, 380, 380, 380 },
                IsDieCutSticker = false,
                HasSpeechBubbles = true,
                BubbleZones = new[] {
                    new Rectangle(10, 8, 200, 165),
                    new Rectangle(8, 15, 205, 165),
                    new Rectangle(215, 8, 195, 165),
                    new Rectangle(15, 15, 185, 170),
                    new Rectangle(15, 15, 180, 175),
                    new Rectangle(15, 10, 210, 170)
                }
            },
            new SheetSpec
            {
                Bird = "twill",
                SheetPath = @"apps\mobile\source_art\mascots\sheets\twill_expressions_3.jpg",
                SepX0 = new[] { 0, 419, 813, 1200 },
                SepX1 = new[] { 0, 423, 805, 1200 },
                SepY = 445,
                Poses = new[] { "piggy_bank", "envelope_budget", "nest_building", "binder_clip", "search_folder", "target_reached" },
                ForcedMaxCutY = new[] { 390, 390, 390, 372, 372, 372 },
                IsDieCutSticker = false,
                HasSpeechBubbles = true,
                BubbleZones = new[] {
                    new Rectangle(250, 8, 165, 175),
                    new Rectangle(180, 8, 210, 165),
                    new Rectangle(190, 8, 195, 170),
                    new Rectangle(210, 10, 210, 180),
                    new Rectangle(190, 10, 190, 170),
                    new Rectangle(220, 8, 175, 170)
                }
            },
            new SheetSpec
            {
                Bird = "scout",
                SheetPath = @"apps\mobile\source_art\mascots\sheets\scout_expressions_3.jpg",
                SepX0 = new[] { 0, 437, 750, 1200 },
                SepX1 = new[] { 0, 393, 791, 1200 },
                SepY = 442,
                Poses = new[] { "compass_guide", "umbrella", "flashlight", "keyring", "express_fly", "destination" },
                ForcedMaxCutY = new[] { 386, 386, 386, 368, 368, 368 },
                IsDieCutSticker = false,
                HasSpeechBubbles = false,
                BubbleZones = null
            }
        };

        // Explicit interior hole seeds per pose (identified visually + verified from CheckRemainingPockets)
        var holeMap = new Dictionary<string, HoleSeed[]>
        {
            // Echo
            { "echo/bookmark", new[] { new HoleSeed(200, 345, 25), new HoleSeed(245, 345, 25) } },
            { "echo/candlelight", new[] { new HoleSeed(392, 292, 12) } }, // candle ring handle
            { "echo/scrapbook", new[] {
                new HoleSeed(77, 257, 16), new HoleSeed(109, 260, 16), // scissor finger loops
                new HoleSeed(103, 240, 14) // small triangle between scissor blades/wing
            } },
            { "echo/stargazing", new[] { new HoleSeed(218, 342, 30) } }, // between ankles
            { "echo/wisdom", new[] { new HoleSeed(196, 339, 30) } }, // between ankles
            { "echo/audio_memo", new[] { new HoleSeed(232, 338, 25) } }, // between ankles

            // Pippin
            { "pippin/trophy", new[] {
                new HoleSeed(295, 111, 22), // left trophy handle
                new HoleSeed(365, 101, 22)  // right trophy handle
            } },
            { "pippin/curious", new[] {
                new HoleSeed(277, 167, 30), // raised arm-head loop
                new HoleSeed(212, 331, 30)  // between legs
            } },

            // Twill
            { "twill/piggy_bank", new[] {
                new HoleSeed(304, 250, 22), // between wing and piggy bank top
                new HoleSeed(256, 336, 32)  // between legs
            } },
            { "twill/nest_building", new[] {
                new HoleSeed(176, 340, 25)  // between legs
            } },
            { "twill/binder_clip", new[] {
                new HoleSeed(361, 158, 15), new HoleSeed(373, 165, 15), // binder clip silver wire loops
                new HoleSeed(309, 321, 10), new HoleSeed(362, 323, 10), new HoleSeed(281, 324, 12),
                new HoleSeed(334, 332, 10), new HoleSeed(386, 334, 10), new HoleSeed(311, 346, 10), new HoleSeed(340, 351, 12) // floor paperclip loops
            } },

            // Scout
            { "scout/umbrella", new[] { new HoleSeed(165, 347, 30) } }, // between legs
            { "scout/keyring", new[] {
                new HoleSeed(310, 152, 35), // inside brass keyring circle
                new HoleSeed(335, 180, 18), // gap between key shaft and fob
                new HoleSeed(370, 238, 12)  // tiny gap near key tip
            } },
            { "scout/destination", new[] { new HoleSeed(210, 282, 30) } } // map pin center hole
        };

        int[] dx = { 1, -1, 0, 0 };
        int[] dy = { 0, 0, 1, -1 };

        foreach (var spec in specs)
        {
            Console.WriteLine("\n=== Processing " + spec.Bird + " ===");
            using (var sheet = new Bitmap(spec.SheetPath))
            {
                Color bg = sheet.GetPixel(4, 4);
                string outDir = Path.Combine(@"apps\mobile\assets\mascots\sprites", spec.Bird);
                Directory.CreateDirectory(outDir);

                for (int i = 0; i < 6; i++)
                {
                    int r = i / 3;
                    int c = i % 3;
                    var seps = (r == 0) ? spec.SepX0 : spec.SepX1;
                    int x0 = seps[c], x1 = seps[c + 1];
                    int y0 = (r == 0) ? 0 : spec.SepY;
                    int y1 = (r == 0) ? spec.SepY : sheet.Height;
                    int w = x1 - x0, h = y1 - y0;
                    string pose = spec.Poses[i];
                    int cutY = Math.Min(h, spec.ForcedMaxCutY[i]);

                    using (var cell = new Bitmap(w, h, PixelFormat.Format32bppArgb))
                    {
                        using (var g = Graphics.FromImage(cell))
                            g.DrawImage(sheet, new Rectangle(0, 0, w, h), new Rectangle(x0, y0, w, h), GraphicsUnit.Pixel);

                        // 1. Auto-refine cutY slightly above any remaining bottom caption ink
                        bool inCaption = false;
                        int emptyRun = 0;
                        for (int y = h - 1; y >= Math.Max((int)(h * 0.72), cutY - 30); y--)
                        {
                            int darkCount = 0;
                            for (int x = 0; x < w; x++)
                            {
                                Color p = cell.GetPixel(x, y);
                                int maxC = Math.Max(p.R, Math.Max(p.G, p.B));
                                int minC = Math.Min(p.R, Math.Min(p.G, p.B));
                                int chroma = maxC - minC;
                                bool isNeutralShadow = (chroma <= 26 && minC >= 175);
                                double d = ColorDist(p, bg);
                                if (d > 42 && !isNeutralShadow) darkCount++;
                            }
                            if (!inCaption)
                            {
                                if (darkCount >= 10) inCaption = true;
                            }
                            else
                            {
                                if (darkCount <= 2)
                                {
                                    emptyRun++;
                                    if (emptyRun >= 6)
                                    {
                                        cutY = Math.Min(cutY, y + 3);
                                        break;
                                    }
                                }
                                else
                                {
                                    emptyRun = 0;
                                }
                            }
                        }

                        // Wipe bottom caption completely
                        for (int y = cutY; y < h; y++)
                            for (int x = 0; x < w; x++)
                                cell.SetPixel(x, y, Color.Transparent);

                        // 2. Outer Flood-Fill Removal
                        bool[,] visited = new bool[w, h];
                        var queue = new Queue<Point>();
                        for (int x = 0; x < w; x++)
                        {
                            queue.Enqueue(new Point(x, 0)); visited[x, 0] = true;
                            queue.Enqueue(new Point(x, Math.Max(0, cutY - 1))); visited[x, Math.Max(0, cutY - 1)] = true;
                        }
                        for (int y = 0; y < cutY; y++)
                        {
                            queue.Enqueue(new Point(0, y)); visited[0, y] = true;
                            queue.Enqueue(new Point(w - 1, y)); visited[w - 1, y] = true;
                        }

                        while (queue.Count > 0)
                        {
                            Point pt = queue.Dequeue();
                            Color p = cell.GetPixel(pt.X, pt.Y);
                            if (p.A == 0) continue;

                            int maxC = Math.Max(p.R, Math.Max(p.G, p.B));
                            int minC = Math.Min(p.R, Math.Min(p.G, p.B));
                            int chroma = maxC - minC;
                            double dist = ColorDist(p, bg);

                            bool erase = dist < 38;
                            if (!erase)
                            {
                                if (spec.IsDieCutSticker)
                                {
                                    // Echo sticker white border + gray drop shadow
                                    if (chroma <= 24 && minC >= 166) erase = true;
                                }
                                else
                                {
                                    // Flat ground oval shadows near bottom (include warm taupe oval shadows up to R-B <= 42)
                                    if (pt.Y >= (int)(h * 0.68) && chroma <= 42 && minC >= 168 && (p.R - p.B) <= 42)
                                        erase = true;
                                }
                            }

                            if (erase)
                            {
                                cell.SetPixel(pt.X, pt.Y, Color.Transparent);
                                for (int d = 0; d < 4; d++)
                                {
                                    int nx = pt.X + dx[d], ny = pt.Y + dy[d];
                                    if (nx >= 0 && nx < w && ny >= 0 && ny < cutY && !visited[nx, ny])
                                    {
                                        visited[nx, ny] = true;
                                        queue.Enqueue(new Point(nx, ny));
                                    }
                                }
                            }
                        }

                        // 3. Speech Bubble Removal for Pippin & Twill
                        if (spec.HasSpeechBubbles && spec.BubbleZones != null)
                        {
                            Rectangle bz = spec.BubbleZones[i];
                            int bx0 = Math.Max(0, bz.Left);
                            int by0 = Math.Max(0, bz.Top);
                            int bx1 = Math.Min(w, bz.Right);
                            int by1 = Math.Min(cutY, bz.Bottom);

                            bool[,] seenW = new bool[w, h];
                            List<Point> bestBubbleWhite = new List<Point>();

                            for (int y = by0; y < by1; y++)
                            {
                                for (int x = bx0; x < bx1; x++)
                                {
                                    Color p = cell.GetPixel(x, y);
                                    int maxC = Math.Max(p.R, Math.Max(p.G, p.B));
                                    int minC = Math.Min(p.R, Math.Min(p.G, p.B));
                                    if (p.A > 128 && minC >= 220 && (maxC - minC) <= 18 && !seenW[x, y])
                                    {
                                        var comp = new List<Point>();
                                        var bq = new Queue<Point>();
                                        bq.Enqueue(new Point(x, y));
                                        seenW[x, y] = true;
                                        while (bq.Count > 0)
                                        {
                                            var cur = bq.Dequeue();
                                            comp.Add(cur);
                                            for (int d = 0; d < 4; d++)
                                            {
                                                int nx = cur.X + dx[d], ny = cur.Y + dy[d];
                                                if (nx >= bx0 && nx < bx1 && ny >= by0 && ny < by1 && !seenW[nx, ny])
                                                {
                                                    Color np = cell.GetPixel(nx, ny);
                                                    int nmax = Math.Max(np.R, Math.Max(np.G, np.B));
                                                    int nmin = Math.Min(np.R, Math.Min(np.G, np.B));
                                                    if (np.A > 128 && nmin >= 200 && (nmax - nmin) <= 22)
                                                    {
                                                        seenW[nx, ny] = true;
                                                        bq.Enqueue(new Point(nx, ny));
                                                    }
                                                }
                                            }
                                        }
                                        if (comp.Count > bestBubbleWhite.Count)
                                            bestBubbleWhite = comp;
                                    }
                                }
                            }

                            if (bestBubbleWhite.Count > 300)
                            {
                                bool[,] bubbleMask = new bool[w, h];
                                int minBX = w, maxBX = 0, minBY = h, maxBY = 0;
                                foreach (var pt in bestBubbleWhite)
                                {
                                    bubbleMask[pt.X, pt.Y] = true;
                                    if (pt.X < minBX) minBX = pt.X;
                                    if (pt.X > maxBX) maxBX = pt.X;
                                    if (pt.Y < minBY) minBY = pt.Y;
                                    if (pt.Y > maxBY) maxBY = pt.Y;
                                }

                                int px0 = Math.Max(0, minBX - 2);
                                int py0 = Math.Max(0, minBY - 2);
                                int px1 = Math.Min(w - 1, maxBX + 2);
                                int py1 = Math.Min(h - 1, maxBY + 2);
                                int bw = px1 - px0 + 1, bh = py1 - py0 + 1;
                                bool[,] reachOut = new bool[bw, bh];
                                var rq = new Queue<Point>();
                                for (int x = 0; x < bw; x++)
                                {
                                    if (!bubbleMask[px0 + x, py0]) { reachOut[x, 0] = true; rq.Enqueue(new Point(x, 0)); }
                                    if (!bubbleMask[px0 + x, py1]) { reachOut[x, bh - 1] = true; rq.Enqueue(new Point(x, bh - 1)); }
                                }
                                for (int y = 0; y < bh; y++)
                                {
                                    if (!bubbleMask[px0, py0 + y] && !reachOut[0, y]) { reachOut[0, y] = true; rq.Enqueue(new Point(0, y)); }
                                    if (!bubbleMask[px1, py0 + y] && !reachOut[bw - 1, y]) { reachOut[bw - 1, y] = true; rq.Enqueue(new Point(bw - 1, y)); }
                                }
                                while (rq.Count > 0)
                                {
                                    var cur = rq.Dequeue();
                                    for (int d = 0; d < 4; d++)
                                    {
                                        int nx = cur.X + dx[d], ny = cur.Y + dy[d];
                                        if (nx >= 0 && nx < bw && ny >= 0 && ny < bh && !reachOut[nx, ny] && !bubbleMask[px0 + nx, py0 + ny])
                                        {
                                            reachOut[nx, ny] = true;
                                            rq.Enqueue(new Point(nx, ny));
                                        }
                                    }
                                }

                                for (int y = 0; y < bh; y++)
                                    for (int x = 0; x < bw; x++)
                                        if (!reachOut[x, y])
                                            bubbleMask[px0 + x, py0 + y] = true;

                                bool[,] isCharacterFill = new bool[w, h];
                                for (int y = Math.Max(0, minBY - 25); y < Math.Min(cutY, maxBY + 40); y++)
                                {
                                    for (int x = Math.Max(0, minBX - 25); x < Math.Min(w, maxBX + 25); x++)
                                    {
                                        if (bubbleMask[x, y]) continue;
                                        Color p = cell.GetPixel(x, y);
                                        if (p.A < 128) continue;
                                        int maxC = Math.Max(p.R, Math.Max(p.G, p.B));
                                        int minC = Math.Min(p.R, Math.Min(p.G, p.B));
                                        if (maxC - minC > 22)
                                            isCharacterFill[x, y] = true;
                                    }
                                }

                                bool[,] protectedOutline = new bool[w, h];
                                for (int y = Math.Max(0, minBY - 20); y < Math.Min(cutY, maxBY + 35); y++)
                                {
                                    for (int x = Math.Max(0, minBX - 20); x < Math.Min(w, maxBX + 20); x++)
                                    {
                                        if (isCharacterFill[x, y])
                                        {
                                            for (int oy = -4; oy <= 4; oy++)
                                                for (int ox = -4; ox <= 4; ox++)
                                                {
                                                    if (ox * ox + oy * oy <= 18)
                                                    {
                                                        int px = x + ox, py = y + oy;
                                                        if (px >= 0 && px < w && py >= 0 && py < cutY)
                                                            protectedOutline[px, py] = true;
                                                    }
                                                }
                                        }
                                    }
                                }

                                for (int y = minBY; y <= maxBY; y++)
                                    for (int x = minBX; x <= maxBX; x++)
                                    {
                                        if (!bubbleMask[x, y]) continue;
                                        Color cp = cell.GetPixel(x, y);
                                        int cmax = Math.Max(cp.R, Math.Max(cp.G, cp.B));
                                        int cmin = Math.Min(cp.R, Math.Min(cp.G, cp.B));
                                        bool isWhiteBubblePixel = (cmin >= 185 && (cmax - cmin) <= 28);
                                        if (!protectedOutline[x, y] || isWhiteBubblePixel)
                                            cell.SetPixel(x, y, Color.Transparent);
                                    }

                                for (int y = Math.Max(0, minBY - 6); y < Math.Min(cutY, maxBY + 18); y++)
                                {
                                    for (int x = Math.Max(0, minBX - 6); x < Math.Min(w, maxBX + 6); x++)
                                    {
                                        Color p = cell.GetPixel(x, y);
                                        if (p.A == 0) continue;
                                        int pmax = Math.Max(p.R, Math.Max(p.G, p.B));
                                        int pmin = Math.Min(p.R, Math.Min(p.G, p.B));
                                        bool isBrightNeutral = (pmin >= 180 && (pmax - pmin) <= 30);
                                        if (protectedOutline[x, y] && !isBrightNeutral) continue;

                                        bool nearBubble = false;
                                        for (int oy = -5; oy <= 5 && !nearBubble; oy++)
                                            for (int ox = -5; ox <= 5 && !nearBubble; ox++)
                                            {
                                                int sx = x + ox, sy = y + oy;
                                                if (sx >= 0 && sx < w && sy >= 0 && sy < cutY && bubbleMask[sx, sy])
                                                    nearBubble = true;
                                            }
                                        if (nearBubble)
                                            cell.SetPixel(x, y, Color.Transparent);
                                    }
                                }

                                bool[,] seenIsl = new bool[w, h];
                                for (int y = by0; y < Math.Min(cutY, by1 + 15); y++)
                                {
                                    for (int x = bx0; x < bx1; x++)
                                    {
                                        Color p = cell.GetPixel(x, y);
                                        if (p.A > 0 && !seenIsl[x, y])
                                        {
                                            var isl = new List<Point>();
                                            var iq = new Queue<Point>();
                                            iq.Enqueue(new Point(x, y));
                                            seenIsl[x, y] = true;
                                            bool touchesMain = false;
                                            while (iq.Count > 0)
                                            {
                                                var cur = iq.Dequeue();
                                                isl.Add(cur);
                                                if (cur.Y >= by1 + 14 || cur.X <= 1 || cur.X >= w - 2 || protectedOutline[cur.X, cur.Y])
                                                    touchesMain = true;
                                                for (int d = 0; d < 4; d++)
                                                {
                                                    int nx = cur.X + dx[d], ny = cur.Y + dy[d];
                                                    if (nx >= 0 && nx < w && ny >= 0 && ny < cutY && !seenIsl[nx, ny] && cell.GetPixel(nx, ny).A > 0)
                                                    {
                                                        seenIsl[nx, ny] = true;
                                                        iq.Enqueue(new Point(nx, ny));
                                                    }
                                                }
                                            }
                                            if (!touchesMain && isl.Count < 800)
                                            {
                                                foreach (var pt in isl)
                                                    cell.SetPixel(pt.X, pt.Y, Color.Transparent);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 4. Surgical interior trapped cream / sticker pocket removal via verified seeds
                        string key = spec.Bird + "/" + pose;
                        if (holeMap.ContainsKey(key))
                        {
                            foreach (var hs in holeMap[key])
                            {
                                FloodEraseHole(cell, hs.X, hs.Y, bg, spec.IsDieCutSticker, hs.MaxRadius);
                            }
                        }

                        // 5. Special Polish: Scout flashlight right-edge beam smooth horizontal alpha fadeout
                        if (key == "scout/flashlight")
                        {
                            int fadeLen = 70;
                            int fadeStart = Math.Max(0, w - fadeLen);
                            for (int y = 0; y < cutY; y++)
                            {
                                for (int x = fadeStart; x < w; x++)
                                {
                                    Color p = cell.GetPixel(x, y);
                                    if (p.A > 0)
                                    {
                                        double t = (double)(w - 1 - x) / fadeLen; // 1 -> 0
                                        t = Math.Max(0, Math.Min(1, t));
                                        // Smoothstep ease
                                        double aFactor = t * t * (3.0 - 2.0 * t);
                                        int newA = (int)(p.A * aFactor);
                                        cell.SetPixel(x, y, Color.FromArgb(newA, p.R, p.G, p.B));
                                    }
                                }
                            }
                        }

                        // 6. Clean tiny stray dust islands (e.g. residual 1-16px ground shadow specks or orphan dots)
                        // Carefully preserve larger stars/sparkles (>= 18px) and bright colorful highlights
                        bool[,] seenDust = new bool[w, h];
                        for (int y = 0; y < cutY; y++)
                        {
                            for (int x = 0; x < w; x++)
                            {
                                if (cell.GetPixel(x, y).A > 0 && !seenDust[x, y])
                                {
                                    var isl = new List<Point>();
                                    var dq = new Queue<Point>();
                                    dq.Enqueue(new Point(x, y));
                                    seenDust[x, y] = true;
                                    int maxChroma = 0;
                                    int islMaxY = y;
                                    while (dq.Count > 0)
                                    {
                                        var cur = dq.Dequeue();
                                        isl.Add(cur);
                                        if (cur.Y > islMaxY) islMaxY = cur.Y;
                                        Color cp = cell.GetPixel(cur.X, cur.Y);
                                        int ch = Math.Max(cp.R, Math.Max(cp.G, cp.B)) - Math.Min(cp.R, Math.Min(cp.G, cp.B));
                                        if (ch > maxChroma) maxChroma = ch;
                                        for (int d = 0; d < 4; d++)
                                        {
                                            int nx = cur.X + dx[d], ny = cur.Y + dy[d];
                                            if (nx >= 0 && nx < w && ny >= 0 && ny < cutY && !seenDust[nx, ny] && cell.GetPixel(nx, ny).A > 0)
                                            {
                                                seenDust[nx, ny] = true;
                                                dq.Enqueue(new Point(nx, ny));
                                            }
                                        }
                                    }
                                    // Erase tiny neutral/shadow specks (< 16px) or ground shadow crumbs near bottom (< 120px & neutral/taupe)
                                    bool isBottomShadowDust = (islMaxY >= cutY - 65 && isl.Count <= 120 && maxChroma <= 45);
                                    if (isl.Count <= 12 || (isl.Count <= 30 && maxChroma <= 28) || isBottomShadowDust)
                                    {
                                        foreach (var pt in isl)
                                            cell.SetPixel(pt.X, pt.Y, Color.Transparent);
                                    }
                                }
                            }
                        }

                        // 7. Two-pass outer edge anti-aliasing & white/cream fringe decontamination for crisp Dark + Light mode edges
                        for (int pass = 0; pass < 2; pass++)
                        {
                            bool[,] isBorder = new bool[w, h];
                            for (int y = 1; y < cutY - 1; y++)
                            {
                                for (int x = 1; x < w - 1; x++)
                                {
                                    if (cell.GetPixel(x, y).A > 0)
                                    {
                                        if (cell.GetPixel(x - 1, y).A == 0 || cell.GetPixel(x + 1, y).A == 0 ||
                                            cell.GetPixel(x, y - 1).A == 0 || cell.GetPixel(x, y + 1).A == 0)
                                        {
                                            isBorder[x, y] = true;
                                        }
                                    }
                                }
                            }
                            for (int y = 1; y < cutY - 1; y++)
                            {
                                for (int x = 1; x < w - 1; x++)
                                {
                                    if (!isBorder[x, y]) continue;
                                    Color p = cell.GetPixel(x, y);
                                    if (p.A < 240) continue;
                                    int maxC = Math.Max(p.R, Math.Max(p.G, p.B));
                                    int minC = Math.Min(p.R, Math.Min(p.G, p.B));
                                    int chroma = maxC - minC;
                                    double lum = (p.R + p.G + p.B) / 3.0;
                                    if ((chroma <= 32 && lum >= 105) || (chroma <= 24 && lum >= 75))
                                    {
                                        int darkMin = 255;
                                        Color darkN = p;
                                        int maxSatChroma = 0;
                                        for (int oy = -1; oy <= 1; oy++)
                                            for (int ox = -1; ox <= 1; ox++)
                                            {
                                                Color np = cell.GetPixel(x + ox, y + oy);
                                                if (np.A >= 200 && !isBorder[x + ox, y + oy])
                                                {
                                                    int nl = (np.R + np.G + np.B) / 3;
                                                    int nc = Math.Max(np.R, Math.Max(np.G, np.B)) - Math.Min(np.R, Math.Min(np.G, np.B));
                                                    if (nc > maxSatChroma) maxSatChroma = nc;
                                                    if (nl < darkMin) { darkMin = nl; darkN = np; }
                                                }
                                            }
                                        // Un-blend neutral sticker/cream rim if touching dark ink (up to 135 for lum>=105, <65 for 75..104)
                                        int darkLimit = lum >= 105 ? 135 : 65;
                                        if (darkMin < darkLimit)
                                        {
                                            double bgEst = spec.IsDieCutSticker ? 248.0 : (bg.R + bg.G + bg.B) / 3.0;
                                            double denom = Math.Max(15.0, bgEst - darkMin);
                                            double cov = Math.Max(0.0, Math.Min(1.0, (bgEst - lum) / denom));
                                            int newA = (int)(cov * p.A);
                                            if (newA < 36)
                                                cell.SetPixel(x, y, Color.Transparent);
                                            else
                                                cell.SetPixel(x, y, Color.FromArgb(newA, darkN.R, darkN.G, darkN.B));
                                        }
                                        else if (lum >= 195 && chroma <= 26 && maxSatChroma > 32)
                                        {
                                            // Neutral bright cream speck sitting directly outside saturated glow/ribbon -> clear smoothly
                                            cell.SetPixel(x, y, Color.Transparent);
                                        }
                                    }
                                }
                            }
                        }

                        // 8. Tight Bounding-Box Crop with 6px transparent padding (matching original 84 sprites!)
                        int minX = w, maxX = 0, minY = cutY, maxY = 0;
                        bool hasPixels = false;
                        for (int y = 0; y < cutY; y++)
                        {
                            for (int x = 0; x < w; x++)
                            {
                                if (cell.GetPixel(x, y).A > 15)
                                {
                                    hasPixels = true;
                                    if (x < minX) minX = x;
                                    if (x > maxX) maxX = x;
                                    if (y < minY) minY = y;
                                    if (y > maxY) maxY = y;
                                }
                            }
                        }

                        string outPath = Path.Combine(outDir, pose + ".png");
                        if (hasPixels && maxX > minX && maxY > minY)
                        {
                            int pad = 6;
                            int cropX = Math.Max(0, minX - pad);
                            int cropY = Math.Max(0, minY - pad);
                            int cropW = Math.Min(w - cropX, (maxX - minX + 1) + pad * 2);
                            int cropH = Math.Min(h - cropY, (maxY - minY + 1) + pad * 2);

                            using (var cropped = new Bitmap(cropW, cropH, PixelFormat.Format32bppArgb))
                            {
                                using (var cg = Graphics.FromImage(cropped))
                                    cg.DrawImage(cell, new Rectangle(0, 0, cropW, cropH), new Rectangle(cropX, cropY, cropW, cropH), GraphicsUnit.Pixel);
                                cropped.Save(outPath, ImageFormat.Png);
                                Console.WriteLine("  -> " + pose + ".png (" + cropW + "x" + cropH + ", cutY=" + cutY + ")");
                            }
                        }
                    }
                }
            }
        }
        Console.WriteLine("All 24 Sheet-3 poses surgically cleaned!");
    }
}
