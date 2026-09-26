local ADDON_NAME = ...

local TITLE = "Boojie Silvermoon Silencer"
local VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or ""
local ICON = "Interface\\AddOns\\BoojieSilvermoonSilencer\\BoojieSilvermoonSilencerBSSIcon.png"
local LDB_NAME = "BoojieSilvermoonSilencer"
local PINK_HEX = "FFFF8DA1"
local PINK_R, PINK_G, PINK_B = 1, 0.553, 0.631

local DEFAULT_NPCS = {
    ["Household Attendant"] = true,
    ["Silvermoon Attendant"] = true,
    ["Silvermoon Noble"] = true,
    ["Silvermoon Resident"] = true,
    ["Silvermoon Truthsayer"] = true,
}

local BACKDROP = {
    bgFile = "Interface/Buttons/WHITE8X8",
    edgeFile = "Interface/Buttons/WHITE8X8",
    edgeSize = 1,
    insets = {left = 1, right = 1, top = 1, bottom = 1},
}

local db
local ldbIcon
local window
local dropdownPopup
local dropdownRows = {}
local selectedName

local function Trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function InitializeDatabase()
    if type(BoojieSilvermoonSilencerDB) ~= "table" then
        BoojieSilvermoonSilencerDB = type(SilvermoonSilencerDB) == "table" and SilvermoonSilencerDB or {}
    end

    db = BoojieSilvermoonSilencerDB
    db.npcs = type(db.npcs) == "table" and db.npcs or {}
    db.showMinimapButton = db.showMinimapButton ~= false

    if type(db.minimap) ~= "table" then
        db.minimap = {minimapPos = tonumber(db.minimapAngle) or 220}
    end
    db.minimapAngle = nil

    if db.initialized == nil then
        for name in pairs(DEFAULT_NPCS) do
            db.npcs[name] = true
        end
        db.initialized = true
    end

    if type(db.defaultsVersion) ~= "number" or db.defaultsVersion < 2 then
        db.npcs["Silvermoon Noble"] = true
        db.defaultsVersion = 2
    end
end

local function ShouldHideMessage(_, _, _, sender)
    return sender and db.npcs[sender] == true
end

local function SortedNpcNames()
    local names = {}
    for name, blocked in pairs(db.npcs) do
        if blocked then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    return names
end

local function ApplyBackdrop(frame, alpha)
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(0, 0, 0, alpha or 1)
    frame:SetBackdropBorderColor(PINK_R, PINK_G, PINK_B, 1)
end

local function SkinButton(button)
    ApplyBackdrop(button, 1)
    button:SetNormalFontObject("GameFontHighlight")
    button:SetHighlightTexture("Interface/Buttons/WHITE8X8")
    button:GetHighlightTexture():SetVertexColor(PINK_R, PINK_G, PINK_B, 0.22)
    button:SetPushedTexture("Interface/Buttons/WHITE8X8")
    button:GetPushedTexture():SetVertexColor(PINK_R, PINK_G, PINK_B, 0.35)
end

local function CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetText(text)
    SkinButton(button)
    return button
end

local function CreateEditBox(parent)
    local editBox = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    editBox:SetFontObject("GameFontHighlight")
    editBox:SetTextInsets(9, 9, 0, 0)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(100)
    ApplyBackdrop(editBox, 1)
    return editBox
end

local function UpdateMinimapButtonVisibility()
    if not ldbIcon then
        return
    end

    db.minimap.hide = not db.showMinimapButton
    if db.showMinimapButton then
        ldbIcon:Show(LDB_NAME)
    else
        ldbIcon:Hide(LDB_NAME)
    end
end

local function ToggleWindow()
    window:SetShown(not window:IsShown())
end

local function CreateMinimapButton()
    ldbIcon = LibStub("LibDBIcon-1.0")
    local launcher = LibStub("LibDataBroker-1.1"):NewDataObject(LDB_NAME, {
        type = "launcher",
        label = TITLE,
        text = TITLE,
        icon = ICON,
        OnClick = ToggleWindow,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(TITLE, PINK_R, PINK_G, PINK_B)
            tooltip:AddLine("Click to open or close.", 1, 1, 1)
        end,
    })

    db.minimap.hide = not db.showMinimapButton
    ldbIcon:Register(LDB_NAME, launcher, db.minimap)
end

local function RefreshDropdown()
    local names = SortedNpcNames()
    if not (selectedName and db.npcs[selectedName]) then
        selectedName = names[1]
    end

    window.dropdown.text:SetText(selectedName or "No ignored names")
    window.removeButton:SetEnabled(selectedName ~= nil)
    window.countText:SetFormattedText("%d ignored %s", #names, #names == 1 and "name" or "names")
    dropdownPopup:Hide()
end

local function CreateDropdownRow(index)
    local row = CreateFrame("Button", nil, dropdownPopup)
    row:SetPoint("TOPLEFT", 2, -2 - ((index - 1) * 28))
    row:SetPoint("TOPRIGHT", -2, -2 - ((index - 1) * 28))
    row:SetHeight(28)
    row:SetHighlightTexture("Interface/Buttons/WHITE8X8")
    row:GetHighlightTexture():SetVertexColor(PINK_R, PINK_G, PINK_B, 0.22)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 9, 0)
    row:SetScript("OnClick", function(self)
        selectedName = self.name
        window.dropdown.text:SetText(self.name)
        dropdownPopup:Hide()
    end)
    return row
end

