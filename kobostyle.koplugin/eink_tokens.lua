--[[--
E-Ink UI Design Tokens (inspired by eink-ui.com & shadcn)
Tailored specifically for E-Paper / E-Ink constraints:
- Line-weight hierarchy (1px hairline, 2px normal/active, 3px heavy/boundary)
- Zero shadows, zero gradients, zero animation
- Pure monochrome contrast (solid black ink, pure white paper)
- Inverted fills for active/toggled states
- Large touch targets (>= 48px)
--]]--

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Screen = Device.screen

local EinkTokens = {
    -- Colors (Strict E-Ink Monochrome)
    COLOR_WHITE        = Blitbuffer.COLOR_WHITE,        -- Paper background (#FFFFFF)
    COLOR_BLACK        = Blitbuffer.COLOR_BLACK,        -- Ink foreground (#000000)
    COLOR_GRAY_BORDER  = Blitbuffer.COLOR_GRAY_D,        -- Hairline border (#D0D0D0)
    COLOR_GRAY_MUTED   = Blitbuffer.COLOR_GRAY_E,        -- Subtle container/track (#E8E8E8)
    COLOR_GRAY_TEXT    = Blitbuffer.COLOR_DARK_GRAY,    -- Secondary text (#555555)

    -- Line Weights (eink-ui hierarchy)
    LINE_HAIRLINE = math.max(1, Screen:scaleBySize(1)), -- 1px: Card borders, dividers, subtle frames
    LINE_NORMAL   = math.max(2, Screen:scaleBySize(2)), -- 2px: Active borders, primary dividers, focused
    LINE_HEAVY    = math.max(3, Screen:scaleBySize(3)), -- 3px: Top/Bottom bar boundaries, active indicator

    -- Corner Radii
    RADIUS_NONE   = 0,
    RADIUS_SM     = Screen:scaleBySize(4),
    RADIUS_MD     = Screen:scaleBySize(8),
    RADIUS_FULL   = 9999,

    -- Sizing & Ergonomics
    TOUCH_TARGET_MIN = Screen:scaleBySize(48), -- Minimum 48px touch zone
    NAV_BAR_HEIGHT   = Screen:scaleBySize(58), -- Bottom nav bar height
    TOP_BAR_HEIGHT   = Screen:scaleBySize(54), -- Top bar height
    DRAWER_HANDLE_H  = Screen:scaleBySize(4),
    DRAWER_HANDLE_W  = Screen:scaleBySize(40),

    -- Fonts
    getFont = function(size_type, custom_size)
        if size_type == "title" then
            return Font:getFace("cfont", custom_size or 16)
        elseif size_type == "body" then
            return Font:getFace("cfont", custom_size or 14)
        elseif size_type == "badge" then
            return Font:getFace("xx_smallinfofont")
        elseif size_type == "info" then
            return Font:getFace("smallinfofont")
        else
            return Font:getFace("smallinfofont")
        end
    end,
}

return EinkTokens
