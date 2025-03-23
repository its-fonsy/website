---
title: "VHDL"
notes: ["HDL"]
---

## Code snippets

{{< details summary="Entity with FSM" >}}
```vhdl
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ENTITY_NAME is
    port (
             clk   : in  std_logic;
             rstn  : in  std_logic
         );
end entity ENTITY_NAME;

architecture RTL of ENTITY_NAME is

    -- FSM states type definition
    type fsm_state is (FSM_INIT);

    -- Constants definition

    -- Signals
    signal cs, ns : fsm_state;

begin

    -- FSM state register
    fsm_reg: process(clk) is
    begin
        if rising_edge(clk) then
            if rstn = '0' then
                cs <= FSM_INIT;
            else
                cs <= ns;
            end if;
        end if;
    end process fsm_reg;

    -- FSM datapath
    fsm_datapath: process(cs) is
    begin

        -- Default signals values

        -- State switch case
        case cs is

            when FSM_INIT =>
                ns <= FSM_INIT;

            when others =>
                ns <= FSM_INIT;

        end case;
    end process fsm_datapath;

end architecture RTL;
```
{{< /details >}}

{{< details summary="Testbench" >}}
```vhdl
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.finish;

-- Empty entity for testbench
entity TESTBENCH is
    end TESTBENCH;

architecture behav of TESTBENCH is

    -- Constants definition
    constant clock_frequency  : integer := 100e6;
    constant clock_period     : time := 1000 ms / clock_frequency;

    -- Component definition
    component ENTITY_TO_TEST is
        port(
                clk : in std_logic
            );
    end component;

    -- Signals definitions
    signal clk         : std_logic := '0';
    signal rstn        : std_logic;

begin

    dut: ENTITY_TO_TEST port map(clk);

    -- Clock process
    clk <= not clk after clock_period / 2;

    -- Main simulation process
    stimuli: process is
    begin

        -- Initialize the signals
        rstn <= '1';
        wait until falling_edge(clk);

        -- Reset the system
        rstn <= '0';
        wait until falling_edge(clk);
        rstn <= '1';

        report "Test finished";
        finish;

    end process;

end behav;
```
{{< /details >}}

{{< details summary="Array of `std_logic_vector`" >}}
```vhdl
type array_t is array (0 to 7) of std_logic_vector(4 downto 0);
constant data : array_t := ("00110", "00000", "01010", "11111",
                            "00000", "11100", "10001", "01100");
```
{{< /details >}}

{{< details summary="Procedure" >}}
```vhdl
procedure procedure_name (
                    signal a    : out std_logic;
                    signal b    : out std_logic;
                    signal clk  : in  std_logic
                  ) is
begin

end procedure procedure_name;
```
{{< /details >}}

{{< details summary="Generate random numbers" >}}
```vhdl
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.uniform;
use ieee.math_real.floor;

-- Variable definitions
variable seed1  : positive;
variable seed2  : positive;
variable x      : real;
variable y      : integer;

-- Procedures
procedure random_data(
                        signal clk      : in    std_logic;
                        signal data_in  : out   std_logic_vector(7 downto 0)
                        ) is
begin
    for n in 1 to 10 loop
        -- Generate random value
        uniform(seed1, seed2, x);
        y := integer(floor(x * 256.0));

        -- Input random value
        data_in <= std_logic_vector(to_unsigned(y, 8));
        wait until falling_edge(clk);
    end loop;
end procedure push_random_data;
```
{{< /details >}}
