package PkgNiFpgaSimulationModelPrivate is

  constant kBaseAddressOnDevice : natural := 16#0#;
  
  ---------------------------------------------------------------------------------------
  -- Define a signal which is used for closing MMCM simulation model. This signal is 
  -- driven from NiFpgaSimulationModel, taking the value of fiStopSim signal and is  
  -- used in TheWindow.vhd, being connected to PwrDwn pin of MMCM Wrapper instance.   
  ---------------------------------------------------------------------------------------
  
  signal fiPkgStopSim : boolean;

end package PkgNiFpgaSimulationModelPrivate;
