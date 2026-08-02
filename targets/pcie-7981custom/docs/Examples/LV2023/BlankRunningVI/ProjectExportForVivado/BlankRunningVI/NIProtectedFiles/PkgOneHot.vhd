-------------------------------------------------------------------------------
--
-- File: pkgOneHot.vhd
-- Author: Christopher A. Clark
-- Original Project: IMAQ PCI-X Interface
-- Date: 18 March 2004
--
-------------------------------------------------------------------------------
-- (c) 2004 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--      This package creates the type OneHotArray_t, and some functions to act
--      upon it.  The type is an array of std_logic, where only one of the bits
--      is '1'.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.PkgNiUtilities.all;

Package pkgOneHot is

  type OneHotArray_t is array (natural range<>) of std_logic;

  function to_OneHotArray (constant Arg : std_logic_vector)
    return OneHotArray_t;

  function to_OneHotArray (constant BitToSet  : natural;
                           constant ArraySize : natural)
    return OneHotArray_t;
  
  function to_unsigned (arg : in OneHotArray_t) return unsigned;

  function to_OneHotArray (arg : in unsigned) return OneHotArray_t;

end pkgOneHot;

Package body pkgOneHot is

  -----------------------------------------------------------------------------
  --Checks to make sure that the supposedly One-Hot array, really is.  Because
  --the type is derived from std_logic_vector, it is very easy to caste
  --something that is not One-Hot to this type.
  function isLegal(arg : in OneHotArray_t ) return boolean is
    variable FoundOne : boolean;
    variable FoundTwo : boolean;
  begin
    FoundOne := false;
    FoundTwo := false;

    for i in arg'range loop
      if arg(i)='1' then
        FoundTwo := FoundOne;
        FoundOne := true;
      end if;
    end loop;

    return FoundOne and not FoundTwo;
  end isLegal;

  -----------------------------------------------------------------------------
  --Returns the index of the one-hot array that contains a '1'.  If it isn't
  --really one-hot, the first one is what is returned.
  function to_unsigned (arg : in OneHotArray_t ) return unsigned is
    variable rval : unsigned(Log2(arg'length)-1 downto 0);
    variable FoundOne : boolean;
  begin

    --RTL_TRANSLATE_OFF
    assert isLegal(arg)
      report "Illegal argument to to_unsigned(arg : in OneHotArray_t)"
      severity error;
    --RTL_TRANSLATE_ON

    rval := (others => '0');
    FoundOne := false;
    for i in arg'range loop
      if (not FoundOne) and (arg(i)='1') then
        FoundOne := true;
        rval := to_unsigned(i,rval'length);
      end if;
    end loop;

    return rval;
  end to_unsigned;

  -----------------------------------------------------------------------------
  --Returns a OneHotArray_t that has one and only one bit set to '1'.
  --The '1' bit will be the index provided as the argument to the function.
  --The size of the argurment (number of bits) determines the length of the
  --OneHotArray_t, it is the smallest array that could describe any of the
  --possible unsigned inputs.
  function to_OneHotArray (arg : in unsigned) return OneHotArray_t is
    variable rval : OneHotArray_t((2**arg'length)-1 downto 0);
  begin
    rval := (others => '0');
    rval(to_integer(arg)) := '1';

    --I don't see how this can really ever fail, but it is a good sanity check
    
    --RTL_TRANSLATE_OFF
    assert isLegal(rval)
      report "Illegal output from to_OneHotArray(arg : in unsigned)"
      severity error;
    --RTL_TRANSLATE_ON

    return rval;
  end to_OneHotArray;

  -----------------------------------------------------------------------------
  --A conversion function from std_logic_vector to OneHotArray_t is not
  --technically required since they are related types.  This function exists so
  --that it will be used instead of the a caste, guaranteeing that
  --OneHotArray_t will always be One-Hot.
  --If the input is no-hot, the rightmost bit of the OneHotArray_t will be set.
  --If the input has multiple bits = '1' then the rightmost one will be used
  --to form the OneHotArray_t 
  function to_OneHotArray (constant Arg : std_logic_vector)
    return OneHotArray_t is
    alias MyArg : std_logic_vector(Arg'length-1 downto 0) is Arg;
    variable RightMostFound : natural := Arg'length;
    variable rVal : OneHotArray_t(Arg'length -1 downto 0) := (others => '0');
  begin

    --Find the right-most '1' in the argument.  If there is none,
    --RightMostFound will be one greater than the upper bound of the argument
    --after this loop completes execution.
    for BitNumber in MyArg'range loop
      if RightMostFound = MyArg'length then
        if MyArg(BitNumber) = '1' then
          RightMostFound := BitNumber;
        end if;
      end if;
    end loop;  -- BitNumber

    --RTL_TRANSLATE_OFF
    assert RightMostFound /= MyArg'length
      report "Attempted to convert no-hot SLV to OneHotArray_t"
      severity ERROR;
    --RTL_TRANSLATE_ON

    if (RightMostFound = MyArg'length) then
      rVal(0) := '1';
    else
      rVal(RightMostFound) := '1';
    end if;
    
    --RTL_TRANSLATE_OFF
    assert isLegal(rVal)
      report "Attempted to convert multiple-hot SLV to OneHotArray_t"
      severity error;
    --RTL_TRANSLATE_ON

    return rVal;
    
  end to_OneHotArray;

  -----------------------------------------------------------------------------
  -- This function allows you to create a OneHotArray_t by specifying how big
  -- that array should be and which index of the array should be hot.
  function to_OneHotArray (constant BitToSet  : natural;
    constant ArraySize : natural)
    return OneHotArray_t is

    variable SLV : std_logic_vector(ArraySize-1 downto 0);
  begin

    --RTL_TRANSLATE_OFF
    assert (ArraySize > BitToSet)
      report "Illegal Inputs to OneHotArray conversion function, cannot set"
             & "a bit outside of the array range"
      severity ERROR;
    --RTL_TRANSLATE_ON

    for i in SLV'range loop
      if i = BitToSet then
        SLV(i) := '1';
      else
        SLV(i) := '0';
      end if;
    end loop;  -- i
    
    return to_OneHotArray(SLV);
    
  end to_OneHotArray;

end pkgOneHot;
