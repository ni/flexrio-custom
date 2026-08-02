-- © 2012 National Instruments Corporation.
library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

entity Wrapper is

  port (
    BusClkTrigger                      : in    std_logic;
    abBusResetTrigger                  : in    std_logic;
    bTriggerRoutingBaRegPortInAddress  : in    std_logic_vector(27 downto 0);
    bTriggerRoutingBaRegPortInData     : in    std_logic_vector(63 downto 0);
    bTriggerRoutingBaRegPortInRdStrobe : in    std_logic_vector(7 downto 0);
    bTriggerRoutingBaRegPortInWtStrobe : in    std_logic_vector(7 downto 0);
    bTriggerRoutingBaRegPortOutData    : out   std_logic_vector(63 downto 0);
    bTriggerRoutingBaRegPortOutAck     : out   std_logic;
    aPxiTrigDataIn                     : in  std_logic_vector(7 downto 0);
    aPxiTrigDataOut                    : out std_logic_vector(7 downto 0);
    aPxiTrigDataTri                    : out std_logic_vector(7 downto 0);
    aPxiStarData                       : in    std_logic;
    pIntSync100Trigger                 : in    std_logic;
    aIntClk10Trigger                   : in    std_logic;
    dDevClkEn                          : in    std_logic; -- ignored for now
    dTdcAssert                         : out   std_logic;
    sTdcDeassert                       : out   std_logic;
    bRoutingClipPresent                : out   std_logic;
    bRoutingClipNiCompatible           : out   std_logic;
    SyncPulseClk                       : in    std_logic;
    PxieClk100Trigger                  : in    std_logic; -- intentionally left
                                                          -- blank below for now
    DataClk                            : in    std_logic;
    aReset                             : in    std_logic;
    aSource0                           : in    std_logic;
    aSource1                           : in    std_logic;
    aSource2                           : in    std_logic;
    aSource3                           : in    std_logic;
    aSource4                           : in    std_logic;
    aSource5                           : in    std_logic;
    aSource6                           : in    std_logic;
    aSource7                           : in    std_logic;
    aSource8                           : in    std_logic;
    aSource9                           : in    std_logic;
    aSource10                          : in    std_logic;
    aSource11                          : in    std_logic;
    aSource12                          : in    std_logic;
    aSource13                          : in    std_logic;
    aSource14                          : in    std_logic;
    aSource15                          : in    std_logic;
    aSource16                          : in    std_logic;
    aSource17                          : in    std_logic;
    aSource18                          : in    std_logic;
    aSource19                          : in    std_logic;
    aSource20                          : in    std_logic;
    aSource21                          : in    std_logic;
    aSource22                          : in    std_logic;
    aSource23                          : in    std_logic;
    aSource24                          : in    std_logic;
    aSource25                          : in    std_logic;
    aSource26                          : in    std_logic;
    aSource27                          : in    std_logic;
    aSource28                          : in    std_logic;
    aSource29                          : in    std_logic;
    aSource30                          : in    std_logic;
    aSource31                          : in    std_logic;
    TClk                               : out   std_logic;
    aDestinationSyncPulse              : out   std_logic;
    aDestination0                      : out   std_logic;
    aDestination1                      : out   std_logic;
    aDestination2                      : out   std_logic;
    aDestination3                      : out   std_logic;
    aDestination4                      : out   std_logic;
    aDestination5                      : out   std_logic;
    aDestination6                      : out   std_logic;
    aDestination7                      : out   std_logic;
    aDestination8                      : out   std_logic;
    aDestination9                      : out   std_logic;
    aDestination10                     : out   std_logic;
    aDestination11                     : out   std_logic;
    aDestination12                     : out   std_logic;
    aDestination13                     : out   std_logic;
    aDestination14                     : out   std_logic;
    aDestination15                     : out   std_logic;
    aDestination16                     : out   std_logic;
    aDestination17                     : out   std_logic;
    aDestination18                     : out   std_logic;
    aDestination19                     : out   std_logic;
    aDestination20                     : out   std_logic;
    aDestination21                     : out   std_logic;
    aDestination22                     : out   std_logic;
    aDestination23                     : out   std_logic;
    aDestination24                     : out   std_logic;
    aDestination25                     : out   std_logic;
    aDestination26                     : out   std_logic;
    aDestination27                     : out   std_logic;
    aDestination28                     : out   std_logic;
    aDestination29                     : out   std_logic;
    aDestination30                     : out   std_logic;
    aDestination31                     : out   std_logic;
    aDiagramIdentity                   : in    std_logic_vector(31 downto 0);
    aClipIdentity                      : out   std_logic_vector(7 downto 0));

