library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.PkgNiUtilities.all;
use work.PkgRegister.all;

entity NiFpgaAG_BlankRunningVI is
		port (
			reset : in std_logic;
			enable_in : in std_logic;
			enable_out : out std_logic;
			enable_clr : in std_logic;
			PllClk80 : in std_logic;
			ReliableClkIn : in std_logic;
			BusClk : in std_logic;
			aBusReset : in std_logic;
			bIrqToInterface : out std_logic_vector(65 downto 0);
			dInputStreamInterfaceFromFifo : out std_logic_vector(19391 downto 0);
			dInputStreamInterfaceToFifo : in std_logic_vector(3839 downto 0);
			dOutputStreamInterfaceFromFifo : out std_logic_vector(4543 downto 0);
			dOutputStreamInterfaceToFifo : in std_logic_vector(21247 downto 0);
			dNiFpgaMasterReadDataToMaster : in std_logic_vector(19519 downto 0);
			dNiFpgaMasterReadRequestFromMaster : out std_logic_vector(5823 downto 0);
			dNiFpgaMasterReadRequestToMaster : in std_logic_vector(63 downto 0);
			dNiFpgaMasterWriteDataFromMaster : out std_logic_vector(16383 downto 0);
			dNiFpgaMasterWriteDataToMaster : in std_logic_vector(3071 downto 0);
			dNiFpgaMasterWriteRequestFromMaster : out std_logic_vector(5823 downto 0);
			dNiFpgaMasterWriteRequestToMaster : in std_logic_vector(63 downto 0);
			dNiFpgaMasterWriteStatusToMaster : in std_logic_vector(959 downto 0);
			bRegPortIn : in std_logic_vector(50 downto 0);
			bRegPortOut : out std_logic_vector(33 downto 0);
			bBusReset : in std_logic;
			DmaClk : in std_logic;
			bIoWtToEnSafeBusCrossing : in std_logic;
			rDiagramResetAssertionErrIn : in std_logic;
			rGatedBaseClkStartupErr : in std_logic;
			rDerivedClkStartupErr : in std_logic;
			rInternalClksValidIn : in std_logic;
			rEnableClksForViRunOut : out std_logic;
			bCommunicationTimeoutIn : in std_logic;
			rDiagramResetStatusIn : in std_logic;
			rDerivedClksValid : in std_logic;
			rDiagramResetIn : in std_logic;
			rDerivedClockLostLockError : out std_logic;
			TopLvClk : in std_logic;
			tDiagramEnableIn : out std_logic;
			tDiagramEnableClear : out std_logic;
			tDiagramEnableOut : in std_logic;
			rAssumeExternalClkInvalid : out std_logic;
			rDerivedFromExternalValid : in std_logic;
			rDiagramResetAssertionErrOut : out std_logic;
			rInternalClksValidOut : out std_logic;
			rEnableClksForViRunIn : in std_logic;
			rSafeToEnableGatedClks : out std_logic;
			rGatedBaseClksValid : in std_logic;
			rDiagramResetStatusOut : out std_logic;
			rDiagramResetOut : out std_logic;
			rDcmPllSourceClksValidOut : out std_logic;
			rBaseClksValid : in std_logic;
			aDiagramResetOut : out std_logic
		);
end NiFpgaAG_BlankRunningVI;

architecture vhdl_labview of NiFpgaAG_BlankRunningVI is

	constant c_0 : std_logic_vector(0 downto 0) := "0";
	signal ei00000001 : std_logic;
	signal eo00000001 : std_logic;
	signal ei00000003 : std_logic;
	signal eo00000003 : std_logic;
	signal subdiag_enable_00000004 : std_logic;
	signal subdiag_done_00000004 : std_logic;
	signal subdiag_clear_00000004 : std_logic;
	signal lt00000002 : std_logic_vector(0 downto 0);
	signal lc00000002 : std_logic_vector(31 downto 0);
	signal li00000002 : std_logic;
	signal res00000007_wi : std_logic_vector(1 downto 0);
	signal res00000007_wo : std_logic_vector(0 downto 0);
	signal fromArbToRes0000000b : std_logic_vector(33 downto 0);
	signal fromResToArb0000000b : std_logic_vector(50 downto 0);
	signal resholder00000000ToArb0000000b : std_logic_vector(33 downto 0);
	signal arb0000000bToResholder00000000 : std_logic_vector(50 downto 0);
	signal res0000000e_wi : std_logic_vector(1 downto 0);
	signal res0000000e_wo : std_logic_vector(32 downto 0);
	signal res00000010_wi : std_logic_vector(33 downto 0);
	signal res00000010_wo : std_logic_vector(0 downto 0);
	signal res00000012_wi : std_logic_vector(1 downto 0);
	signal res00000012_wo : std_logic_vector(32 downto 0);
	signal res00000014_wi : std_logic_vector(33 downto 0);
	signal res00000014_wo : std_logic_vector(0 downto 0);
	signal res00000016_wi : std_logic_vector(1 downto 0);
	signal res00000016_wo : std_logic_vector(128 downto 0);

