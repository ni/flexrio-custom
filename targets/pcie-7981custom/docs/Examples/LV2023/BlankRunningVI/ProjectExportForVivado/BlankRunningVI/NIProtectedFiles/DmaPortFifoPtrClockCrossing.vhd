-------------------------------------------------------------------------------
--
-- File: DmaPortFifoPtrClockCrossing.vhd
-- Author: Haider Khan
-- Original Project: LV FPGA Communication Interface
-- Date: 11 January 2008
--
-------------------------------------------------------------------------------
-- (c) 2008 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
-- The purpose of this module is to safely handshake values from one clock
-- domain to the other with the least number of clock cycles of the input
-- clock and output clock to reduce latency in transferring values.
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity DmaPortFifoPtrClockCrossing is
  generic (
    --kPtrWidth: This is the width of the pointer that needs to move
    --           accross the clock domain crossing.
    kPtrWidth : integer := 32;
    --kOutputResetValue: Value the output data resets to after aReset
    --                   asserts.
    kOutputResetValue : unsigned
  );
  port (
    --aReset: Asynchronous reset to the module.
    aReset:      in  boolean;
    -------------------------------------------------------------------------------------
    --Input Port
    -------------------------------------------------------------------------------------
    --IClk:   Input clock.
    IClk:        in  std_logic;
    --Push:   Signal used to initiate a push of the data from the IClk domain
    --        to the OClk domain.
    iPush:       in  boolean;
    --iData:  Data that is pused to the OClk domain.
    iData:       in  unsigned(kPtrWidth-1 downto 0) := (others => '0');

    -------------------------------------------------------------------------------------
    --Output Port
    -------------------------------------------------------------------------------------
    --OClk:   Output clock.
    OClk:        in  std_logic;
    --oData:  Safely synchronized copy of iData (when iPush asserted) in the OClk domain.
    oData:       out unsigned(kPtrWidth-1 downto 0)
  );
end DmaPortFifoPtrClockCrossing;