end entity Wrapper;

architecture RTL of Wrapper is
  component RegisteredRouting is
    port (
      BusClkTrigger                      : in    std_logic;
      abBusResetTrigger                  : in    std_logic;
      bTriggerRoutingBaRegPortInAddress  : in    std_logic_vector(27 downto 0);
      bTriggerRoutingBaRegPortInData     : in    std_logic_vector(63 downto 0);
      bTriggerRoutingBaRegPortInRdStrobe : in    std_logic_vector(7 downto 0);
      bTriggerRoutingBaRegPortInWtStrobe : in    std_logic_vector(7 downto 0);
      bTriggerRoutingBaRegPortOutData    : out   std_logic_vector(63 downto 0);
      bTriggerRoutingBaRegPortOutAck     : out   std_logic;
      aPxiTrigDataIn                     : in    std_logic_vector(7 downto 0);
      aPxiTrigDataOut                    : out   std_logic_vector(7 downto 0);
      aPxiTrigDataTri                    : out   std_logic_vector(7 downto 0);
      aPxiStarData                       : in    std_logic;
      sSync100                           : in    std_logic;
      dTDCAssert                         : out   std_logic;
      sTDCDeassert                       : out   std_logic;
      SyncPulseClk                       : in    std_logic;
      DataClk                            : in    std_logic;
      aReset                             : in    std_logic;
      aSource0                           : in    std_logic;
      aSource1                           : in    std_logic;
      aSource2                           : in    std_logic;
      aSource3                           : in    std_logic;
      aSource4                           : in    std_logic;
      aSource5                           : in    std_logic;
      aSource6                           : in    std_logic;
      aSource7                           : in    std_logic;
      aSource8                           : in    std_logic;
      aSource9                           : in    std_logic;
      aSource10                          : in    std_logic;
      aSource11                          : in    std_logic;
      aSource12                          : in    std_logic;
      aSource13                          : in    std_logic;
      aSource14                          : in    std_logic;
      aSource15                          : in    std_logic;
      aSource16                          : in    std_logic;
      aSource17                          : in    std_logic;
      aSource18                          : in    std_logic;
      aSource19                          : in    std_logic;
      aSource20                          : in    std_logic;
      aSource21                          : in    std_logic;
      aSource22                          : in    std_logic;
      aSource23                          : in    std_logic;
      aSource24                          : in    std_logic;
      aSource25                          : in    std_logic;
      aSource26                          : in    std_logic;
      aSource27                          : in    std_logic;
      aSource28                          : in    std_logic;
      aSource29                          : in    std_logic;
      aSource30                          : in    std_logic;
      aSource31                          : in    std_logic;
      TClk                               : out   std_logic;
      aDestinationSyncPulse              : out   std_logic;
      aDestination0                      : out   std_logic;
      aDestination1                      : out   std_logic;
      aDestination2                      : out   std_logic;
      aDestination3                      : out   std_logic;
      aDestination4                      : out   std_logic;
      aDestination5                      : out   std_logic;
      aDestination6                      : out   std_logic;
      aDestination7                      : out   std_logic;
      aDestination8                      : out   std_logic;
      aDestination9                      : out   std_logic;
      aDestination10                     : out   std_logic;
      aDestination11                     : out   std_logic;
      aDestination12                     : out   std_logic;
      aDestination13                     : out   std_logic;
      aDestination14                     : out   std_logic;
      aDestination15                     : out   std_logic;
      aDestination16                     : out   std_logic;
      aDestination17                     : out   std_logic;
      aDestination18                     : out   std_logic;
      aDestination19                     : out   std_logic;
      aDestination20                     : out   std_logic;
      aDestination21                     : out   std_logic;
      aDestination22                     : out   std_logic;
      aDestination23                     : out   std_logic;
      aDestination24                     : out   std_logic;
      aDestination25                     : out   std_logic;
      aDestination26                     : out   std_logic;
      aDestination27                     : out   std_logic;
      aDestination28                     : out   std_logic;
      aDestination29                     : out   std_logic;
      aDestination30                     : out   std_logic;
      aDestination31                     : out   std_logic;
      aDiagramIdentity                   : in    std_logic_vector(31 downto 0);
      aClipIdentity                      : out   std_logic_vector(7 downto 0));
  end component RegisteredRouting;

  attribute syn_black_box                      : boolean;
  attribute syn_black_box of RegisteredRouting : component is true;
