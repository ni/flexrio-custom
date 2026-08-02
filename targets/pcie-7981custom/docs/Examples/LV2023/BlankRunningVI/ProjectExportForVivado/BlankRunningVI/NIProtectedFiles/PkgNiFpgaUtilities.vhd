-------------------------------------------------------------------------------
--
-- File: PkgNiFpgaUtilities.vhd
-- Author: Newton Petersen, Dustyn Blasig, Kristin Hampsten
-- Original Project: External Clocks
-- Date: 6 November 2007
--
-------------------------------------------------------------------------------
-- (c) 2007 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--   This package provides miscellaneous types and functions meant to be
--   applicable in a wide variety of situations.
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;

package PkgNiFpgaUtilities is

  -----------------------------------------------------------------------------
  -- TYPES
  -----------------------------------------------------------------------------

  type ClockEdge_t is (
    kRising,
    kFalling
    );

  type TimeoutMode_t is (
    kZeroTimeout,
    kFiniteTimeout,
    kInfiniteTimeout
    );

  type DigitalInputWaitMethod_t is (
    kWaitOnRisingEdge,
    kWaitOnFallingEdge,
    kWaitOnAnyEdge,
    kWaitOnHighLevel,
    kWaitOnLowLevel
    );

  type FeedbackNodeInitMethod_t is (
    kFirstCallInit,
    kCompileLoadInit,
    kLoopInit
    );

  type FeedbackNodeMuxLocation_t is (
    kAfterRegister,
    kBeforeRegister,
    kAutoMuxPlacement
    );

  type TimeUnits_t is (
    kTicks,
    kMicroSeconds,
    kMilliSeconds
  );

  -----------------------------------------------------------------------------
  -- CONSTANTS
  -----------------------------------------------------------------------------

  -- Enables the printing of notes. During simulation, these will act as
  -- expected. For synthesis, the note will be printed once for each function
  -- or procedure call as a component is instantiated. THIS SHOULD BE SET TO
  -- FALSE FOR SHIPPING CODE.

  constant kEnableNotes : boolean := false;

  -----------------------------------------------------------------------------
  -- FUNCTIONS
  -----------------------------------------------------------------------------

  -- Conversions --------------------------------------------------------------

  function resize(
    data     : std_logic_vector;
    length   : positive;
    issigned : boolean := false)
    return std_logic_vector;

  function CreateInitArrayIfUnwired(
    initvecin : std_logic_vector;
    kinittermwidth : natural)
    return std_logic_vector;

  function ResizeInitTermToRegWidth(
    initvecin : std_logic_vector;
    kinitvecinlength : natural;
    kinitvecoutlength : natural;
    kwidth : natural)
    return std_logic_vector;

  -- Miscellaneous ------------------------------------------------------------

  function AddressOutOfRange (
    AddressWidth   : natural := 32;
    MemoryDepth    : natural := 1024;
    ValidationMode : natural := 2;
    Address         : std_logic_vector)
    return boolean;

  procedure note(str : in string);

  -- ReportError ------------------------------------------------------------
  --SwExternalError, SwInternalError, and SwWarning have error codes in the error
  --code database and therefore are software errors.
  --The other error types are assertions that are in the VHDL.
  --For SwExternalError and ExternalError, you must provide some instruction
  --via the ShortDescription to the user how to avoid the error.  The other
  --error types are failures; the user will be instructed to contact NI.
  type ErrorType_t is (InternalError, ExternalError, SwExternalError,
                       SwInternalError, SwWarning);

  procedure ReportError
    (ErrorType : in ErrorType_t := InternalError;
    ErrorCode : integer := -1;
    ShortDescription : string;
    AssertionCondition : boolean := false);


end PkgNiFpgaUtilities;

