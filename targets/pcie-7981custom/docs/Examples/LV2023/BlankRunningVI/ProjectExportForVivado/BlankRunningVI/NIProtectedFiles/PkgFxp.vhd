-- -----------------------------------------------------------------------------
--
-- File: PkgFxp.vhd
-- Author: Dustyn Blasig
-- Original Project: NI LV FPGA Fixed-Point
-- Date: 28 December 2006
--
-- -----------------------------------------------------------------------------
-- (c) 2006 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
--
-- SPECIAL NOTE ABOUT FORMATTING OF THIS FILE
-- "--!" "@brief" and "@details" are special markup so that we can generate
-- html documentation viewable to the end user for the simulation feature
-- using Doxygen.  Be careful when editing comments in this file and 
-- make sure to diff the results of the Doxygen 
-------------------------------------------------------------------------------
library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.PkgNiUtilities.all;
use work.PkgNiFpgaUtilities.all;

--! @brief Purpose: Top-level fixed point utility package. 
--! @details This package includes the actual fixed-point types and many 
--! utility functions for use with those types. Most of this package is 
--! compatible with the VHDL 2008 fixed_pkg vhdl standards.
--!
--! The two key types are tFxpSgn and tFxpUns. 
--! Conversion and cast operators have been provided for going to and from other types.
--! 
--! Several abbreviations found in this package:
--!   IWL - Integer word length, the portion of the number to the left of the
--!     binary point.
--!   FWL - Fractional word length, the portion of the number to the right of
--!     the binary point.
--!   WL - Word length - The length of the entire number. Can be substituted
--!     with "arg'length".
--!
--! There are three fixed-point types included in this package. A fixed-point
--! generic type that has no sign, unsigned, and signed. The fixed-point number
--! is described with a WL, and IWL, and a FWL. The WL is simply length of the
--! vector. The IWL and FWL are described by the range of the vector. Therefore,
--! a vector of range 5 downto -6 would have an an IWL of 6 and a FWL of 6.
--! Notice that FWL is correctly negated to make it easier to declare a
--! fixed-point signal or variable. The binary point is always assumed to be
--! located between the 0 and -1 indices.
--! <pre><code> <!-- Necessary to align this ascii art correctly -->
--!           |<----------------.---------------->|
--! IWL --> 6 |+5 +4 +3 +2 +1 +0 -1 -2 -3 -4 -5 -6| <--! -FWL
--! </code></pre>
-------------------------------------------------------------------------------


