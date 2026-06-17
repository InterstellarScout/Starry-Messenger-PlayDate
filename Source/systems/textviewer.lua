import "CoreLibs/graphics"
import "data/texts"

local pd <const> = playdate
local gfx <const> = pd.graphics

TextViewerEffect = {}
TextViewerEffect.__index = TextViewerEffect

local VIEW_LIBRARY <const> = 1
local VIEW_READER <const> = 2
local CRANK_CURSOR_STEP <const> = 16
local CRANK_SCROLL_STEP <const> = 2
local MAX_TEXT_WIDTH <const> = 356
local READER_CONTENT_TOP <const> = 58
local READER_CONTENT_BOTTOM <const> = 222
local BODY_LINE_HEIGHT <const> = 17
local HEADING_LINE_HEIGHT <const> = 22
local BLANK_LINE_HEIGHT <const> = 11
local SETTINGS_KEY <const> = "textviewer-settings"

local FONT_OPTIONS <const> = {
    { id = "default", label = "Default Playdate", path = nil },
    { id = "roobert-11-medium", label = "Roobert 11 Medium", path = "fonts/textviewer/Roobert-11-Medium" },
    { id = "roobert-11-bold", label = "Roobert 11 Bold", path = "fonts/textviewer/Roobert-11-Bold" },
    { id = "sasser-slab", label = "Sasser Slab", path = "fonts/textviewer/Sasser-Slab" },
    { id = "sasser-slab-italic", label = "Sasser Slab Italic", path = "fonts/textviewer/Sasser-Slab-Italic" },
    { id = "newsleak-serif", label = "Newsleak Serif", path = "fonts/textviewer/Newsleak-Serif" },
    { id = "newsleak-serif-bold", label = "Newsleak Serif Bold", path = "fonts/textviewer/Newsleak-Serif-Bold" },
    { id = "bitmore", label = "Bitmore", path = "fonts/textviewer/font-Bitmore" }
}

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end
    return value
end

local function wrapIndex(index, count)
    if count <= 0 then
        return 1
    end
    while index < 1 do
        index = index + count
    end
    while index > count do
        index = index - count
    end
    return index
end

local function isBlank(line)
    return line == nil or line:match("^%s*$") ~= nil
end

local function isHiddenMediaLine(line)
    return line:match("^%s*!?%[%[.-%]%]%s*$") ~= nil
        or line:match("^%s*!%[.-%]%(.+%)%s*$") ~= nil
end

local function normalizePropertyKey(key)
    return tostring(key or ""):lower():gsub("%s+", "-"):gsub("_", "-")
end

local function normalizeFontId(value)
    local normalized = tostring(value or ""):lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", "-"):gsub("_", "-")
    for _, option in ipairs(FONT_OPTIONS) do
        if normalized == option.id or normalized == option.label:lower():gsub("%s+", "-") then
            return option.id
        end
    end
    return normalized
end

local function getTextWidth(text)
    local width = gfx.getTextSize(text)
    return width or 0
end

