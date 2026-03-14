-------------------------------------------------------------------------------
-- File: UserHdlWindow.vhd
-- Author: National Instruments
-- Workspace: PXIe-7903 HSS
-- Date: 26 August 2022
-------------------------------------------------------------------------------
-- (c) 2025 Copyright National Instruments Corporation
-- 
-- SPDX-License-Identifier: MIT
-------------------------------------------------------------------------------
--
-- Purpose:
--
-------------------------------------------------------------------------------



library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;


entity UserHdlWindow is
  port (
    -------------------------------------------------------------------------------------
    -- NI 7903 Required Signals
    -------------------------------------------------------------------------------------
    -------------------------------------------------------
    -- Reset
    -------------------------------------------------------
    -- Asynchronous reset signal from the LabVIEW FPGA environment.
    -- This signal *must* be present in the port interface for all IO Socket CLIPs.
    -- You should reset your CLIP logic whenever this signal is logic high.
    aResetSl                        : in  std_logic;

    -------------------------------------------------------
    -- REQUIRED Socket Signals
    -------------------------------------------------------
    -- Configuration
    aLmkI2cSda                      : inout std_logic;
    aLmkI2cScl                      : inout std_logic;
    aLmk1Pdn_n                      : out std_logic;
    aLmk2Pdn_n                      : out std_logic;
    aLmk1Gpio0                      : out std_logic;
    aLmk2Gpio0                      : out std_logic;
    aLmk1Status0                    : in std_logic;
    aLmk1Status1                    : in std_logic;
    aLmk2Status0                    : in std_logic;
    aLmk2Status1                    : in std_logic;
    aIPassPrsnt_n                   : in std_logic_vector(7 downto 0);
    aIPassIntr_n                    : in std_logic_vector(7 downto 0);
    aIPassSCL                       : inout std_logic_vector(11 downto 0);
    aIPassSDA                       : inout std_logic_vector(11 downto 0);
    aPortExpReset_n                 : out std_logic;
    aPortExpIntr_n                  : in std_logic;
    aPortExpSda                     : inout std_logic;
    aPortExpScl                     : inout std_logic;
    aIPassVccPowerFault_n           : in std_logic;

    -- Reserved Interfaces
    stIoModuleSupportsFRAGLs        : out std_logic;

    -------------------------------------------------------
    -- DIO Signals
    -------------------------------------------------------
    aDio                            : inout std_logic_vector(7 downto 0);

    -------------------------------------------------------
    -- AXI Communication Interfaces
    -------------------------------------------------------
    AxiClk                          : in  std_logic;
    xHostAxiStreamToClipTData       : in  std_logic_vector(31 downto 0);
    xHostAxiStreamToClipTLast       : in  std_logic;
    xHostAxiStreamFromClipTReady    : out std_logic;
    xHostAxiStreamToClipTValid      : in  std_logic;
    xHostAxiStreamFromClipTData     : out std_logic_vector(31 downto 0);
    xHostAxiStreamFromClipTLast     : out std_logic;
    xHostAxiStreamToClipTReady      : in  std_logic;
    xHostAxiStreamFromClipTValid    : out std_logic;
    xDiagramAxiStreamToClipTData    : in  std_logic_vector(31 downto 0);
    xDiagramAxiStreamToClipTLast    : in  std_logic;
    xDiagramAxiStreamFromClipTReady : out std_logic;
    xDiagramAxiStreamToClipTValid   : in  std_logic;
    xDiagramAxiStreamFromClipTData  : out std_logic_vector(31 downto 0);
    xDiagramAxiStreamFromClipTLast  : out std_logic;
    xDiagramAxiStreamToClipTReady   : in  std_logic;
    xDiagramAxiStreamFromClipTValid : out std_logic;

    -- AXI4 Lite interfaces
    xClipAxi4LiteMasterARAddr       : out std_logic_vector(31 downto 0);
    xClipAxi4LiteMasterARProt       : out std_logic_vector(2 downto 0);
    xClipAxi4LiteMasterARReady      : in  std_logic;
    xClipAxi4LiteMasterARValid      : out std_logic;
    xClipAxi4LiteMasterAWAddr       : out std_logic_vector(31 downto 0);
    xClipAxi4LiteMasterAWProt       : out std_logic_vector(2 downto 0);
    xClipAxi4LiteMasterAWReady      : in  std_logic;
    xClipAxi4LiteMasterAWValid      : out std_logic;
    xClipAxi4LiteMasterBReady       : out std_logic;
    xClipAxi4LiteMasterBResp        : in  std_logic_vector(1 downto 0);
    xClipAxi4LiteMasterBValid       : in  std_logic;
    xClipAxi4LiteMasterRData        : in  std_logic_vector(31 downto 0);
    xClipAxi4LiteMasterRReady       : out std_logic;
    xClipAxi4LiteMasterRResp        : in  std_logic_vector(1 downto 0);
    xClipAxi4LiteMasterRValid       : in  std_logic;
    xClipAxi4LiteMasterWData        : out std_logic_vector(31 downto 0);
    xClipAxi4LiteMasterWReady       : in  std_logic;
    xClipAxi4LiteMasterWStrb        : out std_logic_vector(3 downto 0);
    xClipAxi4LiteMasterWValid       : out std_logic;

    xClipAxi4LiteInterrupt          : in  std_logic;
    --vhook_nowarn xClipAxi4LiteInterrupt

    -------------------------------------------------------
    -- MGT Socket Interface
    -------------------------------------------------------
    -- These signals connect directly to the MGT pins, and should be connected to the
    -- user's IP.
    MgtRefClk_p                     : in  std_logic_vector(11 downto 0);
    MgtRefClk_n                     : in  std_logic_vector(11 downto 0);
    MgtPortRx_p                     : in  std_logic_vector(47 downto 0);
    MgtPortRx_n                     : in  std_logic_vector(47 downto 0);
    MgtPortTx_p                     : out std_logic_vector(47 downto 0);
    MgtPortTx_n                     : out std_logic_vector(47 downto 0)

  );
end UserHdlWindow;

architecture rtl of UserHdlWindow is

begin
  aLmk1Pdn_n <= '0';
  aLmk2Pdn_n <= '0';
  aLmk1Gpio0 <= '0';
  aLmk2Gpio0 <= '0';
  aPortExpReset_n <= '0';
  stIoModuleSupportsFRAGLs <= '0';
  xHostAxiStreamFromClipTReady <= '0';
  xHostAxiStreamFromClipTData <= (others => '0');
  xHostAxiStreamFromClipTLast <= '0';
  xHostAxiStreamFromClipTValid <= '0';
  xDiagramAxiStreamFromClipTReady <= '0';
  xDiagramAxiStreamFromClipTData <= (others => '0');
  xDiagramAxiStreamFromClipTLast <= '0';
  xDiagramAxiStreamFromClipTValid <= '0';
  xClipAxi4LiteMasterARAddr <= (others => '0');
  xClipAxi4LiteMasterARProt <= (others => '0');
  xClipAxi4LiteMasterARValid <= '0';
  xClipAxi4LiteMasterAWAddr <= (others => '0');
  xClipAxi4LiteMasterAWProt <= (others => '0');
  xClipAxi4LiteMasterAWValid <= '0';
  xClipAxi4LiteMasterBReady <= '0';
  xClipAxi4LiteMasterRReady <= '0';
  xClipAxi4LiteMasterWData <= (others => '0');
  xClipAxi4LiteMasterWStrb <= (others => '0');
  xClipAxi4LiteMasterWValid <= '0';
  MgtPortTx_p <= (others => '0');
  MgtPortTx_n <= (others => '0');

end rtl;
