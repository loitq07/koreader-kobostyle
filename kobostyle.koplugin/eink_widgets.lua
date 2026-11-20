--[[--
E-Ink UI Component Library (eink-ui.com implementation for KOReader)
Includes:
- EinkBadge: Capsule / Pill badge with 1px border or inverted solid fill
- EinkButton: Button with outline, ghost, and inverted active states (>= 48px target)
- EinkSegmentedControl: Horizontal segmented switch for Manga/PDF settings
--]]--

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local IconWidget = require("ui/widget/iconwidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local Tokens = require("eink_tokens")
local Screen = Device.screen

local EinkWidgets = {}

--------------------------------------------------------------------------------
-- 1. EinkBadge (Pill / Capsule)
--------------------------------------------------------------------------------
local EinkBadge = Widget:extend{
    text = "",
    inverted = false, -- true = solid black background with white text
    padding_h = nil,
    padding_v = nil,
    face = nil,
}

function EinkBadge:init()
    self.padding_h = self.padding_h or Screen:scaleBySize(8)
    self.padding_v = self.padding_v or Screen:scaleBySize(3)
    self.face = self.face or Tokens.getFont("badge")

    self.text_widget = TextWidget:new{
        text = self.text,
        face = self.face,
        bold = true,
        fgcolor = self.inverted and Tokens.COLOR_WHITE or Tokens.COLOR_BLACK,
    }

    local text_dim = self.text_widget:getSize()
    self.dimen = Geom:new{
        w = text_dim.w + (self.padding_h * 2),
        h = text_dim.h + (self.padding_v * 2),
    }
end

function EinkBadge:setText(text, inverted)
    self.text = text
    if inverted ~= nil then self.inverted = inverted end
    self.text_widget:setText(self.text)
    self.text_widget.fgcolor = self.inverted and Tokens.COLOR_WHITE or Tokens.COLOR_BLACK
    local text_dim = self.text_widget:getSize()
    self.dimen.w = text_dim.w + (self.padding_h * 2)
    self.dimen.h = text_dim.h + (self.padding_v * 2)
end

function EinkBadge:paintTo(bb, x, y)
    local w = self.dimen.w
    local h = self.dimen.h

    if self.inverted then
        -- Solid black pill
        bb:paintRect(x, y, w, h, Tokens.COLOR_BLACK)
    else
        -- White background with 1px hairline border
        bb:paintRect(x, y, w, h, Tokens.COLOR_WHITE)
        bb:paintBorder(x, y, w, h, Tokens.LINE_HAIRLINE, Tokens.COLOR_BLACK)
    end

    -- Paint centered text
    local text_dim = self.text_widget:getSize()
    local text_x = x + math.floor((w - text_dim.w) / 2)
    local text_y = y + math.floor((h - text_dim.h) / 2)
    self.text_widget:paintTo(bb, text_x, text_y)
end

EinkWidgets.Badge = EinkBadge

--------------------------------------------------------------------------------
-- 2. EinkButton (Interactive Touch Control, eink-ui style)
--------------------------------------------------------------------------------
local EinkButton = InputContainer:extend{
    text = nil,
    icon_file = nil,
    fallback_icon = nil,
    variant = "outline", -- "outline", "default" (inverted), "ghost"
    is_active = false,
    width = nil,
    height = nil,
    callback = nil,
}

function EinkButton:init()
    self.width = math.max(self.width or Tokens.TOUCH_TARGET_MIN, Tokens.TOUCH_TARGET_MIN)
    self.height = math.max(self.height or Tokens.TOUCH_TARGET_MIN, Tokens.TOUCH_TARGET_MIN)

    self.dimen = Geom:new{
        w = self.width,
        h = self.height,
    }

    if self.icon_file then
        local icon_dim = Screen:scaleBySize(24)
        self.icon_widget = IconWidget:new{
            file = self.icon_file,
            icon = self.fallback_icon,
            width = icon_dim,
            height = icon_dim,
        }
    end

    if self.text then
        self.text_widget = TextWidget:new{
            text = self.text,
            face = Tokens.getFont("body", 13),
            bold = true,
            fgcolor = (self.variant == "default" or self.is_active) and Tokens.COLOR_WHITE or Tokens.COLOR_BLACK,
        }
    end

    if Device:isTouchDevice() then
        self.ges_events = {
            TapButton = {
                GestureRange:new{
                    ges = "tap",
                    range = self.dimen,
                },
            },
        }
    end
end

function EinkButton:setActive(active)
    self.is_active = active
    if self.text_widget then
        self.text_widget.fgcolor = (self.variant == "default" or self.is_active) and Tokens.COLOR_WHITE or Tokens.COLOR_BLACK
    end
end

function EinkButton:onTapButton(arg, ges_ev)
    if self.callback then
        self.callback(self)
        UIManager:setDirty(nil, "ui")
    end
    return true
end

function EinkButton:paintTo(bb, x, y)
    local w = self.dimen.w
    local h = self.dimen.h
    local is_dark = (self.variant == "default" or self.is_active)

    if is_dark then
        -- Solid black inverted fill
        bb:paintRect(x, y, w, h, Tokens.COLOR_BLACK)
    elseif self.variant == "outline" then
        -- White background with 1px/2px border
        bb:paintRect(x, y, w, h, Tokens.COLOR_WHITE)
        bb:paintBorder(x, y, w, h, Tokens.LINE_HAIRLINE, Tokens.COLOR_BLACK)
    else
        -- Ghost (transparent)
        bb:paintRect(x, y, w, h, Tokens.COLOR_WHITE)
    end

    -- Paint icon
    if self.icon_widget then
        local icon_dim = self.icon_widget:getSize()
        local icon_x = x + math.floor((w - icon_dim.w) / 2)
        local icon_y = y + math.floor((h - icon_dim.h) / 2)
        self.icon_widget:paintTo(bb, icon_x, icon_y)
    end

    -- Paint text
    if self.text_widget then
        local text_dim = self.text_widget:getSize()
        local text_x = x + math.floor((w - text_dim.w) / 2)
        local text_y = y + math.floor((h - text_dim.h) / 2)
        self.text_widget:paintTo(bb, text_x, text_y)
    end
end

EinkWidgets.Button = EinkButton

--------------------------------------------------------------------------------
-- 3. EinkSegmentedControl (eink-ui Segmented Switch)
--------------------------------------------------------------------------------
local EinkSegmentedControl = InputContainer:extend{
    items = nil, -- array of { id = "...", text = "..." }
    selected_id = nil,
    on_change = nil,
    width = nil,
    height = nil,
}

function EinkSegmentedControl:init()
    self.height = self.height or Screen:scaleBySize(44)
    self.dimen = Geom:new{
        w = self.width,
        h = self.height,
    }

    self.text_widgets = {}
    for _, item in ipairs(self.items) do
        local is_sel = (item.id == self.selected_id)
        self.text_widgets[item.id] = TextWidget:new{
            text = item.text,
            face = Tokens.getFont("body", 13),
            bold = is_sel,
            fgcolor = is_sel and Tokens.COLOR_WHITE or Tokens.COLOR_BLACK,
        }
    end

    if Device:isTouchDevice() then
        self.ges_events = {
            TapSegment = {
                GestureRange:new{
                    ges = "tap",
                    range = self.dimen,
                },
            },
        }
    end
end

function EinkSegmentedControl:setSelectedId(id)
    self.selected_id = id
    for item_id, tw in pairs(self.text_widgets) do
        local is_sel = (item_id == self.selected_id)
        tw.bold = is_sel
        tw.fgcolor = is_sel and Tokens.COLOR_WHITE or Tokens.COLOR_BLACK
    end
end

function EinkSegmentedControl:onTapSegment(arg, ges_ev)
    if not ges_ev.pos then return true end
    local rel_x = ges_ev.pos.x - self.dimen.x
    local seg_w = math.floor(self.dimen.w / #self.items)
    local idx = math.min(#self.items, math.max(1, math.floor(rel_x / seg_w) + 1))
    local clicked_item = self.items[idx]

    if clicked_item and clicked_item.id ~= self.selected_id then
        self:setSelectedId(clicked_item.id)
        if self.on_change then
            self.on_change(clicked_item.id)
        end
        UIManager:setDirty(nil, "ui")
    end
    return true
end

function EinkSegmentedControl:paintTo(bb, x, y)
    local w = self.dimen.w
    local h = self.dimen.h
    local n = #self.items
    local seg_w = math.floor(w / n)

    -- Outer border (2px normal eink-ui border)
    bb:paintRect(x, y, w, h, Tokens.COLOR_WHITE)
    bb:paintBorder(x, y, w, h, Tokens.LINE_HAIRLINE, Tokens.COLOR_BLACK)

    for i, item in ipairs(self.items) do
        local item_x = x + (i - 1) * seg_w
        local item_w = (i == n) and (w - (n - 1) * seg_w) or seg_w
        local is_sel = (item.id == self.selected_id)

        if is_sel then
            -- Active segment: Solid black fill (eink-ui signature inverted state)
            bb:paintRect(item_x, y, item_w, h, Tokens.COLOR_BLACK)
        end

        -- Divider line between segments (except last)
        if i > 1 then
            bb:paintRect(item_x, y, Tokens.LINE_HAIRLINE, h, Tokens.COLOR_BLACK)
        end

        -- Text label
        local tw = self.text_widgets[item.id]
        if tw then
            local tw_size = tw:getSize()
            local tw_x = item_x + math.floor((item_w - tw_size.w) / 2)
            local tw_y = y + math.floor((h - tw_size.h) / 2)
            tw:paintTo(bb, tw_x, tw_y)
        end
    end
end

EinkWidgets.SegmentedControl = EinkSegmentedControl

return EinkWidgets
