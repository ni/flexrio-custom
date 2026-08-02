-------------------------------------------------------------------------------
--
-- File: DmaPortCommIfcLvFpgaIrq.vhd
-- Author: Hugo Andrade
-- Original Project: LvFpga Communication Interface
-- Date: 2005
--
-------------------------------------------------------------------------------
-- (c) 2005 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose: Resource implementation of IRQs
--
-------------------------------------------------------------------------------
--
-- Updated to support CHInCh
-- Matthew Koenn
-- 3 December 2007
--
--   The original file was MiteIrq.vhd.  This was updated to support the
-- CHInCh.  The name of the component was changed, and the register port was
-- changed such that it is connected to the register access component rather
-- than the Mite.  The code was changed to support the register access scheme.
--
--   There is also a safe reset crossing in this component from the
-- asynchronous diagram reset domain to the synchronous bus reset domain.
-- The bIrqToInterface, bRegPortIn, and bRegPortOut signals should be reset
-- externally by synchronous bus reset.  All other signals should be reset
-- externally by asynchronous diagram reset.
--
-------------------------------------------------------------------------------

--StaticVHDL Component

library IEEE;
  use IEEE.std_logic_1164.all;
  use IEEE.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgCommunicationInterface.all;
  use work.PkgDmaPortCommunicationInterface.all;
  use work.PkgCommIntConfiguration.all;
  use work.PkgNiFpgaIrqRegisters.all;

entity DmaPortCommIfcLvFpgaIrq is
  port (

    -- This should be tied to the asynchronous diagram reset signal.  There is a safe
    -- reset crossing in this component between the asynchronous diagram reset domain
    -- and the synchronous bus reset domain.
    aDiagramReset         : in boolean;

    aBusReset             : in boolean;
    BusClk                : in std_logic;
    
    -- Synchronous reset for the circuit. This is intended to be tied to the
    -- synchronous bus reset signal.
    bReset                : in boolean;

    -- This is the clock used for the interrupt signals.
    IrqClk                : in  std_logic;

    -- These are the enable chain signals used to handshake in the value of
    -- iIrqNum.
    iIrqEnableIn          : in  std_logic;
    iIrqEnableOut         : out std_logic;
    iIrqEnableClear       : in  std_logic;

    -- This is the value of the interrupt to set.
    iIrqNum               : in  std_logic_vector(4 downto 0);

    -- The acknowledgement of the interrupts from the host.  The ack status is
    -- a '1' when it is cleared from the host.  The associated enable chain is
    -- not used, but it is left here because there are diagram hookups for it.
    -- The signals are hooked up so that they match the equivalent implementation
    -- from the Mite communication interface.
    iIrqAckStatus            : out std_logic_vector(31 downto 0);
    iIrqAckStatusEnableIn    : in  std_logic;
    iIrqAckStatusEnableOut   : out std_logic;
    iIrqAckStatusEnableClear : in  std_logic;
    --vhook_nowarn iIrqAckStatusEnableClear

    -- The status of the client IP interrupt line.
    bIpIrqToInterface     : in IrqStatusToInterface_t;

    ---------------------------------------------------------------------------
    -- Register port access signals
    ---------------------------------------------------------------------------

    -- The signal from the register access component advertising read/write
    -- requests from the bus.
    bRegPortIn            : in  RegPortIn_t;

    -- The signal going back to the register access component responding to
    -- write requests.
    bRegPortOut           : out RegPortOut_t;


    ---------------------------------------------------------------------------
    -- Top level interface
    ---------------------------------------------------------------------------

    -- The signal going to the top level indicating the status of the virtual
    -- IRQs.
    bIrqToInterface       : out IrqToInterface_t

  );
end DmaPortCommIfcLvFpgaIrq;

