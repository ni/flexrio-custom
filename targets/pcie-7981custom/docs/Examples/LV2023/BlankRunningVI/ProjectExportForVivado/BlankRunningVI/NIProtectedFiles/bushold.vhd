-------------------------------------------------------------------------------
--
-- Purpose:
-- ========
--  This componpent deals with all the clock, and reset domain crossings and
--  connects the registers to the resource ports.
--
--
-- Timing optimization:
-- ====================
--  Optimization to meet higher clock rates for control/indicator access logic 
--  may be turned on for certain clock domains.
--
-- These optimizations affect paths to/from controls/indicators as follows -
-- -------------------------------------------------------------------------
-- To control/indicator -
--   For regular registers, host read/write strobes have 2 cycles of pipeline 
--     delay while host write data has 1 cycle of pipeline delay.
--   For wide registers, host read/write strobes have 3 cycles of pipeline 
--     delay while host write data has 1 cycle of pipeline delay.
-- From control/indicator -
--   For both regular and wide registers, read data and datavalid are subject 
--     to a variable pipeline delay (with a minimum of 1 delay) which scales 
--     with the log of the number of controls/indicators (where the base of 
--     the log is the number of inputs to the LUTs on the device). Both read 
--     data and datavalid are subject to the same pipeline delay and coherency 
--     between them is maintained.
--
-- Note -
-- ------
-- 1. There is no combinatorial logic on <CLK>DataIn and so a pipeline stage on 
--    this signal may seem unnecessary. However, through experiments it was 
--    found that adding a stage of pipeline here helped improve timing 
--    considerably and since this stage only costs 32 additional flops, we 
--    decided to keep this optimization.
-- 2. There is a mismatch in the host write strobe and write data of 1 cycle for 
--    regular registers, and 2 cycles for wide registers. The data will arrive 
--    earlier and will be held stable until the write strobe arrives. This is a 
--    safe assumption since the handshake component will hold the data until the 
--    next access for at least 3 more cycles (attributed to the turnaround time 
--    of the handshake).
-- 3. There is a mismatch in the <CLK>WideRead/<CLK>WideRead strobes and 
--    <CLK>WideRegSelect. The latter reaches the logic cloud a cycle earlier 
--    and since the handshake can hold the output data for at least 2 cycles in 
--    between accesses, this should be ok.
-- 4. There is a mismatch in the <CLK>PersistRead/<CLK>PersistWrite strobes and 
--    <CLK>SrCountInit. This is explained properly where these signals are used.
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgRegister.all;
  use work.PkgCommunicationInterface.all;