local function ShowDropdown()
    local names = SortedNpcNames()
    if #names == 0 then
        return
    end

    while #dropdownRows < #names do
        dropdownRows[#dropdownRows + 1] = CreateDropdownRow(#dropdownRows + 1)
    end

    for index, row in ipairs(dropdownRows) do
        local name = names[index]
        row.name = name
        row:SetShown(name ~= nil)
        if name then
            row.label:SetText(name)
        end
    end

    dropdownPopup:SetHeight((#names * 28) + 4)
    dropdownPopup:Show()
end

local function CreateWindow()
    window = CreateFrame("Frame", "BoojieSilvermoonSilencerWindow", UIParent, "BackdropTemplate")
    window:SetSize(470, 360)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetScript("OnShow", RefreshDropdown)
    ApplyBackdrop(window, 0.98)
    window:Hide()

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -17)
    title:SetText("|c" .. PINK_HEX .. TITLE .. "|r  |cffaaaaaav" .. VERSION .. "|r")

    local closeButton = CreateButton(window, "X", 24, 24)
    closeButton:SetPoint("TOPRIGHT", -10, -10)
    closeButton:SetScript("OnClick", function()
        window:Hide()
    end)

    local command = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    command:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
    command:SetText("Open this window: |c" .. PINK_HEX .. "/sms|r")

    local minimapCheck = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", 14, -67)
    minimapCheck:SetChecked(db.showMinimapButton)
    minimapCheck:SetScript("OnClick", function(self)
        db.showMinimapButton = self:GetChecked() and true or false
        UpdateMinimapButtonVisibility()
    end)

    local minimapLabel = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    minimapLabel:SetPoint("LEFT", minimapCheck, "RIGHT", 2, 0)
    minimapLabel:SetText("Show minimap button")

    local separator = window:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(PINK_R, PINK_G, PINK_B, 0.65)
    separator:SetPoint("TOPLEFT", 18, -108)
    separator:SetPoint("TOPRIGHT", -18, -108)
    separator:SetHeight(1)

    local addLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addLabel:SetPoint("TOPLEFT", 18, -130)
    addLabel:SetTextColor(PINK_R, PINK_G, PINK_B)
    addLabel:SetText("Add an NPC name")

    window.input = CreateEditBox(window)
    window.input:SetSize(332, 30)
    window.input:SetPoint("TOPLEFT", 18, -153)

    local addButton = CreateButton(window, "Add", 84, 30)
    addButton:SetPoint("LEFT", window.input, "RIGHT", 10, 0)

    local function AddEnteredName()
        local name = Trim(window.input:GetText())
        if name == "" then
            return
        end

        db.npcs[name] = true
        selectedName = name
        window.input:SetText("")
        window.input:SetFocus()
        RefreshDropdown()
    end

    addButton:SetScript("OnClick", AddEnteredName)
    window.input:SetScript("OnEnterPressed", AddEnteredName)
    window.input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local ignoredLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ignoredLabel:SetPoint("TOPLEFT", 18, -211)
    ignoredLabel:SetTextColor(PINK_R, PINK_G, PINK_B)
    ignoredLabel:SetText("Ignored names")

    window.countText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.countText:SetPoint("RIGHT", -18, 0)
    window.countText:SetPoint("BOTTOM", ignoredLabel, "BOTTOM", 0, 0)

    window.dropdown = CreateButton(window, "", 332, 32)
    window.dropdown:SetPoint("TOPLEFT", 18, -235)
    window.dropdown:SetScript("OnClick", function()
        if dropdownPopup:IsShown() then
            dropdownPopup:Hide()
        else
            ShowDropdown()
        end
    end)

    window.dropdown.text = window.dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    window.dropdown.text:SetPoint("LEFT", 10, 0)
    window.dropdown.text:SetPoint("RIGHT", -30, 0)
    window.dropdown.text:SetJustifyH("LEFT")

    local arrow = window.dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    arrow:SetPoint("RIGHT", -10, 0)
    arrow:SetText("v")

    window.removeButton = CreateButton(window, "Remove", 84, 32)
    window.removeButton:SetPoint("LEFT", window.dropdown, "RIGHT", 10, 0)
    window.removeButton:SetScript("OnClick", function()
        if selectedName then
            db.npcs[selectedName] = nil
            selectedName = nil
            RefreshDropdown()
        end
    end)

    dropdownPopup = CreateFrame("Frame", nil, window, "BackdropTemplate")
    dropdownPopup:SetFrameStrata("TOOLTIP")
    dropdownPopup:SetPoint("TOPLEFT", window.dropdown, "BOTTOMLEFT", 0, -2)
    dropdownPopup:SetPoint("TOPRIGHT", window.dropdown, "BOTTOMRIGHT", 0, -2)
    ApplyBackdrop(dropdownPopup, 1)
    dropdownPopup:Hide()

    local help = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", 18, -287)
    help:SetPoint("RIGHT", -18, 0)
    help:SetJustifyH("LEFT")
    help:SetText("Choose an ignored NPC from the menu, then click Remove to allow its messages again.")

    table.insert(UISpecialFrames, window:GetName())
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon ~= ADDON_NAME then
        return
    end

    InitializeDatabase()
    CreateWindow()
    CreateMinimapButton()

    ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_SAY", ShouldHideMessage)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_YELL", ShouldHideMessage)

    SLASH_BOOJIESILVERMOONSILENCER1 = "/sms"
    SlashCmdList.BOOJIESILVERMOONSILENCER = ToggleWindow
end)
