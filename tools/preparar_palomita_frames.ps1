Add-Type -AssemblyName System.Drawing
$rawPath = Join-Path $PSScriptRoot '..\assets\partido\acciones_palomita_raw.png'
$srcPath = if (Test-Path $rawPath) { $rawPath } else { Join-Path $PSScriptRoot '..\assets\partido\acciones_palomita.png' }
$dstPath = Join-Path $PSScriptRoot '..\assets\partido\palomita_frames.png'
$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $srcPath))
$cellH = if ($src.Width -gt 1000) { $src.Height } else { [int]($src.Height / 10) }
$out = [System.Drawing.Bitmap]::new(256,64,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($out); $g.Clear([System.Drawing.Color]::Transparent)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$occupied = New-Object bool[] $src.Width
for ($x=0; $x -lt $src.Width; $x++) {
    for ($y=0; $y -lt $cellH; $y++) { if ($src.GetPixel($x,$y).A -ge 32) { $occupied[$x]=$true; break } }
}
$runs=@(); $start=-1; $last=-1; $maxGap=50
for ($x=0; $x -lt $src.Width; $x++) {
    if ($occupied[$x]) {
        if ($start -lt 0) { $start=$x }
        elseif ($x-$last -gt $maxGap) { $runs += [System.Drawing.Rectangle]::new($start,0,$last-$start+1,$cellH); $start=$x }
        $last=$x
    }
}
if ($start -ge 0) { $runs += [System.Drawing.Rectangle]::new($start,0,$last-$start+1,$cellH) }
if ($runs.Count -ne 4) { throw "Se esperaban 4 poses, se detectaron $($runs.Count)" }
$crops=@(); $usados=@(); $maxW=1; $maxH=1
for ($i=0; $i -lt 4; $i++) {
    $run=$runs[$i]
    $crop = [System.Drawing.Bitmap]::new($run.Width,$run.Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $cg = [System.Drawing.Graphics]::FromImage($crop)
    $cg.DrawImage($src,[System.Drawing.Rectangle]::new(0,0,$run.Width,$run.Height),$run,[System.Drawing.GraphicsUnit]::Pixel); $cg.Dispose()
    $used=[System.Drawing.Rectangle]::Empty
    for($y=0;$y -lt $run.Height;$y++){for($x=0;$x -lt $run.Width;$x++){if($crop.GetPixel($x,$y).A -ge 32){$r=[System.Drawing.Rectangle]::new($x,$y,1,1);$used=if($used.IsEmpty){$r}else{[System.Drawing.Rectangle]::Union($used,$r)}}}}
    $crops += $crop; $usados += $used
    $maxW=[Math]::Max($maxW,$used.Width); $maxH=[Math]::Max($maxH,$used.Height)
}
# Una sola escala para las cuatro poses: evita que el jugador crezca o
# encoja al cambiar de cuadro. La pose horizontal entra completa en 64 px.
$escala=[Math]::Min(60.0/$maxW,46.0/$maxH)
for ($i=0; $i -lt 4; $i++) {
    $crop=$crops[$i]; $used=$usados[$i]
    $w=[Math]::Max(1,[int]([Math]::Round($used.Width*$escala)))
    $h=[Math]::Max(1,[int]([Math]::Round($used.Height*$escala)))
    $g.DrawImage($crop,[System.Drawing.Rectangle]::new($i*64+[int]((64-$w)/2),58-$h,$w,$h),$used.X,$used.Y,$used.Width,$used.Height,[System.Drawing.GraphicsUnit]::Pixel)
    $crop.Dispose()
}
$g.Dispose();$src.Dispose();$out.Save($dstPath,[System.Drawing.Imaging.ImageFormat]::Png);$out.Dispose();Write-Host 'OK: palomita_frames.png'
