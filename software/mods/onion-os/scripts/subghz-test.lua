-- Sub-GHz radio tool: test, transmit, listen.
-- CANCEL exits back to Onion OS.

local MENU_ITEMS = {
    "1. Quick Test",
    "2. TX 5 Packets",
    "3. Listen",
}

local MODULATIONS = { "ook", "ask", "2fsk", "fsk", "msk" }

local selected = 1
local last_buttons = {}

local function wait_for_release()
    while true do
        local b = onion.buttons()
        if not b.up and not b.down and not b.select and not b.cancel then
            return
        end
        onion.sleep(50)
    end
end

local function draw_menu()
    local lines = { "SubGHz Tool" }
    for i, item in ipairs(MENU_ITEMS) do
        if i == selected then
            lines[#lines + 1] = "> " .. item
        else
            lines[#lines + 1] = "  " .. item
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "UP/DOWN select"
    lines[#lines + 1] = "SEL=run CANCEL=exit"
    onion.display_lines(lines, 8, 20, 17, { font = "bold", clear = true })
end

-- ── Modulation picker ───────────────────────────────────────────────────
-- Returns selected modulation string, or nil if cancelled.

local function pick_modulation()
    local mod_sel = 1
    local lb = {}

    local function draw()
        local lines = { "Modulation:" }
        for i, m in ipairs(MODULATIONS) do
            if i == mod_sel then
                lines[#lines + 1] = "> " .. m:upper()
            else
                lines[#lines + 1] = "  " .. m:upper()
            end
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "SEL=ok CANCEL=back"
        onion.display_lines(lines, 8, 20, 17, { font = "bold", clear = true })
    end

    wait_for_release()
    draw()

    while true do
        local buttons = onion.buttons()

        if buttons.cancel then
            wait_for_release()
            return nil
        end

        if buttons.up and not lb.up then
            mod_sel = mod_sel - 1
            if mod_sel < 1 then mod_sel = #MODULATIONS end
            draw()
        elseif buttons.down and not lb.down then
            mod_sel = mod_sel + 1
            if mod_sel > #MODULATIONS then mod_sel = 1 end
            draw()
        elseif buttons.select and not lb.select then
            wait_for_release()
            return MODULATIONS[mod_sel]
        end

        lb = buttons
        onion.sleep(80)
    end
end

-- ── Frequency picker ────────────────────────────────────────────────────
-- First screen: choose Default (433.92) or Custom.
-- Custom: 5 digits ABC.DE, UP/DOWN changes digit, SELECT locks & advances.
-- Returns frequency as a number, or nil if cancelled.

local function pick_frequency()
    local mode = 1  -- 1 = default, 2 = custom
    local lb = {}

    local function draw_choose()
        local lines = { "Pick Frequency:" }
        if mode == 1 then
            lines[#lines + 1] = "> Default (433.92)"
            lines[#lines + 1] = "  Custom..."
        else
            lines[#lines + 1] = "  Default (433.92)"
            lines[#lines + 1] = "> Custom..."
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "SEL=ok CANCEL=back"
        onion.display_lines(lines, 8, 20, 17, { font = "bold", clear = true })
    end

    wait_for_release()
    draw_choose()

    -- Choose default vs custom
    while true do
        local buttons = onion.buttons()

        if buttons.cancel then
            wait_for_release()
            return nil
        end

        if buttons.up and not lb.up then
            mode = 1
            draw_choose()
        elseif buttons.down and not lb.down then
            mode = 2
            draw_choose()
        elseif buttons.select and not lb.select then
            wait_for_release()
            if mode == 1 then
                return 433.92
            end
            break  -- enter custom digit picker
        end

        lb = buttons
        onion.sleep(80)
    end

    -- Custom digit picker
    local digits = { 4, 3, 3, 9, 2 }
    local pos = 1
    local cursor = 4
    lb = {}

    local function freq_string()
        local d = digits
        return d[1] .. d[2] .. d[3] .. "." .. d[4] .. d[5]
    end

    local function draw_digits()
        local digit_row = ""
        local caret_row = ""
        for i = 0, 9 do
            if i > 0 then digit_row = digit_row .. " " end
            digit_row = digit_row .. tostring(i)
            if i > 0 then caret_row = caret_row .. " " end
            if i == cursor then
                caret_row = caret_row .. "^"
            else
                caret_row = caret_row .. " "
            end
        end

        local prefix = "Freq: "
        local fstr = freq_string()
        local marker_pos = prefix:len() + 1
        local char_offsets = { 1, 2, 3, 5, 6 }
        marker_pos = marker_pos + char_offsets[pos] - 1
        local marker_row = ""
        for i = 1, marker_pos - 1 do marker_row = marker_row .. " " end
        marker_row = marker_row .. "^"

        onion.display_lines({
            "Pick Frequency:",
            " " .. prefix .. fstr .. " MHz",
            marker_row,
            "",
            digit_row,
            caret_row,
            "",
            "L/R=digit SEL=next CANCEL=back"
        }, 8, 16, 14, { font = "bold", clear = true })
    end

    cursor = digits[pos]
    draw_digits()

    while true do
        local buttons = onion.buttons()

        if buttons.cancel then
            wait_for_release()
            return nil
        end

        if buttons.right and not lb.right then
            cursor = cursor + 1
            if cursor > 9 then cursor = 0 end
            draw_digits()
        elseif buttons.left and not lb.left then
            cursor = cursor - 1
            if cursor < 0 then cursor = 9 end
            draw_digits()
        elseif buttons.select and not lb.select then
            digits[pos] = cursor
            pos = pos + 1
            if pos > 5 then
                wait_for_release()
                local int_part = digits[1] * 100 + digits[2] * 10 + digits[3]
                local frac_part = digits[4] * 10 + digits[5]
                return int_part + frac_part / 100.0
            end
            cursor = digits[pos]
            draw_digits()
        end

        lb = buttons
        onion.sleep(80)
    end
end

-- ── Option 1: Quick Test (original code, unchanged) ─────────────────────

local function run_quick_test()
    local ok, err = onion.subghz_begin()
    if not ok then
        onion.log(err or "subghz_begin failed")
        onion.display_lines({
            "SubGHz FAIL",
            err or "begin failed"
        }, 8, 32, 22, { font = "bold", clear = true })
        onion.sleep(3000)
        return
    end

    local info = onion.subghz_info()
    onion.log("partnum=" .. info.partnum .. " version=" .. info.version)
    onion.display_lines({
        "SubGHz " .. (info.variant or "?"),
        "PARTNUM=" .. info.partnum .. " VER=" .. info.version,
        "Freq " .. (info.frequency or "?") .. " MHz",
        "TX test..."
    }, 8, 22, 18, { font = "bold", clear = true })

    local payload = "onion-test:" .. onion.hardware_id():sub(1, 8)
    local sent, tx_err = onion.subghz_transmit(payload)
    if sent then
        onion.log("TX ok (" .. #payload .. " bytes)")
    else
        onion.log(tx_err or "transmit failed")
    end

    -- Read raw RSSI (noise floor)
    local rssi = onion.subghz_rssi()
    onion.log("RSSI (noise floor): " .. tostring(rssi) .. " dBm")

    onion.sleep(200)
    local msg = onion.subghz_receive(3000)
    onion.subghz_end()

    if msg then
        onion.display_lines({
            "SubGHz RX",
            "len=" .. msg.len .. " rssi=" .. msg.rssi_dbm .. "dBm",
            "noise=" .. tostring(rssi) .. "dBm",
            msg.message
        }, 8, 22, 18, { font = "bold", clear = true })
        onion.log("RX len=" .. msg.len .. " rssi=" .. msg.rssi_dbm)
    else
        onion.display_lines({
            "SubGHz TX done",
            sent and "Sent ok" or (tx_err or "TX fail"),
            "RSSI: " .. tostring(rssi) .. " dBm",
            "No RX (expected)"
        }, 8, 28, 20, { font = "bold", clear = true })
        onion.log("No RX (normal if solo)")
    end

    onion.sleep(4000)
end

-- ── Option 2: Transmit 5 packets in waves ───────────────────────────────

local function run_tx_wave()
    local mod = pick_modulation()
    if not mod then return end

    local freq = pick_frequency()
    if not freq then return end

    onion.display_lines({
        "Initializing...",
        mod:upper() .. " @ " .. string.format("%.2f", freq) .. " MHz"
    }, 8, 32, 22, { font = "bold", clear = true })

    local ok, err = onion.subghz_begin({ freq = freq, modulation = mod })
    if not ok then
        onion.display_lines({
            "SubGHz FAIL",
            err or "begin failed"
        }, 8, 32, 22, { font = "bold", clear = true })
        onion.sleep(3000)
        return
    end

    local info = onion.subghz_info()
    local hw = onion.hardware_id():sub(1, 8)

    onion.display_lines({
        "TX Wave Mode",
        mod:upper() .. " " .. (info.frequency or "?") .. " MHz",
        "Sending 5 packets...",
        "0.5s on / 0.5s off"
    }, 8, 22, 18, { font = "bold", clear = true })

    for i = 1, 5 do
        local payload = "onion-tx:" .. hw .. "#" .. i
        local sent, tx_err = onion.subghz_transmit(payload)
        if sent then
            onion.log("TX " .. i .. "/5 ok (" .. #payload .. " bytes)")
        else
            onion.log("TX " .. i .. "/5 fail: " .. (tx_err or "unknown"))
        end
        if i < 5 then
            onion.sleep(500)
        end
    end

    onion.subghz_end()

    onion.display_lines({
        "TX Wave Done",
        "5 packets sent",
        "0.5s interval"
    }, 8, 28, 20, { font = "bold", clear = true })
    onion.sleep(3000)
end

-- ── Option 3: Listen for signals ────────────────────────────────────────

local function run_listen()
    local mod = pick_modulation()
    if not mod then return end

    local freq = pick_frequency()
    if not freq then return end

    onion.display_lines({
        "Initializing...",
        mod:upper() .. " @ " .. string.format("%.2f", freq) .. " MHz"
    }, 8, 32, 22, { font = "bold", clear = true })

    local ok, err = onion.subghz_begin({ freq = freq, modulation = mod })
    if not ok then
        onion.display_lines({
            "SubGHz FAIL",
            err or "begin failed"
        }, 8, 32, 22, { font = "bold", clear = true })
        onion.sleep(3000)
        return
    end

    local info = onion.subghz_info()
    onion.display_lines({
        "Listening...",
        mod:upper() .. " " .. (info.frequency or "?") .. " MHz",
        "CANCEL to stop"
    }, 8, 22, 18, { font = "bold", clear = true })

    local count = 0

    while true do
        local buttons = onion.buttons()
        if buttons.cancel then
            onion.subghz_end()
            wait_for_release()
            return
        end

        -- Always read raw RSSI to show signal strength
        local rssi = onion.subghz_rssi()

        local msg = onion.subghz_receive(500)
        if msg then
            count = count + 1
            onion.log("RX #" .. count .. " len=" .. msg.len .. " rssi=" .. msg.rssi_dbm)
            onion.display_lines({
                "RX #" .. count .. "  RSSI:" .. rssi .. "dBm",
                "Pkt RSSI: " .. msg.rssi_dbm .. " dBm",
                mod:upper() .. " " .. (info.frequency or "?") .. " MHz",
                "Len: " .. msg.len .. " bytes",
                "Data: " .. (msg.message or ""):sub(1, 20),
                "",
                "CANCEL to stop"
            }, 8, 16, 15, { font = "bold", clear = true })
        else
            onion.display_lines({
                "Listening...",
                "RSSI: " .. rssi .. " dBm",
                mod:upper() .. " " .. (info.frequency or "?") .. " MHz",
                "Packets: " .. count,
                "",
                "CANCEL to stop"
            }, 8, 20, 16, { font = "bold", clear = true })
        end
    end
end

-- ── Main loop ───────────────────────────────────────────────────────────

draw_menu()

while true do
    local buttons = onion.buttons()

    if buttons.cancel then
        onion.release_display()
        return
    end

    if buttons.up and not last_buttons.up then
        selected = selected - 1
        if selected < 1 then selected = #MENU_ITEMS end
        draw_menu()
    elseif buttons.down and not last_buttons.down then
        selected = selected + 1
        if selected > #MENU_ITEMS then selected = 1 end
        draw_menu()
    elseif buttons.select and not last_buttons.select then
        wait_for_release()
        if selected == 1 then
            run_quick_test()
        elseif selected == 2 then
            run_tx_wave()
        elseif selected == 3 then
            run_listen()
        end
        draw_menu()
    end

    last_buttons = buttons
    onion.sleep(80)
end