entity bushold is
  generic (
    kdummyWidthIn : POSITIVE := 2;
    kdummyWidthOut : POSITIVE := 1;
    kInterfaceMiteIoLikeWidthOut : NATURAL := 34;
    kInterfaceMiteIoLikeWidthIn : NATURAL := 51;
    kViControlHostReadWidthOut : NATURAL := 2;
    kViControlHostReadWidthIn : NATURAL := 33;
    kViControlHostWriteWidthOut : NATURAL := 34;
    kViControlHostWriteWidthIn : NATURAL := 1;
    kDiagramResetHostReadWidthOut : NATURAL := 2;
    kDiagramResetHostReadWidthIn : NATURAL := 33;
    kDiagramResetHostWriteWidthOut : NATURAL := 34;
    kDiagramResetHostWriteWidthIn : NATURAL := 1;
    kViSignatureHostReadWidthOut : NATURAL := 2;
    kViSignatureHostReadWidthIn : NATURAL := 129
  );

  port (
   BusClk : in std_logic ;
   ReliableClkIn : in std_logic ;
   reset : in std_logic ;
   dummyFromReshold : in std_logic_vector(kdummyWidthIn-1 downto 0);
   dummyToReshold : out std_logic_vector(kdummyWidthOut-1 downto 0);
   busClkToResInterfaceMiteIoLike : out std_logic_vector(kInterfaceMiteIoLikeWidthOut-1 downto 0);
   busClkFromResInterfaceMiteIoLike : in std_logic_vector(kInterfaceMiteIoLikeWidthIn-1 downto 0);
   busClkToResViControlHostRead : out std_logic_vector(kViControlHostReadWidthOut-1 downto 0);
   busClkFromResViControlHostRead : in std_logic_vector(kViControlHostReadWidthIn-1 downto 0);
   busClkToResViControlHostWrite : out std_logic_vector(kViControlHostWriteWidthOut-1 downto 0);
   busClkFromResViControlHostWrite : in std_logic_vector(kViControlHostWriteWidthIn-1 downto 0);
   busClkToResDiagramResetHostRead : out std_logic_vector(kDiagramResetHostReadWidthOut-1 downto 0);
   busClkFromResDiagramResetHostRead : in std_logic_vector(kDiagramResetHostReadWidthIn-1 downto 0);
   busClkToResDiagramResetHostWrite : out std_logic_vector(kDiagramResetHostWriteWidthOut-1 downto 0);
   busClkFromResDiagramResetHostWrite : in std_logic_vector(kDiagramResetHostWriteWidthIn-1 downto 0);
   busClkToResViSignatureHostRead : out std_logic_vector(kViSignatureHostReadWidthOut-1 downto 0);
   busClkFromResViSignatureHostRead : in std_logic_vector(kViSignatureHostReadWidthIn-1 downto 0);
   aBusReset : in std_logic 
  );

end bushold;

architecture rtl of bushold is

  signal aDiagramReset, aBusResetBoolean : boolean;

  constant kNumberOfRegisters : positive := 3;
  constant kFromIntDataWidth : positive := 32 + Log2(kNumberOfRegisters) + 1;
                                 -- DataWidth +         Index            + Write
  signal iRegPortOutArray : RegPortOutArray_t(0 to 1 - 1);
  signal iRegPortOut : RegPortOut_t;

  constant kOrGateMaxFanIn : positive := 6;

  signal iRegPortInBusClk  : RegPortIn_t;
  signal iRegPortOutBusClk : RegPortOut_t;
  signal BusClkIndex : unsigned(kAlignedAddressWidth - 1 downto 0);
  signal BusClkRead : std_logic;
  signal BusClkPersistRead : std_logic;
  signal BusClkWrite : std_logic;
  signal BusClkPersistWrite : std_logic;
  signal BusClkDataIn : std_logic_vector(31 downto 0);
  signal BusClkDataOut : std_logic_vector(31 downto 0);
  signal BusClkDataValid : std_logic;




begin

  -- Type conversion of reset signals.  
  aDiagramReset <= to_boolean(reset);
  aBusResetBoolean <= to_boolean(aBusReset);


  iRegPortOut <= SelectPort(iRegPortOutArray);
  busclkToResInterfaceMiteIoLike <= to_StdLogicVector(iRegPortOut);

  iRegPortInBusClk <= BuildRegPortIn(busclkFromResInterfaceMiteIoLike);

-- TIMING OPTIMIZATION IS OFF
-- ==========================
-- Optimization cannot be turned on for the interface clock domain.
BusClkCrossing:block
  signal iDataValid : boolean;
  signal BusClkDataValidIn : boolean;
  signal iReady : boolean;
  signal BusClkReady : boolean;
  signal iPush : boolean;
  signal BusClkPush : boolean;
  signal iHSDataIn : std_logic_vector(kAlignedAddressWidth + 32 downto 0);
  signal BusClkHSDataIn : std_logic_vector(kAlignedAddressWidth + 32 downto 0);
  signal iHSDataOut : std_logic_vector(31 downto 0);
  signal BusClkHSDataOut : std_logic_vector(31 downto 0);
  
