------------------------------------------------------------------------------
--
-- File: NiFpgaIrq.vhd
-- Author: Hugo Andrade, Asrar Rangwala
-- Original Project: LvFpga Communication Interface
-- Date: 31 January 2010
--
------------------------------------------------------------------------------
-- (c) 2010 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
------------------------------------------------------------------------------
--
-- Purpose: Resource implementation of Virtual Interrupts used by diagram
--          components, and Ip Interrupts that are used by internal client IP.
--
-- Constraints:
--   To guarantee correct operation, constraints must be placed on this
--   component or it's subcomponents. Refer to "!CONSTRAINT!" in the code for
--   more info.
--
-- Ports:
--   aBusReset:             Asynchronous bus reset. Resets all the flip flops
--                          in the BusClk domain.
--
--   aDiagramReset:         Asynchronous FPGA VI Reset. Resets all the flip
--                          flops in the IrqClk domain.
--
--   BusClk:                This is the BusClk.
--
--   bRegPortIn:            The signal from the register access component
--                          advertising read/write requests from the bus.
--
--   bRegPortOut:           The signal going back to the register access
--                          component responding to read/write requests.
--
--   bIpIrq:                IRQ line accessed by IP components (non-FPGA VI
--                          interrupt requesters). This line is essentially
--                          "ORed" with the FPGA VI interrupts. This port
--                          is assumed to be driven from the BusClk, and
--                          aBusReset domain.
--
--   bIrq:                  IRQ line to the processor. This output is 
--                          registered.
--
--   IrqClk:                The FPGA VI interrupts are assumed to be in the
--                          same clock domain (which currently is restricted to
--                          be the board's clock domain).
--
--   iIrqEnableIn,
--   iIrqEnableOut,
--   iIrqEnableClear:       Irq Number enable chain.
--
--   iIrqNum:               Virtual IRQ number from an FPGA VI IRQ requester.
--
--   iIrqAck:               Read by FPGA VI IRQ requesters. Each bit indicates
--                          software acknowledgement of the corresponding
--                          virtual interrupt. Ack is only set for a single
--                          cycle.
--
--   iIrqAckEnableIn,
--   iIrqAckEnableOut:      Ack enable chain. The enable chain is not used,
--                          but it is left here because there are diagram
--                          hookups for it.
------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgCommunicationInterface.all;
  use work.PkgNiFpgaIrqRegisters.all;
  
-- This will cause the LabVIEW FPGA module generators to print all the 
-- dependencies (design and package files) of this file automatically.
--StaticVHDL Component

entity NiFpgaIrq is
  port (
    aBusReset             : in  boolean;
    BusClk                : in  std_logic;
    
    -------------------------------------------
    -- Register Access (PIO) Interface
    -------------------------------------------
    bRegPortIn            : in RegPortIn_t;
    bRegPortOut           : out RegPortOut_t;
    
    -------------------------------------------
    -- IRQ port to the bus
    -------------------------------------------
    bIrq                  : out boolean;

    -------------------------------------------
    -- Diagram Virtual Irq Interface
    -------------------------------------------
    aDiagramReset         : in  boolean;
    IrqClk                : in  std_logic;
    
    iIrqNum               : in  std_logic_vector(Log2(kNumVirtualInterrupts)-1 downto 0);
    iIrqEnableIn          : in  std_logic;
    iIrqEnableOut         : out std_logic;
    iIrqEnableClear       : in  std_logic;
    
    iIrqAck               : out std_logic_vector(kNumVirtualInterrupts-1 downto 0);
    iIrqAckEnableIn       : in  std_logic;
    iIrqAckEnableOut      : out std_logic;
    
    -------------------------------------------
    -- IP Irq Interface
    -------------------------------------------
    bIpIrq                : in boolean
  );
end entity NiFpgaIrq;

architecture behavior of NiFpgaIrq is

  signal bDiagramReset_ms, bDiagramReset : boolean := false;

  signal bIeAddrDecode      : boolean;
  signal bMaskAddrDecode    : boolean;
  signal bStatusAddrDecode  : boolean;
  signal bIrqRegisterAccess : boolean;

  signal bIrqEnable : boolean := false;
  signal bIrqInterrupt : boolean;
  signal bStatus : BooleanVector(iIrqAck'range) := (others => false);
  signal bMask : BooleanVector(iIrqAck'range) := (others => false);
  signal bIrqLoc : boolean := false;
  
  signal bIeReg, bIeRegOut, 
         bMaskReg, bMaskRegOut, 
         bStatusReg, bStatusRegOut : InterfaceData_t;

  signal bIrqNumValid : boolean;
  signal bIrqNum : unsigned (iIrqNum'range);

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of bDiagramReset_ms,bDiagramReset : signal is "true";

begin

  -- SynchronizeDiagramReset: -------------------------------------------------
  -- !CLOCK BOUNDARY CROSSING! Clock crossing from an unknown clock domain
  -- to the BusClk domain.
  --
  -- Double synchronize the async diagram reset. Use this sync version of reset
  -- for all the irq control registers in the BusClk domain. This is because
  -- when the host performs reset to the fpga vi, that action should also clear
  -- the host facing irq control registers.
  -----------------------------------------------------------------------------
  SynchronizeDiagramReset : process(aBusReset, BusClk)
  begin
    if aBusReset then
      bDiagramReset_ms <= false;
      bDiagramReset <= false;
    elsif rising_edge(BusClk) then
      bDiagramReset_ms <= aDiagramReset;
      bDiagramReset <= bDiagramReset_ms;
    end if;
  end process SynchronizeDiagramReset;
  
  ----------------------------------------------------------------------------
  -- IRQ register address decodes
  ----------------------------------------------------------------------------
  bIeAddrDecode <= (bRegPortIn.Address = kIeRegOffset);
  bMaskAddrDecode <= (bRegPortIn.Address = kMaskRegOffset);
  bStatusAddrDecode <= (bRegPortIn.Address = kStatusRegOffset);
  
  bIrqRegisterAccess <= bIeAddrDecode or bMaskAddrDecode or bStatusAddrDecode;

  -- IrqRegisterBlk : --------------------------------------------------------
  -- This block contains all the registers that configure the IRQ module.
  ----------------------------------------------------------------------------
  IrqRegisterBlk : block
  begin
  
    -- IrqEnable : -----------------------------------------------------------
    -- This process registers the Irq Enable bit.
    --------------------------------------------------------------------------
    IrqEnable : process (BusClk, aBusReset) is
    begin
      if aBusReset then
        bIrqEnable <= false;
      elsif rising_edge(BusClk) then
        if bDiagramReset then
          bIrqEnable <= false;
        else
          if bRegPortIn.Wt and bIeAddrDecode then
            bIrqEnable <= to_boolean(bRegPortIn.Data(kIrqEnableBitOffset));
          end if;
        end if;
      end if;
    end process IrqEnable;
    
    -- bIrqInterrupt is a global Interrupt for the FPGA.
    -- This includes FPGA VI and IP interrupts.
    bIrqInterrupt <= OrVector(bStatus and bMask) or bIpIrq;
    
    -- Mask : ----------------------------------------------------------------
    -- This process registers the Mask value of all the Virtual Interrupts.
    --------------------------------------------------------------------------
    Mask : process (BusClk, aBusReset) is
    begin
      if aBusReset then
        bMask <= (others => false);
      elsif rising_edge(BusClk) then
        if bDiagramReset then
          bMask <= (others => false);
        else
          if bRegPortIn.Wt and bMaskAddrDecode then
            bMask <= to_BooleanVector(bRegPortIn.Data);
          end if;
        end if;
      end if;
    end process Mask;
    
    -- GenerateStatus : ------------------------------------------------------
    -- This generates Irq Status of all the Virtual Interrupts.
    -- Set the Status when requested by the diagram. Clear the status when
    -- acknowledged by software.
    --
    -- Diagram should have a higher priority for setting the status than
    -- software for clearing the status.
    --------------------------------------------------------------------------
    GenerateStatus : for bitNum in 0 to kNumVirtualInterrupts-1 generate
      Status : process(BusClk, aBusReset)
      begin
        if aBusReset then
          bStatus(bitNum) <= false;
        elsif rising_edge(BusClk) then
          if bDiagramReset then
            bStatus(bitNum) <= false;
          else
            if (bIrqNumValid and (bitNum = bIrqNum)) then
              bStatus(bitNum) <= true;
            elsif (bRegPortIn.Wt and 
                   bStatusAddrDecode and 
                   bRegPortIn.Data(bitNum) = '1') then
              bStatus(bitNum) <= false;
            end if;
          end if;
        end if;
      end process Status;
    end generate GenerateStatus;
    
    --------------------------------------------------------------------------
    -- IRQ Register read values for software.
    --------------------------------------------------------------------------
    bIeReg <= SetBit(kIrqEnableBitOffset, bIrqEnable) or
              SetBit(kIrqInterruptBitOffset, bIrqInterrupt);
    bMaskReg <= to_StdLogicVector(bMask);
    bStatusReg <= to_StdLogicVector(bStatus);
    
  end block IrqRegisterBlk;
  
  
  -- IrqRegisterReadBlk : ----------------------------------------------------
  -- This block handles register read by software.
  ----------------------------------------------------------------------------
  IrqRegisterReadBlk : block
    signal bDataValid : boolean;
    signal bDataOut : InterfaceData_t;
  begin
  
    bIeRegOut <= bIeReg when bIeAddrDecode else (others => '0');
    bMaskRegOut <= bMaskReg when bMaskAddrDecode else (others => '0');
    bStatusRegOut <= bStatusReg when bStatusAddrDecode else (others => '0');
    
    -- RegisterReadData : ----------------------------------------------------
    -- It's a good idea to register data out. Register DataValid to match
    -- latency in DataOut.
    --------------------------------------------------------------------------
    RegisterReadData : process (aBusReset, BusClk)
    begin
      if aBusReset then
        bDataValid <= false;
        bDataOut <= (others => '0');
      elsif rising_edge(BusClk) then
        bDataValid <= false;
        bDataOut <= (others => '0');
        if bRegPortIn.Rd and bIrqRegisterAccess then
          bDataValid <= true;
          bDataOut <= bIeRegOut or bMaskRegOut or bStatusRegOut;
        end if;
      end if;
    end process RegisterReadData;
    
    bRegPortOut.DataValid <= bDataValid;
    bRegPortOut.Data <= bDataOut;
    
  end block IrqRegisterReadBlk;
  
  -- IrqBlk : ----------------------------------------------------------------
  -- This block generates the IRQ signal to the bus.
  ----------------------------------------------------------------------------
  IrqBlk : block
  begin

    -- IrqReg : --------------------------------------------------------------
    -- bIrq is registered to ensure that this output is glitch-free.
    --------------------------------------------------------------------------
    IrqReg : process(BusClk, aBusReset)
    begin
      if aBusReset then
        bIrqLoc <= false;
      elsif rising_edge(BusClk) then
        bIrqLoc <= bIrqInterrupt and bIrqEnable;
      end if;
    end process IrqReg;
    
    bIrq <= bIrqLoc;
    
  end block IrqBlk;
  
  -- IrqNumberFromDiagramBlk : -----------------------------------------------
  -- This block handles the receiving of IRQ number from the diagram and
  -- pushing it to the BusClk domain.
  ----------------------------------------------------------------------------
  IrqNumberFromDiagramBlk : block
  
    -- Push IRQ number state type
    type PushIrqNumState_t is (
      -- Wait until the EnableIn is set from the diagram. If the handshake is 
      -- ready, do a push, else move to WaitUntilHandshakeIsReady state.
      Idle,
      -- Wait until the handshake is ready to accept a push. When ready, set
      -- push for a cycle and move to Idle state.
      WaitUntilHandshakeIsReady
    );
    signal iPushIrqNumState, iPushIrqNumStateNx : PushIrqNumState_t := Idle;
    
    signal iPushIrqNum : boolean;
    signal iReadyToSyncIrqNum : boolean;
    signal iIrqEnableInDly : std_logic;
    signal iIrqEnableInRisingEdge : boolean;
    signal iHandshakeReady: boolean;
    signal iBusResetStatus: boolean;
    
  begin
  
    -- IrqEnableInDelay : ----------------------------------------------------
    -- Delay the EnableIn signal.
    --------------------------------------------------------------------------
    IrqEnableInDelay : process (IrqClk, aDiagramReset) is
    begin
      if aDiagramReset then
        iIrqEnableInDly <= '0';
      elsif rising_edge(IrqClk) then
        iIrqEnableInDly <= iIrqEnableIn;
      end if;
    end process IrqEnableInDelay;

    -- Generate a rising edge detector on EnableIn.
    iIrqEnableInRisingEdge <= (iIrqEnableIn = '1') and (iIrqEnableInDly = '0');
  
    -- PushIrqNumStateReg : --------------------------------------------------
    -- This process registers the FSM's current state.
    --------------------------------------------------------------------------
    PushIrqNumStateReg : process (aDiagramReset, IrqClk)
    begin
      if aDiagramReset then
        iPushIrqNumState <= Idle;
      elsif rising_edge(IrqClk) then
        iPushIrqNumState <= iPushIrqNumStateNx;
      end if;
    end process PushIrqNumStateReg;

    -- PushIrqNumNextStatePrc : ----------------------------------------------
    -- This state machine generates the push signal for handshaking irq number
    -- from the ViClk domain to the BusClk domain.
    --
    -- !STATE MACHINE STARTUP! This state machine cannot transition any signal
    -- until the enable chain is activated for this component. The diagram
    -- reset component guarantees enough time between de-assertion of 
    -- aDiagramReset and assertion of the enable chain. Since aDiagramReset
    -- powers-up as true, this state machine should have a safe startup after
    -- coming out of aDiagramReset or FPGA configuration.
    --------------------------------------------------------------------------
    PushIrqNumNextStatePrc : process (iPushIrqNumState, 
                                      iReadyToSyncIrqNum, 
                                      iIrqEnableInRisingEdge)
    begin
    
      -- default assignment.
      iPushIrqNumStateNx <= iPushIrqNumState;
      iPushIrqNum <= false;
      
      case iPushIrqNumState is
    
        when Idle =>
    
          if iIrqEnableInRisingEdge then
            if iReadyToSyncIrqNum then
              iPushIrqNum <= true;
            else
              iPushIrqNumStateNx <= WaitUntilHandshakeIsReady;
            end if;
          end if;
    
        when WaitUntilHandshakeIsReady =>
      
          if iReadyToSyncIrqNum then
            iPushIrqNumStateNx <= Idle;
            iPushIrqNum <= true;
          end if;
      
        when others =>

          iPushIrqNumStateNx <= Idle;
        
      end case;
    end process PushIrqNumNextStatePrc;

    -- HandShakeIrqNum: ------------------------------------------------------
    -- !CLOCK BOUNDARY CROSSING! Besides clock crossing, this component also
    -- provides safe reset crossing from aDiagramReset to aBusReset domain.
    --
    -- !CONSTRAINTS! Constraints should be set on this component. Refer to the
    -- components source code for more information.
    --------------------------------------------------------------------------
    --vhook_e HandshakeBaseResetCross HandShakeIrqNum
    --vhook_a kDataWidth iIrqNum'length
    --vhook_a aResetToDlyPush open
    --vhook_a aResetToIResetFast open
    --vhook_a aPushToggleDly open
    --vhook_a aIReset aDiagramReset
    --vhook_a IClk IrqClk
    --vhook_a iPush iPushIrqNum
    --vhook_a iData iIrqNum
    --vhook_a iStoredData open
    --vhook_a iReady iHandshakeReady
    --vhook_a iOResetStatus iBusResetStatus
    --vhook_a aOReset aBusReset
    --vhook_a OClk BusClk
    --vhook_a oDataValid bIrqNumValid
    --vhook_a oDataAck true
    --vhook_af unsigned({oData}) {bIrqNum}
    HandShakeIrqNum: entity work.HandshakeBaseResetCross (rtl)
      generic map (
        kDataWidth => iIrqNum'length)
      port map (
        aResetToDlyPush    => open,
        aResetToIResetFast => open,
        aPushToggleDly     => open,
        aIReset            => aDiagramReset,
        IClk               => IrqClk,
        iPush              => iPushIrqNum,
        iData              => iIrqNum,
        iStoredData        => open,
        iReady             => iHandshakeReady,
        iOResetStatus      => iBusResetStatus,
        aOReset            => aBusReset,
        OClk               => BusClk,
        oDataValid         => bIrqNumValid,
        oDataAck           => true,
        unsigned(oData)    => bIrqNum);


    -- Making sure that ReadyToSyncIrqNum is qualified by handshake ready
    -- and BusResetStatus. This is because, while the bus is in reset
    -- we do not want the fpga vi to hang execution (iIrqEnableOut is not
    -- asserted until iPushIrqNum is set).
    iReadyToSyncIrqNum <= iHandShakeReady or iBusResetStatus;

    -- IrqEnableOut : --------------------------------------------------------
    -- This process generates EnableOut for the diagram IRQ number interface.
    -- Set EnableOut in the same cycle as we decide to push IRQ number to the
    -- bus clk domain.
    --------------------------------------------------------------------------
    IrqEnableOut : process(IrqClk, aDiagramReset)
    begin
      if aDiagramReset then
        iIrqEnableOut <= '0';
      elsif(rising_edge(IrqClk)) then
        if iIrqEnableClear = '1' then
          iIrqEnableOut <= '0';
        elsif (iIrqEnableIn = '1' and iPushIrqNum) then
          iIrqEnableOut <= '1';
        end if;
      end if;
    end process IrqEnableOut;
    
  end block IrqNumberFromDiagramBlk;
  
  -- IrqAckToDiagramBlk : ----------------------------------------------------
  -- This block handles receiving of IrqAck from software and synchronizing
  -- it to the Diagram components.
  ----------------------------------------------------------------------------
  IrqAckToDiagramBlk : block
    
    signal bPushIrqAck  : boolean;
    signal bReadyToSyncIrqAck : boolean;
    signal iIrqAckValid : boolean;
    signal iIrqAckFromHandshake : std_logic_vector (kNumVirtualInterrupts-1 downto 0);
    signal bRegPortReadyForIrqAck : boolean;
    signal bDiagramResetStatus : boolean;
  
  begin
    
    -- Push Ack to the ViClk domain whenever there is a write to the status
    -- register from software.
    bPushIrqAck <= bRegPortIn.Wt and bStatusAddrDecode;

    -- HandShakeIrqAck: ------------------------------------------------------
    -- !CLOCK BOUNDARY CROSSING! Besides clock crossing, this component also
    -- provides safe reset crossing from aBusReset to aDiagramReset domain.
    --
    -- !CONSTRAINTS! Constraints should be set on this component. Refer to the
    -- components source code for more information.
    --------------------------------------------------------------------------
    --vhook_e HandshakeBaseResetCross HandShakeIrqAck
    --vhook_a kDataWidth bRegPortIn.Data'length
    --vhook_a aResetToDlyPush open
    --vhook_a aResetToIResetFast open
    --vhook_a aPushToggleDly open
    --vhook_a aIReset aBusReset
    --vhook_a IClk BusClk
    --vhook_a iPush bPushIrqAck
    --vhook_a iData bRegPortIn.Data
    --vhook_a iStoredData open
    --vhook_a iReady bReadyToSyncIrqAck
    --vhook_a iOResetStatus bDiagramResetStatus
    --vhook_a aOReset aDiagramReset
    --vhook_a OClk IrqClk
    --vhook_a oDataValid iIrqAckValid
    --vhook_a oDataAck true
    --vhook_a oData iIrqAckFromHandshake
    HandShakeIrqAck: entity work.HandshakeBaseResetCross (rtl)
      generic map (
        kDataWidth => bRegPortIn.Data'length)
      port map (
        aResetToDlyPush    => open,
        aResetToIResetFast => open,
        aPushToggleDly     => open,
        aIReset            => aBusReset,
        IClk               => BusClk,
        iPush              => bPushIrqAck,
        iData              => bRegPortIn.Data,
        iStoredData        => open,
        iReady             => bReadyToSyncIrqAck,
        iOResetStatus      => bDiagramResetStatus,
        aOReset            => aDiagramReset,
        OClk               => IrqClk,
        oDataValid         => iIrqAckValid,
        oDataAck           => true,
        oData              => iIrqAckFromHandshake);

    -- Wire Ack EnableOut with Ack EnableIn.
    iIrqAckEnableOut <= iIrqAckEnableIn;
    
    -- IRQ Acknowledge is set for a single cycle. Qualify handshake output
    -- data with data valid.
    IrqStatusBits : for ackBit in 0 to kNumVirtualInterrupts-1 generate
      iIrqAck(ackBit) <= iIrqAckFromHandshake(ackBit) and to_StdLogic(iIrqAckValid);
    end generate IrqStatusBits;
    
    -- It is imperative that Ready signal going back to the Communication 
    -- Interface is qualified with iReady and iOResetStatus of the handshake 
    -- module. This is because:
    -- If only handshake ready was used, it would go low as soon as 
    -- DiagramReset asserted, and stall the communication interface until it
    -- timesout during a write access to a register in non-diagram reset 
    -- domain.
    bRegPortReadyForIrqAck <= bReadyToSyncIrqAck or bDiagramResetStatus;
    
    -- Only write access that may need to hold off ready is IrqAck.
    -- The idea is that we need to hold off register access ready while 
    -- waiting on the handshake because we could receive another IRQ 
    -- acknowledgement write and lose it.
    bRegPortOut.Ready <= bRegPortReadyForIrqAck;
    
  end block IrqAckToDiagramBlk;

end architecture behavior;
