Add-Type -AssemblyName System.Drawing
$path = Join-Path $PSScriptRoot '..\assets\partido\acciones_palomita.png'
$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $path))
if ($src.Width -eq 756 -and $src.Height -eq 2080) {
    $src.Dispose()
    Write-Host 'OK: hoja ya normalizada'
    exit 0
}
$out = [System.Drawing.Bitmap]::new(756,2080,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($out)
$g.Clear([System.Drawing.Color]::Transparent)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$cellW = [int]($src.Width / 4)
$sourceFrames = @(1,1,2,1)
for ($i=0; $i -lt 4; $i++) {
    # Los extremos del render AI tocaron el borde. Usamos solo los dos
    # cuadros centrales completos y los reencuadramos en la grilla.
    $sourceIndex = $sourceFrames[$i]
    $bounds = [System.Drawing.Rectangle]::new(($sourceIndex*$cellW),0,$cellW,$src.Height)
    $crop = [System.Drawing.Bitmap]::new($cellW,$src.Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $cg = [System.Drawing.Graphics]::FromImage($crop)
    $cg.DrawImage($src, [System.Drawing.Rectangle]::new(0,0,$cellW,$src.Height), $bounds, [System.Drawing.GraphicsUnit]::Pixel)
    $cg.Dispose()
    $used = [System.Drawing.Rectangle]::Empty
    for ($y=0; $y -lt $crop.Height; $y++) { for ($x=0; $x -lt $crop.Width; $x++) {
        if ($crop.GetPixel($x,$y).A -ge 32) {
            $one = [System.Drawing.Rectangle]::new($x,$y,1,1)
            $used = if ($used.IsEmpty) { $one } else { [System.Drawing.Rectangle]::Union($used,$one) }
        }
    }}
    $targetH = 190
    $targetW = [Math]::Max(1,[int]($used.Width*$targetH/$used.Height))
    $x0 = $i*189 + [int]((189-$targetW)/2)
    $y0 = 198-$targetH
    $target = [System.Drawing.Rectangle]::new($x0,$y0,$targetW,$targetH)
    for ($fila=0; $fila -lt 10; $fila++) {
        $dest = [System.Drawing.Rectangle]::new($target.X,$target.Y+$fila*208,$target.Width,$target.Height)
        $g.DrawImage($crop,$dest,$used.X,$used.Y,$used.Width,$used.Height,[System.Drawing.GraphicsUnit]::Pixel)
    }
    $crop.Dispose()
}
$g.Dispose(); $src.Dispose()
$out.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
$out.Dispose()
Write-Host 'OK: hoja palomita normalizada a 4x10'
