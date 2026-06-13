$root = "c:/dev/github15-test/flexrio-custom/targets"
$pats = 'use work\.PkgDmaPortDmaFifos\.all|bRegPortOutCommonRegs: RegPortOut_t|bSharedHostRegFpgaHostWrite|bRegPortOutCommonRegs\.Data or|--vhook_g kDmaFifoConfArrayGeneric kDmaFifoConfArray|NiSharedCommonHostRegs_inst|kSignature|end process SharedHostRegisterLoopbackx|FlattenStreamInterface\(dInputStreamInterfaceToFifo\)|UnflattenStreamInterface\(dInputStreamInterfaceFromFifoFlat\)|Host writes to lower registers'
foreach ($t in $args) {
  $f = "$root/$t/rtl-lvfpga/MacallanTop.vhd"
  Write-Host ""
  Write-Host "##### $t #####"
  Select-String -Path $f -Pattern $pats | ForEach-Object { "{0,5}: {1}" -f $_.LineNumber, $_.Line.Trim() }
}
