param(
    [string]$SheetPath,
    [string]$OutputDir,
    [string[]]$PoseNames,
    [int]$Tolerance = 36
)

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $SheetPath)) {
    Write-Error "Sheet not found: $SheetPath"
    exit 1
}

if (-not (Test-Path $OutputDir)) {
    [void](New-Item -ItemType Directory -Force -Path $OutputDir)
}

$sheet = [System.Drawing.Bitmap]::FromFile($SheetPath)
$w = [int]$sheet.Width
$h = [int]$sheet.Height
$cw = [int]($w / 3)
$ch = [int]($h / 2)

Write-Host "Slicing $SheetPath ($w x $h), cells: $cw x $ch"

$transparent = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)

for ($i = 0; $i -lt 6 -and $i -lt $PoseNames.Length; $i++) {
    $pose = $PoseNames[$i]
    $row = [Math]::Floor($i / 3)
    $col = $i % 3

    $startX = $col * $cw
    $startY = $row * $ch

    $cell = New-Object System.Drawing.Bitmap $cw, $ch, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($cell)
    $src = New-Object System.Drawing.Rectangle $startX, $startY, $cw, $ch
    $dst = New-Object System.Drawing.Rectangle 0, 0, $cw, $ch
    [void]$g.DrawImage($sheet, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()

    # Corner background color
    $c1 = $cell.GetPixel(4, 4)
    $c2 = $cell.GetPixel($cw - 5, 4)
    $c3 = $cell.GetPixel(4, $ch - 5)
    $c4 = $cell.GetPixel($cw - 5, $ch - 5)
    $bgR = [int](($c1.R + $c2.R + $c3.R + $c4.R) / 4)
    $bgG = [int](($c1.G + $c2.G + $c3.G + $c4.G) / 4)
    $bgB = [int](($c1.B + $c2.B + $c3.B + $c4.B) / 4)

    # Fast Flood Fill from borders
    $visited = New-Object 'bool[,]' $cw, $ch
    $queue = New-Object System.Collections.Generic.Queue[System.Drawing.Point]

    for ($x = 0; $x -lt $cw; $x++) {
        [void]$queue.Enqueue((New-Object System.Drawing.Point($x, 0)))
        $visited[$x, 0] = $true
        [void]$queue.Enqueue((New-Object System.Drawing.Point($x, ($ch - 1))))
        $visited[$x, ($ch - 1)] = $true
    }
    for ($y = 0; $y -lt $ch; $y++) {
        [void]$queue.Enqueue((New-Object System.Drawing.Point(0, $y)))
        $visited[0, $y] = $true
        [void]$queue.Enqueue((New-Object System.Drawing.Point(($cw - 1), $y)))
        $visited[($cw - 1), $y] = $true
    }

    $dx = @(1, -1, 0, 0)
    $dy = @(0, 0, 1, -1)

    while ($queue.Count -gt 0) {
        $pt = $queue.Dequeue()
        $px = $cell.GetPixel($pt.X, $pt.Y)

        $dr = [int]$px.R - $bgR
        $dg = [int]$px.G - $bgG
        $db = [int]$px.B - $bgB
        $dist = [Math]::Sqrt($dr*$dr + $dg*$dg + $db*$db)

        if ($dist -lt $Tolerance -or ($px.R -gt 238 -and $px.G -gt 238 -and $px.B -gt 238)) {
            $cell.SetPixel($pt.X, $pt.Y, $transparent)

            for ($d = 0; $d -lt 4; $d++) {
                $nx = $pt.X + $dx[$d]
                $ny = $pt.Y + $dy[$d]
                if ($nx -ge 0 -and $nx -lt $cw -and $ny -ge 0 -and $ny -lt $ch) {
                    if (-not $visited[$nx, $ny]) {
                        $visited[$nx, $ny] = $true
                        [void]$queue.Enqueue((New-Object System.Drawing.Point($nx, $ny)))
                    }
                }
            }
        }
    }

    # Bounding box calculation
    $minX = $cw; $maxX = 0; $minY = $ch; $maxY = 0
    $hasPixels = $false
    $bottomCutoff = [int]($ch * 0.88)

    for ($y = 0; $y -lt $ch; $y++) {
        for ($x = 0; $x -lt $cw; $x++) {
            $p = $cell.GetPixel($x, $y)
            if ($p.A -gt 30) {
                # Clear text label at bottom if separated
                if ($y -gt $bottomCutoff -and $maxY -gt 0 -and ($y - $maxY -gt 12)) {
                    $cell.SetPixel($x, $y, $transparent)
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

    $outPath = Join-Path $OutputDir "$pose.png"

    if ($hasPixels -and $maxX -gt $minX -and $maxY -gt $minY) {
        $pad = 6
        $cropX = [Math]::Max(0, $minX - $pad)
        $cropY = [Math]::Max(0, $minY - $pad)
        $cropW = [Math]::Min($cw - $cropX, ($maxX - $minX) + ($pad * 2))
        $cropH = [Math]::Min($ch - $cropY, ($maxY - $minY) + ($pad * 2))

        $cropped = New-Object System.Drawing.Bitmap $cropW, $cropH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $cg = [System.Drawing.Graphics]::FromImage($cropped)
        $cSrc = New-Object System.Drawing.Rectangle $cropX, $cropY, $cropW, $cropH
        $cDst = New-Object System.Drawing.Rectangle 0, 0, $cropW, $cropH
        [void]$cg.DrawImage($cell, $cDst, $cSrc, [System.Drawing.GraphicsUnit]::Pixel)
        $cg.Dispose()

        $cropped.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $cropped.Dispose()
        Write-Host "  -> Sliced: $outPath ($cropW x $cropH)"
    } else {
        $cell.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "  -> Saved: $outPath"
    }

    $cell.Dispose()
}

$sheet.Dispose()
Write-Host "Done $SheetPath"
