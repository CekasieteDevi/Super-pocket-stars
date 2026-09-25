Add-Type -AssemblyName System.Drawing

$sourceDir = Join-Path $PSScriptRoot '..\assets\partido\palomita_fuentes'
$targetDir = Join-Path $PSScriptRoot '..\assets\partido\palomita'
$legacyPath = Join-Path $PSScriptRoot '..\assets\partido\palomita_frames.png'
$styles = @('puntas', 'afro', 'rapado', 'atado', 'mohicano', 'rastas',
    'degrade', 'vincha', 'rodete', 'raya', 'trenzas', 'rulos_cortos',
    'rulos_largos', 'melena', 'mullet', 'flequillo', 'jopo', 'tupe', 'hongo',
    'coleta', 'cucurella', 'doble_cresta')
$generatedStyles = $styles[11..21]
$generatedDir = Join-Path $PSScriptRoot '..\assets\partido\generados'
$frames = 8
$cell = 64
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

function Convert-PalomitaSheet([string]$sourcePath, [string]$targetPath, [int[]]$targetHeights) {
    $src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $sourcePath))
    $out = [System.Drawing.Bitmap]::new($frames * $cell, $cell,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $crops = @()
    $usedRects = @()
    $maxWidth = 1
    $maxHeight = 1

    for ($i = 0; $i -lt $frames; $i++) {
        $x0 = [int][Math]::Floor($i * $src.Width / [double]$frames)
        $x1 = [int][Math]::Floor(($i + 1) * $src.Width / [double]$frames)
        $width = $x1 - $x0
        $crop = [System.Drawing.Bitmap]::new($width, $src.Height,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $cg = [System.Drawing.Graphics]::FromImage($crop)
        $cg.DrawImage($src, [System.Drawing.Rectangle]::new(0, 0, $width, $src.Height),
            $x0, 0, $width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel)
        $cg.Dispose()
        $used = [System.Drawing.Rectangle]::Empty
        for ($y = 0; $y -lt $crop.Height; $y++) {
            for ($x = 0; $x -lt $crop.Width; $x++) {
                if ($crop.GetPixel($x, $y).A -lt 96) { continue }
                $pixel = [System.Drawing.Rectangle]::new($x, $y, 1, 1)
                $used = if ($used.IsEmpty) { $pixel } else {
                    [System.Drawing.Rectangle]::Union($used, $pixel)
                }
            }
        }
        if ($used.IsEmpty) { throw "Cuadro vacio: $sourcePath / $i" }
        $crops += $crop
        $usedRects += $used
        $maxWidth = [Math]::Max($maxWidth, $used.Width)
        $maxHeight = [Math]::Max($maxHeight, $used.Height)
    }

    # Una escala comun por peinado: el cuerpo no crece entre fases.
    $scale = [Math]::Min(60.0 / $maxWidth, 54.0 / $maxHeight)
    for ($i = 0; $i -lt $frames; $i++) {
        $used = $usedRects[$i]
        $frameScale = if ($targetHeights.Count -eq $frames) {
            $targetHeights[$i] / [double]$used.Height
        } else { $scale }
        $width = [Math]::Min($cell - 2,
            [Math]::Max(1, [int][Math]::Round($used.Width * $frameScale)))
        $height = [Math]::Max(1, [int][Math]::Round($used.Height * $frameScale))
        $target = [System.Drawing.Rectangle]::new(
            $i * $cell + [int](($cell - $width) / 2), 60 - $height, $width, $height)
        $g.DrawImage($crops[$i], $target, $used.X, $used.Y, $used.Width, $used.Height,
            [System.Drawing.GraphicsUnit]::Pixel)
        $crops[$i].Dispose()
    }
    $g.Dispose()
    $src.Dispose()
    $out.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
}

$referenceHeights = @()
foreach ($style in $styles) {
    $sourcePath = if ($generatedStyles -contains $style) {
        Join-Path $generatedDir "${style}_palomita_ai.png"
    } else {
        Join-Path $sourceDir "$style.png"
    }
    $targetPath = Join-Path $targetDir "$style.png"
    Convert-PalomitaSheet $sourcePath $targetPath $referenceHeights
    if ($style -eq 'puntas') {
        $reference = [System.Drawing.Bitmap]::FromFile((Resolve-Path $targetPath).Path)
        for ($i = 0; $i -lt $frames; $i++) {
            $minY = $cell
            $maxY = -1
            for ($y = 0; $y -lt $cell; $y++) {
                for ($x = 0; $x -lt $cell; $x++) {
                    if ($reference.GetPixel($i * $cell + $x, $y).A -lt 96) { continue }
                    $minY = [Math]::Min($minY, $y)
                    $maxY = [Math]::Max($maxY, $y)
                }
            }
            $referenceHeights += $maxY - $minY + 1
        }
        $reference.Dispose()
    }
}
Copy-Item -LiteralPath (Join-Path $targetDir 'puntas.png') -Destination $legacyPath -Force
Write-Host "OK: $($styles.Count) peinados de palomita, 8 cuadros cada uno"