architecture rtl of DmaPortFifoPtrClockCrossing is

  type TxSm_t is (

    Idle,  --The state machine stays in the idle state and monitors the iPush signal.
           --Whenever iPush is true, it initiates a push of the data from the IClk
           --domain to the OClk domain.

    Push   --The state machine stays in the Push state till it receives an Ack from
           --the OClk domain. Once an Ack is received, the state machine initiates
           --a new push if push is true and if it is not true then it goes to the
           --Idle state.
    );
  signal iNextTxSmState,iTxSmState : TxSm_t;

  --Signals used by the IClk side:
  signal iAckRcvd_ms : boolean;
  signal iAckRcvd : boolean;
  signal iAckRcvdDlyd : boolean;
  signal iAck : boolean;
  signal iNextTogglePush, iTogglePush : boolean;
  signal iNextDataToPush, iDataToPush : unsigned(kPtrWidth-1 downto 0);

  --Signals used by the OClk side:
  signal oPushRcvd_ms : boolean;
  signal oPushRcvd : boolean;
  signal oPushRcvdDlyd : boolean;
  signal oAck : boolean;
  signal oDataSlv : std_logic_vector(oData'range);
  signal oDataEnable : boolean;

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of iAckRcvd_ms,iAckRcvd : signal is "true";
  attribute ASYNC_REG of oPushRcvd_ms,oPushRcvd : signal is "true";

begin

  ---------------------------------------------------------------------------------------
  --Transmit side
  ---------------------------------------------------------------------------------------

  --iPush can be tied to a logic high if one wants to send across pointers as soon as
  --the circuit frees up.

  --Bring over Ack from OClk domain to the IClk domain. Once the Ack is synchronized
  --to IClk, a one IClk cycle pulse is generated whenever the level changes (Ack is
  --toggled). It takes 3 IClk cycles to generate a valid iAck output after oAck
  --toggles.

  AckFFs:
  process(aReset, IClk)
  begin
    if aReset then
      iAckRcvd_ms <= false;
      iAckRcvd <= false;
      iAckRcvdDlyd <= false;
    elsif rising_edge(IClk) then
      iAckRcvd_ms <= oAck;
      iAckRcvd <= iAckRcvd_ms;
      iAckRcvdDlyd <= iAckRcvd;
    end if;
  end process;

  --Look for a toggle on the Ack signal
  iAck <= ((iAckRcvd and not iAckRcvdDlyd) or
          (not iAckRcvd and iAckRcvdDlyd));


  --The state machine handles the initiation of a push and monitors Ack.
  TxSmLogic:
  process(iTxSmState,iPush,iDataToPush,iTogglePush,iData,iAck)
  begin

    --Default values
    iNextTogglePush <= iTogglePush;
    iNextDataToPush <= iDataToPush;
    iNextTxSmState <= iTxSmState;

    case iTxSmState is
      when Idle =>
        if iPush then
          iNextTogglePush <= not iTogglePush;
          iNextDataToPush <= iData;
          iNextTxSmState <= Push;
        end if;

      when Push =>
        if iAck then
          --A new push can be initiated from here instead of going
          --back to the Idle state. This saves 1 IClk cycle of latency.
          if iPush then
            iNextTogglePush <= not iTogglePush;
            iNextDataToPush <= iData;
          else
            iNextTxSmState <= Idle;
          end if;
        end if;

      when others =>
          iNextTxSmState <= Idle;

    end case;
  end process;

  TxFFs:
  process(aReset, IClk)
  begin
    if aReset then
      iTogglePush <= false;
      iDataToPush <= (others => '0');
      iTxSmState <= Idle;
    elsif rising_edge(IClk) then
      iTogglePush <= iNextTogglePush;
      iDataToPush <= iNextDataToPush;
      iTxSmState <= iNextTxSmState;
    end if;
  end process;


  --vscan Begin Exception FifoPtrClockCrossingExc
  --vscan # Handshaking is used to ensure that this assignment is done safely.
  --vscan Path: *[DmaPortFifoPtrClockCrossing]DataReg/[DFlopSlvResetVal]cD
  --vscan NewQ: *[DmaPortFifoPtrClockCrossing]DataReg/[DFlopSlvResetVal]cLclQ
  --vscan End Exception

  ---------------------------------------------------------------------------------------
  --Receive Side
  ---------------------------------------------------------------------------------------
  --The receive side runs on OClk. There is no need of a state machine in the OClk
  --domain. The first process synchronizes the push signal coming from the IClk domain.
  --The synchronized signal along with a delayed version of the signal is used to
  --detect a level change to latch the data in the OClk domain. The Ack going back
  --to the IClk domain is toggled when a toggle on push is observed. The toggle of
  --Ack concides with latching of data in the OClk domain.

  PushFFs:
  process(aReset,OClk)
  begin
    if aReset then
      oPushRcvd_ms <= false;
      oPushRcvd <= false;
      oPushRcvdDlyd <= false;
    elsif rising_edge(OClk) then
      oPushRcvd_ms <= iTogglePush;
      oPushRcvd <= oPushRcvd_ms;
      oPushRcvdDlyd <= oPushRcvd;
    end if;
  end process;


  -- It is important that the enable for oData is tied directly to the clock enable
  -- for the oData flop in order to prevent asynchronous data (in the iClk domain)
  -- from creating metastability on the oData flop.  XST doesn't support
  -- syn_direct_enable or any equivalent, so I use the DFlop components to ensure that
  -- the enable is tied directly to the flop enables.

  --vhook_e DFlopSlvResetVal DataReg
  --vhook_a kWidth kOutputResetValue'length
  --vhook_a kResetVal std_logic_vector(kOutputResetValue)
  --vhook_a Clk OClk
  --vhook_a cEn oDataEnable
  --vhook_a cD std_logic_vector(iDataToPush)
  --vhook_a cQ oDataSlv
  DataReg: entity work.DFlopSlvResetVal (rtl)
    generic map (
      kWidth    => kOutputResetValue'length,             -- in  integer
      kResetVal => std_logic_vector(kOutputResetValue))  -- in  std_logic_vector
    port map (
      aReset => aReset,                         -- in  boolean
      cEn    => oDataEnable,                    -- in  boolean
      Clk    => OClk,                           -- in  std_logic
      cD     => std_logic_vector(iDataToPush),  -- in  std_logic_vector(kWidth-1 downto 0
      cQ     => oDataSlv);                      -- out std_logic_vector(kWidth-1 downto 0

  oData <= unsigned(oDataSlv);

  RxFFs:
  process(aReset,OClk)
  begin
    if aReset then
      oAck <= false;
    elsif rising_edge(OClk) then
      if oDataEnable then
        oAck <= not oAck;
      end if;
    end if;
  end process;

  --Look for push toggling to latch the data and to toggle the Ack going back
  --to the IClk domain.
  oDataEnable <= (oPushRcvd xor oPushRcvdDlyd);

end rtl;
