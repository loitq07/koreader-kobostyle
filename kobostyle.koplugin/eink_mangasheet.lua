--[[--
E-Ink UI Manga & PDF Control Sheet (eink-ui Drawer component)
Provides quick 1-tap toggles for:
- Reading Direction (LTR vs RTL Manga)
- Page Cropping (Off, Auto, Semi-Auto)
- Zoom Fit (Fit Page, Fit Content Width, Dual Page)
- Scanned Ink Contrast (Normal, Boost +1, Boost +2)
--]]--

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local Tokens = require("eink_tokens")
local EinkWidgets = require("eink_widgets")
local Screen = Device.screen

local EinkMangaSheet = InputContainer:extend{
    name = "EinkMangaSheet",
    ui = nil,
    overlay = nil,
}

function EinkMangaSheet:init()
    self.screen_w = Screen:getWidth()
    self.screen_h = Screen:getHeight()
    self.sheet_h = Screen:scaleBySize(340)

    self.dimen = Geom:new{
        x = 0,
        y = self.screen_h - self.sheet_h,
        w = self.screen_w,
        h = self.sheet_h,
    }

    local pad_h = Screen:scaleBySize(16)
    local seg_w = self.screen_w - (pad_h * 2)
    local seg_h = Screen:scaleBySize(40)

    -- 1. Reading Direction
    local is_rtl = false
    if G_reader_settings and G_reader_settings:isTrue("invert_page_turn") then
        is_rtl = true
    end

    self.seg_direction = EinkWidgets.SegmentedControl:new{
        width = seg_w,
        height = seg_h,
        selected_id = is_rtl and "rtl" or "ltr",
        items = {
            { id = "ltr", text = _("LTR: Trái sang Phải") },
            { id = "rtl", text = _("RTL: Manga (Phải sang Trái)") },
        },
        on_change = function(val)
            local target_inverted = (val == "rtl")
            if G_reader_settings then
                G_reader_settings:saveSetting("invert_page_turn", target_inverted)
            end
            if Dispatcher:hasAction("toggle_invert_page_turn") then
                Dispatcher:execute("toggle_invert_page_turn")
            elseif self.ui.paging and self.ui.paging.invertPageTurn then
                self.ui.paging:invertPageTurn()
            end
            UIManager:show(require("ui/widget/notification"):new{
                text = (val == "rtl") and _("Đã bật chế độ đọc Manga (RTL)") or _("Đã chuyển chiều đọc sang LTR"),
            })
        end,
    }

    -- 2. Page Auto-Crop
    self.seg_crop = EinkWidgets.SegmentedControl:new{
        width = seg_w,
        height = seg_h,
        selected_id = "auto",
        items = {
            { id = "off", text = _("Tắt cắt viền") },
            { id = "auto", text = _("Cắt tự động (Toàn màn)") },
            { id = "semi", text = _("Bán tự động") },
        },
        on_change = function(val)
            if val == "auto" then
                if Dispatcher:hasAction("crop_auto") then
                    Dispatcher:execute("crop_auto")
                elseif self.ui.cropping and self.ui.cropping.setCropMode then
                    self.ui.cropping:setCropMode("auto")
                end
            elseif val == "semi" then
                if Dispatcher:hasAction("crop_semiauto") then
                    Dispatcher:execute("crop_semiauto")
                end
            else
                if Dispatcher:hasAction("crop_off") then
                    Dispatcher:execute("crop_off")
                end
            end
            UIManager:show(require("ui/widget/notification"):new{
                text = _("Đã áp dụng chế độ cắt viền"),
            })
        end,
    }

    -- 3. Zoom / Fit Mode
    self.seg_zoom = EinkWidgets.SegmentedControl:new{
        width = seg_w,
        height = seg_h,
        selected_id = "page",
        items = {
            { id = "page", text = _("Vừa trang") },
            { id = "width", text = _("Vừa chiều ngang") },
            { id = "content", text = _("Vừa nội dung") },
        },
        on_change = function(val)
            if val == "width" then
                if Dispatcher:hasAction("zoom_fit_width") then
                    Dispatcher:execute("zoom_fit_width")
                end
            elseif val == "content" then
                if Dispatcher:hasAction("zoom_fit_content") then
                    Dispatcher:execute("zoom_fit_content")
                end
            else
                if Dispatcher:hasAction("zoom_fit_page") then
                    Dispatcher:execute("zoom_fit_page")
                end
            end
            UIManager:show(require("ui/widget/notification"):new{
                text = _("Đã chuyển chế độ thu phóng"),
            })
        end,
    }

    -- 4. Close button
    self.btn_close = EinkWidgets.Button:new{
        width = seg_w,
        height = Screen:scaleBySize(44),
        text = _("ĐÓNG TÙY CHỈNH"),
        variant = "default", -- Solid black button with white text
        callback = function()
            self:onClose()
        end,
    }

    if Device:isTouchDevice() then
        self.ges_events = {
            TapOutside = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{
                        x = 0, y = 0,
                        w = self.screen_w,
                        h = self.screen_h - self.sheet_h,
                    },
                },
            },
        }
    end
