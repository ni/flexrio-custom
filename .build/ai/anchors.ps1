$root = "c:/dev/github15-test/flexrio-custom/targets"
$pats = 'use work\.PkgNiSharedFifo|use work\.PkgUserHdl|use work\.PkgCommIntConfiguration|MergeDmaFifoConf|GetForceChannelEnable|kDmaFifoConfArrayGeneric|kForceChannelEnable|bRegPortOutUserHdl|bRegPortOutCommonRegs|bRegPortOutSharedRegs|NiSharedCommonHostRegs|NiSharedHostRegisterArray|SharedHostRegisterLoopback|UserHdl_inst|dInputStreamInterfaceToFifo|dWinInputStreamInterface|FlattenStreamInterface|UnflattenStreamInterface|dInputStreamInterfaceToFifoFlat|HostInterfacex|StreamInterfaceRouting|bSharedHostReg'
foreach ($t in @("pxie-7912custom","pxie-7985custom")) {
  $f = "$root/$t/rtl-lvfpga/MacallanTop.vhd"
  Write-Host ""
  Write-Host "##### $t #####"
  Select-String -Path $f -Pattern $pats | ForEach-Object { "{0,5}: {1}" -f $_.LineNumber, $_.Line.Trim() }
}
