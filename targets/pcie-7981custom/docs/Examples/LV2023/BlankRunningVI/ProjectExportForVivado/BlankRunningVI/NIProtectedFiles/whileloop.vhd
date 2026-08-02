-- (c) 2003, 2005, 2006 National Instruments Corporation.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
library work;
  use work.PkgNiUtilities.all;

entity whileloop is
  generic (
    STOP_IF_TRUE : NATURAL := 0;
    INIT_NEEDED : NATURAL := 0;
    kNeverEnds : Natural := 0;
    kDiagramWithInit : Natural := 0;
    kJustDiagram : Natural := 0;
    kCounterUnconnected : Natural := 0;
    kRegisterMode : integer := 1 
  );
  port(
    clk : in std_logic;
    reset : in std_logic;
    enable_in : in std_logic;
    enable_out : out std_logic;
    enable_clr : in std_logic;
    subdiag_en : out std_logic;
    subdiag_done : in std_logic;
    subdiag_clr : out std_logic;
    iteration : out std_logic_vector(31 downto 0);
    loopinit : out std_logic;
    cont : in std_logic_vector(0 downto 0)
  );
end whileloop;

architecture rtl of whileloop is
  
  type state_t is (idle_st,  -- reset state
                   calc_st,  -- enable diagram execution
                   test_st,  -- check for loop completion
                   end_st    -- assert enable_out
                  );


  signal nstate,state : state_t;

  signal lp_iteration : std_logic_vector(31 downto 0);
  signal fcont : std_logic_vector(0 downto 0);
  signal prevEnable_in : std_logic;
  signal timer_en, timer_clr : std_logic;

begin

  subdiag_en <= timer_en;
  subdiag_clr <= timer_clr;

justdiag: if (kJustDiagram=1) generate
  timer_en <= enable_in;
  timer_clr <= enable_clr;
  enable_out <= enable_in and subdiag_done;
  loopinit <= '0';
  iteration <= (others=>'0');
end generate;



diagwithinit: if (kDiagramWithInit = 1) generate
  iteration <= (others=>'0');  
  enable_out <= enable_in and subdiag_done;
  timer_clr <= enable_clr;

  process( clk, reset )
  begin
    if( reset = '1' ) then
        loopinit <= '0';
        prevEnable_in <= '0';
        timer_en <= '0';
    elsif( rising_edge(clk) ) then
        prevEnable_in <= enable_in;
        if( enable_clr = '1' ) then
            timer_en <= '0';
            loopinit <= '0';
        elsif( prevEnable_in = '0' and enable_in = '1' ) then
            loopinit <= '1';
        elsif( enable_in = '1' ) then
            loopinit <= '0';
            timer_en <= '1';
        end if;
    end if;
  end process;
end generate;


normalproc: if (kDiagramWithInit=0 and kJustDiagram = 0) generate

  stop_if_true_g:
  if (STOP_IF_TRUE=1) generate
  fcont <= not cont;
  end generate;

  continue_if_true_g:
  if (STOP_IF_TRUE=0) generate
    fcont <= cont;
  end generate;
  
  process(state,enable_in,enable_clr,subdiag_done,fcont)
  begin
    timer_clr <= '0';
    timer_en <= '0';
    enable_out <= '0';

    case state is
      when idle_st =>
        timer_clr <= '1';
        loopinit <= '0';
        if enable_in='1' then
          nstate <= calc_st;
        else
          nstate <= idle_st;
        end if;
      when calc_st =>
        timer_en <= '1';
        loopinit <= '0';
        if subdiag_done='1' then
          nstate <= test_st;
        else
          nstate <= calc_st;
        end if;
      when test_st =>
        loopinit <= '0';
        if fcont(0 downto 0)="1" then -- this may be a problem, b/c subdiag_clr is function of input
          timer_clr <= '1';                 -- and not just the current state
          nstate <= calc_st;
        else
          timer_en <= '1';
          nstate <= end_st;
        end if;
      when end_st =>
        loopinit <= '0';
        timer_en <= '1';                            -- Anshul M. (11/08): On
                                                      -- the last iteration
                                                      -- keep the sub_diagram
                                                      -- enabled so that values
                                                      -- from the subdiagram
                                                      -- can be read through
                                                      -- the tunnels.
        enable_out <= '1';
        nstate <= end_st;
    end case;

    -- Because it appears at the end of the process, this test
    -- overrides any previous assignments to nstate
    if enable_clr='1' then
      -- Fix CAR:507809, to assert shift register one cycle earlier when the subdiagram is done.
      timer_clr <= '1'; 
      nstate <= idle_st;
    end if;
  end process;
  
  process(clk, reset)
  begin
    if (reset = '1') then
      state <= idle_st; 
    elsif rising_edge(clk) then
      state <= nstate;
    end if;
  end process;

countuncon: if (kCounterUnconnected=1) generate
  iteration <= (others=>'0');
end generate;

countcon: if (kCounterUnconnected=0) generate
  iteration <= lp_iteration;

  process(clk, reset)
  begin
    if (reset = '1') then
      lp_iteration <= Zeros(32);
    elsif rising_edge(clk) then
      if state=idle_st then
        lp_iteration <= Zeros(32);
      elsif state = test_st and fcont(0 downto 0)="1" 
              and lp_iteration(30 downto 0) /= Ones(31) then
        lp_iteration <= lp_iteration + 1;
      end if;
    end if;
  end process;
end generate;

end generate;

end rtl;
