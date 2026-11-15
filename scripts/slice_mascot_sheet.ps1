param(
    [Parameter(Mandatory=$true)]
    [string]$SheetPath,

    [Parameter(Mandatory=$true)]
    [string]$OutputDir,

    [Parameter(Mandatory=$true)]
    [string[]]$PoseNames,

    [int]$Tolerance = 30
)

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $SheetPath)) {
    Write-Error "Sheet not found: $SheetPath"
    exit 1
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

$sheet = [System.Drawing.Bitmap]::FromFile($SheetPath)
$sheetW = $sheet.Width
$sheetH = $sheet.Height

# 2 rows, 3 columns = 6 cells
$cellW = [int]($sheetW / 3)
$cellH = [int]($sheetH / 2)

Write-Host "Processing $SheetPath ($sheetW x $sheetH), cell size: $cellW x $cellH"

function Get-ColorDistance([System.Drawing.Color]$c1, [System.Drawing.Color]$c2) {
    $dr = [int]$c1.R - [int]$c2.R
    $dg = [int]$c1.G - [int]$c2.G
    $db = [int]$c1.B - [int]$c2.B
    return [Math]::Sqrt($dr*$dr + $dg*$dg + $db*$db)
}

for ($i = 0; $i -lt 6 -and $i -lt $PoseNames.Length; $i++) {
    $poseName = $PoseNames[$i]
    $row = [Math]::Floor($i / 3)
    $col = $i % 3

    $startX = $col * $cellW
    $startY = $row * $cellH

    # Extract cell
    $cellRect = New-Object System.Drawing.Rectangle($startX, $startY, $cellW, $cellH)
    $cellBmp = New-Object System.Drawing.Bitmap($cellW, $cellH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($cellBmp)
    $g.DrawImage($sheet, (New-Object System.Drawing.Rectangle(0, 0, $cellW, $cellH)), $cellRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()

    # Detect background color from the 4 corners
    $c1 = $cellBmp.GetPixel(2, 2)
    $c2 = $cellBmp.GetPixel($cellW - 3, 2)
    $c3 = $cellBmp.GetPixel(2, $cellH - 3)
    $c4 = $cellBmp.GetPixel($cellW - 3, $cellH - 3)
    $avgR = [int](($c1.R + $c2.R + $c3.R + $c4.R) / 4)
    $avgG = [int](($c1.G + $c2.G + $c3.G + $c4.G) / 4)
    $avgB = [int](($c1.B + $c2.B + $c3.B + $c4.B) / 4)
    $bgColor = [System.Drawing.Color]::FromArgb(255, $avgR, $avgG, $avgB)

    # BFS Flood-Fill from borders to make background transparent
    $visited = New-Object 'bool[,]' $cellW, $cellH
    $queue = New-Object System.Collections.Generic.Queue[System.Drawing.Point]

    # Enqueue borders
    for ($x = 0; $x -lt $cellW; $x++) {
        $queue.Enqueue((New-Object System.Drawing.Point($x, 0)))
        $queue.Enqueue((New-Object System.Drawing.Point($x, $cellH - 1)))
        $visited[$x, 0] = $true
        $visited[$x, $cellH - 1] = $true
    }
    for ($y = 0; $y -lt $cellH; $y++) {
        $queue.Enqueue((New-Object System.Drawing.Point(0, $y)))
        $queue.Enqueue((New-Object System.Drawing.Point($cellW - 1, $y)))
        $visited[0, $y] = $true
        $visited[$cellW - 1, $y] = $true
    }

    $transparent = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
    $dirs = @(
        [System.Drawing.Point]::new(1, 0),
        [System.Drawing.Point]::new(-1, 0),
        [System.Drawing.Point]::new(0, 1),
        [System.Drawing.Point]::new(0, -1)
    )

    while ($queue.Count -gt 0) {
        $pt = $queue.Dequeue()
        $px = $cellBmp.GetPixel($pt.X, $pt.Y)
        $dist = Get-ColorDistance $px $bgColor

        if ($dist -lt $Tolerance -or ($px.R -gt 240 -and $px.G -gt 240 -and $px.B -gt 240)) {
            $cellBmp.SetPixel($pt.X, $pt.Y, $transparent)

            foreach ($d in $dirs) {
                $nx = $pt.X + $d.X
                $ny = $pt.Y + $d.Y
                if ($nx -ge 0 -and $nx -lt $cellW -and $ny -ge 0 -and $ny -lt $cellH) {
                    if (-not $visited[$nx, $ny]) {
                        $visited[$nx, $ny] = $true
                        $queue.Enqueue((New-Object System.Drawing.Point($nx, $ny)))
                    }
                }
            }
        }
    }

    # Find bounding box of remaining non-transparent pixels
    $minX = $cellW; $maxX = 0; $minY = $cellH; $maxY = 0
    $hasPixels = $false

    # Check bottom 20% to skip any text label if present
    $labelCutoffY = [int]($cellH * 0.85)

    for ($y = 0; $y -lt $cellH; $y++) {
        for ($x = 0; $x -lt $cellW; $x++) {
            $p = $cellBmp.GetPixel($x, $y)
            if ($p.A -gt 30) {
                # If isolated text at very bottom, clear it
                if ($y -gt $labelCutoffY -and ($maxY -gt 0) -and ($y - $maxY -gt 15)) {
                    $cellBmp.SetPixel($x, $y, $transparent)
                    continue
                }
                $hasPixels = $true
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    if ($hasPixels -and $maxX -gt $minX -and $maxY -gt $minY) {
        $pad = 6
        $cropX = [Math]::Max(0, $minX - $pad)
        $cropY = [Math]::Max(0, $minY - $pad)
        $cropW = [Math]::Min($cellW - $cropX, ($maxX - $minX) + ($pad * 2))
        $cropH = [Math]::Min($cellH - $cropY, ($maxY - $minY) + ($pad * 2))

        $cropped = New-Object System.Drawing.Bitmap($cropW, $cropH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $cg = [System.Drawing.Graphics]::FromImage($cropped)
        $cg.DrawImage($cellBmp, (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)), (New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)), [System.Drawing.GraphicsUnit]::Pixel)
        $cg.Dispose()

        $outPath = Join-Path $OutputDir "$poseName.png"
        $cropped.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $cropped.Dispose()
        Write-Host "  -> Saved: $outPath ($cropW x $cropH)"
    } else {
        $outPath = Join-Path $OutputDir "$poseName.png"
        $cellBmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "  -> Saved full cell: $outPath"
    }

    $cellBmp.Dispose()
}

$sheet.Dispose()
Write-Host "Done slicing $SheetPath!"
