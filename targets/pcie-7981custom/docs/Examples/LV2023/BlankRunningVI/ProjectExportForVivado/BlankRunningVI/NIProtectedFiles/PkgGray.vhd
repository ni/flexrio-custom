-------------------------------------------------------------------------------
--
-- File: PkgGray.vhd
-- Author: Paul Butler
-- Original Project: FIFO
-- Date: 12 April 2000
--
-------------------------------------------------------------------------------
-- (c) 2003 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--  Converts unsigned to gray and gray to unsigned
--  Also supplies functions for adding and subtracting
-- gray numbers and unsigned numbers in any combination.
--  Has general purpose use but was specifically
-- designed to be used in FifoFlags.vhd module to
-- allow safe crossing of address pointers.
--
-- Modified:
--   4/11/03 Craig Conway
--      Added comments and header
--   10/21/03 Craig Conway
--      Updated per style guidelines
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package PkgGray is

  -- type definition
  type Gray is array (natural range<>) of std_ulogic;

  ----------------------
  -- Function prototypes
  ----------------------

  -- Conversion functions
  function To_Gray (Arg : in unsigned) return Gray ;
  function To_Unsigned (Arg : in Gray) return unsigned ;
  function To_GrayInt ( Arg : in Gray) return integer ;

  -- Addition functions
  function "+" (l : in Gray; r : in Gray) return Gray ;
  function "+" (l : in Gray; r : in integer) return Gray ;
  function "+" (l : in integer; r : in Gray) return Gray ;
  function "+" (l : in Gray; r : in unsigned) return Gray ;
  function "+" (l : in unsigned; r : in Gray) return Gray ;

  -- Subtraction functions
  function "-" (l : in Gray; r : in Gray) return unsigned ;
  function "-" (l : in Gray; r : in integer) return unsigned ;
  function "-" (l : in integer; r : in Gray) return unsigned ;
  function "-" (l : in Gray; r : in unsigned) return unsigned ;
  function "-" (l : in unsigned; r : in Gray) return unsigned ;

  -- Equality functions
  function "=" (l, r : in Gray) return boolean;
  function "/=" (l, r : in Gray) return boolean;

end PkgGray;

package body PkgGray is

  -------------------------------------------------------------------
  -- Conversion functions
  -------------------------------------------------------------------

  -- Conversion function from unsigned to gray
  function To_Gray (Arg : in unsigned) return Gray is
    variable Result : Gray(Arg'range);
  begin
    Result := (others => '0');
    Result(Result'high) := Arg(Arg'high);
    for i in Result'high-1 downto Result'low loop
      Result(i) := Arg(i) xor Arg(i+1);
    end loop;
    return Result;
  end To_Gray;

  -- Conversion function from gray to unsigned
  function To_Unsigned (Arg : in Gray) return unsigned is
    variable Result : unsigned(Arg'range);
  begin
    Result(Result'high) := Arg(Arg'high);
    for i in Result'high-1 downto Result'low loop
      Result(i) := Result(i+1) xor Arg(i);
    end loop;
    return Result;
  end To_Unsigned;


  function To_GrayInt ( Arg : in Gray) return integer is
    variable Uns : unsigned(Arg'range);
  begin
    for i in Arg'range loop
      Uns(i) := Arg(i);
    end loop;
    return To_Integer(Uns);
  end function To_GrayInt;


  -------------------------------------------------------------------
  -- Addition functions
  -------------------------------------------------------------------

  -- Addition of two grays
  function "+" (l : in Gray; r : in Gray) return Gray is
  begin
    return To_Gray(To_unsigned(l) + To_unsigned(r));
  end "+";

  -- Addition of gray and integer
  function "+" (l : in Gray; r : in integer) return Gray is
  begin
    return To_Gray(To_unsigned(l) + r);
  end "+";

  -- Addition of integer and gray
  function "+" (l : in integer; r : in Gray) return Gray is
  begin
    return To_Gray(l + To_unsigned(r));
  end "+";

  -- Addition of gray and unsigned
  function "+" (l : in Gray; r : in unsigned) return Gray is
  begin
    return To_Gray(To_unsigned(l) + r);
  end "+";

  -- Addition of unsigned and gray
  function "+" (l : in unsigned; r : in Gray) return Gray is
  begin
    return To_Gray(l + To_unsigned(r));
  end "+";

  -------------------------------------------------------------------
  -- Subtraction functions
  -------------------------------------------------------------------

  -- Subtraction of two grays
  function "-" (l : in Gray; r : in Gray) return unsigned is
  begin
    return (To_unsigned(l)-To_unsigned(r));
  end "-";

  -- Subtraction of gray and integer
  function "-" (l : in Gray; r : in integer) return unsigned is
  begin
    return (To_unsigned(l)-r);
  end "-";

  -- Subtraction of integer and gray
  function "-" (l : in integer; r : in Gray) return unsigned is
  begin
    return (l-To_unsigned(r));
  end "-";

  -- Subtraction of gray and unsigned
  function "-" (l : in Gray; r : in unsigned) return unsigned is
  begin
    return (To_unsigned(l)-r);
  end "-";

  -- Subtraction of unsigned and gray
  function "-" (l : in unsigned; r : in Gray) return unsigned is
  begin
    return (l-To_unsigned(r));
  end "-";


  -------------------------------------------------------------------
  -- Equality functions
  -------------------------------------------------------------------
  function "=" (l, r : in Gray) return boolean is
  begin
    for i in l'range loop
      if l(i)/=r(i) then return false; end if;
    end loop;
    return true;
  end function "=";

  function "/=" (l, r : in Gray) return boolean is
  begin
    if l=r then return false; else return true; end if;
    --return not l=r;
  end function "/=";

end PkgGray;

