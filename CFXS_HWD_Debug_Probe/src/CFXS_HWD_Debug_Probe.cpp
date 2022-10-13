// [CFXS] //
#include <CFXS/Platform/App.hpp>
#include <CFXS/Platform/TM4C/CoreInit.hpp>
#include <CFXS/Platform/CPU.hpp>
#include <CFXS/Base/Debug.hpp>
#include <CFXS/Base/Time.hpp>
#include <CFXS/Platform/Task.hpp>
#include <CFXS/LLDS/Types.hpp>
#include <CFXS/LLDS/ARM/ADI_Types.hpp>

using CFXS::Task;
using namespace CFXS;

void InitializeModules() {
    Task::AddGroups({
        {LOW_PRIORITY, 64},
        {HIGH_PRIORITY, 32},
        {SYSTEM_PRIORITY, 2},
    });
}

#include <CFXS/HW/Peripherals/GPIO.hpp>
#include <CFXS/HW/Peripherals/Descriptors/TM4C/Desc_GPIO_TM4C.hpp>

#include <inc/hw_memmap.h>
#include <driverlib/pin_map.h>
#include <driverlib/sysctl.h>

using namespace CFXS::HW;
using namespace CFXS::HW::TM4C;
static const Desc_GPIO desc_LED = {"PF0"};
static CFXS::HW::GPIO pin_LED   = {&desc_LED};

static const Desc_GPIO desc_BTN = {"PJ0", 0, GPIO_PIN_TYPE_STD_WPU};
static CFXS::HW::GPIO pin_BTN   = {&desc_BTN};

static const Desc_GPIO desc_RST = {"PB2", 0, GPIO_PIN_TYPE_STD_WPU};
static CFXS::HW::GPIO pin_RST   = {&desc_RST};

static const Desc_GPIO desc_SWDIO = {"PD3", 0, GPIO_PIN_TYPE_STD_WPU};
static CFXS::HW::GPIO pin_SWDIO   = {&desc_SWDIO};

static const Desc_GPIO desc_SWCLK = {"PC7", 0, GPIO_PIN_TYPE_STD_WPU};
static CFXS::HW::GPIO pin_SWCLK   = {&desc_SWCLK};

////////////////////////////////////////////////////////////
#define SWDIO_ACCESS_ADDRESS (GPIO_PORTD_BASE | GPIO_O_DATA | (GPIO_PIN_3 << 2))
#define SWCLK_ACCESS_ADDRESS (GPIO_PORTC_BASE | GPIO_O_DATA | (GPIO_PIN_7 << 2))
#define READ_SWDIO()         HWREGB(SWDIO_ACCESS_ADDRESS)
#define WRITE_SWDIO(x)       HWREGB(SWDIO_ACCESS_ADDRESS) = x ? 0xFF : 0
#define WRITE_SWCLK(x)       HWREGB(SWCLK_ACCESS_ADDRESS) = x ? 0xFF : 0
#define CLOCK_DELAY()        CFXS::CPU::BlockingCycles(CFXS::CPU::GetCyclesPerMicrosecond() / 2)
////////////////////////////////////////////////////////////
static void SendData(uint32_t data, uint32_t bitCount) {
    for (int i = bitCount - 1; i >= 0; i--) {
        WRITE_SWDIO((data & (1 << i)) != 0);
        CLOCK_DELAY();
        WRITE_SWCLK(false);
        CLOCK_DELAY();
        WRITE_SWCLK(true);
    }
}
static void SendDataWithParity(uint32_t data) {
    bool parity = false;
    for (int i = 0; i < 32; i++) {
        WRITE_SWDIO((data & (1 << i)) != 0);
        if ((data & (1 << i))) {
            parity = !parity;
        }
        CLOCK_DELAY();
        WRITE_SWCLK(false);
        CLOCK_DELAY();
        WRITE_SWCLK(true);
    }
    WRITE_SWDIO(parity);
    CLOCK_DELAY();
    WRITE_SWCLK(false);
    CLOCK_DELAY();
    WRITE_SWCLK(true);
}

template<typename T, bool CALCULATE_PARITY = false>
static T ReadData(uint32_t bitCount, bool* parity = nullptr) {
    CFXS_ASSERT(bitCount <= 32, "Too many bits");
    uint32_t res = 0;
    if constexpr (CALCULATE_PARITY == true) {
        CFXS_ASSERT(parity, "Parity output is nullptr");
        *parity = false;
    }
    for (int i = 0; i < bitCount; i++) {
        WRITE_SWCLK(false);
        CLOCK_DELAY();
        if (READ_SWDIO()) {
            res |= 1 << i;
            if constexpr (CALCULATE_PARITY == true) {
                *parity = !*parity;
            }
        }
        WRITE_SWCLK(true);
        CLOCK_DELAY();
    }
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wstrict-aliasing"
    return *(T*)&res;
#pragma GCC diagnostic pop
}