begin

  iHsDataIn(kAlignedAddressWidth downto 1) <= std_logic_vector(iRegPortInBusClk.Address(kAlignedAddressWidth - 1 downto 0));
  iHsDataIn(kAlignedAddressWidth+32 downto kAlignedAddressWidth + 1)
     <= iRegPortInBusClk.Data;
  iHSDataIn(0) <= to_StdLogic(iRegPortInBusClk.Wt);
  iPush <= (iRegPortInBusClk.Wt or iRegPortInBusClk.Rd); 

  --Outputs of the block
  iRegPortOutBusClk.Data <= iHSDataOut;
  iRegPortOutBusClk.DataValid <= iDataValid;
  iRegPortOutBusClk.Ready <= iReady;

  -- Non-qualified, persisting version of Read and Write signal
  BusClkPersistRead <= not BusClkHSDataIn(0);
  BusClkPersistWrite <=  BusClkHSDataIn(0);

  BusClkIndex <= unsigned(BusClkHsDataIn(kAlignedAddressWidth downto 1));
  BusClkRead <= to_StdLogic(BusClkDataValidIn) and BusClkPersistRead;
  BusClkWrite <=  to_StdLogic(BusClkDataValidIn) and BusClkPersistWrite;
  BusClkDataIn <= BusClkHsDataIn(kAlignedAddressWidth+32 downto kAlignedAddressWidth + 1);
  BusClkHSDataIn <= iHSDataIn;
  BusClkDataValidIn <= iPush;
  iReady <= BusClkReady;

  iHSDataOut <= BusClkDataOut;     
  iDataValid <= to_Boolean(BusClkDataValid);
  BusClkReady <= to_Boolean(BusClkFromResViControlHostWrite(0)) and to_Boolean(BusClkFromResDiagramResetHostWrite(0)) and  true;
end block;

BusClkShifter: block

  constant kBusClkMaxWidth : positive := 128;
  constant kBusClkCounterWidth : positive :=  Log2(4 + 1);
  signal BusClkWideWrite : std_logic;
  signal BusClkWideDataIn : std_logic_vector(kBusClkMaxWidth-1 downto 0);
  signal BusClkWideRead : std_logic;
  signal BusClkWideDataValid : std_logic;
  signal BusClkWideDataOut : std_logic_vector(kBusClkMaxWidth-1 downto 0);
  signal BusClkRegWrite : std_logic;
  signal BusClkRegDataIn : std_logic_vector(31 downto 0);
  signal BusClkRegRead : std_logic;
  signal BusClkRegDataValid : std_logic;
  signal BusClkRegDataOut : std_logic_vector(31 downto 0);
  signal BusClkWideAccess : boolean;
  signal BusClkReadToWide : boolean;
  signal BusClkWriteToWide : boolean;
  signal BusClkSrDataValid : boolean;
  signal BusClkSrDataOut : std_logic_vector (31 downto 0);
  signal BusClkSrCount : natural range 0 to (2**kBusClkCounterWidth)-1;
  signal cRegRead, cRegWrite : boolean;
  signal cCount : unsigned(kBusClkCounterWidth - 1 downto 0);