package PkgFxp is

  -------------------------------------------------------------------------------
  -- Basic Fixed-Point Types
  -------------------------------------------------------------------------------

  -- Brief limited to a single line.  Details can be multi-line.
  -- Brief and details are concatenated.
  
  --! Unsigned fixed-point type
  type FxpUns_t is array (integer range <>) of std_logic;
  --! Signed fixed-point type
  type FxpSgn_t is array (integer range <>) of std_logic;
  --! @brief Generic fixed-point type that has no sign.
  --! @details Functions using this type must supply whether it is 
  --! signed. Rarely should this type be required outside the 
  --! fixed-point package and its associated components.
  type FxpGen_t is array (integer range <>) of std_logic;

  --! Unsigned fixed-point type provided for the simulation testbench
  subtype tFxpUns is FxpUns_t;
  --! Signed fixed-point type provided for the simulation testbench
  subtype tFxpSgn is FxpSgn_t;
  --! @brief Generic fixed-point type that has no sign.
  --! @details Functions using this type must supply whether it is 
  --! signed. Rarely should this type be required outside the 
  --! fixed-point package and its associated components.
  subtype tFxpGen is FxpGen_t;
  
  --! @brief Meta data type used to describe the above types
  --! @details This type describes the signed-ness, the width
  --! and the number of Integer bits for a specific fixed-point 
  --! type. This is especially useful for the generic fixed-point 
  --! type.
  type FxpMeta_t is record
    kSigned    : boolean;
    kIwl, kFwl : integer;
  end record;

  -- Several functions in PkgFxpArithmetic use the PrintNote procedure
  -- to print helpful information during simulation.  However, most
  -- of the time you don't want to see them.  Set the kFxpEnableNotes
  -- constant to true to enable the notes.

  --Internal use only
  constant kFxpEnableNotes : boolean := false;

  --! @brief Maximum word-length allowed for signals going to and from LabVIEW
  --! @details Intermediate signals need not worry about the limit.
  constant kFxpMaxWl  : positive := 64;
  --! @brief Maximum Integer word-length allowed for signals going to and from LabVIEW
  --! @details Intermediate signals need not worry about the limit.
  constant kFxpMaxIwl : positive := 1024;
  --! @brief Minimum Integer word-length allowed for signals going to and from LabVIEW
  --! @details Intermediate signals need not worry about the limit.
  constant kFxpMinIwl : integer  := -1024;

  -----------------------------------------------------------------------------
  --! @brief Round (Quantization) Mode
  --! @details
  --! kNotNeeded: Rounding not needed (truncate)<br/>
  --! kTruncate: Chop off extra bits (Round to -Inf)<br/>
  --! kRoundToNearest: Round up when 1/2 LSB is set<br/>
  --! kConvergent: Round to even when exactly 1/2 LSB<br/>
  --! kRoundToPosInf: Round to positive infinity<br/>
  type FxpRoundMode_t is (
    kNotNeeded,                         
    kTruncate,                         
    kRoundToNearest,                   
    kConvergent,                       
    kRoundToPosInf                     
    );

  constant kFxpDefaultRoundMode : FxpRoundMode_t := kTruncate;

  --! @brief Overflow Mode
  --! @details
  --! kNotNeeded: Don't need, optimize<br/>
  --! kWrap: Ignore extra MSBs<br/>
  --! kSaturate: Disallow overflow into MSBs
  type FxpOverflowMode_t is (
    kNotNeeded,
    kWrap,
    kSaturate
    );

  constant kFxpDefaultOverflowMode : FxpOverflowMode_t := kNotNeeded;

  -----------------------------------------------------------------------------
  --! @brief Comparison Modes
  --! @details The following modes are named after the name of the LabVIEW primitive
  --! doing the same operation (minus the '?').
  type FxpComparisonOp_t is (
    kEqual,
    kNotEqual,
    kGreater,
    kGreaterOrEqual,
    kLess,
    kLessOrEqual
    );

  -----------------------------------------------------------------------------
  -- Register Modes

  -- Modes that determine how a module will register its outputs. In most
  -- cases, the default value passed from LabVIEW to the implementations should
  -- be kRegisterIfNeeded unless the node is in a single-cycle loop in which
  -- case it should be kNoRegisters.

  --Internal use only
  type FxpRegisterMode_t is (
    kNoRegisters,
    kRegisterIfNeeded,
    kRegister
    );

  --Internal use only
  constant kFxpDefaultRegisterMode : FxpRegisterMode_t := kRegisterIfNeeded;

  -----------------------------------------------------------------------------
  -- Misc Helper Functions
  -----------------------------------------------------------------------------

  --Internal use only
  procedure PrintNote (text : in string);

  function ExtractFxpOverflow(
    kIncludesOverflow : boolean;
    fxpArg            : std_logic_vector)
    return std_logic;

  function ExtractFxpValue(
    kIncludesOverflow : boolean;
    fxpArg            : std_logic_vector)
    return std_logic_vector;

  function PackFxpValueAndOverflow(
    fxpVal          : std_logic_vector;
    fxpOvfl         : std_logic;
    includeOverflow : boolean := true)
    return std_logic_vector;
  
  function NumOfOvflBits(constant kIncludesOverflow : boolean) return natural;

  -- The following functions are used to convert from the LabVIEW enum value
  -- for round, overflow, and comparison operations to their respective
  -- fixed-point package versions. They are only used in the module generators
  -- to assign the natural enum value from LabVIEW to the vhdl version in the
  -- component instantiation.

  --Internal use only
  function ConvertLvToFpgaRoundMode (
    constant kRoundMode : natural) 
    return FxpRoundMode_t;
  --Internal use only
  function ConvertLvToFpgaOverflowMode (
    constant kOverflowMode : natural) 
    return FxpOverflowMode_t;
  --Internal use only
  function ConvertLvToFpgaComparisonOp (
    constant kComparisonOp : natural) 
    return FxpComparisonOp_t;
  --Internal use only
  function ConvertLvToFpgaRegisterMode (
    constant kRegisterMode : natural) 
    return FxpRegisterMode_t;
 
  -- This is a fix for the "U64 problem", which is chosen 
  -- to allow handling U64 as a signed vector.
  constant kPackedVectorMaxWl : positive := 65;
  subtype PackedVector_t is std_logic_vector(kPackedVectorMaxWl-1 downto 0);

  function PackVectorForEntityBoundaryCrossing (
    arg : std_logic_vector)
    return PackedVector_t;

  function UnpackVectorFromEntityBoundaryCrossing (
    arg        : PackedVector_t;
    kIwl, kFwl : integer)
    return FxpGen_t;

  -----------------------------------------------------------------------------

  -- Returns the register mode required by the two inputs. If the
  -- original mode states to register if needed, then the second
  -- operand is returned.  Otherwise, the first operand is
  -- returned. Basically, it just forces a priority on the first
  -- operand.

  --Internal use only
  function GetRegisterMode (
    kOrigRegMode      : FxpRegisterMode_t;
    kRequestedRegMode : FxpRegisterMode_t)
    return FxpRegisterMode_t;

  -----------------------------------------------------------------------------

  -- Returns true if the operation is an integer operation that
  -- requires special conversions to take place. LabVIEW does old C
  -- style conversions for its integer operators such that the inputs
  -- are sign (or zero) extended to the length of the larger operand
  -- and then type-casted to the larger representation. If the numbers
  -- have the same length and either is unsigned, they are both
  -- converted to unsigned. This function returns true if this special
  -- behavior is required.

  --Internal use only
  function OpNeedsSpecialCoercion (
    constant kIntegerOperation : boolean;
    constant kInOneSigned      : boolean;
    constant kInOneIwl         : integer;
    constant kInTwoSigned      : boolean;
    constant kInTwoIwl         : integer)
    return boolean;

  -----------------------------------------------------------------------------

  -- Returns the offset range information for a unary or binary
  -- operand to work around Xilinx's issue with negative ranges. This
  -- should be used from top-level entry points so the underlying code
  -- remains the same. Set kKeepRangesNatural to false to allow the
  -- fixed-point types to propogate unchanged.

  --Internal use only
  constant kKeepRangesNatural : boolean := true;

  --Internal use only
  type UnOpRangeFix_t is record
    InMeta  : FxpMeta_t;
    OutMeta : FxpMeta_t;
  end record;

  --Internal use only
  function GetRangeFixInfo (
    kInMeta          : FxpMeta_t;
    kOutMeta         : FxpMeta_t;
    kAdditionalShift : natural := 0)
    return UnOpRangeFix_t;

  --Internal use only
  type BinOpRangeFix_t is record
    InOneMeta : FxpMeta_t;
    InTwoMeta : FxpMeta_t;
    OutMeta   : FxpMeta_t;
  end record;

  --Internal use only
  function GetRangeFixInfo (
    kInOneMeta : FxpMeta_t;
    kInTwoMeta : FxpMeta_t;
    kOutMeta   : FxpMeta_t;
    kOp        : character := '+')
    return BinOpRangeFix_t;

  -----------------------------------------------------------------------------

  -- At some point I want to add a debugging option that will instantiate some runtime
  -- code that passes out a known value (e.g. 'deadbeef') whenever something wrong
  -- occurs, but that's not done yet. The checks are compile time and result in
  -- no logic.
  
  --! @brief Ensures types and values of a fixed-point number are within the specification
  --! @details 
  --! Put this anywhere you want to ensure the types and values of the generic
  --! fixed-point number are within the fixed-point specifications. 
  procedure CheckInvariant (arg : in FxpGen_t);
  --! @brief Ensures types and values of a fixed-point number are within the specification
  --! @details 
  --! Put this anywhere you want to ensure the types and values of the unsigned
  --! fixed-point number are within the fixed-point specifications. 
  procedure CheckInvariant (arg : in FxpUns_t);
  --! @brief Ensures types and values of a fixed-point number are within the specification
  --! @details 
  --! Put this anywhere you want to ensure the types and values of signed
  --! fixed-point number are within the fixed-point specifications. 
  procedure CheckInvariant (arg : in FxpSgn_t);

  -----------------------------------------------------------------------------


  function Maximum (x, y    : integer) return integer;
  function Maximum (x, y, z : integer) return integer;

  function Minimum (x, y    : integer) return integer;
  function Minimum (x, y, z : integer) return integer;

  -----------------------------------------------------------------------------

  --! @brief Used to selet between two different inputs based on a boolean input
  --! @details This is helpful because it can be called when declaring signals
  --! to select between different parameters, etc. If choice is true, the first
  --! input will be returned, otherwise the second input is returned.
  function Choose (selectFirst : boolean; a, b : boolean) return boolean;
  --! @brief Used to selet between two different inputs based on a boolean input
  --! @details This is helpful because it can be called when declaring signals
  --! to select between different parameters, etc. If choice is true, the first
  --! input will be returned, otherwise the second input is returned.
  function Choose (selectFirst : boolean; a, b : integer) return integer;
  --! @brief Used to selet between two different inputs based on a boolean input
  --! @details This is helpful because it can be called when declaring signals
  --! to select between different parameters, etc. If choice is true, the first
  --! input will be returned, otherwise the second input is returned.
  function Choose (selectFirst : boolean; a, b : string) return string;
  --! @brief Used to selet between two different inputs based on a boolean input
  --! @details This is helpful because it can be called when declaring signals
  --! to select between different parameters, etc. If choice is true, the first
  --! input will be returned, otherwise the second input is returned.
  function Choose (selectFirst : boolean; a, b : FxpGen_t) return FxpGen_t;
  --! @brief Used to selet between two different inputs based on a boolean input
  --! @details This is helpful because it can be called when declaring signals
  --! to select between different parameters, etc. If choice is true, the first
  --! input will be returned, otherwise the second input is returned.
  function Choose (selectFirst : boolean; a, b : FxpUns_t) return FxpUns_t;
  --! @brief Used to selet between two different inputs based on a boolean input
  --! @details This is helpful because it can be called when declaring signals
  --! to select between different parameters, etc. If choice is true, the first
  --! input will be returned, otherwise the second input is returned.
  function Choose (selectFirst : boolean; a, b : FxpSgn_t) return FxpSgn_t;
  --! @brief Used to selet between two different inputs based on a boolean input
  --! @details This is helpful because it can be called when declaring signals
  --! to select between different parameters, etc. If choice is true, the first
  --! input will be returned, otherwise the second input is returned.
  function Choose (selectFirst : boolean; a, b : FxpRoundMode_t) return FxpRoundMode_t;
  --! @brief Used to selet between two different inputs based on a boolean input
  --! @details This is helpful because it can be called when declaring signals
  --! to select between different parameters, etc. If choice is true, the first
  --! input will be returned, otherwise the second input is returned.
  function Choose (selectFirst : boolean; a, b : FxpOverflowMode_t) 
  return FxpOverflowMode_t;
  --! @brief Used to selet between two different inputs based on a boolean input
  --! @details This is helpful because it can be called when declaring signals
  --! to select between different parameters, etc. If choice is true, the first
  --! input will be returned, otherwise the second input is returned.
  function Choose (selectFirst : boolean; a, b : FxpRegisterMode_t) 
  return FxpRegisterMode_t;

  -----------------------------------------------------------------------------

  --! @brief Sign extends the argument to the given integer word length. 
  --! @details If the requested integer word length is less than the arguments 
  --! integer word length, an error is thrown.
  function SignExtend (
    constant kArgSigned : boolean;
    arg                 : FxpGen_t;
    constant kReqIwl    : integer) 
    return FxpGen_t;

  --! @brief Sign extends the argument to the given integer word length. 
  --! @details If the requested integer word length is less than the arguments 
  --! integer word length, an error is thrown.
  function SignExtend (
    arg              : FxpUns_t;
    constant kReqIwl : integer) 
    return FxpUns_t;
	
  --! @brief Sign extends the argument to the given integer word length. 
  --! @details If the requested integer word length is less than the arguments 
  --! integer word length, an error is thrown.
  function SignExtend (arg : FxpSgn_t; constant kReqIwl : integer) return FxpSgn_t;

  -----------------------------------------------------------------------------

  -- Extends or truncates the argument to the requested integer and fractional
  -- word lengths. If the input is signed and the integer word length
  -- requested is larger than the input argument, the argument will be sign
  -- extended. If the argument extends further in either direction than the
  -- requested lengths, the extra bits will be truncated. 
  -- This function should probably not be called from anywhere except within 
  -- this package and the complete resize function.
  --Internal use only
  function SimpleResize (
    constant kArgSigned       : boolean;
    arg                       : FxpGen_t;
    constant kReqIwl, kReqFwl : integer) 
    return FxpGen_t;
  --Internal use only
  function SimpleResize (
    arg                       : FxpUns_t;
    constant kReqIwl, kReqFwl : integer) 
    return FxpUns_t;
  --Internal use only
  function SimpleResize (
    arg                       : FxpSgn_t;
    constant kReqIwl, kReqFwl : integer) 
    return FxpSgn_t;

  -----------------------------------------------------------------------------

  --! If the input is a null-array, the function returns true.
  function IsZero (arg : FxpGen_t) return boolean;
  --! If the input is a null-array, the function returns true.
  function IsZero (arg : FxpUns_t) return boolean;
  --! If the input is a null-array, the function returns true.
  function IsZero (arg : FxpSgn_t) return boolean;

  --! If the input is a null-array, false is returned.
  function IsAllOnes (arg : FxpGen_t) return boolean;
  --! If the input is a null-array, false is returned.
  function IsAllOnes (arg : FxpUns_t) return boolean;
  --! If the input is a null-array, false is returned.
  function IsAllOnes (arg : FxpSgn_t) return boolean;

  --! @brief Checks if input is exactly 1/2 
  --! @details Assumes the msb of the input is the 1/2 bit position. This
  --! function returns true if the msb is a one and the rest of the bits are
  --! zero.
  function IsExactlyHalf (arg : FxpGen_t) return boolean;
  --! @brief Checks if input is exactly 1/2
  --! @details Assumes the msb of the input is the 1/2 bit position. This
  --! function returns true if the msb is a one and the rest of the bits are
  --! zero.
  function IsExactlyHalf (arg : FxpUns_t) return boolean;
  --! @brief Checks if input is eactly 1/2
  --! @details Assumes the msb of the input is the 1/2 bit position. This
  --! function returns true if the msb is a one and the rest of the bits are
  --! zero.
  function IsExactlyHalf (arg : FxpSgn_t) return boolean;

  -----------------------------------------------------------------------------

  --! Used to specify mode of saturation (upper or lower limit)
  type SaturateLimit_t is (kUpper, kLower);

  --! Returns a constant saturated at the limit given.
  function Saturate (
    constant kSigned    : boolean;
    constant kIwl, kFwl : integer;
    constant kLimitType : SaturateLimit_t)
    return FxpGen_t;

  --! Returns a constant saturated at the limit given.
  function Saturate (
    constant kIwl, kFwl : integer;
    constant kLimitType : SaturateLimit_t) 
    return FxpUns_t;
	
  --! Returns a constant saturated at the limit given.
  function Saturate (
    constant kIwl, kFwl : integer;
    constant kLimitType : SaturateLimit_t) 
    return FxpSgn_t;

  -----------------------------------------------------------------------------

  --! Used to describe results of comparing two fixed-point values
  type OpDescriptionRetVal_t is record
    kFirstOpLarger : boolean;
    kSmallSigned   : boolean;
    kSmallIwl      : integer;
    kSmallFwl      : integer;
    kLargeSigned   : boolean;
    kLargeIwl      : integer;
    kLargeFwl      : integer;
  end record;

  --! @brief Helper function for use when trying to swap operands among other things.
  --! @details The input signals are only used to read attributes such as IWL, etc. 
  --! and shouldn't cause any problems during synthesis as far as signal wiring.
  function DescribeOperands (
    constant kLeftSigned  : boolean; left : FxpGen_t;
    constant kRightSigned : boolean; right : FxpGen_t)
    return OpDescriptionRetVal_t;

  --! @brief Helper function for use when trying to swap operands among other things.
  --! @details The input signals are only used to read attributes such as IWL, etc. 
  --! and shouldn't cause any problems during synthesis as far as signal wiring.
  function DescribeOperands (
    left  : FxpUns_t;
    right : FxpUns_t) 
    return OpDescriptionRetVal_t;
	
  --! @brief Helper function for use when trying to swap operands among other things.
  --! @details The input signals are only used to read attributes such as IWL, etc. 
  --! and shouldn't cause any problems during synthesis as far as signal wiring.
  function DescribeOperands (
    left  : FxpSgn_t;
    right : FxpSgn_t) 
    return OpDescriptionRetVal_t;
	
  --! @brief Helper function for use when trying to swap operands among other things.
  --! @details The input signals are only used to read attributes such as IWL, etc. 
  --! and shouldn't cause any problems during synthesis as far as signal wiring.
  function DescribeOperands (
    left  : FxpSgn_t;
    right : FxpUns_t) 
    return OpDescriptionRetVal_t;

  --! @brief Helper function for use when trying to swap operands among other things.
  --! @details The input signals are only used to read attributes such as IWL, etc. 
  --! and shouldn't cause any problems during synthesis as far as signal wiring.
  function DescribeOperands (
    left  : FxpUns_t;
    right : FxpSgn_t) 
    return OpDescriptionRetVal_t;

  -----------------------------------------------------------------------------
  -- Conversion Operations
  -----------------------------------------------------------------------------
  --! Conversion Operation
  function to_Fxp (
    arg      : std_logic_vector;
    sizeType : FxpGen_t;
    kSigned  : boolean := false)
    return FxpGen_t;
	
  --! Conversion Operation
  function to_Fxp (arg : integer; sizeType : FxpGen_t) return FxpGen_t;
  
  --! Conversion Operation
  function to_slv (arg      : FxpGen_t) return std_logic_vector;
  
  --! Conversion Operation
  function to_unsigned (arg : FxpGen_t) return unsigned;
  
  --! Conversion Operation
  function to_signed (arg   : FxpGen_t) return signed;

  -----------------------------------------------------------------------------
  -- unsigned cast operators

  --! unsigned cast operator
  function to_Fxp (arg : std_logic_vector; sizeType : FxpUns_t) return FxpUns_t;
  --! unsigned cast operator
  function to_Fxp (arg : integer; sizeType : FxpUns_t) return FxpUns_t;
  --! unsigned cast operator
  function to_slv (arg      : FxpUns_t) return std_logic_vector;
  --! unsigned cast operator
  function to_unsigned (arg : FxpUns_t) return unsigned;
  --! unsigned cast operator
  function to_signed (arg   : FxpUns_t) return signed;

  -----------------------------------------------------------------------------
  -- signed cast operators

  --! signed cast operator
  function to_FxpSgn (arg : FxpUns_t) return FxpSgn_t;
  --! signed cast operator
  function to_Fxp (arg : std_logic_vector; sizeType : FxpSgn_t) return FxpSgn_t;
  --! signed cast operator
  function to_Fxp (arg : integer; sizeType : FxpSgn_t) return FxpSgn_t;
  --! signed cast operator
  function to_slv (arg    : FxpSgn_t) return std_logic_vector;
  --! signed cast operator
  function to_signed (arg : FxpSgn_t) return signed;

  -----------------------------------------------------------------------------
  -- Comparison Operations

  function "=" (x : FxpUns_t; y : FxpUns_t) return boolean;
  function "=" (x : FxpSgn_t; y : FxpUns_t) return boolean;
  function "=" (x : FxpUns_t; y : FxpSgn_t) return boolean;
  function "=" (x : FxpSgn_t; y : FxpSgn_t) return boolean;

  -----------------------------------------------------------------------------

  function "/=" (x : FxpUns_t; y : FxpUns_t) return boolean;
  function "/=" (x : FxpSgn_t; y : FxpUns_t) return boolean;
  function "/=" (x : FxpUns_t; y : FxpSgn_t) return boolean;
  function "/=" (x : FxpSgn_t; y : FxpSgn_t) return boolean;

  -----------------------------------------------------------------------------

  function ">" (x : FxpUns_t; y : FxpUns_t) return boolean;
  function ">" (x : FxpSgn_t; y : FxpUns_t) return boolean;
  function ">" (x : FxpUns_t; y : FxpSgn_t) return boolean;
  function ">" (x : FxpSgn_t; y : FxpSgn_t) return boolean;

  -----------------------------------------------------------------------------

  function ">=" (x : FxpUns_t; y : FxpUns_t) return boolean;
  function ">=" (x : FxpSgn_t; y : FxpUns_t) return boolean;
  function ">=" (x : FxpUns_t; y : FxpSgn_t) return boolean;
  function ">=" (x : FxpSgn_t; y : FxpSgn_t) return boolean;

  -----------------------------------------------------------------------------

  function "<" (x : FxpUns_t; y : FxpUns_t) return boolean;
  function "<" (x : FxpSgn_t; y : FxpUns_t) return boolean;
  function "<" (x : FxpUns_t; y : FxpSgn_t) return boolean;
  function "<" (x : FxpSgn_t; y : FxpSgn_t) return boolean;

  -----------------------------------------------------------------------------

  function "<=" (x : FxpUns_t; y : FxpUns_t) return boolean;
  function "<=" (x : FxpSgn_t; y : FxpUns_t) return boolean;
  function "<=" (x : FxpUns_t; y : FxpSgn_t) return boolean;
  function "<=" (x : FxpSgn_t; y : FxpSgn_t) return boolean;

