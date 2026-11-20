--[[--
E-Ink UI Reader Overlay (eink-ui.com specification)
Features:
- High contrast line hierarchy (2px boundaries, 1px badges)
- Top Bar: Back button, centered Title + Page Badge, Quick RTL Manga toggle, Search, Bookmark
- Bottom Bar: Reading info with capsule Badges, 4px crisp progress bar with ticks & +/-10 step buttons,
  5 Action Buttons including 1-tap "Manga & PDF" Quick Control Sheet
--]]--

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local FocusManager = require("ui/widget/focusmanager")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconButton = require("ui/widget/iconbutton")
local IconWidget = require("ui/widget/iconwidget")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local ProgressWidget = require("ui/widget/progresswidget")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local TopContainer = require("ui/widget/container/topcontainer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local RightContainer = require("ui/widget/container/rightcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local Tokens = require("eink_tokens")
local EinkWidgets = require("eink_widgets")
local Screen = Device.screen

local plugin_dir = debug.getinfo(1, "S").source:match("@?(.*)[/\\]")
local icons_dir = plugin_dir and (plugin_dir .. "/icons") or "plugins/kobostyle.koplugin/icons"

-- Subclass of IconButton for E-Ink UI (sharp touch targets)
local EinkIconButton = IconButton:extend{
    file = nil,
}

function EinkIconButton:init()
    self.image = IconWidget:new{
        file = self.file,
        icon = self.icon,
        width = self.width,
        height = self.height,
    }

    self.show_parent = self.show_parent or self
    self.horizontal_group = HorizontalGroup:new{
        HorizontalSpan:new{},
        self.image,
        HorizontalSpan:new{},
    }

    self.button = VerticalGroup:new{
        VerticalSpan:new{},
        self.horizontal_group,
        VerticalSpan:new{},
    }

    self[1] = self.button
    self:update()
end

local KoboReaderOverlay = FocusManager:extend{
    name = "KoboReaderOverlay",
    ui = nil,
    plugin = nil,
    curr_page = 1,
    total_pages = 1,
}

function KoboReaderOverlay:init()
    self.screen_w = Screen:getWidth()
    self.screen_h = Screen:getHeight()

    self.curr_page = self.ui:getCurrentPage()
    self.total_pages = math.max(1, self.ui.document:getPageCount())

    self.top_bar_h = Tokens.TOP_BAR_HEIGHT
    self.bottom_bar_h = Screen:scaleBySize(124)
    local icon_btn_size = Screen:scaleBySize(24)
    local btn_padding = Screen:scaleBySize(11)

    -- Physical Back key handler
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end

    -- Full-screen tap catcher for dismissing when tapping outside bars
    if Device:isTouchDevice() then
        self.ges_events.TapOverlay = {
            GestureRange:new{
                ges = "tap",
                range = Geom:new{
                    x = 0, y = 0,
                    w = self.screen_w,
                    h = self.screen_h,
                },
            },
        }
    end

    --------------------------------------------------------------------------
    -- 1. TOP BAR (Library Back, Title, Page Badge, RTL Manga Toggle, Search, Bookmark)
    --------------------------------------------------------------------------
    local back_btn = EinkIconButton:new{
        file = icons_dir .. "/arrow-left.svg",
        icon = "appbar.filebrowser",
        width = icon_btn_size,
        height = icon_btn_size,
        padding = btn_padding,
        show_parent = self,
        callback = function()
            self:onClose()
            self.ui:onClose()
            self.ui:showFileManager(self.ui.document.file)
        end,
    }

    local is_rtl = false
    if G_reader_settings and G_reader_settings:isTrue("invert_page_turn") then
        is_rtl = true
    end

    -- Quick Manga RTL Toggle Badge Button (eink-ui style)
    local rtl_badge = EinkWidgets.Badge:new{
        text = is_rtl and _("MANGA (RTL)") or _("LTR"),
        inverted = is_rtl,
        padding_h = Screen:scaleBySize(6),
        padding_v = Screen:scaleBySize(3),
    }

    local rtl_btn = EinkIconButton:new{
        width = Screen:scaleBySize(76),
        height = icon_btn_size,
        padding = Screen:scaleBySize(6),
        show_parent = self,
        callback = function()
            if Dispatcher:hasAction("toggle_invert_page_turn") then
                Dispatcher:execute("toggle_invert_page_turn")
            elseif self.ui.paging and self.ui.paging.invertPageTurn then
                self.ui.paging:invertPageTurn()
            end
            local new_rtl = not (G_reader_settings and G_reader_settings:isTrue("invert_page_turn"))
            if G_reader_settings then
                G_reader_settings:saveSetting("invert_page_turn", new_rtl)
            end
            rtl_badge:setText(new_rtl and _("MANGA (RTL)") or _("LTR"), new_rtl)
            UIManager:setDirty(self, "ui")
            UIManager:show(require("ui/widget/notification"):new{
                text = new_rtl and _("Đã bật chiều đọc Manga (Phải sang Trái)") or _("Đã chuyển chiều đọc sang LTR"),
            })
        end,
    }
    rtl_btn[1] = rtl_badge

    local search_btn = EinkIconButton:new{
        file = icons_dir .. "/magnifying-glass.svg",
        icon = "appbar.search",
        width = icon_btn_size,
        height = icon_btn_size,
        padding = btn_padding,
        show_parent = self,
        callback = function()
            self:onClose()
            UIManager:nextTick(function()
                if self.ui.search then
                    self.ui.search:onShowFulltextSearchInput()
                end
            end)
        end,
    }

    local bookmark_btn = EinkIconButton:new{
        file = icons_dir .. "/bookmark-simple.svg",
        icon = "bookmark",
        width = icon_btn_size,
        height = icon_btn_size,
        padding = btn_padding,
        show_parent = self,
        callback = function()
            if self.ui.bookmark then
                self.ui.bookmark:onToggleBookmark()
                UIManager:show(require("ui/widget/notification"):new{
                    text = _("Đã đánh dấu trang"),
                })
            end
            self:onClose()
        end,
    }

    local title_str = self:getBookTitle()
    local max_title_w = self.screen_w - Screen:scaleBySize(240)

    self.title_widget = TextWidget:new{
        text = title_str,
        max_width = math.max(Screen:scaleBySize(100), max_title_w),
        face = Tokens.getFont("title", 15),
        bold = true,
        fgcolor = Tokens.COLOR_BLACK,
    }

    local page_badge = EinkWidgets.Badge:new{
        text = string.format("%d / %d", self.curr_page, self.total_pages),
        inverted = false,
        padding_h = Screen:scaleBySize(6),
        padding_v = Screen:scaleBySize(2),
    }

    local top_inner = OverlapGroup:new{
        dimen = Geom:new{ x = 0, y = 0, w = self.screen_w, h = self.top_bar_h },
        LeftContainer:new{
            dimen = Geom:new{ x = 0, y = 0, w = self.screen_w, h = self.top_bar_h },
            back_btn,
        },
        CenterContainer:new{
            dimen = Geom:new{ x = 0, y = 0, w = self.screen_w, h = self.top_bar_h },
            HorizontalGroup:new{
                self.title_widget,
                HorizontalSpan:new{ width = Screen:scaleBySize(8) },
                page_badge,
            },
        },
        RightContainer:new{
            dimen = Geom:new{ x = 0, y = 0, w = self.screen_w, h = self.top_bar_h },
            HorizontalGroup:new{
                rtl_btn,
                search_btn,
                bookmark_btn,
            },
        },
    }

    self.top_frame = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = Tokens.COLOR_WHITE,
        VerticalGroup:new{
            top_inner,
            LineWidget:new{
                dimen = Geom:new{ w = self.screen_w, h = Tokens.LINE_NORMAL },
                background = Tokens.COLOR_BLACK,
            },
        },
    }

    --------------------------------------------------------------------------
    -- 2. BOTTOM BAR (eink-ui badges info, 4px progress bar, 5 primary buttons)
    --------------------------------------------------------------------------
    local pct = math.floor((self.curr_page / self.total_pages) * 100)
    local pages_left = self.total_pages - self.curr_page
    local chapter_title = self:getChapterTitle() or _("Chương hiện tại")

    local badge_chapter = EinkWidgets.Badge:new{
        text = chapter_title,
        inverted = false,
    }
    local badge_pct = EinkWidgets.Badge:new{
        text = string.format("%d%%", pct),
        inverted = true, -- Inverted black pill for percent
    }
    local badge_left = EinkWidgets.Badge:new{
        text = string.format(_("Còn %d trang"), pages_left),
        inverted = false,
    }

    local info_badges_row = HorizontalGroup:new{
        badge_pct,
        HorizontalSpan:new{ width = Screen:scaleBySize(6) },
        badge_chapter,
        HorizontalSpan:new{ width = Screen:scaleBySize(6) },
        badge_left,
    }

    local progress_bar_w = self.screen_w - Screen:scaleBySize(96)
    local progress_bar_h = Screen:scaleBySize(10)
    local ticks = nil
    if self.ui.toc and self.ui.toc.getTocTicksFlattened then
        ticks = self.ui.toc:getTocTicksFlattened()
    end

    self.progress_bar = ProgressWidget:new{
        width = progress_bar_w,
        height = progress_bar_h,
        percentage = self.curr_page / self.total_pages,
        ticks = ticks,
        tick_width = Tokens.LINE_HAIRLINE,
        last = self.total_pages,
        bordersize = Tokens.LINE_HAIRLINE,
        bgcolor = Tokens.COLOR_GRAY_MUTED,
        fillcolor = Tokens.COLOR_BLACK,
        initial_pos_marker = true,
    }

    -- Rapid step buttons: -10 and +10
    local step_minus_btn = EinkWidgets.Button:new{
        width = Screen:scaleBySize(36),
        height = Screen:scaleBySize(28),
        text = "-10",
        variant = "outline",
        callback = function()
            local target_p = math.max(1, self.curr_page - 10)
            self.ui:gotoPage(target_p)
            self.curr_page = target_p
            self:updateProgress()
        end,
    }

    local step_plus_btn = EinkWidgets.Button:new{
        width = Screen:scaleBySize(36),
        height = Screen:scaleBySize(28),
        text = "+10",
        variant = "outline",
        callback = function()
            local target_p = math.min(self.total_pages, self.curr_page + 10)
            self.ui:gotoPage(target_p)
            self.curr_page = target_p
            self:updateProgress()
        end,
    }

    local progress_slider_row = HorizontalGroup:new{
        step_minus_btn,
        HorizontalSpan:new{ width = Screen:scaleBySize(8) },
        self.progress_bar,
        HorizontalSpan:new{ width = Screen:scaleBySize(8) },
        step_plus_btn,
    }

    -- 5 Primary Action Buttons
    local action_btn_w = math.floor(self.screen_w / 5)
    local action_btn_h = Screen:scaleBySize(46)

    local function make_bottom_action(icon_filename, fallback_icon, label_text, callback)
        return CenterContainer:new{
            dimen = Geom:new{ w = action_btn_w, h = action_btn_h },
            EinkIconButton:new{
                file = icons_dir .. "/" .. icon_filename,
                icon = fallback_icon,
                width = icon_btn_size,
                height = icon_btn_size,
                padding = btn_padding,
                show_parent = self,
                callback = callback,
            },
        }
    end

    -- 1. Table of Contents (list-bullets)
    local toc_btn = make_bottom_action("list-bullets.svg", "book.opened", _("Mục lục"), function()
        self:onClose()
        UIManager:nextTick(function()
            if self.ui.toc then
                self.ui.toc:onShowToc()
            end
        end)
    end)

    -- 2. Manga & PDF Quick Settings (book-open) -> Opens EinkMangaSheet
    local manga_btn = make_bottom_action("book-open.svg", "appbar.textsize", _("Manga & PDF"), function()
        local EinkMangaSheet = require("eink_mangasheet")
        local sheet = EinkMangaSheet:new{
            ui = self.ui,
            overlay = self,
        }
        UIManager:show(sheet)
    end)

    -- 3. Brightness / Frontlight (sun)
    local light_btn = make_bottom_action("sun.svg", "appbar.contrast", _("Độ sáng"), function()
        self:onClose()
        UIManager:nextTick(function()
            if Device:hasFrontlight() then
                local FrontLightWidget = require("ui/widget/frontlightwidget")
                UIManager:show(FrontLightWidget:new{})
            else
                UIManager:show(require("ui/widget/notification"):new{
                    text = _("Thiết bị không hỗ trợ đèn nền"),
                })
            end
        end)
    end)

    -- 4. Page Jump (navigation-arrow)
    local goto_btn = make_bottom_action("navigation-arrow.svg", "appbar.navigation", _("Nhảy trang"), function()
        self:onClose()
        UIManager:nextTick(function()
            if self.ui.goto then
                self.ui.goto:onShowGotoDialog()
            end
        end)
    end)

    -- 5. Full KOReader Menu (dots-three-vertical)
    local more_btn = make_bottom_action("dots-three-vertical.svg", "appbar.menu", _("Cài đặt"), function()
        self:onClose()
        UIManager:nextTick(function()
            if self.ui.menu then
                self.ui.menu:onShowMenu()
            end
        end)
    end)

    local bottom_actions_row = HorizontalGroup:new{
        toc_btn,
        manga_btn,
        light_btn,
        goto_btn,
        more_btn,
    }

    self.bottom_frame = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = Tokens.COLOR_WHITE,
        VerticalGroup:new{
            align = "center",
            LineWidget:new{
                dimen = Geom:new{ w = self.screen_w, h = Tokens.LINE_NORMAL },
                background = Tokens.COLOR_BLACK,
            },
            VerticalSpan:new{ width = Screen:scaleBySize(6) },
            CenterContainer:new{
                dimen = Geom:new{ w = self.screen_w, h = Screen:scaleBySize(22) },
                info_badges_row,
            },
            VerticalSpan:new{ width = Screen:scaleBySize(6) },
            CenterContainer:new{
                dimen = Geom:new{ w = self.screen_w, h = Screen:scaleBySize(30) },
                progress_slider_row,
            },
            VerticalSpan:new{ width = Screen:scaleBySize(4) },
            bottom_actions_row,
            VerticalSpan:new{ width = Screen:scaleBySize(6) },
        },
    }

    --------------------------------------------------------------------------
    -- 3. CONTAINER ASSEMBLY (TopContainer + BottomContainer)
    --------------------------------------------------------------------------
    self.top_container = TopContainer:new{
        dimen = Geom:new{ x = 0, y = 0, w = self.screen_w, h = self.screen_h },
        self.top_frame,
    }

    self.bottom_container = BottomContainer:new{
        dimen = Geom:new{ x = 0, y = 0, w = self.screen_w, h = self.screen_h },
        self.bottom_frame,
    }

    self.root_group = OverlapGroup:new{
        dimen = Geom:new{ x = 0, y = 0, w = self.screen_w, h = self.screen_h },
        self.top_container,
        self.bottom_container,
    }

    self[1] = self.root_group
    self:initSliderGestures(progress_bar_w)