begin
	n_NiFpgaAG_00000000_WhileLoop_Diagram : entity work.NiFpgaAG_00000000_WhileLoop
		port map(
			reset => reset,
			enable_in => ei00000001,
			enable_out => eo00000001,
			enable_clr => subdiag_clear_00000004,
			iteration => lc00000002,
			cont => lt00000002
		);

	n_While_Loop_43: entity work.whileloop (rtl)
		generic map (
			kNeverEnds => 0,
			kDiagramWithInit => 0,
			kJustDiagram => 0,
			kCounterUnconnected => 0,
			INIT_NEEDED => 0,
			STOP_IF_TRUE => 1,
			kRegisterMode => 1
		)
		port map(
			Clk => PllClk80,
			reset => reset,
			enable_in => ei00000003,
			enable_out => eo00000003,
			enable_clr => enable_clr,
			subdiag_en => subdiag_enable_00000004,
			subdiag_done => subdiag_done_00000004,
			subdiag_clr => subdiag_clear_00000004,
			iteration => lc00000002,
			loopinit => li00000002,
			cont => lt00000002
		);

	n_InvisibleResholder : entity work.InvisibleResholder
		generic map(
			kbusholddummyWidthOut => 2,
			kbusholddummyWidthIn => 1
		)
		port map(
			Clk => PllClk80,
			reset => reset,
			ToResbusholddummy => res00000007_wi,
			FromResbusholddummy => res00000007_wo
		);

	n_bushold : entity work.bushold
		generic map(
			kdummyWidthIn => 2,
			kdummyWidthOut => 1,
			kInterfaceMiteIoLikeWidthOut => 34,
			kInterfaceMiteIoLikeWidthIn => 51,
			kViControlHostReadWidthOut => 2,
			kViControlHostReadWidthIn => 33,
			kViControlHostWriteWidthOut => 34,
			kViControlHostWriteWidthIn => 1,
			kDiagramResetHostReadWidthOut => 2,
			kDiagramResetHostReadWidthIn => 33,
			kDiagramResetHostWriteWidthOut => 34,
			kDiagramResetHostWriteWidthIn => 1,
			kViSignatureHostReadWidthOut => 2,
			kViSignatureHostReadWidthIn => 129
		)
		port map(
			BusClk => BusClk,
			ReliableClkIn => ReliableClkIn,
			reset => reset,
			dummyFromReshold => res00000007_wi,
			dummyToReshold => res00000007_wo,
			busClkToResInterfaceMiteIoLike => resholder00000000ToArb0000000b,
			busClkFromResInterfaceMiteIoLike => arb0000000bToResholder00000000,
			busClkToResViControlHostRead => res0000000e_wi,
			busClkFromResViControlHostRead => res0000000e_wo,
			busClkToResViControlHostWrite => res00000010_wi,
			busClkFromResViControlHostWrite => res00000010_wo,
			busClkToResDiagramResetHostRead => res00000012_wi,
			busClkFromResDiagramResetHostRead => res00000012_wo,
			busClkToResDiagramResetHostWrite => res00000014_wi,
			busClkFromResDiagramResetHostWrite => res00000014_wo,
			busClkToResViSignatureHostRead => res00000016_wi,
			busClkFromResViSignatureHostRead => res00000016_wo,
			aBusReset => aBusReset
		);

	n_Interface : entity work.Interface
		generic map(
			kMiteIoLikeWidthIn => 34,
			kMiteIoLikeWidthOut => 51
		)
		port map(
			DmaClk => DmaClk,
			BusClk => BusClk,
			PllClk80 => PllClk80,
			reset => reset,
			busClkMiteIoLikeFromReshold => fromArbToRes0000000b,
			busClkMiteIoLikeToReshold => fromResToArb0000000b,
			aBusReset => aBusReset,
			bIrqToInterface => bIrqToInterface,
			dInputStreamInterfaceFromFifo => dInputStreamInterfaceFromFifo,
			dInputStreamInterfaceToFifo => dInputStreamInterfaceToFifo,
			dOutputStreamInterfaceFromFifo => dOutputStreamInterfaceFromFifo,
			dOutputStreamInterfaceToFifo => dOutputStreamInterfaceToFifo,
			dNiFpgaMasterReadDataToMaster => dNiFpgaMasterReadDataToMaster,
			dNiFpgaMasterReadRequestFromMaster => dNiFpgaMasterReadRequestFromMaster,
			dNiFpgaMasterReadRequestToMaster => dNiFpgaMasterReadRequestToMaster,
			dNiFpgaMasterWriteDataFromMaster => dNiFpgaMasterWriteDataFromMaster,
			dNiFpgaMasterWriteDataToMaster => dNiFpgaMasterWriteDataToMaster,
			dNiFpgaMasterWriteRequestFromMaster => dNiFpgaMasterWriteRequestFromMaster,
			dNiFpgaMasterWriteRequestToMaster => dNiFpgaMasterWriteRequestToMaster,
			dNiFpgaMasterWriteStatusToMaster => dNiFpgaMasterWriteStatusToMaster,
			bRegPortIn => bRegPortIn,
			bRegPortOut => bRegPortOut,
			bBusReset => bBusReset
		);

	ViControlx : entity work.ViControl (rtl) 
   generic map (
      kHostReadWidthIn => 2,
      kHostReadWidthOut => 33,
      kHostWriteWidthIn => 34,
      kHostWriteWidthOut => 1,
      kAutoRun => work.PkgCommIntConfiguration.kAutoRun,
      kInitDuration => 0,
      kAllowEnableRemoval => false
  )

  port map (
      BusClk => BusClk,
      ReliableClk => ReliableClkIn,
      aDiagramReset => to_Boolean(reset),
      bHostReadIn => res0000000e_wi,
      bHostReadOut => res0000000e_wo,
      bHostWriteIn => res00000010_wi,
      bHostWriteOut => res00000010_wo,
      aBusReset => to_Boolean(aBusReset),
      bBusReset => to_Boolean(bBusReset),
      bIoWtToEnSafeBusCrossing => to_Boolean(bIoWtToEnSafeBusCrossing),
      rDiagramResetAssertionErr => to_Boolean(rDiagramResetAssertionErrIn),
      rGatedBaseClkStartupErr => to_Boolean(rGatedBaseClkStartupErr),
      rDerivedClkStartupErr => to_Boolean(rDerivedClkStartupErr),
      rInternalClksValid => to_Boolean(rInternalClksValidIn),
      rEnableClksForViRun => rEnableClksForViRunOut,
      bCommunicationTimeout => to_Boolean(bCommunicationTimeoutIn),
      rDiagramResetStatus => to_Boolean(rDiagramResetStatusIn),
      rDerivedClksValid => to_Boolean(rDerivedClksValid),
      rDiagramReset => to_Boolean(rDiagramResetIn),
      rDerivedClockLostLockError => rDerivedClockLostLockError,
      TopLvClk => TopLvClk,
      tDiagramEnableIn => tDiagramEnableIn,
      tDiagramEnableClear => tDiagramEnableClear,
      tDiagramEnableOut => tDiagramEnableOut
  );

	DiagramResetx : entity work.DiagramReset (rtl) 
   generic map (
      kHostReadWidthIn => 2,
      kHostReadWidthOut => 33,
      kHostWriteWidthIn => 34,
      kHostWriteWidthOut => 1,
      kDiagRstDeAsrtPropDlyWait => 103,
      kDiagRstAssertionDuration => 21,
      kAllowEnableRemoval => false
  )

  port map (
      BusClk => BusClk,
      ReliableClk => ReliableClkIn,
      bHostReadIn => res00000012_wi,
      bHostReadOut => res00000012_wo,
      bHostWriteIn => res00000014_wi,
      bHostWriteOut => res00000014_wo,
      aBusReset => to_Boolean(aBusReset),
      bIoWtToEnSafeBusCrossing => to_Boolean(bIoWtToEnSafeBusCrossing),
      rDerivedClksValid => to_Boolean(rDerivedClksValid),
      rAssumeExternalClkInvalid => rAssumeExternalClkInvalid,
      rDerivedFromExternalValid => to_Boolean(rDerivedFromExternalValid),
      rDiagramResetAssertionErr => rDiagramResetAssertionErrOut,
      rInternalClksValid => rInternalClksValidOut,
      rEnableClksForViRun => to_Boolean(rEnableClksForViRunIn),
      rSafeToEnableGatedClks => rSafeToEnableGatedClks,
      rGatedBaseClksValid => to_Boolean(rGatedBaseClksValid),
      rDiagramResetStatus => rDiagramResetStatusOut,
      rDiagramReset => rDiagramResetOut,
      rDcmPllSourceClksValid => rDcmPllSourceClksValidOut,
      rBaseClksValid => to_Boolean(rBaseClksValid),
      aDiagramReset => aDiagramResetOut
  );

	n_ViSignature : entity work.ViSignature
		generic map(
			kHostReadWidthIn => 2,
			kHostReadWidthOut => 129
		)
		port map(
			Clk => BusClk,
			reset => reset,
			clkHostReadFromReshold => res00000016_wi,
			clkHostReadToReshold => res00000016_wo
		);

	n_CustomArbForMiteIoLikePortOnResInterface : entity work.CustomArbForMiteIoLikePortOnResInterface
		generic map(
			kNumResholders => 1,
			kResWidthIn => 34,
			kResWidthOut => 51,
			kResName => "Interface",
			kResPortName => "MiteIoLike"
		)
		port map(
			Clk => BusClk,
			reset => reset,
			interfaceClockToRes => fromArbToRes0000000b,
			interfaceClockFromRes => fromResToArb0000000b,
			interfaceClockFromResholder00000000 => resholder00000000ToArb0000000b,
			interfaceClockToResholder00000000 => arb0000000bToResholder00000000
		);

	subdiag_done_00000004 <= eo00000001;
	ei00000001 <= subdiag_enable_00000004;
	ei00000003 <= enable_in;
	enable_out <= eo00000003;

end vhdl_labview;