template<bool CALCULATE_PARITY = false, typename T>
static void ReadDataTo(T* readTo, uint32_t bitCount, bool* parity = nullptr) {
    CFXS_ASSERT(readTo, "[readTo] is nullptr");
    CFXS_ASSERT(bitCount <= 32, "Too many bits");
    if constexpr (CALCULATE_PARITY == true) {
        CFXS_ASSERT(parity, "Parity output is nullptr");
        *parity = false;
    }
    for (int i = 0; i < bitCount; i++) {
        WRITE_SWCLK(false);
        CLOCK_DELAY();
        if (READ_SWDIO()) {
            *readTo |= 1 << i;
            if constexpr (CALCULATE_PARITY == true) {
                *parity = !*parity;
            }
        }
        WRITE_SWCLK(true);
        CLOCK_DELAY();
    }
}

static void SwitchToDataInput() {
    pin_SWDIO.SetPinType(CFXS::HW::GPIO::PinType::INPUT);
}

static void SwitchToDataOutput() {
    pin_SWDIO.SetPinType(CFXS::HW::GPIO::PinType::OUTPUT);
}

////////////////////////////////////////////////////////////
static void SendLineReset() {
    // At least 50 clocks on SWCLK with SWDIO == 1
    SendData(0xFFFFFFFF, 32);
    SendData(0xFFFFFFFF, 32);
}

static void SendSwitchSequence_JTAG_To_SWD() {
    SendLineReset();
    SendData(0x79E7, 16);
    SendLineReset();
    SendData(0, 2); // Dont't remember where I read this, but at least 2 low bits are required for the switch to work
}

template<uint8_t COMMAND, typename T>
static LLDS::ProtocolStatus SWD_Read(T* readTo) {
    SendData(COMMAND, 8);
    SwitchToDataInput();
    SendData(0, 1); // turnaround [probe drives line]
    auto ackCode = ReadData<LLDS::ProtocolStatus>(3);
    bool readParityGood;
    if (ackCode == LLDS::ProtocolStatus::OK) {
        ReadDataTo<true>(reinterpret_cast<uint32_t*>(readTo), 32, &readParityGood);
        readParityGood = readParityGood == ReadData<bool>(1);
    }

    SendData(0, 1); // turnaround [target drives line]
    SwitchToDataOutput();

    if (ackCode == LLDS::ProtocolStatus::OK) {
        return readParityGood ? LLDS::ProtocolStatus::OK : LLDS::ProtocolStatus::BAD_DATA;
    } else if (ackCode == LLDS::ProtocolStatus::SWD_INVALID_ACK_1 || ackCode == LLDS::ProtocolStatus::SWD_INVALID_ACK_2) {
        return LLDS::ProtocolStatus::BAD_DATA;
    } else {
        return ackCode;
    }
}

template<uint8_t COMMAND>
static LLDS::ProtocolStatus SWD_Write(uint32_t data) {
    SendData(COMMAND, 8);
    SwitchToDataInput();
    SendData(0, 1); // turnaround [probe drives line]
    auto ackCode = ReadData<LLDS::ProtocolStatus>(3);
    SendData(0, 1); // turnaround [target drives line]
    SwitchToDataOutput();

    if (ackCode != LLDS::ProtocolStatus::OK) {
        return ackCode;
    }

    SendDataWithParity(data);

    if (ackCode == LLDS::ProtocolStatus::SWD_INVALID_ACK_1 || ackCode == LLDS::ProtocolStatus::SWD_INVALID_ACK_2) {
        return LLDS::ProtocolStatus::BAD_DATA;
    } else {
        return ackCode;
    }
}
////////////////////////////////////////////////////////////

