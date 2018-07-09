
local Event = require("ui/event")
local Generic = require("device/generic/device")
local util = require("ffi/util")
local logger = require("logger")

local function yes() return true end
local function no() return false end

local Kindle = Generic:new{
    model = "Kindle",
    isKindle = yes,
}

function Kindle:initNetworkManager(NetworkMgr)
    NetworkMgr.turnOnWifi = function()
        return false
    end

    NetworkMgr.turnOffWifi = function()
        return false
    end
end

--[[
Test if a kindle device has Special Offers
--]]
local function isSpecialOffers()
    return false
end

function Kindle:supportsScreensaver()
    return false
end

function Kindle:setDateTime(year, month, day, hour, min, sec)
    if hour == nil or min == nil then return true end
    local command
    if year and month and day then
        command = string.format("date -s '%d-%d-%d %d:%d:%d'", year, month, day, hour, min, sec)
    else
        command = string.format("date -s '%d:%d'",hour, min)
    end
    if os.execute(command) == 0 then
        os.execute('hwclock -u -w')
        return true
    else
        return false
    end
end

function Kindle:usbPlugIn()

    self.charging_mode = true
end

function Kindle:intoScreenSaver()
    return false
end

function Kindle:outofScreenSaver()
    return false
end

function Kindle:usbPlugOut()

    self.charging_mode = false
end

function Kindle:ambientBrightnessLevel()
    return 4
end


local KindleFread = Kindle:new{
    model = "KindleFread",
    isSDL = yes,
    hasKeyboard = no,
    hasKeys = yes,
    hasDPad = yes,
    hasFrontlight = no,
    isTouchDevice = no,
    needsScreenRefreshAfterResume = no,
    hasColorScreen = yes,
}

function KindleFread:init()
    -- allows to set a viewport via environment variable
    -- syntax is Lua table syntax, e.g. EMULATE_READER_VIEWPORT="{x=10,w=550,y=5,h=790}"
    local viewport = os.getenv("EMULATE_READER_VIEWPORT")
    if viewport then
        self.viewport = require("ui/geometry"):new(loadstring("return " .. viewport)())
    end
    local portrait = os.getenv("EMULATE_READER_FORCE_PORTRAIT")
    if portrait then
        self.isAlwaysPortrait = yes
    end

    if util.haveSDL2() then
        self.hasClipboard = yes
        self.screen = require("ffi/framebuffer_SDL2_0"):new{device = self, debug = logger.dbg}

        local ok, re = pcall(self.screen.setWindowIcon, self.screen, "resources/koreader.png")
        if not ok then logger.warn(re) end

        local input = require("ffi/input")
    end

    if portrait then
        self.input:registerEventAdjustHook(self.input.adjustTouchSwitchXY)
        self.input:registerEventAdjustHook(
            self.input.adjustTouchMirrorX,
            self.screen:getScreenWidth()
        )
    end


    self.input = require("device/input"):new{
        device = self,
        event_map = require("device/kindle_fread/event_map_kindle4"),
    }
    self.input.open("/dev/input/event0")
    self.input.open("/dev/input/event1")
    self.input.open("fake_events")
    Kindle.init(self)

--    Generic.init(self)
end

function KindleFread:setDateTime(year, month, day, hour, min, sec)
    if hour == nil or min == nil then return true end
    local command
    if year and month and day then
        command = string.format("date -s '%d-%d-%d %d:%d:%d'", year, month, day, hour, min, sec)
    else
        command = string.format("date -s '%d:%d'",hour, min)
    end
    if os.execute(command) == 0 then
        os.execute('hwclock -u -w')
        return true
    else
        return false
    end
end

-- called on suspend from frontend/ui/uimanager.lua
function KindleFread:simulateSuspend()
    local InfoMessage = require("ui/widget/infomessage")
    local UIManager = require("ui/uimanager")
    local _ = require("gettext")
    UIManager:show(InfoMessage:new{
        text = _("Suspend")
    })
end

-- called on resume from frontend/ui/uimanager.lua
function KindleFread:simulateResume()
    local InfoMessage = require("ui/widget/infomessage")
    local UIManager = require("ui/uimanager")
    local _ = require("gettext")
    UIManager:show(InfoMessage:new{
        text = _("Resume")
    })
end

local function Set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end


local kindle_sn_fd = io.open("/proc/usid", "r")
if not kindle_sn_fd then return end
local kindle_sn = kindle_sn_fd:read()
kindle_sn_fd:close()
local kindle_devcode = string.sub(kindle_sn,3,4)
local kindle_devcode_v2 = string.sub(kindle_sn,4,6)

local k4_set = Set { "0E", "23" }

if k4_set[kindle_devcode] then
    return KindleFread
end

error("unknown Kindle model "..kindle_devcode.." ("..kindle_devcode_v2..")")
