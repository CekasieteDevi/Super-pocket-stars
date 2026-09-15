Add-Type -AssemblyName System.Drawing

$srcPath = Join-Path $PSScriptRoot '..\assets\partido\acciones_palomita.png'
$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $srcPath))
$cellWidth = [int]($src.Width / 4)
$cellHeight = [int]($src.Height / 10)
$prepared = Join-Path $PSScriptRoot '..\assets\partido\preparados'

Get-ChildItem $prepared -Filter '*.png' | ForEach-Object {
    $old = [System.Drawing.Bitmap]::FromFile($_.FullName)
    $out = [System.Drawing.Bitmap]::new(512,640,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.DrawImage($old, 0, 0, 512, 640)
    for ($i = 0; $i -lt 4; $i++) {
        $bounds = [System.Drawing.Rectangle]::new(($i * $cellWidth),0,$cellWidth,$cellHeight)
        $crop = [System.Drawing.Bitmap]::new($cellWidth,$cellHeight,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $cg = [System.Drawing.Graphics]::FromImage($crop)
        $cg.DrawImage($src, 0, 0, $bounds, [System.Drawing.GraphicsUnit]::Pixel)
        $cg.Dispose()
        $used = [System.Drawing.Rectangle]::Empty
        for ($y=0; $y -lt $crop.Height; $y++) { for ($x=0; $x -lt $crop.Width; $x++) {
            if ($crop.GetPixel($x,$y).A -ge 32) {
                if ($used.IsEmpty) { $used = [System.Drawing.Rectangle]::new($x,$y,1,1) }
                else { $used = [System.Drawing.Rectangle]::Union($used,[System.Drawing.Rectangle]::new($x,$y,1,1)) }
            }
        }}
        $targetH = 58
        $targetW = [Math]::Max(1,[int]([double]$used.Width * $targetH / [double]$used.Height))
        $target = [System.Drawing.Rectangle]::new(((4 + $i) * 64) + [int]((64-$targetW)/2), (576 + (58-$targetH)), $targetW, $targetH)
        $g.DrawImage($crop, $target, $used.X, $used.Y, $used.Width, $used.Height, [System.Drawing.GraphicsUnit]::Pixel)
        $crop.Dispose()
    }
    $g.Dispose(); $old.Dispose()
    $out.Save($_.FullName, [System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
}
$src.Dispose()
Write-Host 'OK: palomita agregada a los atlas preparados'