void InitializeApp() {
    pin_LED.Initialize(GPIO::PinType::OUTPUT);
    pin_RST.Initialize(GPIO::PinType::OUTPUT);
    pin_BTN.Initialize(GPIO::PinType::INPUT);
    pin_SWDIO.Initialize(GPIO::PinType::INPUT);
    pin_SWCLK.Initialize(GPIO::PinType::OUTPUT);
    WRITE_SWCLK(true);

    // Reset target
    pin_RST.Write(false);
    CFXS::CPU::BlockingMilliseconds(10);
    pin_RST.Write(true);
    CFXS::CPU::BlockingMilliseconds(5);

    // Send switch to SWD sequence
    SwitchToDataOutput();
    SendSwitchSequence_JTAG_To_SWD();

    // Read ID
    LLDS::ADI::IDCODE_t idcode;
    idcode._val = 0;
    auto stat   = SWD_Read<LLDS::ADI::Command::DP::READ_IDCODE>(&idcode);

    uint32_t ctrlStat;
    SWD_Read<LLDS::ADI::Command::DP::READ_CTRL_STAT>(&ctrlStat);
    SWD_Write<LLDS::ADI::Command::DP::WRITE_ABORT>(0b11110); // Clear errors

    auto writeCtrlStat              = SWD_Write<LLDS::ADI::Command::DP::WRITE_CTRL_STAT>((1 << 28) | (1 << 30));
    LLDS::ProtocolStatus selectStat = LLDS::ProtocolStatus::OK;

    if (writeCtrlStat == LLDS::ProtocolStatus::OK) {
        uint32_t statx = 0;
        // wait for powerup to finish
        while (!(statx & (1 << 29)) || !(statx & (1 << 31)))
            SWD_Read<LLDS::ADI::Command::DP::READ_CTRL_STAT>(&statx);
        // Select AP 0
        selectStat = SWD_Write<LLDS::ADI::Command::DP::WRITE_SELECT>(0);

        SWD_Write<LLDS::ADI::Command::AP::WRITE_CSW>(0x23000012);
        SWD_Write<LLDS::ADI::Command::AP::WRITE_TAR>(0x20000000);
        uint32_t memval = 0;
        while (SWD_Read<LLDS::ADI::Command::AP::READ_DRW>(&memval) == LLDS::ProtocolStatus::WAIT) {
        }
        CFXS_printf("memval: %lx\n", memval);

        SWD_Write<LLDS::ADI::Command::AP::WRITE_CSW>(0x23000012);
        SWD_Write<LLDS::ADI::Command::AP::WRITE_TAR>(0x20000000);
        SWD_Write<LLDS::ADI::Command::AP::WRITE_DRW>(0xDEADA555);

        SWD_Write<LLDS::ADI::Command::AP::WRITE_CSW>(0x23000012);
        SWD_Write<LLDS::ADI::Command::AP::WRITE_TAR>(0x20000000);
        while (SWD_Read<LLDS::ADI::Command::AP::READ_DRW>(&memval) == LLDS::ProtocolStatus::WAIT) {
        }
        CFXS_printf("memval: %lx\n", memval);
    }

    CFXS::CPU::BlockingMicroseconds(100);
    SendLineReset();

    if (stat == LLDS::ProtocolStatus::OK) {
        CFXS_printf("Read IDCODE\n");
        CFXS_printf(" IDCODE:              0x%lX\n", idcode._val);
        CFXS_printf(" IDCODE.Version:      0x%X\n", idcode.Version);
        CFXS_printf(" IDCODE.PARTNO:       0x%X\n", idcode.PARTNO);
        CFXS_printf(" IDCODE.MANUFACTURER: 0x%X\n", idcode.MANUFACTURER);
    } else {
        CFXS_printf("Read IDCODE failed: %s", ToString(stat));
    }

    CFXS_printf("Read  CTRL_STAT: %lX\n", ctrlStat);
    CFXS_printf("Write CTRL_STAT: %s\n", ToString(writeCtrlStat));
    CFXS_printf("Write SELECT:    %s\n", ToString(selectStat));

    //auto t2 = Task::Create(
    //    LOW_PRIORITY,
    //    "Test",
    //    [](void* data) {
    //    },
    //    0);
    //t2->Start();

    Task::EnableProcessing();
}

///////////////////////////////////////////////////////////////////////////////////

void CFXS_SystemPriorityLoop() {
    CFXS::Time::ms++;
    Task::ProcessGroup(SYSTEM_PRIORITY);
}

void CFXS_HighPriorityLoop() {
    Task::ProcessGroup(HIGH_PRIORITY);
}

void CFXS_LowPriorityLoop() {
    Task::ProcessGroup(LOW_PRIORITY);
}

///////////////////////////////////////////////////////////////////////////////////

static const CFXS::TM4C::CoreInitDescriptor s_CoreInitDesc{
    .highPriorityTimer      = 7,
    .splitHighPriorityTimer = 0,
};

const CFXS::AppDescriptor e_AppDescriptor{
    .platformInitDescriptor     = &s_CoreInitDesc,
    .moduleInit                 = InitializeModules,
    .postModuleInit             = InitializeApp,
    .highPriorityLoopPeriod     = CFXS::CPU::GetCyclesPerMillisecond(),
    .highPriorityLoopPriority   = 4,
    .systemPriorityLoopPeriod   = CFXS::CPU::GetCyclesPerMillisecond(),
    .systemPriorityLoopPriority = 1, // ignored
};