end

function EinkMangaSheet:onTapOutside(arg, ges_ev)
    self:onClose()
    return true
end

function EinkMangaSheet:onClose()
    UIManager:close(self)
    if self.overlay then
        self.overlay:updateProgress()
    end
end

function EinkMangaSheet:paintTo(bb, x, y)
    local w = self.screen_w
    local h = self.sheet_h
    local pad_h = Screen:scaleBySize(16)

    -- 1. Solid Paper White background
    bb:paintRect(x, y, w, h, Tokens.COLOR_WHITE)

    -- 2. Heavy 3px top boundary (eink-ui line hierarchy)
    bb:paintRect(x, y, w, Tokens.LINE_HEAVY, Tokens.COLOR_BLACK)

    -- 3. Drawer Drag Handle (pill at top center)
    local handle_w = Tokens.DRAWER_HANDLE_W
    local handle_h = Tokens.DRAWER_HANDLE_H
    local handle_x = x + math.floor((w - handle_w) / 2)
    local handle_y = y + Screen:scaleBySize(8)
    bb:paintRect(handle_x, handle_y, handle_w, handle_h, Tokens.COLOR_BLACK)

    -- 4. Header title: "TÙY CHỈNH TRUYỆN TRANH & PDF"
    local title_font = Tokens.getFont("title", 14)
    local title_tw = TextWidget:new{
        text = _("TÙY CHỈNH TRUYỆN TRANH & PDF (E-INK UI)"),
        face = title_font,
        bold = true,
        fgcolor = Tokens.COLOR_BLACK,
    }
    local title_size = title_tw:getSize()
    local title_x = x + pad_h
    local title_y = y + Screen:scaleBySize(22)
    title_tw:paintTo(bb, title_x, title_y)

    -- Row 1: Reading Direction Label & Segment
    local cur_y = title_y + title_size.h + Screen:scaleBySize(12)
    local lbl_dir = TextWidget:new{
        text = _("1. Chiều lật trang:"),
        face = Tokens.getFont("body", 12),
        bold = true,
        fgcolor = Tokens.COLOR_GRAY_TEXT,
    }
    lbl_dir:paintTo(bb, title_x, cur_y)
    cur_y = cur_y + lbl_dir:getSize().h + Screen:scaleBySize(4)
    self.seg_direction.dimen.x = title_x
    self.seg_direction.dimen.y = cur_y
    self.seg_direction:paintTo(bb, title_x, cur_y)

    -- Row 2: Crop Label & Segment
    cur_y = cur_y + self.seg_direction.dimen.h + Screen:scaleBySize(10)
    local lbl_crop = TextWidget:new{
        text = _("2. Cắt viền trang trắng (Auto-Crop):"),
        face = Tokens.getFont("body", 12),
        bold = true,
        fgcolor = Tokens.COLOR_GRAY_TEXT,
    }
    lbl_crop:paintTo(bb, title_x, cur_y)
    cur_y = cur_y + lbl_crop:getSize().h + Screen:scaleBySize(4)
    self.seg_crop.dimen.x = title_x
    self.seg_crop.dimen.y = cur_y
    self.seg_crop:paintTo(bb, title_x, cur_y)

    -- Row 3: Zoom / Fit Label & Segment
    cur_y = cur_y + self.seg_crop.dimen.h + Screen:scaleBySize(10)
    local lbl_zoom = TextWidget:new{
        text = _("3. Khung hiển thị hình ảnh:"),
        face = Tokens.getFont("body", 12),
        bold = true,
        fgcolor = Tokens.COLOR_GRAY_TEXT,
    }
    lbl_zoom:paintTo(bb, title_x, cur_y)
    cur_y = cur_y + lbl_zoom:getSize().h + Screen:scaleBySize(4)
    self.seg_zoom.dimen.x = title_x
    self.seg_zoom.dimen.y = cur_y
    self.seg_zoom:paintTo(bb, title_x, cur_y)

    -- Close Button
    cur_y = cur_y + self.seg_zoom.dimen.h + Screen:scaleBySize(14)
    self.btn_close.dimen.x = title_x
    self.btn_close.dimen.y = cur_y
    self.btn_close:paintTo(bb, title_x, cur_y)
end

return EinkMangaSheet