end

function KoboReaderOverlay:initSliderGestures(progress_bar_w)
    if not Device:isTouchDevice() then return end

    local slider_y = self.screen_h - self.bottom_bar_h + Screen:scaleBySize(34)
    local slider_x = math.floor((self.screen_w - progress_bar_w) / 2)

    self.ges_events.TapProgressBar = {
        GestureRange:new{
            ges = "tap",
            range = Geom:new{
                x = slider_x,
                y = slider_y - Screen:scaleBySize(10),
                w = progress_bar_w,
                h = Screen:scaleBySize(30),
            },
        },
    }
end

function KoboReaderOverlay:onTapProgressBar(arg, ges_ev)
    if not ges_ev.pos then return true end

    local progress_bar_w = self.progress_bar.width
    local slider_x = math.floor((self.screen_w - progress_bar_w) / 2)
    local tap_offset = math.max(0, math.min(progress_bar_w, ges_ev.pos.x - slider_x))
    local ratio = tap_offset / progress_bar_w

    local target_page = math.max(1, math.min(self.total_pages, math.floor(ratio * self.total_pages) + 1))
    self.ui:gotoPage(target_page)
    self.curr_page = target_page
    self:updateProgress()

    return true
end

function KoboReaderOverlay:updateProgress()
    self.curr_page = self.ui:getCurrentPage()
    if self.progress_bar then
        self.progress_bar.percentage = self.curr_page / self.total_pages
    end
    UIManager:setDirty(self, "ui")
end

function KoboReaderOverlay:onTapOverlay(arg, ges_ev)
    if not ges_ev.pos then return true end
    local y = ges_ev.pos.y
    if y > self.top_bar_h and y < (self.screen_h - self.bottom_bar_h) then
        self:onClose()
        return true
    end
    return false
end

function KoboReaderOverlay:onClose()
    UIManager:close(self)
    if self.plugin then
        self.plugin.overlay = nil
    end
end

function KoboReaderOverlay:getBookTitle()
    if self.ui.doc_props and self.ui.doc_props.title and self.ui.doc_props.title ~= "" then
        return self.ui.doc_props.title
    end
    if self.ui.document and self.ui.document.file then
        local filename = self.ui.document.file:match("([^/\\]+)$")
        if filename then
            return filename:gsub("%..+$", "")
        end
    end
    return _("Đang đọc")
end

function KoboReaderOverlay:getChapterTitle()
    if self.ui.toc and self.ui.toc.getCurrentChapterTitle then
        local chapter = self.ui.toc:getCurrentChapterTitle()
        if chapter and chapter ~= "" then
            return chapter
        end
    end
    return nil
end

return KoboReaderOverlay
