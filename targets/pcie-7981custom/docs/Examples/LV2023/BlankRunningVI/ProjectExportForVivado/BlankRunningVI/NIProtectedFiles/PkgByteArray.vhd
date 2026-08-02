-------------------------------------------------------------------------------
--
-- File: PkgByteArray.vhd
-- Author: Christopher A. Clark
-- Original Project: IMAQ PCI-X Interface
-- Date: 3 March 2004
--
-------------------------------------------------------------------------------
-- (c) 2004 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--      This is a package which introduces a type for bytes and arrays of
--      bytes. It also provides some useful functions for operating on these
--      types.
--
-- Dependencies:
--      One of the functions ("and") uses the type OneHotArray_t,
--      so PkgOneHot must be in any project that uses this package
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgOneHot.all;

package PkgByteArray is

  subtype Byte_t is std_logic_vector(7 downto 0);
  type ByteArray_t is array(natural range<>) of Byte_t;

  function to_ByteArray(arg : std_logic_vector) return ByteArray_t;
  function to_ByteArray(arg : unsigned) return ByteArray_t;

  function to_StdLogicVector(arg : ByteArray_t) return std_logic_vector;
  function to_Unsigned(arg : ByteArray_t) return unsigned;

  -----------------------------------------------------------------------------
  -- "and"[ByteArray_t, OneHotArray_t return Byte_t] and
  -- OrReduce[ByteArray_t return Byte_t]
  -- are useful for creating a byte-wide and/or mux:
  --    signal Sel : unsigned(2 downto 0);
  --    signal ByteSel : OneHotArray_t(2**Sel'length - 1 downto 0);
  --    signal MuxInput : ByteArray_t(ByteSel'range);
  --    signal MuxOutput : Byte_t;
  --    . . .
  --    ByteSel <= to_OneHotArray(Sel);
  --    MuxOutput <= OrReduce( MuxInput and ByteSel );
  -----------------------------------------------------------------------------

  function OrReduce (constant Arg : ByteArray_t) return Byte_t;

  -- These functions have been removed due to the ambiguity created
  -- when VHDL-2008 started supporting AND(std_logic,std_logic_vector)
  -- They have been replaced with functions named "ByteAnd" so that the
  -- ByteArray_t overloads below will still work.
  --function "and" ( L : Byte_t; R : std_ulogic) return Byte_t;
  --function "and" ( L : std_ulogic; R : Byte_t) return Byte_t;
  function ByteAnd ( L : Byte_t; R : std_ulogic) return Byte_t;
  function ByteAnd ( L : std_ulogic; R : Byte_t) return Byte_t;

  function "and" ( lByteArray : ByteArray_t; rOneHot : OneHotArray_t)
    return ByteArray_t;

  function "and" ( lOneHot : OneHotArray_t; rByteArray : ByteArray_t)
    return ByteArray_t;

  function "or" ( Left, Right : ByteArray_t ) return ByteArray_t;

  function "and" ( Enable : std_ulogic; Word : ByteArray_t )
    return ByteArray_t;

  function "and" ( Word : ByteArray_t; Enable : std_ulogic)
    return ByteArray_t;

end PkgByteArray;

package body PkgByteArray is

  -----------------------------------------------------------------------------
  -- The conversion function from std_logic_vector to ByteArray_t takes the
  -- leftmost 8 bits and puts it into the leftmost byte of the array.  The MSB
  -- of each byte will be the leftmost bit in the std_logic_vector.
  --
  -- For example: If the input is (31 downto 0), bit 31 will be the MSB in byte
  -- 3 of the output and bit 24 will be the LSB. Likewise if the input is
  -- (0 to 31), bit 0 will be the MSB in byte 3 of the output and bit 7 will be
  -- the LSB.
  --
  -- The input must be a multiple of 8 bits. The function checks for illegal
  -- inputs at simulation time.
  -----------------------------------------------------------------------------
  function to_ByteArray(arg : std_logic_vector) return ByteArray_t is
    alias MyArg : std_logic_vector(arg'length-1 downto 0) is arg;

    variable rVal : ByteArray_t(arg'length / 8 - 1 downto 0);
  begin

    --RTL_SYNTHESIS_OFF
    assert (((arg'length) mod 8) = 0)
      report "Input to the function to_ByteArray must be a multiple of 8"
      severity FAILURE;
    --RTL_SYNTHESIS_ON

    for ThisByte in rVal'range loop
      rVal(ThisByte) := MyArg((ThisByte*8)+7 downto ThisByte*8);
    end loop;

    return rval;
  end function to_ByteArray;

  -----------------------------------------------------------------------------
  --Converting an unsigned to a Byte array works in the same way as converting
  --a std_logic_vector.  The existence of the function is purely for
  --typographical convenience.
  -----------------------------------------------------------------------------
  function to_ByteArray(arg : unsigned) return ByteArray_t is
  begin
    return to_ByteArray(std_logic_vector(arg));
  end function to_ByteArray;

  -----------------------------------------------------------------------------
  -- When converting from ByteArray_t to std_logic_vector, the leftmost Byte in
  -- the ByteArray_t ends up in the leftmost bits of te std_logic_vector
  -- regardless of whether that vector or ByteArray is declared as "downto"
  -- or "to".  It is the exact inverse of the to_ByteArray function.
  -----------------------------------------------------------------------------
  function to_StdLogicVector( arg : ByteArray_t) return std_logic_vector is
    alias MyArg : ByteArray_t(arg'length-1 downto 0) is arg;
    variable rval : std_logic_vector(arg'length*8 - 1 downto 0);
  begin

    --Because ByteArray_t is a subtype of SLV, it can be directly assigned.
    for ThisByte in MyArg'range loop
      rval((ThisByte*8)+7 downto ThisByte*8) := MyArg(ThisByte);
    end loop;

    return rval;

  end function to_StdLogicVector;

  -----------------------------------------------------------------------------
  -- The function to convert a ByteArray_t to an unsigned is identical to the
  -- function to convert a ByteArray_t to a std_logic_vector.  It only exists
  -- for typographical convenience.
  -----------------------------------------------------------------------------
  function to_Unsigned( arg : ByteArray_t) return unsigned is
  begin
    return unsigned(to_StdLogicVector(arg));
  end function to_Unsigned;

  -----------------------------------------------------------------------------
  --This ORs all the bytes of the byte array together to make a single byte.
  --This is most useful after having "ANDed" the ByteArray_t with a
  --OneHotArray_t, esentially implementing a multiplexor.
  -----------------------------------------------------------------------------
  function OrReduce (constant Arg : ByteArray_t) return Byte_t is
    variable AccumulatedByte : Byte_t := (others => '0');
  begin  -- OrReduce

    --The OR operator works on Byte_t because it is a subtype of std_logic_
    --vector.
    for ThisByte in Arg'range loop
      AccumulatedByte := AccumulatedByte or Arg(ThisByte);
    end loop;  -- ThisByte

    return AccumulatedByte;
  end OrReduce;

  function ByteAnd ( L : Byte_t; R : std_ulogic) return Byte_t is
    variable rval : Byte_t;
  begin
    for i in rval'range loop
      rval(i) := L(i) and R; -- uses the 1164 "and"
    end loop;
    return rval;
  end function ByteAnd;

  function ByteAnd ( L : std_ulogic; R : Byte_t) return Byte_t is
  begin
    return ByteAnd(R,L); -- uses the predefined twin (above)
  end function ByteAnd;

  -----------------------------------------------------------------------------
  --These functions takes a OneHotArray type and a ByteArray, which must be of
  --the same size.  It then masks off (sets to X"00") all bytes except for the
  --byte corresponding to the '1' in the OneHotArray.
  -----------------------------------------------------------------------------
  function "and"( lByteArray : ByteArray_t; rOneHot : OneHotArray_t)
    return ByteArray_t is
    variable AlignedOneHot : OneHotArray_t(lByteArray'range);
    variable RetVal : ByteArray_t(lByteArray'range);
  begin  -- "and"

    --RTL_SYNTHESIS_OFF
    assert (lByteArray'length = rOneHot'length)
      report ("Can't AND together a ByteArray and a OneHotArray unless they"
              & "are the same size")
      severity FAILURE;
    --RTL_SYNTHESIS_ON

    --Although both of the vectors are of the same size, keep in mind that they
    --may have different indices, which shouldn't cause a simulation-time
    --error. This is achieved by assigning the input OneHotArray_t, to one that
    --has the same range as the ByteArray_t.
    AlignedOneHot := rOneHot;
    for i in lByteArray'range loop
      RetVal(i) := ByteAnd(lByteArray(i), AlignedOneHot(i));
    end loop;  -- CurrentByte

    return RetVal;

  end "and";

  -----------------------------------------------------------------------------
  -- This is the same as the other "AND" function for ByteArray_t and OneHot_t,
  -- it exists simply to make AND work the same way no matter which parameter
  -- is on the left or the right.
  -----------------------------------------------------------------------------
  function "and"( lOneHot : OneHotArray_t; rByteArray : ByteArray_t)
    return ByteArray_t is
  begin  -- "and"

    return (rByteArray and lOneHot);

  end "and";

  function "or" ( Left, Right : ByteArray_t ) return ByteArray_t is
    alias lv : ByteArray_t(1 to Left'length) is Left;
    alias rv : ByteArray_t(1 to Right'length) is Right;
    variable rval : ByteArray_t(1 to Left'length);
  begin

    if (Left'length /= Right'length ) then
      report "arguments of 'or' operator are not the same length"
      severity failure;
    else
      for i in rval'range loop
        rval(i) := lv(i) or rv(i);
      end loop;
    end if;

    return rval;
  end function "or";

  function "and" ( Enable : std_ulogic; Word : ByteArray_t ) return ByteArray_t is
    variable rval : ByteArray_t(Word'range);
  begin
    for i in rval'range loop
      rval(i) := ByteAnd(Enable, Word(i));
    end loop;
    return rval;
  end function "and";

  function "and" ( Word : ByteArray_t; Enable : std_ulogic) return ByteArray_t is
  begin
    return Enable and Word;
  end function "and";

end PkgByteArray;
