local args = { ... }
local Root = args[1]:gsub("\\", "/")

local LATTICE_PROJECT_NAME = "CFXS_HWD_ICE40_TestDev"
local QUARTUS_PROJECT_NAME = "CFXS_HWD_TestDev"
local LATTICE              = 0x01
local QUARTUS              = 0x02
local ALL                  = 0xFF

local ProjectFiles = {
    root = "X:/CFXS/CFXS-HWD-Debug-Probe/Dev/HDL",
    files = {
        { "src/main.vhd", ALL }
    }
}

local LibraryFiles = {
    {
        name = "CFXS",
        root = "X:/CFXS/CFXS-HDL-Library/VHDL",
        files = {
            "Packages/Types.vhd",
            "Packages/Utils.vhd",
            "Components/FixedDebounce.vhd",
            "Components/PulseGenerator.vhd",
            "Components/ClockDivider.vhd",
            "Components/FixedClockDivider.vhd",
            "Components/CascadeClockDivider.vhd",
            "Components/Interfaces/SWD.vhd"
        }
    }
}

function Esc(x)
    return (x:gsub('%%', '%%%%'):gsub('^%^', '%%^'):gsub('%$$', '%%$'):gsub('%(', '%%('):gsub('%)', '%%)'):gsub('%.',
        '%%.'):gsub('%[', '%%['):gsub('%]', '%%]'):gsub('%*', '%%*'):gsub('%+', '%%+'):gsub('%-', '%%-'):gsub('%?',
        '%%?'))
end

function ReadFile(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local content = f:read("*a")
    f:close()
    return content
end

function WriteFile(path, content)
    local folderIndex = path:match('^.*()/')
    local folder = path:sub(1, folderIndex - 1):gsub("/", "\\")
    os.execute('if not exist "' .. folder .. '" mkdir "' .. folder .. '"')
    local f = io.open(path, "w+")
    if not f then
        error("Failed to write file to " .. path)
    end
    f:write(content)
    f:close()
end

print("VHDL_Project Generator")
local latticeProjectPath = Root .. "/Lattice/" .. LATTICE_PROJECT_NAME .. "_syn.prj"
local quartusProjectPath = Root .. "/Quartus/" .. QUARTUS_PROJECT_NAME .. ".qsf"

local latticeFile = ReadFile(latticeProjectPath)
local quartusFile = ReadFile(quartusProjectPath)

if latticeFile then
    print(" - Generating Lattice File")
    latticeFile = latticeFile:gsub("add_file %-vhdl %-lib.-\n", "")
    local content = ""
    for i, v in pairs(LibraryFiles) do
        for _, filePath in pairs(v.files) do
            content = content .. string.format("add_file -vhdl -lib %s %s/%s\n", v.name, v.root, filePath)
        end
    end
    for _, file in pairs(ProjectFiles.files) do
        if ((file[2] & LATTICE) ~= 0) then
            content = content .. string.format("add_file -vhdl -lib work %s/%s\n", ProjectFiles.root, file[1])
        end
    end
    latticeFile = latticeFile:gsub("\n#project files", "\n#project files\n" .. content)
    WriteFile(latticeProjectPath, latticeFile)
end

if quartusFile then
    print(" - Generating Quartus File")
    quartusFile = quartusFile:gsub("set_global_assignment %-name VHDL_FILE.-\n", "")
    local content = ""
    for i, v in pairs(LibraryFiles) do
        for _, filePath in pairs(v.files) do
            content = content ..
                string.format("set_global_assignment -name VHDL_FILE \"%s/%s\" -library %s\n", v.root, filePath, v.name)
        end
    end
    for _, file in pairs(ProjectFiles.files) do
        if ((file[2] & QUARTUS) ~= 0) then
            content = content ..
                string.format("set_global_assignment -name VHDL_FILE \"%s/%s\"\n", ProjectFiles.root, file[1])
        end
    end
    quartusFile = quartusFile .. "\n" .. content
    WriteFile(quartusProjectPath, quartusFile)
end

print("Done")
