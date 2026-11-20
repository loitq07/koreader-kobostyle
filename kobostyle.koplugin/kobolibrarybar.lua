--[[--
E-Ink UI Library Bottom Navigation Bar (eink-ui.com specification)
Features:
- Line-weight hierarchy (2px top boundary, 3px active tab indicator)
- Zero animation, high-contrast monochrome rendering
- Minimum 48px touch targets (58px bar height)
- Automatic switch to 3-column Cover Grid (Mihon style) on "Sách của tôi"
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
local _ = require("gettext")
local Tokens = require("eink_tokens")
local Screen = Device.screen

local plugin_dir = debug.getinfo(1, "S").source:match("@?(.*)[/\\]")
local icons_dir = plugin_dir and (plugin_dir .. "/icons") or "plugins/kobostyle.koplugin/icons"

local KoboLibraryBar = InputContainer:extend{
    name = "KoboLibraryBar",
    ui = nil,
    plugin = nil,
    active_tab = "books",
}

function KoboLibraryBar:init()
    self.screen_w = Screen:getWidth()
    self.screen_h = Screen:getHeight()
    self.nav_bar_h = Tokens.NAV_BAR_HEIGHT
    self.dimen = Geom:new{
        x = 0,
        y = self.screen_h - self.nav_bar_h,
        w = self.screen_w,
        h = self.nav_bar_h,
    }

    local icon_size = Screen:scaleBySize(22)
    local tab_font = Tokens.getFont("badge")

    local function create_icon(filename, fallback_name)
        return IconWidget:new{
            file = icons_dir .. "/" .. filename,
            icon = fallback_name,
            width = icon_size,
            height = icon_size,
        }
    end

    local function create_label(text, is_bold)
        return TextWidget:new{
            text = text,
            face = tab_font,
            bold = is_bold or false,
            fgcolor = is_bold and Tokens.COLOR_BLACK or Tokens.COLOR_GRAY_TEXT,
        }
    end

    -- 5 E-Ink UI Library Tabs
    self.tabs = {
        {
            id = "home",
            text = _("Trang chủ"),
            icon_widget = create_icon("house.svg", "home"),
            text_widget = create_label(_("Trang chủ"), false),
            text_widget_bold = create_label(_("Trang chủ"), true),
            callback = function()
                if self.ui.history then
                    self.ui.history:onShowHistory()
                else
                    self.ui:onHome()
                end
            end,
        },
        {
            id = "books",
            text = _("Sách của tôi"),
            icon_widget = create_icon("books.svg", "book.opened"),
            text_widget = create_label(_("Sách của tôi"), false),
            text_widget_bold = create_label(_("Sách của tôi"), true),
            callback = function()
                -- Enforce Mihon-style 3-column Cover Grid
                local ok, BookInfoManager = pcall(require, "bookinfomanager")
                if ok and BookInfoManager then
                    BookInfoManager:saveSetting("filemanager_display_mode", "mosaic_image")
                    BookInfoManager:saveSetting("nb_cols_portrait", 3)
                    BookInfoManager:saveSetting("nb_rows_portrait", 3)
                end
                self.ui:onHome()
            end,
        },
        {
            id = "collections",
            text = _("Bộ sưu tập"),
            icon_widget = create_icon("bookmark.svg", "bookmark"),
            text_widget = create_label(_("Bộ sưu tập"), false),
            text_widget_bold = create_label(_("Bộ sưu tập"), true),
            callback = function()
                if self.ui.collections then
                    self.ui.collections:onShowCollections()
                end
            end,
        },
        {
            id = "stats",
            text = _("Thống kê"),
            icon_widget = create_icon("chart-bar.svg", "appbar.navigation"),
            text_widget = create_label(_("Thống kê"), false),
            text_widget_bold = create_label(_("Thống kê"), true),
            callback = function()
                local Dispatcher = require("dispatcher")
                if Dispatcher:hasAction("show_statistics") then
                    Dispatcher:execute("show_statistics")
                elseif self.ui.history then
                    self.ui.history:onShowHistory()
                else
                    UIManager:show(require("ui/widget/notification"):new{
                        text = _("Chưa có dữ liệu thống kê"),
                    })
                end
            end,
        },
        {
            id = "more",
            text = _("Thêm"),
            icon_widget = create_icon("dots-three.svg", "appbar.menu"),
            text_widget = create_label(_("Thêm"), false),
            text_widget_bold = create_label(_("Thêm"), true),
            callback = function()
                if self.ui.menu then
                    self.ui.menu:onShowMenu()
                end
            end,
        },
    }

    self:initGesListener()
end

function KoboLibraryBar:getSize()
    return { w = self.screen_w, h = self.nav_bar_h }
end

function KoboLibraryBar:initGesListener()
    if not Device:isTouchDevice() then return end

    self.ges_events = {
        TapNavBar = {
            GestureRange:new{
                ges = "tap",
                range = Geom:new{
                    x = 0,
                    y = self.screen_h - self.nav_bar_h,
                    w = self.screen_w,
                    h = self.nav_bar_h,
                },
            },
        },
    }
end

function KoboLibraryBar:onTapNavBar(arg, ges_ev)
    if not ges_ev.pos then return true end

    local x = ges_ev.pos.x
    local tab_w = math.floor(self.screen_w / #self.tabs)
    local tab_idx = math.min(#self.tabs, math.max(1, math.floor(x / tab_w) + 1))
    local tab = self.tabs[tab_idx]

    if tab and tab.callback then
        self.active_tab = tab.id
        tab.callback()
        UIManager:setDirty(self.ui, "ui")
    end

    return true
end

function KoboLibraryBar:paintTo(bb, x, y)
    local screen_w = self.screen_w
    local nav_bar_h = self.nav_bar_h
    local num_tabs = #self.tabs
    local tab_w = math.floor(screen_w / num_tabs)

    -- 1. Solid Pure Paper White background (Zero shadow)
    bb:paintRect(x, y, screen_w, nav_bar_h, Tokens.COLOR_WHITE)

    -- 2. 2px Normal boundary line (eink-ui line hierarchy)
    bb:paintRect(x, y, screen_w, Tokens.LINE_NORMAL, Tokens.COLOR_BLACK)

    -- 3. Draw each tab
    for i, tab in ipairs(self.tabs) do
        local tab_x = x + (i - 1) * tab_w
        local is_active = (self.active_tab == tab.id)

        -- If active: 3px heavy black accent line on top of this tab
        if is_active then
            bb:paintRect(tab_x, y, tab_w, Tokens.LINE_HEAVY, Tokens.COLOR_BLACK)
        end

        -- Icon
        local icon_w = tab.icon_widget
        local icon_size = icon_w:getSize()
        local icon_x = tab_x + math.floor((tab_w - icon_size.w) / 2)
        local icon_y = y + Screen:scaleBySize(8)
        icon_w:paintTo(bb, icon_x, icon_y)

        -- Text label
        local text_w = is_active and tab.text_widget_bold or tab.text_widget
        local text_size = text_w:getSize()
        local text_x = tab_x + math.floor((tab_w - text_size.w) / 2)
        local text_y = icon_y + icon_size.h + Screen:scaleBySize(3)
        text_w:paintTo(bb, text_x, text_y)
    end
end

return KoboLibraryBar
