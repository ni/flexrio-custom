$root = "c:/dev/github15-test/flexrio-custom/targets"
$tops = [ordered]@{
  "pxie-7912custom" = "MacallanTop.vhd"
  "pxie-7981custom" = "MacallanTop.vhd"
  "pxie-7982custom" = "MacallanTop.vhd"
  "pxie-7985custom" = "MacallanTop.vhd"
  "pxie-7903custom" = "SasquatchTopTemplate.vhd"
  "pxie-7986custom" = "AppletonTopTemplate.vhd"
  "pxie-7994custom" = "BTracePlusTopTemplate.vhd"
}
# distinctive board-IO base names to probe
$probes = @(
  'aLvAuxDio','bdDoneaLvAuxDio','bdRequestaLvAuxDio','bdDirectionaLvAuxDio',
  'aAuxIoData','MacallanIoBuffers',
  'DioMgt','MgtPort','MgtRefClk','xClipAxi4Lite','xDiagramAxiStream','xHostAxiStream',
  'aConfigTx','aConfigRx','aRsrvGpio','aReservedToClip','aJesd204','dvTdcAssert','DeviceClk',
  'aDio','aLmk','aIPass','aPortExp',
  'aBaseDio','aBaseI2c','aSeGpio','aDiffGpio','Qsfp','SampleClk'
)
foreach ($t in $tops.Keys) {
  $f = "$root/$t/rtl-lvfpga/$($tops[$t])"
  Write-Host ""
  Write-Host "##### $t : $($tops[$t]) #####"
  foreach ($p in $probes) {
    $n = (Select-String -Path $f -Pattern ([regex]::Escape($p)) -AllMatches | Measure-Object).Count
    if ($n -gt 0) { "  {0,-22} {1}" -f $p, $n }
  }
}