package body PkgNiFpgaUtilities is

  -----------------------------------------------------------------------------
  -- FUNCTIONS
  -----------------------------------------------------------------------------

  -- Conversions --------------------------------------------------------------

  function resize(
    data     : std_logic_vector;
    length   : positive;
    issigned : boolean := false)
    return std_logic_vector
  is
    variable ret : std_logic_vector(length-1 downto 0);
  begin
    if issigned then
      ret := std_logic_vector(resize(signed(data), length));
    else
      ret := std_logic_vector(resize(unsigned(data), length));
    end if;
    return ret;
  end function resize;

  --This function will check if initvecin is an empty array. (Init unwired)
  --If so, output an zero array with length kinittermwidth as initial value.
  function CreateInitArrayIfUnwired(
    initvecin : std_logic_vector;
    kinittermwidth : natural)
    return std_logic_vector
  is
    variable initvecout : std_logic_vector(kinittermwidth-1 downto 0);
  begin
    if initvecin'length = kinittermwidth then
      initvecout := initvecin;
      if kinittermwidth = 1 then
        initvecout(0) := initvecin(0);
      end if;
    else
      initvecout := (others => '0');
      assert( initvecin'length = 0 )
        report "Invalid length of Initial Value Constant."
      severity warning;
    end if;
    return initvecout;
  end function CreateInitArrayIfUnwired;

  --This function makes the length of initial value vector to the size of registers.
  --If kinitvecinlength >= kinitvecoutlength, the function truncates input.
  --If kinitvecinlength < kinitvecoutlength, the function expands input with
  --the last element of input. kwidth is the width of one element.
  function ResizeInitTermToRegWidth(
    initvecin : std_logic_vector;
    kinitvecinlength : natural;
    kinitvecoutlength : natural;
    kwidth : natural)
    return std_logic_vector
  is
    variable initvecout : std_logic_vector(kinitvecoutlength-1 downto 0);
    variable elmvec : std_logic_vector(kwidth-1 downto 0);
    variable num : natural;
  begin
    elmvec := initvecin(kwidth-1 downto 0);
    if kinitvecinlength >= kinitvecoutlength then
      initvecout := initvecin(kinitvecinlength-1
                                downto kinitvecinlength-kinitvecoutlength);
    else
      num := (kinitvecoutlength-kinitvecinlength) / kwidth;
      initvecout( kinitvecoutlength-1 downto kinitvecoutlength-kinitvecinlength )
                                                                     := initvecin;
      for i in 0 to num-1 loop
        initvecout( (i+1)*kwidth-1 downto i*kwidth ) := elmvec;
      end loop;
    end if;
    return initvecout;
  end function ResizeInitTermToRegWidth;

  -- Miscellaneous ------------------------------------------------------------

  -- This function if used to verify whether or not a particular address is
  -- within the address range set for a memory block. It has three modes:
  --   (0) None   - Pass through mode
  --   (1) Simple - Only high-order bits are checked (default for PO2)
  --   (2) Safe   - Full comparison if needed, PO2 looks at high order bits
  function AddressOutOfRange (
    AddressWidth   : natural := 32;
    MemoryDepth    : natural := 1024;
    ValidationMode : natural := 2;
    Address         : std_logic_vector)
    return boolean
  is
    variable RequiredAddressWidth   : natural;
    variable AddressWidthsIdentical : boolean;
    variable PowerOf2               : boolean;
    variable SafeModeRequired       : boolean;
    variable SimpleModeRequired     : boolean;
    variable NoneModeRequired       : boolean;
    variable ModeIsSafe             : boolean;
    variable ModeIsSimple           : boolean;
    variable ModeIsNone             : boolean;
    variable OutOfRange              : boolean;
  begin
    RequiredAddressWidth := Log2(MemoryDepth);
    AddressWidthsIdentical := AddressWidth = RequiredAddressWidth;
    PowerOf2 := RequiredAddressWidth /= Log2(MemoryDepth+1);

    SafeModeRequired := not PowerOf2;
    SimpleModeRequired := not AddressWidthsIdentical;
    NoneModeRequired := not ( SafeModeRequired  or SimpleModeRequired );

    ModeIsSafe := (ValidationMode = 2) and SafeModeRequired;
    ModeIsSimple := (ValidationMode = 1 or (ValidationMode = 2 and not ModeIsSafe)) and SimpleModeRequired;
    ModeIsNone := ValidationMode = 0 or not ( ModeIsSimple or ModeIsSafe );

    if ModeIsSimple then -- safe address validation
      OutOfRange := to_boolean(OrVector(Address(AddressWidth-1 downto RequiredAddressWidth)));
    elsif ModeIsSafe then -- simple address validation
      OutOfRange := unsigned(Address) >= to_unsigned(MemoryDepth, AddressWidth);
    elsif ModeIsNone then -- no address validation
      OutOfRange := false;
    end if;

    return OutOfRange;
  end function AddressOutOfRange;


  procedure note(str : in string) is
  begin
    if kEnableNotes then
      assert false report str severity note;
    end if;
  end procedure note;

  -- ReportError --------------------------------------------------------------
  -- This error function prints assertions in a fixed format.  It differentiates
  -- internal and external software errors (for simulation) as well as internal assertions.

  function ReturnErrorCodeString (ErrorCode : integer; ErrorType : ErrorType_t) return string is
  begin
    case ErrorType is
      when SwInternalError | SwExternalError =>
        return "Error "&integer'image(ErrorCode) &" occurred at an unidentified location" & LF;
      when SwWarning =>
        return "Warning " & integer'image(ErrorCode) &
               " occurred at an unidentified location" & LF;
      when others =>
        return "Error occurred" & LF;
    end case;
  end function ReturnErrorCodeString;

  function ReturnPrefix (ErrorType : in ErrorType_t) return string is
    constant kContactNiString : string := "Please contact National Instruments technical support at ni.com/support with the following information:";
    constant kSwInternalError : string := "An internal software error in the LabVIEW FPGA Module has occurred.  " & kContactNiString;
    constant kSwExternalError : string := "A software error has occurred.  ";
    constant kExternalError : string :=  "An error in the LabVIEW FPGA Module has occurred.  ";
    constant kInternalError : string := kExternalError & kContactNiString;
    constant kSwWarning : string := "A software warning has occurred.";
  begin
    case ErrorType is
      when SwInternalError => return kSwInternalError;
      when SwExternalError => return kSwExternalError;
      when ExternalError => return kExternalError;
      when InternalError => return kInternalError;
      when SwWarning => return kSwWarning;
    end case;
  end function ReturnPrefix;

   procedure ReportError
    (ErrorType : in ErrorType_t := InternalError;
    ErrorCode : integer := -1;
    ShortDescription : string;
    AssertionCondition : boolean := false
    ) is
      variable SeverityLevel : severity_level;
    begin

      if not AssertionCondition then

        case ErrorType is
          when ExternalError | SwExternalError =>
            SeverityLevel := error;
          when InternalError | SwInternalError =>
            SeverityLevel := failure;
          when SwWarning =>
            SeverityLevel := warning;
        end case;


        assert false
          report
            LF
            & "==================================================="
            & LF &
            ReturnErrorCodeString(ErrorCode,ErrorType)
            & LF
            & "Possible reason(s):  " & LF
            & LF
            & "LabVIEW FPGA:  " & ReturnPrefix(ErrorType) & LF
            & LF
            & ShortDescription & LF
            & "==================================================="
          severity SeverityLevel;

        end if;

    end procedure ReportError;

end package body PkgNiFpgaUtilities;