end PkgFxp;

-------------------------------------------------------------------------------
-- PkgFxp Body ----------------------------------------------------------------
-------------------------------------------------------------------------------

package body PkgFxp is

  -----------------------------------------------------------------------------
  -- Misc Functions
  -----------------------------------------------------------------------------

  procedure PrintNote (text : in string) is
  begin
    if kFxpEnableNotes then
      assert false report text severity note;
    end if;
  end procedure PrintNote;

  -----------------------------------------------------------------------------
  -- Functions for overflow flag packing and extraction
  -----------------------------------------------------------------------------
  
  function ExtractFxpOverflow(
    kIncludesOverflow : boolean;
    fxpArg            : std_logic_vector)
    return std_logic
  is
    variable ovfl : std_logic := '0';
  begin
    if kIncludesOverflow then
      ovfl := fxpArg(fxpArg'left);  --assuming the left most element is overflow
    end if;
    return ovfl;
  end function ExtractFxpOverflow;

  -----------------------------------------------------------------------------

  function ExtractFxpValue(
    kIncludesOverflow : boolean;
    fxpArg            : std_logic_vector)
    return std_logic_vector
  is
    alias arg          : std_logic_vector(fxpArg'length-1 downto 0) is fxpArg;
    variable leftBound : natural;
  begin
    if kIncludesOverflow then
      leftBound := arg'left-1;
    else
      leftBound := arg'left;
    end if;
    return arg(leftBound downto 0);
  end function ExtractFxpValue;

  -----------------------------------------------------------------------------
  
  function PackFxpValueAndOverflow(
    fxpVal          : std_logic_vector;
    fxpOvfl         : std_logic;
    includeOverflow : boolean := true)
    return std_logic_vector is
  begin
    if includeOverflow then
      return fxpOvfl & fxpVal;
    else
      return fxpVal;
    end if;
  end function PackFxpValueAndOverflow;

  -----------------------------------------------------------------------------
  
  function NumOfOvflBits(constant kIncludesOverflow : boolean) return natural
  is
    variable num : natural;
  begin
    if kIncludesOverflow then
      num := 1;
    else
      num := 0;
    end if;
    return num;
  end function NumOfOvflBits;

  -----------------------------------------------------------------------------
  -- Helper functions for information coming from LabVIEW

  function ConvertLvToFpgaRoundMode (
    constant kRoundMode : natural)
    return FxpRoundMode_t
  is
    variable vFxpRoundMode : FxpRoundMode_t;
  begin
    case kRoundMode is
      when 0 => vFxpRoundMode := kNotNeeded;
      when 1 => vFxpRoundMode := kTruncate;
      when 2 => vFxpRoundMode := kRoundToNearest;
      when 3 => vFxpRoundMode := kConvergent;
      when others =>
        assert false
          report "Unsupported rounding mode '" &
          natural'image(kRoundMode) & "'."
          severity error;
    end case;
    return vFxpRoundMode;
  end function ConvertLvToFpgaRoundMode;

  function ConvertLvToFpgaOverflowMode (
    constant kOverflowMode : natural)
    return FxpOverflowMode_t
  is
    variable vFxpOverflowMode : FxpOverflowMode_t;
  begin
    case kOverflowMode is
      when 0 => vFxpOverflowMode := kNotNeeded;
      when 1 => vFxpOverflowMode := kWrap;
      when 2 => vFxpOverflowMode := kSaturate;
      when others =>
        assert false
          report "Unsupported overflow mode '" &
          natural'image(kOverflowMode) & "'."
          severity error;
    end case;
    return vFxpOverflowMode;
  end function ConvertLvToFpgaOverflowMode;

  function ConvertLvToFpgaComparisonOp (
    constant kComparisonOp : natural)
    return FxpComparisonOp_t
  is
    variable vFxpComparisonOp : FxpComparisonOp_t;
  begin
    case kComparisonOp is
      when 0 => vFxpComparisonOp := kEqual;
      when 1 => vFxpComparisonOp := kNotEqual;
      when 2 => vFxpComparisonOp := kGreaterOrEqual;
      when 3 => vFxpComparisonOp := kGreater;
      when 4 => vFxpComparisonOp := kLessOrEqual;
      when 5 => vFxpComparisonOp := kLess;
      when others =>
        assert false
          report "Unsupported comparison op '" &
          natural'image(kComparisonOp) & "'."
          severity error;
    end case;
    return vFxpComparisonOp;
  end function ConvertLvToFpgaComparisonOp;

  function ConvertLvToFpgaRegisterMode (
    constant kRegisterMode : natural)
    return FxpRegisterMode_t
  is
    variable vFxpRegisterMode : FxpRegisterMode_t;
  begin
    case kRegisterMode is
      when 0 => vFxpRegisterMode := kNoRegisters;
      when 1 => vFxpRegisterMode := kRegisterIfNeeded;
      when 2 => vFxpRegisterMode := kRegister;
      when others =>
        assert false
          report "Unsupported register mode '" &
          natural'image(kRegisterMode) & "'."
          severity error;
    end case;
    return vFxpRegisterMode;
  end function ConvertLvToFpgaRegisterMode;

  -----------------------------------------------------------------------------

  -- Currently, the vhdl standard does not allow you to use generics to declare
  -- other generics. This causes a problem in some cases such as the arithmetic
  -- entities because we need to pass vectors to the entity for the saturation
  -- limits but we don't know the size of the vector without looking at other
  -- generics. To get around this, we can pack the vector into a known width
  -- and then unpack it again on the other side and hope the synthesizer will
  -- remove the dangling lines.

  function PackVectorForEntityBoundaryCrossing (
    arg : std_logic_vector)
    return PackedVector_t
  is
    variable result : PackedVector_t := (others => '0');
  begin

    if not (kPackedVectorMaxWl >= arg'length) then
      ReportError
       (ErrorType => ExternalError,
        ShortDescription => "PackVectorForEntityBoundaryCrossing: We were given an " &
                            "argument of length " & integer'image(arg'length) &
                            " which is larger than maximum allowed length of " &
                            integer'image(kPackedVectorMaxWl));
    end if;
    
    if arg'high /= arg'left then
      -- Handles literals that are inferred as "to" format
      for i in arg'range loop
        result(arg'length-(i-arg'low)-1) := arg(i);
      end loop;
    else
      result(arg'length-1 downto 0) := arg;
    end if;

    return result;
  end function PackVectorForEntityBoundaryCrossing;

  function UnpackVectorFromEntityBoundaryCrossing (
    arg        : PackedVector_t;
    kIwl, kFwl : integer)
    return FxpGen_t
  is
    constant kPadBits : integer := arg'length - (kIwl+kFwl);
    variable vResult  : FxpGen_t(kIwl-1 downto -kFwl);
  begin
    vResult := FxpGen_t(arg(arg'left-kPadBits downto arg'right));
    return vResult;
  end function UnpackVectorFromEntityBoundaryCrossing;

  -----------------------------------------------------------------------------

  function GetRegisterMode (
    kOrigRegMode      : FxpRegisterMode_t;
    kRequestedRegMode : FxpRegisterMode_t)
    return FxpRegisterMode_t is
  begin

    if kOrigRegMode /= kRegisterIfNeeded then
      return kOrigRegMode;
    end if;

    return kRequestedRegMode;

  end function GetRegisterMode;

  ---------------------------------------------------------------------------

  function OpNeedsSpecialCoercion (
    constant kIntegerOperation : boolean;
    constant kInOneSigned      : boolean;
    constant kInOneIwl         : integer;
    constant kInTwoSigned      : boolean;
    constant kInTwoIwl         : integer)
    return boolean is
  begin

    if not kIntegerOperation then
      return false;
    elsif kInOneSigned = kInTwoSigned then
      return false;
    elsif kInOneIwl > kInTwoIwl then
      return not kInOneSigned;
    elsif kInTwoIwl > kInOneIwl then
      return not kInTwoSigned;
    end if;

    return true;

  end function OpNeedsSpecialCoercion;

  -----------------------------------------------------------------------------
  -- Range Fix Helpers

  function GetRangeFixInfo (
    kInMeta          : FxpMeta_t;
    kOutMeta         : FxpMeta_t;
    kAdditionalShift : natural := 0)
    return UnOpRangeFix_t
  is
    variable vOffset : integer        := 0;
    variable vRet    : UnOpRangeFix_t := (kInMeta, kOutMeta);
  begin

    if not kKeepRangesNatural then
      return vRet;
    end if;

    vOffset := Maximum(kInMeta.kFwl, kOutMeta.kFwl) + kAdditionalShift;

    vRet.InMeta.kIwl := kInMeta.kIwl + vOffset;
    vRet.InMeta.kFwl := kInMeta.kFwl - vOffset;

    vRet.OutMeta.kIwl := kOutMeta.kIwl + vOffset;
    vRet.OutMeta.kFwl := kOutMeta.kFwl - vOffset;

    return vRet;
  end function GetRangeFixInfo;

  function GetRangeFixInfo (
    kInOneMeta : FxpMeta_t;
    kInTwoMeta : FxpMeta_t;
    kOutMeta   : FxpMeta_t;
    kOp        : character := '+')
    return BinOpRangeFix_t
  is
    variable vInOneOffset, vInTwoOffset, vOutOffset : integer := 0;

    variable vFudge, vInOneExtraBits, vInTwoExtraBits : integer := 0;
    
    variable vRet   : BinOpRangeFix_t := (kInOneMeta, kInTwoMeta, kOutMeta);
  begin

    if not kKeepRangesNatural then
      return vRet;
    end if;

    -- we're fixing up the types so we don't end up with any negative
    -- indices in the operation, even for intermediate results. This
    -- is pretty straightforward for most operations because we can
    -- just shift all the operands by the largest fractional word
    -- length, but for some (like multiply) we have to work a little
    -- harder.

    case kOp is
      when '*' =>

        -- for multiply, we can first shift each input up such that it
        -- has no fractional bits which will shift the intermediate
        -- result such that it has no fractional bits. This, however,
        -- might not be enough if the output type has more fractional
        -- bits than the intermediate result. We can account for this
        -- case by further shifting one of the inputs until the the
        -- output is all integer bits.

        vInOneOffset := kInOneMeta.kFwl;
        vInTwoOffset := kInTwoMeta.kFwl;
        vOutOffset   := vInOneOffset + vInTwoOffset;

        vFudge := kOutMeta.kFwl - vOutOffset;

        if vFudge > 0 then
          -- The output has more fractional bits than the intermediate
          -- result would have, so we need to actually shift over a
          -- little more to get the intermediate result to line up
          -- such that the output doesn't have any negative indices.
          vInOneOffset := vInOneOffset + vFudge;
          vOutOffset   := vOutOffset + vFudge;
        end if;

        -- xilinx currently doesn't sythesize single bit signed numbers
        -- correctly. they treat them as unsigned. to workaround the issue, we
        -- will extend these single bit values by a bit to force xilinx to
        -- treat them correctly as two bit values.
        
        if kInOneMeta.kSigned and (kInOneMeta.kIwl + kInOneMeta.kFwl = 1) then
          vInOneExtraBits := 1;
        end if;
          
        if kInTwoMeta.kSigned and (kInTwoMeta.kIwl + kInTwoMeta.kFwl = 1) then
          vInTwoExtraBits := 1;
        end if;
        
      when others =>

        vInOneOffset := Maximum(kInOneMeta.kFwl, kInTwoMeta.kFwl, kOutMeta.kFwl);
        vInTwoOffset := vInOneOffset;
        vOutOffset   := vInOneOffset;

    end case;

    vRet.InOneMeta.kIwl := kInOneMeta.kIwl + vInOneOffset + vInOneExtraBits;
    vRet.InOneMeta.kFwl := kInOneMeta.kFwl - vInOneOffset;
    vRet.InTwoMeta.kIwl := kInTwoMeta.kIwl + vInTwoOffset + vInTwoExtraBits;
    vRet.InTwoMeta.kFwl := kInTwoMeta.kFwl - vInTwoOffset;

    vRet.OutMeta.kIwl := kOutMeta.kIwl + vOutOffset;
    vRet.OutMeta.kFwl := kOutMeta.kFwl - vOutOffset;

    return vRet;
  end function GetRangeFixInfo;

  -----------------------------------------------------------------------------

  procedure CheckInvariant (arg : in FxpGen_t) is
  begin

    if arg'length <= 0 then
      ReportError
       (ErrorType => ExternalError,
        ShortDescription => "Argument length (" & integer'image(arg'length) &
                            ") must be greater than zero.");		 
    end if;
    -- xilinx 9.2 seems to have issues with the following line for single bit
    -- arguments pass as generics to a component. for now, the workaround is
    -- to remove this check until xilinx fixes the issue or we come up with
    -- another workaround.  
    -- 
    -- assert arg'left >= arg'right
    --   report "Left index must (" & integer'image(arg'left) & 
    --   ") be greater or equal than right index (" & integer'image(arg'right) & ")."
    --   severity error;

  end procedure CheckInvariant;

  procedure CheckInvariant (arg : in FxpUns_t) is
  begin
    CheckInvariant(FxpGen_t(arg));
  end procedure CheckInvariant;

  procedure CheckInvariant (arg : in FxpSgn_t)is
  begin
    CheckInvariant(FxpGen_t(arg));
  end procedure CheckInvariant;

  -----------------------------------------------------------------------------
  -- Max/Min

  function Maximum (x, y : integer) return integer is
  begin
    return Larger(x, y);
  end function Maximum;

  function Maximum (x, y, z : integer) return integer is
  begin
    return Maximum(Maximum(x, y), z);
  end function Maximum;

  function Minimum (x, y : integer) return integer is
  begin
    return Smaller(x, y);
  end function Minimum;

  function Minimum (x, y, z : integer) return integer is
  begin
    return Minimum(Minimum(x, y), z);
  end function Minimum;

  -----------------------------------------------------------------------------
  -- Choose

  function Choose (selectFirst : boolean; a, b : boolean) return boolean is
  begin
    if selectFirst then
      return a;
    else
      return b;
    end if;
  end function Choose;

  function Choose (selectFirst : boolean; a, b : integer) return integer is
  begin
    if selectFirst then
      return a;
    else
      return b;
    end if;
  end function Choose;
  
  function Choose (selectFirst : boolean; a, b : string) return string is
  begin
    if selectFirst then
      return a;
    else
      return b;
    end if;
  end function Choose;

  function Choose (selectFirst : boolean; a, b : FxpGen_t) return FxpGen_t is
  begin
    if selectFirst then
      return a;
    else
      return b;
    end if;
  end function Choose;

  function Choose (selectFirst : boolean; a, b : FxpUns_t) return FxpUns_t is
  begin
    return FxpUns_t(Choose(selectFirst, FxpGen_t(a), FxpGen_t(b)));
  end function Choose;

  function Choose (selectFirst : boolean; a, b : FxpSgn_t) return FxpSgn_t is
  begin
    return FxpSgn_t(Choose(selectFirst, FxpGen_t(a), FxpGen_t(b)));
  end function Choose;

  function Choose (selectFirst : boolean; a, b : FxpRoundMode_t) return FxpRoundMode_t is
  begin
    if selectFirst then
      return a;
    else
      return b;
    end if;
  end function Choose;

  function Choose (selectFirst : boolean; a, b : FxpOverflowMode_t) 
  return FxpOverflowMode_t is
  begin
    if selectFirst then
      return a;
    else
      return b;
    end if;
  end function Choose;

  function Choose (selectFirst : boolean; a, b : FxpRegisterMode_t) 
  return FxpRegisterMode_t is
  begin
    if selectFirst then
      return a;
    else
      return b;
    end if;
  end function Choose;

  -----------------------------------------------------------------------------

  function SimpleResize (
    constant kArgSigned       : boolean;
    arg                       : FxpGen_t;
    constant kReqIwl, kReqFwl : integer) 
    return FxpGen_t
  is

    constant kArgIwl : integer := arg'high+1;
    constant kArgFwl : integer := -arg'low;

    constant kArgHiIdx : integer := Minimum(kArgIwl, kReqIwl)-1;
    constant kArgLoIdx : integer := -Minimum(kArgFwl, kReqFwl);

    constant kOverlap : boolean := kArgHiIdx >= kArgLoIdx;

    -- Determine whether a sign (or zero) extension is required and
    -- create the sign extension vector we'll append onto the
    -- result. The HiIdx is created solely to ensure we don't get null
    -- vector. It won't be used in that case anyway.

    constant kSignExtReq   : boolean := kReqIwl > kArgIwl;
    constant kSignExtLoIdx : integer := Maximum(-kReqFwl, kArgHiIdx + 1);
    constant kSignExtHiIdx : integer := Maximum(kReqIwl, kSignExtLoIdx + 1);

    variable vSignExt : FxpGen_t(kSignExtHiIdx-1 downto kSignExtLoIdx) 
                        := (others => '0');

    variable vResult : FxpGen_t(kReqIwl-1 downto -kReqFwl) := (others => '0');

  begin

    CheckInvariant(vResult);

    if kOverlap then
      -- Get the bits from the input that overlap with the output into
      -- the output vector.
      vResult(kArgHiIdx downto kArgLoIdx) := arg(kArgHiIdx downto kArgLoIdx);
    end if;

    if kSignExtReq then
      if kArgSigned then
        -- If the input argument is signed, we have to sign extend
        -- out. If its unsigned, we don't have to do anyting since the
        -- default value for the sign extension is set to zeros in the
        -- declaration.
        vSignExt := (others => arg(arg'left));
      end if;
      vResult(kReqIwl-1 downto kSignExtLoIdx) := vSignExt;
    end if;

    -- Notice we don't have to worry about the bits in the output to
    -- the right of the input argument since they are assigned zeros
    -- in the declaration of our result variable and can only be
    -- zeros.

    return vResult;

  end function SimpleResize;

  function SimpleResize (
    arg                       : FxpUns_t;
    constant kReqIwl, kReqFwl : integer) 
    return FxpUns_t
  is
  begin
    return FxpUns_t(SimpleResize(false, FxpGen_t(arg), kReqIwl, kReqFwl));
  end function SimpleResize;

  function SimpleResize (
    arg                       : FxpSgn_t;
    constant kReqIwl, kReqFwl : integer) 
    return FxpSgn_t
  is
  begin
    return FxpSgn_t(SimpleResize(true, FxpGen_t(arg), kReqIwl, kReqFwl));
  end function SimpleResize;

  -----------------------------------------------------------------------------

  function SignExtend (
    constant kArgSigned : boolean;
    arg                 : FxpGen_t;
    constant kReqIwl    : integer) 
    return FxpGen_t
  is
    constant kArgIwl : integer := arg'left+1;
    constant kArgFwl : integer := -arg'right;
  begin

    if not (kReqIwl >= kArgIwl) then
      ReportError
       (ErrorType => ExternalError,
        ShortDescription => "Requested Iwl of " & integer'image(kReqIwl) &
                            " is less than original IWL of " &
                            integer'image(kArgIwl) & ".");
    end if;

    return SimpleResize(kArgSigned, arg, kReqIwl, kArgFwl);
  end function SignExtend;

  function SignExtend (arg : FxpUns_t; constant kReqIwl : integer) return FxpUns_t is
  begin
    return FxpUns_t(SignExtend(false, FxpGen_t(arg), kReqIwl));
  end function SignExtend;

  function SignExtend (arg : FxpSgn_t; constant kReqIwl : integer) return FxpSgn_t is
  begin
    return FxpSgn_t(SignExtend(true, FxpGen_t(arg), kReqIwl));
  end function SignExtend;

  -----------------------------------------------------------------------------

  function IsZero (arg : FxpGen_t) return boolean is
    variable vZeros : FxpGen_t(arg'range) := (others => '0');
  begin

    if arg'length <= 0 then
      return true;
    end if;

    CheckInvariant(vZeros);
    return arg = vZeros;
  end function IsZero;

  function IsZero (arg : FxpUns_t) return boolean is
  begin
    return IsZero(FxpGen_t(arg));
  end function IsZero;

  function IsZero (arg : FxpSgn_t) return boolean is
  begin
    return IsZero(FxpGen_t(arg));
  end function IsZero;

  function IsAllOnes (arg : FxpGen_t) return boolean is
    variable vOnes : FxpGen_t(arg'range) := (others => '1');
  begin
    return arg = vOnes;
  end function IsAllOnes;

  function IsAllOnes (arg : FxpUns_t) return boolean is
  begin
    return IsAllOnes(FxpGen_t(arg));
  end function IsAllOnes;

  function IsAllOnes (arg : FxpSgn_t) return boolean is
  begin
    return IsAllOnes(FxpGen_t(arg));
  end function IsAllOnes;

  -----------------------------------------------------------------------------

  function IsExactlyHalf (arg : FxpGen_t) return boolean is
    variable vCompare : FxpGen_t(arg'range) := (others => '0');
  begin
    CheckInvariant(vCompare);
    vCompare(vCompare'left) := '1';
    return arg = vCompare;
  end function IsExactlyHalf;

  function IsExactlyHalf (arg : FxpUns_t) return boolean is
  begin
    return IsExactlyHalf(FxpGen_t(arg));
  end function IsExactlyHalf;

  function IsExactlyHalf (arg : FxpSgn_t) return boolean is
  begin
    return IsExactlyHalf(FxpGen_t(arg));
  end function IsExactlyHalf;

  -----------------------------------------------------------------------------

  function Saturate (
    constant kSigned    : boolean;
    constant kIwl, kFwl : integer;
    constant kLimitType : SaturateLimit_t)
    return FxpGen_t
  is
    variable vResult : FxpGen_t(kIwl-1 downto -kFwl);
  begin

    if not (kIwl > -kFwl) then
      ReportError
       (ErrorType => ExternalError,
        ShortDescription => "Saturate called with parameters for a zero sized vector.");
    end if;

    case kLimitType is
      when kUpper =>
        if kSigned then
          vResult(vResult'left) := '0';
          if vResult'length > 1 then
            vResult(vResult'left-1 downto vResult'right) := (others => '1');
          end if;
        else
          vResult := (others => '1');
        end if;
      when kLower =>
        if kSigned then
          vResult(vResult'left) := '1';
          if vResult'length > 1 then
            vResult(vResult'left-1 downto vResult'right) := (others => '0');
          end if;
        else
          vResult := (others => '0');
        end if;
      when others =>
        ReportError
         (ErrorType => ExternalError,
          ShortDescription => "Invalid limit " & SaturateLimit_t'image(kLimitType) &
                              " passed to Saturate.");
    end case;

    CheckInvariant(vResult);

    return vResult;
  end function Saturate;

  function Saturate (
    constant kIwl, kFwl : integer;
    constant kLimitType : SaturateLimit_t) 
    return FxpUns_t
  is
  begin
    return FxpUns_t(Saturate(false, kIwl, kFwl, kLimitType));
  end function Saturate;

  function Saturate (
    constant kIwl, kFwl : integer;
    constant kLimitType : SaturateLimit_t) 
    return FxpSgn_t
  is
  begin
    return FxpSgn_t(Saturate(true, kIwl, kFwl, kLimitType));
  end function Saturate;

  -----------------------------------------------------------------------------

  function DescribeOperands (
    constant kLeftSigned  : boolean; left : FxpGen_t;
    constant kRightSigned : boolean; right : FxpGen_t)
    return OpDescriptionRetVal_t
  is
    constant kLeftLarger : boolean := Maximum(left'high, right'high) = left'high;

    constant kLargeSigned : boolean := Choose(kLeftLarger, kLeftSigned, kRightSigned);
    constant kLargeIwl    : integer := Choose(kLeftLarger, left'high+1, right'high+1);
    constant kLargeFwl    : integer := Choose(kLeftLarger, -left'low, -right'low);
    constant kLargeWl     : integer := kLargeIwl+kLargeFwl;

    constant kSmallSigned : boolean := Choose(kLeftLarger, kRightSigned, kLeftSigned);
    constant kSmallIwl    : integer := Choose(kLeftLarger, right'high+1, left'high+1);
    constant kSmallFwl    : integer := Choose(kLeftLarger, -right'low, -left'low);
    constant kSmallWl     : integer := kSmallIwl+kSmallFwl;

    variable vResult : OpDescriptionRetVal_t;
  begin

    CheckInvariant(left);
    CheckInvariant(right);

    vResult.kFirstOpLarger := kLeftLarger;
    vResult.kSmallSigned   := kSmallSigned;
    vResult.kSmallIwl      := kSmallIwl;
    vResult.kSmallFwl      := kSmallFwl;
    vResult.kLargeSigned   := kLargeSigned;
    vResult.kLargeIwl      := kLargeIwl;
    vResult.kLargeFwl      := kLargeFwl;
    return vResult;
  end function DescribeOperands;

  function DescribeOperands (
    left  : FxpUns_t;
    right : FxpUns_t) 
    return OpDescriptionRetVal_t
  is
  begin
    return DescribeOperands(false, FxpGen_t(left), false, FxpGen_t(right));
  end function DescribeOperands;

  function DescribeOperands (
    left  : FxpUns_t;
    right : FxpSgn_t) 
    return OpDescriptionRetVal_t
  is
  begin
    return DescribeOperands(false, FxpGen_t(left), true, FxpGen_t(right));
  end function DescribeOperands;

  function DescribeOperands (
    left  : FxpSgn_t;
    right : FxpUns_t) 
    return OpDescriptionRetVal_t
  is
  begin
    return DescribeOperands(true, FxpGen_t(left), false, FxpGen_t(right));
  end function DescribeOperands;

  function DescribeOperands (
    left  : FxpSgn_t;
    right : FxpSgn_t) 
    return OpDescriptionRetVal_t
  is
  begin
    return DescribeOperands(true, FxpGen_t(left), true, FxpGen_t(right));
  end function DescribeOperands;

  -----------------------------------------------------------------------------
  -- generic cast operators

  function to_Fxp (
    arg      : std_logic_vector;
    sizeType : FxpGen_t;
    kSigned  : boolean := false)
    return FxpGen_t
  is
    variable result : FxpGen_t(arg'length + sizeType'low - 1 downto sizeType'low);
  begin
    result := FxpGen_t(arg);
    CheckInvariant(result);
    return SimpleResize(kSigned, result, sizeType'left+1, -sizeType'right);
  end function to_Fxp;

  function to_Fxp (arg : integer; sizeType : FxpGen_t) return FxpGen_t is
    variable result : FxpGen_t(sizeType'range);
  begin
    return to_Fxp(std_logic_vector(to_signed(arg, result'length)), result);
  end function to_Fxp;

  function to_slv (arg : FxpGen_t) return std_logic_vector is
    variable vResult : std_logic_vector(arg'length-1 downto 0);
    variable vResIndex : integer := 0;
  begin
    CheckInvariant(arg);
    for i in arg'low to arg'high loop
      vResult(vResIndex) := arg(i);
      vResIndex := vResIndex + 1;
    end loop;
    return vResult;
  end function to_slv;

  function to_unsigned (arg : FxpGen_t) return unsigned is
  begin
    return unsigned(to_slv(arg));
  end function to_unsigned;

  function to_signed (arg : FxpGen_t) return signed is
  begin
    return signed(to_slv(arg));
  end function to_signed;

  -----------------------------------------------------------------------------
  -- unsigned cast operators

  function to_Fxp (arg : std_logic_vector; sizeType : FxpUns_t) return FxpUns_t is
  begin
    return FxpUns_t(to_Fxp(arg, FxpGen_t(sizeType), false));
  end function to_Fxp;

  function to_Fxp (arg : integer; sizeType : FxpUns_t) return FxpUns_t is
    variable result : FxpUns_t(sizeType'range);
  begin
    return to_Fxp(std_logic_vector(to_unsigned(arg, result'length)), result);
  end function to_Fxp;

  function to_slv (arg : FxpUns_t) return std_logic_vector is
  begin
    return to_slv(FxpGen_t(arg));
  end to_slv;

  function to_unsigned (arg : FxpUns_t) return unsigned is
  begin
    return to_unsigned(FxpGen_t(arg));
  end function to_unsigned;

  function to_signed (arg : FxpUns_t) return signed is
    variable vConcat : FxpGen_t(arg'length downto 0);
  begin
  --BMouring: Variable added due to CAR 151925
    vConcat := '0' & FxpGen_t(arg);
    return to_signed(vConcat);
  end function to_signed;

  -----------------------------------------------------------------------------
  -- signed cast operators

  function to_FxpSgn (arg : FxpUns_t) return FxpSgn_t is
    variable result : FxpSgn_t(arg'high+1 downto arg'low);
  begin
    result := '0' & FxpSgn_t(arg);
    return result;
  end function to_FxpSgn;

  function to_Fxp (arg : std_logic_vector; sizeType : FxpSgn_t) return FxpSgn_t is
  begin
    return FxpSgn_t(to_Fxp(arg, FxpGen_t(sizeType), true));
  end function to_Fxp;

  function to_Fxp (arg : integer; sizeType : FxpSgn_t) return FxpSgn_t is
    variable result : FxpSgn_t(sizeType'range);
  begin
    return to_Fxp(std_logic_vector(to_signed(arg, result'length)), result);
  end function to_Fxp;

  function to_slv (arg : FxpSgn_t) return std_logic_vector is
  begin
    return to_slv(FxpGen_t(arg));
  end to_slv;

  function to_signed (arg : FxpSgn_t) return signed is
  begin
    return to_signed(FxpGen_t(arg));
  end function to_signed;

  -----------------------------------------------------------------------------
  -- Comparison Operations

  function "=" (x : FxpUns_t; y : FxpUns_t) return boolean is
    constant kResFwl : integer := -Minimum(x'right, y'right);
    constant kResIwl : integer := Maximum(x'left+1, y'left+1)+1;
    variable vRes    : FxpUns_t(kResIwl-1 downto -kResFwl);
  begin

    return to_unsigned(SimpleResize(x, x'left+1, kResFwl)) =
      to_unsigned(SimpleResize(y, y'left+1, kResFwl));

  end function "=";

  function "=" (x : FxpSgn_t; y : FxpUns_t) return boolean is
  begin
    return x = to_FxpSgn(y);
  end function "=";

  function "=" (x : FxpUns_t; y : FxpSgn_t) return boolean is
  begin
    return to_FxpSgn(x) = y;
  end function "=";

  function "=" (x : FxpSgn_t; y : FxpSgn_t) return boolean is
    constant kResFwl : integer := -Minimum(x'right, y'right);
    constant kResIwl : integer := Maximum(x'left+1, y'left+1)+1;
    variable vRes    : FxpSgn_t(kResIwl-1 downto -kResFwl);
  begin

    return to_signed(SimpleResize(x, x'left+1, kResFwl)) =
      to_signed(SimpleResize(y, y'left+1, kResFwl));

  end function "=";

  -----------------------------------------------------------------------------

  function "/=" (x : FxpUns_t; y : FxpUns_t) return boolean is
  begin
    return not (x = y);
  end function "/=";

  function "/=" (x : FxpSgn_t; y : FxpUns_t) return boolean is
  begin
    return not (x = y);
  end function "/=";

  function "/=" (x : FxpUns_t; y : FxpSgn_t) return boolean is
  begin
    return not (x = y);
  end function "/=";

  function "/=" (x : FxpSgn_t; y : FxpSgn_t) return boolean is
  begin
    return not (x = y);
  end function "/=";

  -----------------------------------------------------------------------------

  function ">" (x : FxpUns_t; y : FxpUns_t) return boolean is
  begin
    return not (x <= y);
  end function ">";

  function ">" (x : FxpSgn_t; y : FxpUns_t) return boolean is
  begin
    return not (x <= y);
  end function ">";

  function ">" (x : FxpUns_t; y : FxpSgn_t) return boolean is
  begin
    return not (x <= y);
  end function ">";

  function ">" (x : FxpSgn_t; y : FxpSgn_t) return boolean is
  begin
    return not (x <= y);
  end function ">";

  -----------------------------------------------------------------------------

  -- NOTE: in the following functions, we would love to be able to
  -- just cast the inputs to the appropriate signed or unsigned
  -- vectors and then use the normal compare routines, but Xilinx
  -- doesn't sythesize them correctly all the time (especially for
  -- constant comparisons). Therefore, for now we have to write our
  -- own comparison functions and wait for Xilinx to catch up. The fix
  -- has been used in both the ">=" case and the "<=" case.

  function ">=" (x : FxpUns_t; y : FxpUns_t) return boolean is
    constant kResFwl : integer := -Minimum(x'right, y'right);
    constant kResIwl : integer := Maximum(x'left+1, y'left+1)+1;
    variable vRes    : FxpUns_t(kResIwl-1 downto -kResFwl);
  begin

    -- return to_unsigned(SimpleResize(x, x'left+1, kResFwl)) >=
    --   to_unsigned(SimpleResize(y, y'left+1, kResFwl));

    vRes := FxpUns_t(
      to_unsigned(SimpleResize(x, kResIwl, kResFwl)) -
      to_unsigned(SimpleResize(y, kResIwl, kResFwl))
      );

    return vRes(vRes'left) = '0';

  end function ">=";

  function ">=" (x : FxpSgn_t; y : FxpUns_t) return boolean is
  begin
    return x >= to_FxpSgn(y);
  end function ">=";

  function ">=" (x : FxpUns_t; y : FxpSgn_t) return boolean is
  begin
    return to_FxpSgn(x) >= y;
  end function ">=";

  function ">=" (x : FxpSgn_t; y : FxpSgn_t) return boolean is
    constant kResFwl : integer := -Minimum(x'right, y'right);
    constant kResIwl : integer := Maximum(x'left+1, y'left+1)+1;
    variable vRes    : FxpSgn_t(kResIwl-1 downto -kResFwl);
  begin

    -- return to_signed(SimpleResize(x, x'left+1, kResFwl)) >=
    --   to_signed(SimpleResize(y, y'left+1, kResFwl));

    vRes := FxpSgn_t(
      to_signed(SimpleResize(x, kResIwl, kResFwl)) -
      to_signed(SimpleResize(y, kResIwl, kResFwl))
      );

    return vRes(vRes'left) = '0';

  end function ">=";

  -----------------------------------------------------------------------------

  function "<" (x : FxpUns_t; y : FxpUns_t) return boolean is
  begin
    return not (x >= y);
  end function "<";

  function "<" (x : FxpSgn_t; y : FxpUns_t) return boolean is
  begin
    return not (x >= y);
  end function "<";

  function "<" (x : FxpUns_t; y : FxpSgn_t) return boolean is
  begin
    return not (x >= y);
  end function "<";

  function "<" (x : FxpSgn_t; y : FxpSgn_t) return boolean is
  begin
    return not (x >= y);
  end function "<";

  -----------------------------------------------------------------------------

  function "<=" (x : FxpUns_t; y : FxpUns_t) return boolean is
  begin
    return y >= x;
  end function "<=";

  function "<=" (x : FxpSgn_t; y : FxpUns_t) return boolean is
  begin
    return x <= to_FxpSgn(y);
  end function "<=";

  function "<=" (x : FxpUns_t; y : FxpSgn_t) return boolean is
  begin
    return to_FxpSgn(x) <= y;
  end function "<=";

  function "<=" (x : FxpSgn_t; y : FxpSgn_t) return boolean is
  begin
    return y >= x;
  end function "<=";

end PkgFxp;