architecture rtl of DmaPortCommIfcLvFpgaIrq is

  signal bIeRegDecode : boolean := false;
  signal bMaskRegDecode : boolean := false;
  signal bStatusRegDecode : boolean := false;

  signal bIeReg : std_logic := '0';
  signal bStatusReg : std_logic_vector(31 downto 0) := (others=>'0');
  signal bMaskReg : std_logic_vector(31 downto 0) := (others=>'0');

  signal bIrqClear : std_logic_vector(31 downto 0) := (others=>'0');

  signal bIrqInt : std_logic := '0';

  signal iReadyIrqNum : boolean := false;
  signal bIrqNumValid : boolean := false;
  signal bIrqNum : std_logic_vector (4 downto 0) := (others=>'0');

  signal bPushIrqAck, bPushIrqAckHold : boolean := false;
  signal bIrqAck : std_logic_vector(31 downto 0) := (others=>'0');
  signal bReadyIrqAck : boolean := false;
  signal iIrqAckValid : boolean := false;
  signal iIrqAck : std_logic_vector (31 downto 0) := (others=>'0');

  signal iIrqEnableInDly : std_logic := '0';
  signal iIrqEnableInEdge : boolean := false;

  type PushIrqNumState_t is (waitPushIrqNumEi, waitPushIrqNumReady);
  signal iPushIrqNumState, iPushIrqNumNextState : PushIrqNumState_t;
  signal iPushIrqNum : boolean := false;

  signal bIpIrq, bIpIrq_ms : IrqStatusToInterface_t := kIrqStatusToInterfaceZero;
  signal bIrqToInterfaceLcl : IrqToInterface_t := (others=>kIrqStatusToInterfaceZero);
  signal bRegPortOutLcl : RegPortOut_t := kRegPortOutZero;
  
  signal bDiagramReset_ms, bDiagramReset : boolean := false;

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of bIpIrq_ms,bIpIrq : signal is "true";
  attribute ASYNC_REG of bDiagramReset_ms,bDiagramReset : signal is "true";

  --vhook_sigstart
  signal bDiagramResetStatus: boolean;
  signal iBusResetStatus: boolean;
  signal iHandShakeReady: boolean;
  --vhook_sigend

