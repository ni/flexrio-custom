$root = "c:/dev/github15-test/flexrio-custom/targets"
$specs = [ordered]@{
  "pxie-7912custom" = 119
  "pxie-7981custom" = 113
  "pxie-7982custom" = 119
  "pxie-7985custom" = 119
  "pxie-7903custom" = 174
  "pxie-7986custom" = 118
  "pxie-7994custom" = 176
}
foreach ($t in $specs.Keys) {
  $m = "$root/$t/rtl-lvfpga/TheLvWindowFlatWrapper.vhd.mako"
  $lines = Get-Content $m
  $start = $specs[$t] - 1
  $end = $start
  for ($i = $start; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*%\s*endif') { $end = $i; break }
  }
  Write-Host ""
  Write-Host "##### $t  (entity board IO block lines $($start+1)..$($end+1)) #####"
  for ($i = $start; $i -le $end; $i++) {
    "{0,5}: {1}" -f ($i + 1), $lines[$i]
  }
}
