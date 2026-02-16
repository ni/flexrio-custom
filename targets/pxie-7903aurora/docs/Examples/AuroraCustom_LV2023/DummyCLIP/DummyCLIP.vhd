


library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;



entity DummyCLIP is
  port (

    ---------------------------
    -- IO SOCKET SIGNALS
    ---------------------------
  
    
    aResetSl                        : in  std_logic;
   
    
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

    
    stIoModuleSupportsFRAGLs        : out std_logic;
   
    aDio                            : inout std_logic_vector(7 downto 0);
  
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
    


    MgtRefClk_p                     : in  std_logic_vector(11 downto 0);
    MgtRefClk_n                     : in  std_logic_vector(11 downto 0);
    MgtPortRx_p                     : in  std_logic_vector(47 downto 0);
    MgtPortRx_n                     : in  std_logic_vector(47 downto 0);
    MgtPortTx_p                     : out std_logic_vector(47 downto 0);
    MgtPortTx_n                     : out std_logic_vector(47 downto 0);

    --------------------------------
    -- LV IO SIGNALS
    --------------------------------
    
    dummysignal                  : out std_logic    
    

  );
end DummyCLIP;

architecture rtl of DummyCLIP is

begin


  dummysignal <= '0';  -- Dummy signal to prevent synthesis warnings

  
end rtl;