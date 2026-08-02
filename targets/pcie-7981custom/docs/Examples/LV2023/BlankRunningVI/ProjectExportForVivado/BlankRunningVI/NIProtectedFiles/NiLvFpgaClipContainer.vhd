
 library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

entity NiLvFpgaClipContainer is
 port(
    Dram0ClkSocket : in std_logic;
    du0DramAddrFifoAddr : out std_logic_vector(28 downto 0);
    du0DramAddrFifoCmd : out std_logic_vector(2 downto 0);
    du0DramAddrFifoFull : in std_logic;
    du0DramAddrFifoWrEn : out std_logic;
    du0DramPhyInitDone : in std_logic;
    du0DramRdDataValid : in std_logic;
    du0DramRdFifoDataOut : in std_logic_vector(255 downto 0);
    du0DramWrFifoDataIn : out std_logic_vector(255 downto 0);
    du0DramWrFifoFull : in std_logic;
    du0DramWrFifoMaskData : out std_logic_vector(31 downto 0);
    du0DramWrFifoWrEn : out std_logic;
    Dram1ClkSocket : in std_logic;
    du1DramAddrFifoAddr : out std_logic_vector(28 downto 0);
    du1DramAddrFifoCmd : out std_logic_vector(2 downto 0);
    du1DramAddrFifoFull : in std_logic;
    du1DramAddrFifoWrEn : out std_logic;
    du1DramPhyInitDone : in std_logic;
    du1DramRdDataValid : in std_logic;
    du1DramRdFifoDataOut : in std_logic_vector(255 downto 0);
    du1DramWrFifoDataIn : out std_logic_vector(255 downto 0);
    du1DramWrFifoFull : in std_logic;
    du1DramWrFifoMaskData : out std_logic_vector(31 downto 0);
    du1DramWrFifoWrEn : out std_logic;
    abBusResetTrigger : in std_logic;
    aIntClk10Trigger : in std_logic;
    aPxiStarData : in std_logic;
    aPxiTrigDataIn : in std_logic_vector(7 downto 0);
    aPxiTrigDataOut : out std_logic_vector(7 downto 0);
    aPxiTrigDataTri : out std_logic_vector(7 downto 0);
    bRoutingClipNiCompatible : out std_logic;
    bRoutingClipPresent : out std_logic;
    bTriggerRoutingBaRegPortInAddress : in std_logic_vector(27 downto 0);
    bTriggerRoutingBaRegPortInData : in std_logic_vector(63 downto 0);
    bTriggerRoutingBaRegPortInRdStrobe : in std_logic_vector(7 downto 0);
    bTriggerRoutingBaRegPortInWtStrobe : in std_logic_vector(7 downto 0);
    bTriggerRoutingBaRegPortOutAck : out std_logic;
    bTriggerRoutingBaRegPortOutData : out std_logic_vector(63 downto 0);
    BusClkTrigger : in std_logic;
    dDevClkEn : in std_logic;
    dTdcAssert : out std_logic;
    pIntSync100Trigger : in std_logic;
    PxieClk100Trigger : in std_logic;
    sTdcDeassert : out std_logic;

Routing_DataClk : in std_logic;
Routing_SyncPulseClk : in std_logic;
Routing_aSource0 : in std_logic_vector(0 downto 0);
Routing_aSource1 : in std_logic_vector(0 downto 0);
Routing_aSource2 : in std_logic_vector(0 downto 0);
Routing_aSource3 : in std_logic_vector(0 downto 0);
Routing_aSource4 : in std_logic_vector(0 downto 0);
Routing_aSource5 : in std_logic_vector(0 downto 0);
Routing_aSource6 : in std_logic_vector(0 downto 0);
Routing_aSource7 : in std_logic_vector(0 downto 0);
Routing_aSource8 : in std_logic_vector(0 downto 0);
Routing_aSource9 : in std_logic_vector(0 downto 0);
Routing_aSource10 : in std_logic_vector(0 downto 0);
Routing_aSource11 : in std_logic_vector(0 downto 0);
Routing_aSource12 : in std_logic_vector(0 downto 0);
Routing_aSource13 : in std_logic_vector(0 downto 0);
Routing_aSource14 : in std_logic_vector(0 downto 0);
Routing_aSource15 : in std_logic_vector(0 downto 0);
Routing_aSource16 : in std_logic_vector(0 downto 0);
Routing_aSource17 : in std_logic_vector(0 downto 0);
Routing_aSource18 : in std_logic_vector(0 downto 0);
Routing_aSource19 : in std_logic_vector(0 downto 0);
Routing_aSource20 : in std_logic_vector(0 downto 0);
Routing_aSource21 : in std_logic_vector(0 downto 0);
Routing_aSource22 : in std_logic_vector(0 downto 0);
Routing_aSource23 : in std_logic_vector(0 downto 0);
Routing_aSource24 : in std_logic_vector(0 downto 0);
Routing_aSource25 : in std_logic_vector(0 downto 0);
Routing_aSource26 : in std_logic_vector(0 downto 0);
Routing_aSource27 : in std_logic_vector(0 downto 0);
Routing_aSource28 : in std_logic_vector(0 downto 0);
Routing_aSource29 : in std_logic_vector(0 downto 0);
Routing_aSource30 : in std_logic_vector(0 downto 0);
Routing_aSource31 : in std_logic_vector(0 downto 0);
Routing_TClk : out std_logic_vector(0 downto 0);
Routing_aDestinationSyncPulse : out std_logic_vector(0 downto 0);
Routing_aDestination0 : out std_logic_vector(0 downto 0);
Routing_aDestination1 : out std_logic_vector(0 downto 0);
Routing_aDestination2 : out std_logic_vector(0 downto 0);
Routing_aDestination3 : out std_logic_vector(0 downto 0);
Routing_aDestination4 : out std_logic_vector(0 downto 0);
Routing_aDestination5 : out std_logic_vector(0 downto 0);
Routing_aDestination6 : out std_logic_vector(0 downto 0);
Routing_aDestination7 : out std_logic_vector(0 downto 0);
Routing_aDestination8 : out std_logic_vector(0 downto 0);
Routing_aDestination9 : out std_logic_vector(0 downto 0);
Routing_aDestination10 : out std_logic_vector(0 downto 0);
Routing_aDestination11 : out std_logic_vector(0 downto 0);
Routing_aDestination12 : out std_logic_vector(0 downto 0);
Routing_aDestination13 : out std_logic_vector(0 downto 0);
Routing_aDestination14 : out std_logic_vector(0 downto 0);
Routing_aDestination15 : out std_logic_vector(0 downto 0);
Routing_aDestination16 : out std_logic_vector(0 downto 0);
Routing_aDestination17 : out std_logic_vector(0 downto 0);
Routing_aDestination18 : out std_logic_vector(0 downto 0);
Routing_aDestination19 : out std_logic_vector(0 downto 0);
Routing_aDestination20 : out std_logic_vector(0 downto 0);
Routing_aDestination21 : out std_logic_vector(0 downto 0);
Routing_aDestination22 : out std_logic_vector(0 downto 0);
Routing_aDestination23 : out std_logic_vector(0 downto 0);
Routing_aDestination24 : out std_logic_vector(0 downto 0);
Routing_aDestination25 : out std_logic_vector(0 downto 0);
Routing_aDestination26 : out std_logic_vector(0 downto 0);
Routing_aDestination27 : out std_logic_vector(0 downto 0);
Routing_aDestination28 : out std_logic_vector(0 downto 0);
Routing_aDestination29 : out std_logic_vector(0 downto 0);
Routing_aDestination30 : out std_logic_vector(0 downto 0);
Routing_aDestination31 : out std_logic_vector(0 downto 0);
Routing_aDiagramIdentity : in std_logic_vector(31 downto 0);
Routing_aClipIdentity : out std_logic_vector(7 downto 0);

aClockGate: in std_logic;
aReset : in std_logic
);
end NiLvFpgaClipContainer;

