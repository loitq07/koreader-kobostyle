--[[--
Main entry point for Kobo Style E-Ink UI KOReader Plugin
Implements eink-ui.com design system for KOReader:
1. E-Ink UI Reader Overlay (with Manga/PDF Sheet, RTL toggle, Badges, 4px progress slider)
2. E-Ink UI Library Navigation Bar (58px height, 2px/3px line hierarchy, 5 Kobo tabs)
3. Automatic 3-column Cover Grid (Mihon style) integration for CoverBrowser
--]]--

local DataStorage = require("datastorage")
local Device = require("device")
local Geom = require("ui/geometry")
local LuaSettings = require("luasettings")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local Tokens = require("eink_tokens")
local Screen = Device.screen

local Kobostyle = WidgetContainer:extend{
    name = "kobostyle",
    is_doc_only = false,
    settings = nil,
    enabled = true,
    library_enabled = true,
    overlay = nil,
    library_bar_attached = false,
}

function Kobostyle:init()
    self.settings_file = DataStorage:getSettingsDir() .. "/kobostyle.lua"
    self.settings = LuaSettings:open(self.settings_file)
    self.enabled = self.settings:nilOrTrue("enabled")
    self.library_enabled = self.settings:nilOrTrue("library_enabled")

    if self.ui.document then
        -- In reader mode: listen for tap gestures
        self:initGesListener()
    else
        -- In file manager (library) mode
        self:applyMihonGridSettings()
        self:initFileManager()
    end

    if self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

-- Ensure 3-column Mihon Cover Grid mode is active
function Kobostyle:applyMihonGridSettings()
    local ok, BookInfoManager = pcall(require, "bookinfomanager")
    if ok and BookInfoManager then
        BookInfoManager:saveSetting("filemanager_display_mode", "mosaic_image")
        BookInfoManager:saveSetting("nb_cols_portrait", 3)
        BookInfoManager:saveSetting("nb_rows_portrait", 3)
    end
end

function Kobostyle:initGesListener()
    if not Device:isTouchDevice() then return end

    local DTAP_ZONE_MENU = G_defaults:readSetting("DTAP_ZONE_MENU") or {
        x = 1/8, y = 0,
        w = 6/8, h = 1/8,
    }

    self.ui:registerTouchZones({
        {
            id = "kobostyle_menu_tap",
            ges = "tap",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU.x, ratio_y = DTAP_ZONE_MENU.y,
                ratio_w = DTAP_ZONE_MENU.w, ratio_h = DTAP_ZONE_MENU.h,
            },
            overrides = {
                "readermenu_tap",
                "readermenu_ext_tap",
                "tap_forward",
                "tap_backward",
            },
            handler = function(ges)
                return self:onTapToggleOverlay(ges)
            end,
        },
        {
            id = "kobostyle_center_tap",
            ges = "tap",
            screen_zone = {
                ratio_x = 0.25, ratio_y = 0.25,
                ratio_w = 0.50, ratio_h = 0.50,
            },
            overrides = {
                "tap_forward",
                "tap_backward",
            },
            handler = function(ges)
                return self:onTapToggleOverlay(ges)
            end,
        },
    })
end

function Kobostyle:onTapToggleOverlay(ges)
    if not self.enabled then
        return false
    end

    if self.overlay then
        self.overlay:onClose()
        self.overlay = nil
        return true
    end

    self:showOverlay()
    return true
end

function Kobostyle:showOverlay()
    local KoboReaderOverlay = require("koboreaderoverlay")
    self.overlay = KoboReaderOverlay:new{
        ui = self.ui,
        plugin = self,
    }
    UIManager:show(self.overlay)
end

function Kobostyle:initFileManager()
    if not self.library_enabled or not self.enabled then
        return
    end

    if self.ui.registerPostInitCallback then
        self.ui:registerPostInitCallback(function()
            self:attachKoboLibraryBar()
        end)
    else
        UIManager:nextTick(function()
            self:attachKoboLibraryBar()
        end)
    end
end

function Kobostyle:attachKoboLibraryBar()
    if not self.ui or self.ui.document or self.library_bar_attached then
        return
    end

    local KoboLibraryBar = require("kobolibrarybar")
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()
    local nav_bar_h = Tokens.NAV_BAR_HEIGHT

    -- Adjust file chooser height so items aren't obscured by bottom bar
    if self.ui.file_chooser then
        self.ui.file_chooser.height = screen_h - nav_bar_h
        if self.ui.file_chooser.dimen then
            self.ui.file_chooser.dimen.h = screen_h - nav_bar_h
        end
        if self.ui.file_chooser.inner_dimen then
            self.ui.file_chooser.inner_dimen.h = screen_h - nav_bar_h
        end
        if self.ui.file_chooser.recalculateDimen then
            self.ui.file_chooser:recalculateDimen()
        end
    end

    self.library_bar = KoboLibraryBar:new{
        ui = self.ui,
        plugin = self,
    }

    local BottomContainer = require("ui/widget/container/bottomcontainer")
    local OverlapGroup = require("ui/widget/overlapgroup")

    local bottom_nav_container = BottomContainer:new{
        dimen = Geom:new{ x = 0, y = 0, w = screen_w, h = screen_h },
        self.library_bar,
    }

    if self.ui[1] then
        self.ui[1] = OverlapGroup:new{
            dimen = Geom:new{ x = 0, y = 0, w = screen_w, h = screen_h },
            self.ui[1],
            bottom_nav_container,
        }
    end

    self.library_bar_attached = true
    UIManager:setDirty(self.ui, "ui")
end

function Kobostyle:addToMainMenu(menu_items)
    menu_items.kobostyle_menu = {
        text = _("Giao diện E-Ink UI (eink-ui.com)"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text = _("Bật giao diện E-Ink UI khi đọc"),
                checked_func = function()
                    return self.enabled
                end,
                callback = function()
                    self.enabled = not self.enabled
                    self.settings:saveSetting("enabled", self.enabled)
                    self.settings:flush()
                end,
            },
            {
                text = _("Bật thanh điều hướng dưới đáy Thư viện"),
                checked_func = function()
                    return self.library_enabled
                end,
                callback = function()
                    self.library_enabled = not self.library_enabled
                    self.settings:saveSetting("library_enabled", self.library_enabled)
                    self.settings:flush()
                    if not self.ui.document then
                        UIManager:show(require("ui/widget/notification"):new{
                            text = _("Cài đặt sẽ áp dụng khi mở lại Thư viện"),
                        })
                    end
                end,
            },
            {
                text = _("Áp dụng lưới bìa 3 cột Mihon (Cover Grid)"),
                callback = function()
                    self:applyMihonGridSettings()
                    UIManager:show(require("ui/widget/notification"):new{
                        text = _("Đã chuyển thư viện sang lưới bìa 3 cột Mihon"),
                    })
                    if not self.ui.document and self.ui.onHome then
                        self.ui:onHome()
                    end
                end,
            },
            {
                text = _("Hiện thanh điều khiển ngay"),
                enabled_func = function()
                    return self.ui.document ~= nil
                end,
                callback = function()
                    if self.ui.menu then
                        self.ui.menu:onTapCloseMenu()
                    end
                    UIManager:nextTick(function()
                        self:showOverlay()
                    end)
                end,
            },
        },
    }
end

function Kobostyle:onClose()
    if self.overlay then
        self.overlay:onClose()
        self.overlay = nil
    end
end

return Kobostyle