begin
  RegisteredRouting_1 : RegisteredRouting
    port map (
      BusClkTrigger                      => BusClkTrigger,
      abBusResetTrigger                  => abBusResetTrigger,
      bTriggerRoutingBaRegPortInAddress  => bTriggerRoutingBaRegPortInAddress,
      bTriggerRoutingBaRegPortInData     => bTriggerRoutingBaRegPortInData,
      bTriggerRoutingBaRegPortInRdStrobe => bTriggerRoutingBaRegPortInRdStrobe,
      bTriggerRoutingBaRegPortInWtStrobe => bTriggerRoutingBaRegPortInWtStrobe,
      bTriggerRoutingBaRegPortOutData    => bTriggerRoutingBaRegPortOutData,
      bTriggerRoutingBaRegPortOutAck     => bTriggerRoutingBaRegPortOutAck,
      aPxiTrigDataIn                     => aPxiTrigDataIn,
      aPxiTrigDataOut                    => aPxiTrigDataOut,
      aPxiTrigDataTri                    => aPxiTrigDataTri,
      aPxiStarData                       => aPxiStarData,
      sSync100                           => pIntSync100Trigger, --sSync100,
      dTDCAssert                         => dTDCAssert,
      sTDCDeassert                       => sTDCDeassert,
      SyncPulseClk                       => SyncPulseClk,
      DataClk                            => DataClk,
      aReset                             => aReset,
      aSource0                           => aSource0,
      aSource1                           => aSource1,
      aSource2                           => aSource2,
      aSource3                           => aSource3,
      aSource4                           => aSource4,
      aSource5                           => aSource5,
      aSource6                           => aSource6,
      aSource7                           => aSource7,
      aSource8                           => aSource8,
      aSource9                           => aSource9,
      aSource10                          => aSource10,
      aSource11                          => aSource11,
      aSource12                          => aSource12,
      aSource13                          => aSource13,
      aSource14                          => aSource14,
      aSource15                          => aSource15,
      aSource16                          => aSource16,
      aSource17                          => aSource17,
      aSource18                          => aSource18,
      aSource19                          => aSource19,
      aSource20                          => aSource20,
      aSource21                          => aSource21,
      aSource22                          => aSource22,
      aSource23                          => aSource23,
      aSource24                          => aSource24,
      aSource25                          => aSource25,
      aSource26                          => aSource26,
      aSource27                          => aSource27,
      aSource28                          => aSource28,
      aSource29                          => aSource29,
      aSource30                          => aSource30,
      aSource31                          => aSource31,
      TClk                               => TClk,
      aDestinationSyncPulse              => aDestinationSyncPulse,
      aDestination0                      => aDestination0,
      aDestination1                      => aDestination1,
      aDestination2                      => aDestination2,
      aDestination3                      => aDestination3,
      aDestination4                      => aDestination4,
      aDestination5                      => aDestination5,
      aDestination6                      => aDestination6,
      aDestination7                      => aDestination7,
      aDestination8                      => aDestination8,
      aDestination9                      => aDestination9,
      aDestination10                     => aDestination10,
      aDestination11                     => aDestination11,
      aDestination12                     => aDestination12,
      aDestination13                     => aDestination13,
      aDestination14                     => aDestination14,
      aDestination15                     => aDestination15,
      aDestination16                     => aDestination16,
      aDestination17                     => aDestination17,
      aDestination18                     => aDestination18,
      aDestination19                     => aDestination19,
      aDestination20                     => aDestination20,
      aDestination21                     => aDestination21,
      aDestination22                     => aDestination22,
      aDestination23                     => aDestination23,
      aDestination24                     => aDestination24,
      aDestination25                     => aDestination25,
      aDestination26                     => aDestination26,
      aDestination27                     => aDestination27,
      aDestination28                     => aDestination28,
      aDestination29                     => aDestination29,
      aDestination30                     => aDestination30,
      aDestination31                     => aDestination31,
      aDiagramIdentity                   => aDiagramIdentity,
      aClipIdentity                      => aClipIdentity);

  bRoutingClipPresent      <= '1';
  bRoutingClipNiCompatible <= '1';

end architecture RTL;
