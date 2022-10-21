library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library CFXS;
use CFXS.Utils.all;

-------------------------------
-- [SWD Pins]
-- yellow SWDIO GPIO_1.0  PIN_Y15  => PIN_AC24
-- green SWCLK GPIO_1.2   PIN_AA15 => PIN_AD26
-- blue SWO GPIO_1.4      PIN_AG28 => PIN_AF28
-- white RESET GPIO_1.6   PIN_AE25 => PIN_AF27

entity main is
    port (
        clock_System : in std_logic;
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
    constant SLOW_CLOCK_CASCADE    : natural := 7;          -- /128
    constant SLOW_CLOCK_FREQUENCY  : natural := 50_000_000 / (2 ** SLOW_CLOCK_CASCADE);
    constant SWCLK_FREQUENCY       : natural := 12_500_000;                                -- SWCLK frequency
    constant SWCLK_DEFAULT_DIVIDER : natural := CLOCK_FREQUENCY / 2 / SWCLK_FREQUENCY - 1; -- Divider for SWCLK

    signal reg_ButtonState : std_logic_vector(i_button'length - 1 downto 0) := (others => '0');

    -- SWD/SWO registers
    signal reg_SWCLK_Divider             : unsigned(HighBit(SWCLK_DEFAULT_DIVIDER) downto 0) := to_unsigned(SWCLK_DEFAULT_DIVIDER, RequiredBits(SWCLK_DEFAULT_DIVIDER));
    signal reg_target_swclk              : std_logic;
    signal reg_SWD_RequestLineReset      : std_logic := '0';
    signal reg_SWD_RequestReadData       : std_logic := '0';
    signal reg_SWD_RequestSwitchSequence : std_logic := '0';
    signal reg_SWD_DataOut               : std_logic_vector(31 downto 0);

    -- Target reset
    signal reg_Target_NRESET : std_logic;

    -- Slow clock
    signal clock_Slow : std_logic := '0';
begin
    instance_SlowClockDivider : entity CFXS.CascadeClockDivider
        generic map(
            N => SLOW_CLOCK_CASCADE
        )
        port map(
            clock     => clock_System,
            clock_div => clock_slow
        );

    instance_ButtonDebouncer : entity CFXS.FixedDebounce
        generic map(
            STABLE_CYCLES => MillisecondsToCycles(10, SLOW_CLOCK_FREQUENCY),
            N             => i_button'length
        )
        port map(
            clock  => clock_Slow,
            input  => not i_button,
            output => reg_ButtonState
        );

    o_led(7 downto 6) <= reg_ButtonState;

    instance_TestPulse1 : entity CFXS.PulseGenerator
        generic map(
            IDLE_OUTPUT  => '0',
            PULSE_LENGTH => SLOW_CLOCK_FREQUENCY / SWCLK_FREQUENCY + 1
        )
        port map(
            clock   => clock_Slow,
            trigger => reg_ButtonState(0),
            output  => reg_SWD_RequestReadData
        );

    instance_TestPulse2 : entity CFXS.PulseGenerator
        generic map(
            IDLE_OUTPUT  => '0',
            PULSE_LENGTH => SLOW_CLOCK_FREQUENCY / SWCLK_FREQUENCY + 1
        )
        port map(
            clock   => clock_Slow,
            trigger => reg_ButtonState(1),
            output  => reg_SWD_RequestSwitchSequence
        );

    ----------------------------------------------------
    -- Reset signal
    instance_ResetPulseGenerator : entity CFXS.PulseGenerator
        generic map(
            IDLE_OUTPUT  => '1',
            PULSE_LENGTH => MillisecondsToCycles(20, SLOW_CLOCK_FREQUENCY)
        )
        port map(
            clock   => clock_Slow,
            trigger => i_switch(3),
            output  => reg_Target_NRESET
        );

    target_nreset     <= reg_Target_NRESET;
    dbg_target_nreset <= reg_Target_NRESET;
    o_led(5)          <= not reg_Target_NRESET;

    ----------------------------------------------------
    -- SWD/SWO
    instance_SWD_Interface : entity CFXS.Interface_SWD
        generic map(
            SWCLK_DIV_WIDTH  => RequiredBits(SWCLK_DEFAULT_DIVIDER),
            USE_SWDIO_MIRROR => true
        )
        port map(
            clock                      => clock_System,
            cfg_SWCLK_Divider          => reg_SWCLK_Divider,
            target_swclk               => reg_target_swclk,
            target_swdio               => target_swdio,
            mirror_target_swdio        => dbg_target_swdio,
            request_SendLineReset      => '0',
            request_SendSwitchSequence => reg_SWD_RequestSwitchSequence,
            request_ReadData           => reg_SWD_RequestReadData,
            status_Busy                => o_led(0),
            status_ParityError         => o_led(1),
            status_TransferDone        => o_led(2),
            swd_DataOut                => reg_SWD_DataOut,

            swd_Header => "10100101" -- Read DP IDCODE
        );

    -- Multiple outputs for SWCLK
    target_swclk     <= reg_target_swclk;
    dbg_target_swclk <= reg_target_swclk;

    -- Forward SWO
    dbg_target_swo <= target_swo;

end architecture;