local function wrapText(text, maxWidth)
    local lines = {}
    local current = ""

    for word in tostring(text or ""):gmatch("%S+") do
        local candidate = current == "" and word or (current .. " " .. word)
        if current ~= "" and getTextWidth(candidate) > maxWidth then
            lines[#lines + 1] = current
            current = word
        else
            current = candidate
        end
    end

    if current ~= "" then
        lines[#lines + 1] = current
    end

    if #lines == 0 then
        lines[1] = ""
    end

    return lines
end

local function buildDocument(rawDocument)
    local source = rawDocument.source or ""
    local lines = {}
    for line in (source .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end

    local doc = {
        id = rawDocument.id,
        title = lines[1] or rawDocument.title or "Untitled",
        description = lines[2] or rawDocument.description or "",
        properties = {},
        bodyLines = {}
    }

    local lastBlank = false
    local bodyStart = 3
    for i = 3, #lines do
        local key, value = (lines[i] or ""):match("^%s*([%w%-%_ ]+):%s*(.-)%s*$")
        if key == nil then
            break
        end
        doc.properties[normalizePropertyKey(key)] = value
        bodyStart = i + 1
    end

    while bodyStart <= #lines and isBlank(lines[bodyStart]) do
        bodyStart = bodyStart + 1
    end

    for i = bodyStart, #lines do
        local line = lines[i] or ""
        if isHiddenMediaLine(line) then
            lastBlank = true
        elseif isBlank(line) then
            if not lastBlank then
                doc.bodyLines[#doc.bodyLines + 1] = ""
                lastBlank = true
            end
        else
            doc.bodyLines[#doc.bodyLines + 1] = line
            lastBlank = false
        end
    end

    while #doc.bodyLines > 0 and isBlank(doc.bodyLines[#doc.bodyLines]) do
        doc.bodyLines[#doc.bodyLines] = nil
    end

    return doc
end

local function buildDocuments()
    local documents = {}
    local rawDocuments = TEXT_VIEWER_DOCUMENTS or {}
    for i = 1, #rawDocuments do
        documents[#documents + 1] = buildDocument(rawDocuments[i])
    end
    return documents
end

function TextViewerEffect.getModeLabel()
    return "Text Viewer"
end

function TextViewerEffect.new(width, height, options)
    local self = setmetatable({}, TextViewerEffect)
    options = options or {}
    self.width = width or 400
    self.height = height or 240
    self.preview = options.preview == true
    self.documents = buildDocuments()
    self.index = clamp(options.documentIndex or 1, 1, math.max(1, #self.documents))
    self.defaultFont = gfx.getFont and gfx.getFont() or nil
    self.fonts = {}
    self.fontOptionsById = {}
    for _, option in ipairs(FONT_OPTIONS) do
        self.fontOptionsById[option.id] = option
        if option.path ~= nil then
            self.fonts[option.id] = gfx.font.new(option.path)
        end
    end
    local settings = pd.datastore and pd.datastore.read(SETTINGS_KEY) or nil
    self.defaultFontId = settings and settings.defaultFontId or "default"
    self.samplerSetsDefault = false
    self.view = VIEW_LIBRARY
    self.scrollY = 0
    self.maxScrollY = 0
    self.crankAccumulator = 0
    self.cursorLineIndex = 1
    self.cursorEnabled = true
    self.pageRollingEnabled = true
    self.pageRollAngle = 0
    self.pageRollVelocity = 0
    self.readerLines = {}
    self.totalReaderHeight = 0
    self.previewPulse = 0
    self:rebuildReader()
    return self
end

function TextViewerEffect:getFontOptionByLabel(label)
    local normalized = normalizeFontId(label)
    return self.fontOptionsById[normalized]
end

function TextViewerEffect:getFontForId(fontId)
    if fontId == nil or fontId == "default" then
        return self.defaultFont
    end
    return self.fonts[fontId] or self.defaultFont
end

function TextViewerEffect:getDocumentFontId(doc)
    if doc ~= nil and doc.properties ~= nil and doc.properties.font ~= nil then
        return normalizeFontId(doc.properties.font)
    end
    return self.defaultFontId or "default"
end

function TextViewerEffect:getActiveFont()
    return self:getFontForId(self:getDocumentFontId(self:getCurrentDocument()))
end

function TextViewerEffect:setDrawingFont(font)
    if font ~= nil then
        gfx.setFont(font)
    elseif self.defaultFont ~= nil then
        gfx.setFont(self.defaultFont)
    end
end

function TextViewerEffect:saveSettings()
    if pd.datastore == nil then
        return
    end
    pd.datastore.write({
        defaultFontId = self.defaultFontId or "default"
    }, SETTINGS_KEY)
end

function TextViewerEffect:setPreview(preview)
    self.preview = preview == true
end

function TextViewerEffect:activate()
end

function TextViewerEffect:shutdown()
end

function TextViewerEffect:getCurrentDocument()
    return self.documents[self.index]
end

function TextViewerEffect:rebuildReader()
    local doc = self:getCurrentDocument()
    self.readerLines = {}
    self.totalReaderHeight = 0
    if doc == nil then
        return
    end

    local previousFont = gfx.getFont and gfx.getFont() or nil
    self:setDrawingFont(self:getActiveFont())
    if doc.properties ~= nil and doc.properties.type == "font-sampler" then
        self.readerLines[#self.readerLines + 1] = {
            text = (self.samplerSetsDefault and "[x] Use selected font as default" or "[ ] Use selected font as default"),
            kind = "fontDefaultToggle",
            height = BODY_LINE_HEIGHT,
            y = self.totalReaderHeight
        }
        self.totalReaderHeight = self.totalReaderHeight + BODY_LINE_HEIGHT
        self.totalReaderHeight = self.totalReaderHeight + BLANK_LINE_HEIGHT
        for _, option in ipairs(FONT_OPTIONS) do
            self.readerLines[#self.readerLines + 1] = {
                text = option.label,
                kind = "fontOption",
                fontId = option.id,
                height = HEADING_LINE_HEIGHT,
                y = self.totalReaderHeight
            }
            self.totalReaderHeight = self.totalReaderHeight + HEADING_LINE_HEIGHT
        end
        self.maxScrollY = math.max(0, self.totalReaderHeight - 178)
        self.scrollY = clamp(self.scrollY, 0, self.maxScrollY)
        self.cursorLineIndex = clamp(self.cursorLineIndex or 1, 1, math.max(1, #self.readerLines))
        if previousFont ~= nil then
            gfx.setFont(previousFont)
        end
        return
    end

    for _, rawLine in ipairs(doc.bodyLines) do
        if isBlank(rawLine) then
            self.readerLines[#self.readerLines + 1] = {
                text = "",
                kind = "blank",
                height = BLANK_LINE_HEIGHT,
                y = self.totalReaderHeight
            }
            self.totalReaderHeight = self.totalReaderHeight + BLANK_LINE_HEIGHT
        else
            local marks, heading = rawLine:match("^(#+)%s+(.+)$")
            local kind = marks ~= nil and "heading" or "body"
            local text = heading or rawLine
            if kind == "heading" and #marks <= 2 then
                text = string.upper(text)
            end
            local wrapped = wrapText(text, MAX_TEXT_WIDTH)
            for i = 1, #wrapped do
                local height = kind == "heading" and HEADING_LINE_HEIGHT or BODY_LINE_HEIGHT
                self.readerLines[#self.readerLines + 1] = {
                    text = wrapped[i],
                    kind = kind,
                    height = height,
                    y = self.totalReaderHeight
                }
                self.totalReaderHeight = self.totalReaderHeight + height
            end
            if kind == "heading" then
                self.totalReaderHeight = self.totalReaderHeight + 3
            end
        end
    end

    self.maxScrollY = math.max(0, self.totalReaderHeight - 178)
    self.scrollY = clamp(self.scrollY, 0, self.maxScrollY)
    self.cursorLineIndex = clamp(self.cursorLineIndex or 1, 1, math.max(1, #self.readerLines))
    if previousFont ~= nil then
        gfx.setFont(previousFont)
    end
end

function TextViewerEffect:setIndex(index)
    if #self.documents <= 0 then
        return
    end
    self.index = wrapIndex(index, #self.documents)
    self.scrollY = 0
    self.cursorLineIndex = 1
    self.crankAccumulator = 0
    self:rebuildReader()
end

function TextViewerEffect:stepDocument(direction)
    self:setIndex(self.index + direction)
end

function TextViewerEffect:scrollBy(amount)
    self.scrollY = clamp(self.scrollY + amount, 0, self.maxScrollY)
end

function TextViewerEffect:getCursorLine()
    return self.readerLines[self.cursorLineIndex]
end

function TextViewerEffect:getCursorScreenY()
    local line = self:getCursorLine()
    if line == nil then
        return READER_CONTENT_TOP
    end
    return READER_CONTENT_TOP + line.y - self.scrollY
end

function TextViewerEffect:moveCursor(direction)
    if #self.readerLines <= 0 then
        return
    end

    local oldIndex = self.cursorLineIndex or 1
    self.cursorLineIndex = clamp(oldIndex + direction, 1, #self.readerLines)
    if self.cursorLineIndex == oldIndex then
        return
    end

    local line = self:getCursorLine()
    if line == nil then
        return
    end

    local middleY = READER_CONTENT_TOP + math.floor((READER_CONTENT_BOTTOM - READER_CONTENT_TOP) * 0.5)
    local cursorY = self:getCursorScreenY()
    if direction > 0 and cursorY >= middleY then
        self:scrollBy(cursorY - middleY)
    elseif direction < 0 and cursorY <= middleY then
        self:scrollBy(cursorY - middleY)
    elseif cursorY < READER_CONTENT_TOP then
        self:scrollBy(cursorY - READER_CONTENT_TOP)
    elseif cursorY + line.height > READER_CONTENT_BOTTOM then
        self:scrollBy((cursorY + line.height) - READER_CONTENT_BOTTOM)
    end
end

function TextViewerEffect:updatePageRoll(input)
    if not self.pageRollingEnabled then
        self.pageRollVelocity = 0
        self.pageRollAngle = self.pageRollAngle * 0.82
        return
    end

    local target = clamp((input or 0) * 0.1, -3.5, 3.5)
    self.pageRollVelocity = self.pageRollVelocity + ((target - self.pageRollVelocity) * 0.25)
    self.pageRollAngle = self.pageRollAngle + ((self.pageRollVelocity - self.pageRollAngle) * 0.22)
end

function TextViewerEffect:applyCrank(change, acceleratedChange)
    if self.preview then
        return
    end

    local input = acceleratedChange or change or 0
    if math.abs(input) <= 0.01 then
        return
    end

    if self.view == VIEW_LIBRARY then
        self.crankAccumulator = self.crankAccumulator + input
        while self.crankAccumulator >= 22 do
            self:stepDocument(1)
            self.crankAccumulator = self.crankAccumulator - 22
        end
        while self.crankAccumulator <= -22 do
            self:stepDocument(-1)
            self.crankAccumulator = self.crankAccumulator + 22
        end
    elseif self.cursorEnabled then
        self:updatePageRoll(input)
        self.crankAccumulator = self.crankAccumulator + input
        while self.crankAccumulator >= CRANK_CURSOR_STEP do
            self:moveCursor(1)
            self.crankAccumulator = self.crankAccumulator - CRANK_CURSOR_STEP
        end
        while self.crankAccumulator <= -CRANK_CURSOR_STEP do
            self:moveCursor(-1)
            self.crankAccumulator = self.crankAccumulator + CRANK_CURSOR_STEP
        end
    else
        self:updatePageRoll(input)
        self:scrollBy(input * CRANK_SCROLL_STEP)
    end
end

function TextViewerEffect:handlePrimaryAction()
    if self.view == VIEW_LIBRARY then
        self.view = VIEW_READER
        self.scrollY = 0
        self.cursorLineIndex = 1
        self:rebuildReader()
    else
        local line = self:getCursorLine()
        if line ~= nil and line.kind == "fontDefaultToggle" then
            self.samplerSetsDefault = not self.samplerSetsDefault
            self:rebuildReader()
        elseif line ~= nil and line.kind == "fontOption" then
            local doc = self:getCurrentDocument()
            doc.properties.font = line.fontId
            if self.samplerSetsDefault then
                self.defaultFontId = line.fontId
                self:saveSettings()
            end
            self:rebuildReader()
        else
            self.cursorEnabled = not self.cursorEnabled
        end
    end
end

function TextViewerEffect:handleBack()
    if self.view == VIEW_READER then
        self.view = VIEW_LIBRARY
        self.scrollY = 0
        self:rebuildReader()
        return true
    end
    return false
end

function TextViewerEffect:handleDirectionalInput(up, down, left, right)
    if self.preview then
        return
    end

    if self.view == VIEW_LIBRARY then
        if up or left then
            self:stepDocument(-1)
        elseif down or right then
            self:stepDocument(1)
        end
    else
        if up then
            if self.cursorEnabled then
                self:moveCursor(-1)
            else
                self:scrollBy(-18)
            end
        elseif down then
            if self.cursorEnabled then
                self:moveCursor(1)
            else
                self:scrollBy(18)
            end
        end
        if left then
            self.pageRollingEnabled = not self.pageRollingEnabled
        elseif right then
            self.cursorEnabled = not self.cursorEnabled
        end
    end
end

function TextViewerEffect:update()
    self.previewPulse = (self.previewPulse + 1) % 120
    if not self.pageRollingEnabled or self.view ~= VIEW_READER then
        self:updatePageRoll(0)
    end
end

function TextViewerEffect:drawPanel()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, self.width, self.height)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(6, 6, self.width - 12, self.height - 12)
end

function TextViewerEffect:drawLibrary()
    local doc = self:getCurrentDocument()
    self:setDrawingFont(self.defaultFont)
    self:drawPanel()

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.drawTextAligned("Text Viewer", 200, 18, kTextAlignment.center)
    gfx.drawLine(22, 39, 378, 39)

    if doc == nil then
        gfx.drawTextAligned("No documents found.", 200, 112, kTextAlignment.center)
        return
    end

    gfx.fillRoundRect(22, 62, 356, 84, 6)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextInRect(doc.title, 32, 74, 336, 20)
    gfx.drawTextInRect(doc.description, 32, 98, 336, 30)
    gfx.drawTextAligned(string.format("%d / %d", self.index, #self.documents), 366, 130, kTextAlignment.right)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)

    gfx.drawTextInRect("A open   Crank or D-pad choose   B title", 32, 180, 336, 36)
end

function TextViewerEffect:drawReader()
    local doc = self:getCurrentDocument()
    local previousFont = gfx.getFont and gfx.getFont() or nil
    local activeFont = self:getActiveFont()
    self:setDrawingFont(self.defaultFont)
    self:drawPanel()
    if doc == nil then
        return
    end

    gfx.drawTextInRect(doc.title, 18, 13, 190, 18)
    gfx.drawTextAligned(string.format("%d%%", math.floor((self.scrollY / math.max(1, self.maxScrollY)) * 100)), 378, 13, kTextAlignment.right)
    gfx.drawLine(14, 34, 386, 34)

    local cursorLabel = self.cursorEnabled and "Cursor:on" or "Cursor:off"
    local rollLabel = self.pageRollingEnabled and "Roll:on" or "Roll:off"
    gfx.drawText(cursorLabel, 22, 39)
    gfx.drawText(rollLabel, 116, 39)
    gfx.drawLine(14, 55, 386, 55)

    local contentTop = READER_CONTENT_TOP
    local contentBottom = READER_CONTENT_BOTTOM
    gfx.setColor(gfx.kColorBlack)
    local yOffset = contentTop - self.scrollY
    local rollAmount = self.pageRollingEnabled and clamp(self.pageRollAngle or 0, -3, 3) or 0
    local lastFont = nil
    local function setLineFont(font)
        if font ~= lastFont then
            self:setDrawingFont(font)
            lastFont = font
        end
    end

    for _, line in ipairs(self.readerLines) do
        local y = yOffset + line.y
        if y + line.height >= contentTop and y <= contentBottom then
            local rollX = 0
            if math.abs(rollAmount) > 0.08 then
                rollX = math.floor(math.sin(((y - contentTop) * 0.08) + rollAmount) * math.abs(rollAmount) + 0.5)
            end
            if line.kind == "fontOption" then
                setLineFont(self:getFontForId(line.fontId))
            else
                setLineFont(activeFont)
            end
            if line.kind == "heading" then
                gfx.fillRect(18 + rollX, y - 1, 364, line.height)
                gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
                gfx.drawText(line.text, 22 + rollX, y)
                gfx.setImageDrawMode(gfx.kDrawModeCopy)
            elseif line.kind == "body" or line.kind == "fontOption" or line.kind == "fontDefaultToggle" then
                gfx.drawText(line.text, 22 + rollX, y)
            end
        end
    end
    if self.cursorEnabled then
        local cursorLine = self:getCursorLine()
        if cursorLine ~= nil then
            local cursorY = yOffset + cursorLine.y
            if cursorY + cursorLine.height >= contentTop and cursorY <= contentBottom then
                local rollX = 0
                if math.abs(rollAmount) > 0.08 then
                    rollX = math.floor(math.sin(((cursorY - contentTop) * 0.08) + rollAmount) * math.abs(rollAmount) + 0.5)
                end
                local height = math.max(9, cursorLine.height - 2)
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(20 + rollX, cursorY, 8, height)
                gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
                if cursorLine.text ~= "" then
                    if cursorLine.kind == "fontOption" then
                        setLineFont(self:getFontForId(cursorLine.fontId))
                    else
                        setLineFont(activeFont)
                    end
                    gfx.drawText(string.sub(cursorLine.text, 1, 1), 22 + rollX, cursorY)
                end
                gfx.setImageDrawMode(gfx.kDrawModeCopy)
            end
        end
    end

    if self.maxScrollY > 0 then
        self:setDrawingFont(self.defaultFont)
        local trackY = READER_CONTENT_TOP
        local trackHeight = READER_CONTENT_BOTTOM - READER_CONTENT_TOP
        local knobHeight = math.max(18, math.floor(trackHeight * (trackHeight / math.max(trackHeight, self.totalReaderHeight))))
        local knobY = trackY + math.floor((trackHeight - knobHeight) * (self.scrollY / self.maxScrollY))
        gfx.drawRect(386, trackY, 4, trackHeight)
        gfx.fillRect(386, knobY, 4, knobHeight)
    end
    if previousFont ~= nil then
        gfx.setFont(previousFont)
    end
end

function TextViewerEffect:drawPreview()
    self:drawLibrary()
    if self.previewPulse < 60 then
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
        gfx.drawTextAligned("A open", 200, 206, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end

function TextViewerEffect:draw()
    if self.preview then
        self:drawPreview()
    elseif self.view == VIEW_LIBRARY then
        self:drawLibrary()
    else
        self:drawReader()
    end
end
