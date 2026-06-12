-- Sub-GHz radio test: begin, transmit, receive, end.

local ok, err = onion.subghz_begin()
if not ok then
    onion.log(err or "subghz_begin failed")
    onion.display_lines({
        "SubGHz FAIL",
        err or "begin failed"
    }, 8, 32, 22, { font = "bold", clear = true })
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

-- Transmit a short test payload
local payload = "onion-test:" .. onion.hardware_id():sub(1, 8)
local sent, tx_err = onion.subghz_transmit(payload)
if sent then
    onion.log("TX ok (" .. #payload .. " bytes)")
else
    onion.log(tx_err or "transmit failed")
end

-- Brief receive window
onion.sleep(200)
local msg = onion.subghz_receive(3000)
onion.subghz_end()

if msg then
    onion.display_lines({
        "SubGHz RX",
        "len=" .. msg.len .. " rssi=" .. msg.rssi_dbm .. "dBm",
        msg.message
    }, 8, 28, 20, { font = "bold", clear = true })
    onion.log("RX len=" .. msg.len .. " rssi=" .. msg.rssi_dbm)
else
    onion.display_lines({
        "SubGHz TX done",
        sent and "Sent ok" or (tx_err or "TX fail"),
        "No RX (expected)"
    }, 8, 28, 20, { font = "bold", clear = true })
    onion.log("No RX (normal if solo)")
end