architecture ClipContainer_VHDL of NiLvFpgaClipContainer is





begin



Routing_CLIP0 : entity work.Wrapper(RTL) 
port map (
DataClk => Routing_DataClk,
SyncPulseClk => Routing_SyncPulseClk,
aSource0 => Routing_aSource0(0),
aSource1 => Routing_aSource1(0),
aSource2 => Routing_aSource2(0),
aSource3 => Routing_aSource3(0),
aSource4 => Routing_aSource4(0),
aSource5 => Routing_aSource5(0),
aSource6 => Routing_aSource6(0),
aSource7 => Routing_aSource7(0),
aSource8 => Routing_aSource8(0),
aSource9 => Routing_aSource9(0),
aSource10 => Routing_aSource10(0),
aSource11 => Routing_aSource11(0),
aSource12 => Routing_aSource12(0),
aSource13 => Routing_aSource13(0),
aSource14 => Routing_aSource14(0),
aSource15 => Routing_aSource15(0),
aSource16 => Routing_aSource16(0),
aSource17 => Routing_aSource17(0),
aSource18 => Routing_aSource18(0),
aSource19 => Routing_aSource19(0),
aSource20 => Routing_aSource20(0),
aSource21 => Routing_aSource21(0),
aSource22 => Routing_aSource22(0),
aSource23 => Routing_aSource23(0),
aSource24 => Routing_aSource24(0),
aSource25 => Routing_aSource25(0),
aSource26 => Routing_aSource26(0),
aSource27 => Routing_aSource27(0),
aSource28 => Routing_aSource28(0),
aSource29 => Routing_aSource29(0),
aSource30 => Routing_aSource30(0),
aSource31 => Routing_aSource31(0),
TClk => Routing_TClk(0),
aDestinationSyncPulse => Routing_aDestinationSyncPulse(0),
aDestination0 => Routing_aDestination0(0),
aDestination1 => Routing_aDestination1(0),
aDestination2 => Routing_aDestination2(0),
aDestination3 => Routing_aDestination3(0),
aDestination4 => Routing_aDestination4(0),
aDestination5 => Routing_aDestination5(0),
aDestination6 => Routing_aDestination6(0),
aDestination7 => Routing_aDestination7(0),
aDestination8 => Routing_aDestination8(0),
aDestination9 => Routing_aDestination9(0),
aDestination10 => Routing_aDestination10(0),
aDestination11 => Routing_aDestination11(0),
aDestination12 => Routing_aDestination12(0),
aDestination13 => Routing_aDestination13(0),
aDestination14 => Routing_aDestination14(0),
aDestination15 => Routing_aDestination15(0),
aDestination16 => Routing_aDestination16(0),
aDestination17 => Routing_aDestination17(0),
aDestination18 => Routing_aDestination18(0),
aDestination19 => Routing_aDestination19(0),
aDestination20 => Routing_aDestination20(0),
aDestination21 => Routing_aDestination21(0),
aDestination22 => Routing_aDestination22(0),
aDestination23 => Routing_aDestination23(0),
aDestination24 => Routing_aDestination24(0),
aDestination25 => Routing_aDestination25(0),
aDestination26 => Routing_aDestination26(0),
aDestination27 => Routing_aDestination27(0),
aDestination28 => Routing_aDestination28(0),
aDestination29 => Routing_aDestination29(0),
aDestination30 => Routing_aDestination30(0),
aDestination31 => Routing_aDestination31(0),
aDiagramIdentity => Routing_aDiagramIdentity,
aClipIdentity => Routing_aClipIdentity,
BusClkTrigger => BusClkTrigger,
abBusResetTrigger => abBusResetTrigger,
bTriggerRoutingBaRegPortInAddress => bTriggerRoutingBaRegPortInAddress,
bTriggerRoutingBaRegPortInData => bTriggerRoutingBaRegPortInData,
bTriggerRoutingBaRegPortInRdStrobe => bTriggerRoutingBaRegPortInRdStrobe,
bTriggerRoutingBaRegPortInWtStrobe => bTriggerRoutingBaRegPortInWtStrobe,
bTriggerRoutingBaRegPortOutData => bTriggerRoutingBaRegPortOutData,
bTriggerRoutingBaRegPortOutAck => bTriggerRoutingBaRegPortOutAck,
aPxiTrigDataIn => aPxiTrigDataIn,
aPxiTrigDataOut => aPxiTrigDataOut,
aPxiTrigDataTri => aPxiTrigDataTri,
aPxiStarData => aPxiStarData,
PxieClk100Trigger => PxieClk100Trigger,
pIntSync100Trigger => pIntSync100Trigger,
aIntClk10Trigger => aIntClk10Trigger,
dTdcAssert => dTdcAssert,
dDevClkEn => dDevClkEn,
sTdcDeassert => sTdcDeassert,
bRoutingClipPresent => bRoutingClipPresent,
bRoutingClipNiCompatible => bRoutingClipNiCompatible,
aReset => aReset
);



end ClipContainer_VHDL;
