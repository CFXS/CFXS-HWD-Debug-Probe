library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library CFXS;

-------------------------------
-- [SWD Pins]
-- yellow SWDIO GPIO_1.0  PIN_Y15 => PIN_AC24
-- green SWCLK GPIO_1.2   PIN_AA15 => PIN_AD26
-- blue SWO GPIO_1.4      PIN_AG28 => PIN_AF28
-- white RESET GPIO_1.6   PIN_AE25 => PIN_AF27

entity CFXS_HWD_TestDev is
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

architecture RTL of CFXS_HWD_TestDev is
    constant CLOCK_FREQUENCY       : natural := 50_000_000;                          -- 50MHz
    constant SWCLK_DEFAULT_DIVIDER : natural := CLOCK_FREQUENCY / 2 / 1_000_000 - 1; -- Target SWCLK frequency 1MHz

    signal reg_ButtonState : std_logic_vector(i_button'length - 1 downto 0) := (others => '0');

    -- SWD/SWO registers
    signal reg_SWCLK_Divider : unsigned(CFXS.Utils.RequiredBits(SWCLK_DEFAULT_DIVIDER) - 1 downto 0) := to_unsigned(SWCLK_DEFAULT_DIVIDER, CFXS.Utils.RequiredBits(SWCLK_DEFAULT_DIVIDER));
    signal reg_target_swclk  : std_logic;
begin
    instance_ButtonDebouncer : entity CFXS.FixedDebounce
        generic map(
            STABLE_CYCLES => CFXS.Utils.MillisecondsToCycles(10, CLOCK_FREQUENCY),
            N             => i_button'length
        )
        port map(
            clock  => system_clock,
            input  => not i_button,
            output => reg_ButtonState
        );

    o_led(7 downto 6) <= reg_ButtonState;

    ----------------------------------------------------
    -- SWD/SWO
    instance_SWD_Interface : entity CFXS.Interface_SWD
        generic map(
            SWCLK_DIV_WIDTH  => CFXS.Utils.RequiredBits(SWCLK_DEFAULT_DIVIDER),
            USE_SWDIO_MIRROR => true
        )
        port map(
            clock                      => system_clock,
            cfg_SWCLK_Divider          => reg_SWCLK_Divider,
            target_swclk               => reg_target_swclk,
            target_swdio               => target_swdio,
            mirror_target_swdio        => dbg_target_swdio,
            request_SendLineReset      => not i_button(0),
            request_SendSwitchSequence => not i_button(1),
            status_Busy                => o_led(0)
        );

    -- Multiple outputs for SWCLK
    target_swclk     <= reg_target_swclk;
    dbg_target_swclk <= reg_target_swclk;

    -- Forward SWO
    dbg_target_swo <= target_swo;

end architecture;