begin
  cCount <= to_unsigned(BusClkSrCount,kBusClkCounterWidth);
  BusClkWideRead <= to_StdLogic(cRegRead);
  BusClkWideWrite <= to_StdLogic(cRegWrite);

  --Regular Registers
  BusClkRegWrite <= BusClkWrite;
  BusClkRegDataIn <= BusClkDataIn;
  BusClkRegRead <= BusClkRead;
  BusClkDataValid <= BusClkRegDataValid or to_StdLogic(BusClkSrDataValid);

  BusClkReadToWide <= to_Boolean(BusClkRead) and BusClkWideAccess;
  BusClkWriteToWide <= to_Boolean(BusClkWrite) and BusClkWideAccess;

  -- Are we accessing a wide register ?
  BusClkWideAccess <=   (BusClkIndex = kViSignatureIndex);

 -- Count depends on the selected register ...
  BusClkSrCount <=  kViSignatureShiftCount when unsigned(BusClkIndex) = kViSignatureIndex and BusClkWrite = '1'
     else  kViSignatureShiftCount - 1  when unsigned(BusClkIndex) = kViSignatureIndex and BusClkRead = '1'
     else   0;


  -- ShiftRegister: ----------------------------------------------------------
  -- Building the Read and Write Signal for the Shift Register
  -- Note : the ShiftRegister needs pulses as input, and DataValid
  --        is a pulse (from the handshake component)
  ----------------------------------------------------------------------------
  ShiftRegister: entity work.NiFpgaRegFrameworkShiftReg (rtl)
    generic map (
      kRegWidth     => kBusClkMaxWidth,      
      kBusWidth     => 32,
      kCounterWidth => kBusClkCounterWidth)
    port map (
      aReset           => aBusResetBoolean,
      aBusReset        => aBusResetBoolean,
      Clock            => BusClk,
      ReliableClk      => ReliableClkIn,
      cCount           => cCount ,
      cBusRead         => BusClkReadToWide,
      cBusWrite        => BusClkWriteToWide,
      cBusDataIn       => BusClkDataIn,
      cBusDataOut      => BusClkSrDataOut,
      cBusDataOutValid => BusClkSrDataValid,
      cRegRead         => cRegRead,
      cRegWrite        => cRegWrite,
      cRegDataIn       => BusClkWideDataOut,
      cRegDataInValid  => to_Boolean(BusClkWideDataValid),
      cRegDataOut      => BusClkWideDataIn);	

  -- Regular Registers : Host Write
    -- Write
    BusClkToResViControlHostWrite(0) <= BusClkRegWrite when BusClkIndex=kViControlIndex else '0';
    -- Data is just distributed
    BusClkToResViControlHostWrite(kViControlWidth + 1 downto 2) <= 
        BusClkRegDataIn(kViControlWidth - 1 downto 0);
  -- Regular Registers : Host Read
    -- Read
    BusClkToResViControlHostRead(0) <= BusClkRegRead when BusClkIndex=kViControlIndex else '0';

  -- Regular Registers : Host Write
    -- Write
    BusClkToResDiagramResetHostWrite(0) <= BusClkRegWrite when BusClkIndex=kDiagramResetIndex else '0';
    -- Data is just distributed
    BusClkToResDiagramResetHostWrite(kDiagramResetWidth + 1 downto 2) <= 
        BusClkRegDataIn(kDiagramResetWidth - 1 downto 0);
  -- Regular Registers : Host Read
    -- Read
    BusClkToResDiagramResetHostRead(0) <= BusClkRegRead when BusClkIndex=kDiagramResetIndex else '0';

  -- WideRegisters : Host Read
    --  Read
    BusClkToResViSignatureHostRead(0) <= BusClkWideRead when BusClkIndex=kViSignatureIndex else '0';

  -- Regular Registers
    -- Host Read : DataValid
    BusClkRegDataValid <= BusClkFromResViControlHostRead(0) or 
  BusClkFromResDiagramResetHostRead(0) or 
  '0';

  -- Wide Registers
    -- Host Read : DataValid
    BusClkWideDataValid <= BusClkFromResViSignatureHostRead(0) or 
  '0';

  -- Regular Registers
    -- Host Read : Data
    BusClkRegDataOut <=  BusClkFromResViControlHostRead(kViControlWidth downto 1)   or
 BusClkFromResDiagramResetHostRead(kDiagramResetWidth downto 1)   ;
  -- Wide Registers
    -- Host Read : Data
    BusClkWideDataOut <=  BusClkFromResViSignatureHostRead(kViSignatureWidth downto 1)   ;

  BusClkDataOut <= BusClkSrDataOut when BusClkSrDataValid else BusClkRegDataOut;

end block BusClkShifter;



 iRegPortOutArray(0) <= iRegPortOutBusClk;
   

end rtl;
