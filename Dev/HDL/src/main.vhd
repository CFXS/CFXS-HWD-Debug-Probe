library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library CFXS;
use CFXS.Utils.RequiredBits;
use CFXS.Utils.MillisecondsToCycles;

-------------------------------
-- [SWD Pins]
-- yellow SWDIO GPIO_1.0  PIN_Y15 => PIN_AC24
-- green SWCLK GPIO_1.2   PIN_AA15 => PIN_AD26
-- blue SWO GPIO_1.4      PIN_AG28 => PIN_AF28
-- white RESET GPIO_1.6   PIN_AE25 => PIN_AF27

entity main is
    port (
        system_clock : in std_logic;
        i_switch     : in std_logic_vector(3 downto 0);
        i_button     : in std_logic_vector(1 downto 0);
        o_led        : out std_logic_vector(7 downto 0);

        -- Target SWD/SWO signals
        target_nreset : out std_logic;
        target_swclk  : out std_logic;
        target_swdio  : inout std_logic;
        target_swo    : in std_logic;

        -- Mirrored pins for logic analyzer
        dbg_target_nreset : out std_logic;
        dbg_target_swclk  : out std_logic;
        dbg_target_swdio  : out std_logic;
        dbg_target_swo    : out std_logic
    );
end entity;

architecture RTL of main is
    constant CLOCK_FREQUENCY       : natural := 50_000_000; -- 50MHz
    constant SLOW_CLOCK_FREQUENCY  : natural := 50_000_000 / 128;
    constant SWCLK_FREQUENCY       : natural := 500_000;                                   -- SWCLK frequency
    constant SWCLK_DEFAULT_DIVIDER : natural := CLOCK_FREQUENCY / 2 / SWCLK_FREQUENCY - 1; -- Divider for SWCLK

    signal reg_ButtonState : std_logic_vector(i_button'length - 1 downto 0) := (others => '0');

    -- SWD/SWO registers
    signal reg_SWCLK_Divider        : unsigned(RequiredBits(SWCLK_DEFAULT_DIVIDER) - 1 downto 0) := to_unsigned(SWCLK_DEFAULT_DIVIDER, RequiredBits(SWCLK_DEFAULT_DIVIDER));
    signal reg_target_swclk         : std_logic;
    signal reg_SWD_RequestLineReset : std_logic := '0';

    -- Target reset
    signal reg_Target_NRESET : std_logic;

    -- Slow clock
    signal reg_SlowClockCounter : unsigned(6 downto 0) := (others => '0');
    signal slow_clock           : std_logic            := '0';
begin
    process (system_clock)
    begin
        if rising_edge(system_clock) then
            reg_SlowClockCounter <= reg_SlowClockCounter + 1;
            slow_clock           <= reg_SlowClockCounter(6);
        end if;
    end process;

    instance_ButtonDebouncer : entity CFXS.FixedDebounce
        generic map(
            STABLE_CYCLES => MillisecondsToCycles(10, SLOW_CLOCK_FREQUENCY),
            N             => i_button'length
        )
        port map(
            clock  => slow_clock,
            input  => not i_button,
            output => reg_ButtonState
        );

    o_led(7 downto 6) <= reg_ButtonState;

    instance_TestPulse : entity CFXS.PulseGenerator
        generic map(
            IDLE_OUTPUT  => '0',
            PULSE_LENGTH => SLOW_CLOCK_FREQUENCY / SWCLK_FREQUENCY + 1
        )
        port map(
            clock   => slow_clock,
            trigger => reg_ButtonState(0),
            output  => reg_SWD_RequestLineReset
        );

    ----------------------------------------------------
    -- Reset signal
    instance_ResetPulseGenerator : entity CFXS.PulseGenerator
        generic map(
            IDLE_OUTPUT  => '1',
            PULSE_LENGTH => MillisecondsToCycles(20, SLOW_CLOCK_FREQUENCY)
        )
        port map(
            clock   => slow_clock,
            trigger => reg_ButtonState(1),
            output  => reg_Target_NRESET
        );

    target_nreset     <= reg_Target_NRESET;
    dbg_target_nreset <= reg_Target_NRESET;
    o_led(1)          <= not reg_Target_NRESET;

    ----------------------------------------------------
    -- SWD/SWO
    instance_SWD_Interface : entity CFXS.Interface_SWD
        generic map(
            SWCLK_DIV_WIDTH  => RequiredBits(SWCLK_DEFAULT_DIVIDER),
            USE_SWDIO_MIRROR => true
        )
        port map(
            clock                 => system_clock,
            cfg_SWCLK_Divider     => reg_SWCLK_Divider,
            target_swclk          => reg_target_swclk,
            target_swdio          => target_swdio,
            mirror_target_swdio   => dbg_target_swdio,
            request_SendLineReset => reg_SWD_RequestLineReset or i_switch(0),
            status_Busy           => o_led(0)
        );

    -- Multiple outputs for SWCLK
    target_swclk     <= reg_target_swclk;
    dbg_target_swclk <= reg_target_swclk;

    -- Forward SWO
    dbg_target_swo <= target_swo;

end architecture;