begin

  -- The diagram reset status signal is not necessary anywhere in this design.
  --vhook_nowarn bDiagramResetStatus

  bIrqToInterface <= bIrqToInterfaceLcl;
  bRegPortOut <= bRegPortOutLcl;
  
  
  -- SynchronizeDiagramReset: -------------------------------------------------
  -- !CLOCK BOUNDARY CROSSING! Clock crossing from an unknown clock domain
  -- to the BusClk domain.
  --
  -- Double synchronize the async diagram reset. Use this sync version of reset
  -- for all the irq control registers in the BusClk domain. This is because
  -- when the host performs reset to the fpga vi, that action should also clear
  -- the host facing irq control registers.
  -----------------------------------------------------------------------------
  
  -- The component who instantiate this module should connect either bReset or 
  -- aBusReset, and not both. It is redundant to connect both reset signals.
  -- If both reset singals are connected, a combinatorial logic is inferred 
  -- before and after bDiagramReset_ms flop.
  
  SynchronizeDiagramReset: process(aBusReset, BusClk)
  begin
    if aBusReset then
      bDiagramReset_ms <= false;
      bDiagramReset <= false;
    elsif rising_edge(BusClk) then
      if bReset then
        bDiagramReset_ms <= false;
        bDiagramReset <= false;
      else
        bDiagramReset_ms <= aDiagramReset;
        bDiagramReset <= bDiagramReset_ms;
      end if;
    end if;
  end process SynchronizeDiagramReset;

  -- Set the lines going to the top level communication interface.
  SetIrqToInterface: process(aBusReset, BusClk)
  begin
    if aBusReset then

      for IrqNum in bIrqToInterfaceLcl'range loop
        bIrqToInterfaceLcl(IrqNum).Status <= '0';
        bIrqToInterfaceLcl(IrqNum).Clear <= '0';
      end loop;
    
    elsif rising_edge(BusClk) then

      if bReset then

        for IrqNum in bIrqToInterfaceLcl'range loop
          bIrqToInterfaceLcl(IrqNum).Status <= '0';
          bIrqToInterfaceLcl(IrqNum).Clear <= '0';
        end loop;

      else

        -- The lines for the LvFpga interrupts are always 32 bits (regardless of the
        -- number that are actually used or available to the VI).  These always go into
        -- the lower 32 bits of the signal going to the comm interface.
        for IrqNum in 31 downto 0 loop
          bIrqToInterfaceLcl(IrqNum).Status <= bStatusReg(IrqNum) and bMaskReg(IrqNum)
                                               and bIeReg;
          bIrqToInterfaceLcl(IrqNum).Clear <= bIrqClear(IrqNum);
        end loop;

        bIrqToInterfaceLcl(32).Status <= bIpIrq.Status and bIeReg;
        bIrqToInterfaceLcl(32).Clear <= bIpIrq.Clear;

      end if;

    end if;
  end process SetIrqToInterface;


  -- The IP IRQ signal may come from the asynchronous diagram reset domain, so we
  -- double synchronize the signal here to prevent metastability from the reset
  -- triggering near a clock edge.
  
  -- CAR #434493 - multi-bit data type synced with double sync
  -- This data type contains only two bits: Status and Clear. It is safe to double
  -- sync this record because Clear functionality is not supported yet. Also, this
  -- two bits have independent operation from each other and are not expected to be
  -- read as a coherent vector.
  
  SynchronizeIpIrq: process(aBusReset, BusClk)
  begin
    if aBusReset then
      bIpIrq_ms <= kIrqStatusToInterfaceZero;
      bIpIrq <= kIrqStatusToInterfaceZero;
    elsif rising_edge(BusClk) then
      bIpIrq_ms <= bIpIrqToInterface;
      bIpIrq <= bIpIrq_ms;
    end if;

  end process;


  -- Decode the addresses for the various IRQ registers.
  bIeRegDecode <= bRegPortIn.Address = to_unsigned(kIeRegOffset,
    bRegPortIn.Address'length);
  bMaskRegDecode <= bRegPortIn.Address = to_unsigned(kMaskRegOffset,
    bRegPortIn.Address'length);
  bStatusRegDecode <= bRegPortIn.Address = to_unsigned(kStatusRegOffset,
    bRegPortIn.Address'length);


  -- Handle writes to any of the writeable register bits.
  WriteRegs: process(aBusReset, BusClk)
  begin
  
    if aBusReset then
    
      bIeReg <= '0';
      bMaskReg <= (others=>'0');
      bStatusReg <= (others=>'0');
      bIrqClear <= (others=>'0');

    elsif rising_edge(BusClk) then

      if bReset then

        bIeReg <= '0';
        bMaskReg <= (others=>'0');
        bStatusReg <= (others=>'0');
        bIrqClear <= (others=>'0');
        
      elsif bDiagramReset then
      
        bIeReg <= '0';
        bMaskReg <= (others=>'0');
        bStatusReg <= (others=>'0');
        
        -- On diagram reset, clear any status bits that are currently set.
        bIrqClear <= bStatusReg;

      else

        -- Clear the clear lines every clock cycle until they are set.
        bIrqClear <= (others=>'0');

        if bRegPortIn.Wt and bIeRegDecode then
          bIeReg <= bRegPortIn.Data(kIrqEnableBitOffset);
        end if;

        if bRegPortIn.Wt and bMaskRegDecode then
          bMaskReg <= bRegPortIn.Data;
        end if;

        -- Clear any status bit that is being written with a '1'.
        if bRegPortIn.Wt and bStatusRegDecode then
          bStatusReg <= (not bRegPortIn.Data) and bStatusReg;

          -- Notify the interface when the IRQs are cleared.
          bIrqClear <= bRegPortIn.Data;
        end if;

        -- Set the status bit when the corresponding IRQ is set.  This
        -- overrides any bit that was also being cleared with a write in the
        -- same clock cycle.
        if bIrqNumvalid then
          bStatusReg(to_integer(unsigned(bIrqNum))) <= '1';
        end if;

      end if;

    end if;

  end process WriteRegs;


  -- Handle reads to the IRQ registers.
  ReadRegs: process(aBusReset, BusClk)
    variable ReadData : std_logic_vector(bRegPortOutLcl.Data'range);
  begin
  
    if aBusReset then

      bRegPortOutLcl.Data <= (others=>'0');
      bRegPortOutLcl.DataValid <= false;
    
    elsif rising_edge(BusClk) then

      if bReset then

        bRegPortOutLcl.Data <= (others=>'0');
        bRegPortOutLcl.DataValid <= false;

      else

        bRegPortOutLcl.Data <= (others=>'0');
        bRegPortOutLcl.DataValid <= false;

        if bRegPortIn.Rd and bIeRegDecode then
        
          ReadData := (others=>'0');
          ReadData(kIrqEnableBitOffset) := bIeReg;
          ReadData(kIrqInterruptBitOffset) := bIrqInt;
          
          bRegPortOutLcl.Data <= ReadData;
          bRegPortOutLcl.DataValid <= true;
          
        elsif bRegPortIn.Rd and bMaskRegDecode then
          bRegPortOutLcl.Data <= bMaskReg;
          bRegPortOutLcl.DataValid <= true;
        elsif bRegPortIn.Rd and bStatusRegDecode then
          bRegPortOutLcl.Data <= bStatusReg;
          bRegPortOutLcl.DataValid <= true;
        end if;

      end if;

    end if;

  end process ReadRegs;

  --bIrqInt is a global Interrupt for the FPGA. This includes FPGA VI and IP interrupts.
  bIrqInt <= '0' when (((bStatusReg and bMaskReg) = Zeros(bStatusReg'length))
                       and (bIpIrq.Status = '0')) else '1';



  ---------------------------------------------------------------------------------------
  -- This section is copied from the original MiteIrq component.
  ---------------------------------------------------------------------------------------

  iIrqEnableInDelay: process (IrqClk, aDiagramReset) is
  begin
    if aDiagramReset then
      iIrqEnableInDly <= '0';
    elsif rising_edge(IrqClk) then
      iIrqEnableInDly <= iIrqEnableIn;
    end if;
  end process iIrqEnableInDelay;

  iIrqEnableInEdge <= ((iIrqEnableIn = '1') and (iIrqEnableInDly = '0'));

  PushIrqNumSync: process (IrqClk, aDiagramReset)
  begin
    if (aDiagramReset) then
      iPushIrqNumState <= waitPushIrqNumEi;
    elsif (rising_edge(IrqClk)) then
      iPushIrqNumState <= iPushIrqNumNextState;
    end if;
  end process;

  PushIrqNumOutput: process (iPushIrqNumState, iReadyIrqNum, iIrqEnableInEdge)
  begin
    if ((((iPushIrqNumState = waitPushIrqNumEi) and iIrqEnableInEdge) or
       (iPushIrqNumState = waitPushIrqNumReady)) and iReadyIrqNum) then
      iPushIrqNum <= true;
    else
      iPushIrqNum <= false;
    end if;
  end process;

  PushIrqNumNextState: process (iPushIrqNumState, iReadyIrqNum, iIrqEnableInEdge)
  begin
    iPushIrqNumNextState <= iPushIrqNumState;
    case (iPushIrqNumState) is
      when waitPushIrqNumEi =>
        if (iIrqEnableInEdge and (not iReadyIrqNum)) then
          iPushIrqNumNextState <= waitPushIrqNumReady;
        end if;
      when waitPushIrqNumReady =>
        if (iReadyIrqNum) then
           iPushIrqNumNextState <= waitPushIrqNumEi;
        end if;
      when others =>
        iPushIrqNumNextState <= waitPushIrqNumEi;
    end case;
  end process;

  -- Handshake the IRQ number being set from the IrqClk domain to the BusClk domain.
  -- There is also a reset crossing here from the asynchronous diagram reset domain to
  -- the synchronous bus reset domain.  This is handled by the handshake with safe
  -- reset crossing component.

  --vhook_e HandshakeBaseResetCross HandshakeIrqNum
  --vhook_a kDataWidth 5
  --vhook_a aResetToDlyPush open
  --vhook_a aResetToIResetFast open
  --vhook_a aPushToggleDly open
  --vhook_a aIReset aDiagramReset
  --vhook_a IClk IrqClk
  --vhook_a iPush iPushIrqNum
  --vhook_a iData iIrqNum
  --vhook_a iStoredData open
  --vhook_a iReady iHandShakeReady
  --vhook_a iOResetStatus iBusResetStatus
  --vhook_a aOReset aBusReset
  --vhook_a OClk BusClk
  --vhook_a oDataValid bIrqNumValid
  --vhook_a oDataAck true
  --vhook_a oData bIrqNum
  HandshakeIrqNum: entity work.HandshakeBaseResetCross (rtl)
    generic map (
      kDataWidth => 5)  -- in  integer := 1
    port map (
      aResetToDlyPush    => open,             -- in  integer := 0
      aResetToIResetFast => open,             -- in  integer := 0
      aPushToggleDly     => open,             -- in  integer := 0
      aIReset            => aDiagramReset,    -- in  boolean
      IClk               => IrqClk,           -- in  std_logic
      iPush              => iPushIrqNum,      -- in  boolean
      iData              => iIrqNum,          -- in  std_logic_vector(kDataWidth-1 downto
      iStoredData        => open,             -- out std_logic_vector(kDataWidth-1 downto
      iReady             => iHandShakeReady,  -- out boolean := false
      iOResetStatus      => iBusResetStatus,  -- out boolean := false
      aOReset            => aBusReset,        -- in  boolean
      OClk               => BusClk,           -- in  std_logic
      oDataValid         => bIrqNumValid,     -- out boolean := false
      oDataAck           => true,             -- in  boolean := true
      oData              => bIrqNum);         -- out std_logic_vector(kDataWidth-1 downto

  -- Making sure that ReadyIrqNum is qualified by the handshake ready
  -- and BusResetStatus. This is because, while the bus is in reset
  -- we do not want the fpga vi to hang execution (IrqEnableOut is not
  -- asserted until ReadyIrqNum is true).
  iReadyIrqNum <= iHandShakeReady or iBusResetStatus;
      
  process(IrqClk, aDiagramReset)
  begin
    if(aDiagramReset) then
      iIrqEnableOut <= '0';
    elsif( rising_edge(IrqClk)) then
      if( iIrqEnableClear = '1' ) then
        iIrqEnableOut <= '0';
      elsif((iIrqEnableIn = '1') and (iReadyIrqNum)) then
        iIrqEnableOut <= '1';
      end if;
    end if;
  end process;


  --bPushIrqAck <= bRegPortIn.Wt and bStatusRegDecode and bReadyIrqAck;

  -- When an IRQ acknowledgement write is received, we need to hold the push to the
  -- corresponding handshake until the handshake is ready to accept the push.  We also
  -- need to hold off register access ready while waiting on the handshake because we
  -- could receive another IRQ acknowledgement write and lose it.
  AckHandshakeControl: process(aBusReset, BusClk)
  begin
    if aBusReset then
        bPushIrqAckHold <= false;
        bRegPortOutLcl.Ready <= true;
        bIrqAck <= (others => '0');
    elsif rising_edge(BusClk) then

      if bReset then
        bPushIrqAckHold <= false;
        bRegPortOutLcl.Ready <= true;
        -- no need to reset bIrqAck which is a data path

      -- When an IRQ ack write occurs, latch the push to the handshake module and
      -- de-assert the register port ready so that we don't receive another ack
      -- write before this one completes.
      elsif bRegPortIn.Wt and bStatusRegDecode then
        bPushIrqAckHold <= true;
        bRegPortOutLcl.Ready <= false;
        bIrqAck <= bRegPortIn.Data;

      -- If the handshake for the acknowledgement signal is ready, then we can
      -- de-assert the push.  We are also ready for another register access at
      -- this point.
      elsif bReadyIrqAck then
        bPushIrqAckHold <= false;
        bRegPortOutLcl.Ready <= true;

      end if;

    end if;
  end process AckHandshakeControl;

  bPushIrqAck <= bPushIrqAckHold and bReadyIrqAck;


  -- HandShakeIrqAck: ---------------------------------------------------------
  -- !CLOCK BOUNDARY CROSSING! Besides clock crossing, this component also
  -- provides safe reset crossing from aMiteReset to aDiagramReset domain.
  --
  -- !CONSTRAINTS! Constraints should be set on this component. Refer to the
  -- components source code for more information.
  --
  -- We do not need to use iOResetStatus signal the way NiFpgaIrq.vhd component
  -- does. This is because we register the Ready signal on the RegPort and it
  -- is not affected by de-assertion of Ready from the handshake component.
  -----------------------------------------------------------------------------
  --vhook_e HandshakeBaseResetCross HandShakeIrqAck
  --vhook_a kDataWidth 32
  --vhook_a aResetToDlyPush open
  --vhook_a aResetToIResetFast open
  --vhook_a aPushToggleDly open
  --vhook_a aIReset aBusReset
  --vhook_a IClk BusClk
  --vhook_a iPush bPushIrqAck
  --vhook_a iData bIrqAck
  --vhook_a iStoredData open
  --vhook_a iReady bReadyIrqAck
  --vhook_a iOResetStatus bDiagramResetStatus
  --vhook_a aOReset aDiagramReset
  --vhook_a OClk IrqClk
  --vhook_a oDataValid iIrqAckValid
  --vhook_a oDataAck true
  --vhook_a oData iIrqAck
  HandShakeIrqAck: entity work.HandshakeBaseResetCross (rtl)
    generic map (
      kDataWidth => 32)  -- in  integer := 1
    port map (
      aResetToDlyPush    => open,                 -- in  integer := 0
      aResetToIResetFast => open,                 -- in  integer := 0
      aPushToggleDly     => open,                 -- in  integer := 0
      aIReset            => aBusReset,            -- in  boolean
      IClk               => BusClk,               -- in  std_logic
      iPush              => bPushIrqAck,          -- in  boolean
      iData              => bIrqAck,              -- in  std_logic_vector(kDataWidth-1 do
      iStoredData        => open,                 -- out std_logic_vector(kDataWidth-1 do
      iReady             => bReadyIrqAck,         -- out boolean := false
      iOResetStatus      => bDiagramResetStatus,  -- out boolean := false
      aOReset            => aDiagramReset,        -- in  boolean
      OClk               => IrqClk,               -- in  std_logic
      oDataValid         => iIrqAckValid,         -- out boolean := false
      oDataAck           => true,                 -- in  boolean := true
      oData              => iIrqAck);             -- out std_logic_vector(kDataWidth-1 do

  iIrqAckStatusEnableOut <= iIrqAckStatusEnableIn;

  AckBits: for ackBit in 0 to 31 generate
    iIrqAckStatus(ackBit) <= iIrqAck(ackBit) and to_StdLogic(iIrqAckValid);
  end generate;

end rtl;
