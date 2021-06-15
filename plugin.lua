RED = {.96, .38, .32, 1}

function draw()
    imgui.Begin("YaLTeR's Misc")

    random_small_shift()
    imgui.Separator()
    shift()
    imgui.Separator()
    find_anchors()

    imgui.End()
end

function get(name, default)
    return state.GetValue(name) or default
end

function set(name, value)
    state.SetValue(name, value)
end

function random_small_shift()
    imgui.Text("Random Small Shift")
    
    local max_shift = get("max_shift", 32)
    _, max_shift = imgui.SliderInt("Maximum shift (ms)", max_shift, 1, 100)
    set("max_shift", max_shift)
    
    if #state.SelectedHitObjects == 0 then
        imgui.TextColored(RED, "No objects selected.")
        return
    end
    
    if not imgui.Button("Apply") then
        return
    end
    
    local old_notes, new_notes = {}, {}
    for _, note in pairs(state.SelectedHitObjects) do
        table.insert(old_notes, note)
        
        local start_time = note.StartTime + math.random() * max_shift
        local end_time = note.EndTime
        if end_time ~= 0 then
            end_time = end_time + math.random() * max_shift
        end

        table.insert(new_notes, utils.CreateHitObject(start_time, note.Lane, end_time, note.HitSound, note.EditorLayer))
    end
    
    actions.RemoveHitObjectBatch(old_notes)
    actions.PlaceHitObjectBatch(new_notes)
    actions.SetHitObjectSelection(new_notes)
end

function shift()
    imgui.Text("Shift")
    
    if #state.SelectedHitObjects == 0 then
        imgui.TextColored(RED, "No objects selected.")
        return
    end
    
    local lanes
    if imgui.Button("Left") then
        if map.Mode == game_mode.Keys4 then
            lanes = {1, 2, 3, 4}
        elseif map.Mode == game_mode.Keys7 then
            lanes = {1, 2, 3, 4, 5, 6, 7}
        end
    end
    imgui.SameLine()
    if imgui.Button("Center") then
        if map.Mode == game_mode.Keys4 then
            lanes = {2, 3, 4, 1}
        elseif map.Mode == game_mode.Keys7 then
            lanes = {4, 5, 3, 6, 2, 7, 1}
        end
    end
    imgui.SameLine()
    if imgui.Button("Right") then
        if map.Mode == game_mode.Keys4 then
            lanes = {4, 3, 2, 1}
        elseif map.Mode == game_mode.Keys7 then
            lanes = {7, 6, 5, 4, 3, 2, 1}
        end
    end
    if not lanes then
        return
    end
    
    local old_notes = {}
    for _, note in pairs(state.SelectedHitObjects) do
        table.insert(old_notes, note)
    end
    
    -- Remove right away so they don't affect the checks.
    actions.RemoveHitObjectBatch(old_notes)
    
    local new_notes = {}
    
    local function note_exists(start_time, lane)
        -- TODO: If we want to place an LN we also need to check notes ahead, up to end time.
        
        for _, note in pairs(new_notes) do
            if note.StartTime > start_time then
                -- Hit objects are sorted by start time.
                break
            elseif note.Lane == lane and
                   ((note.EndTime == 0 and note.StartTime == start_time) or
                    (note.StartTime <= start_time and note.EndTime >= start_time))
            then
                return true
            end
        end
        
        for _, note in pairs(map.HitObjects) do
            if note.StartTime > start_time then
                -- Hit objects are sorted by start time.
                break
            elseif note.Lane == lane and
                   ((note.EndTime == 0 and note.StartTime == start_time) or
                    (note.StartTime <= start_time and note.EndTime >= start_time))
            then
                return true
            end
        end
        
        return false
    end
        
    for _, note in pairs(old_notes) do
        local lane
        for _, i in pairs(lanes) do
            if not note_exists(note.StartTime, i) then
                lane = i
                break
            end
        end
        
        -- Could only be false if there are overlaps.
        if lane then
            table.insert(new_notes, utils.CreateHitObject(note.StartTime, lane, note.EndTime, note.HitSound, note.EditorLayer))
        end
    end
    
    actions.PlaceHitObjectBatch(new_notes)
    actions.SetHitObjectSelection(new_notes)
end

function find_anchors()
    imgui.Text("Find Anchors")
    
    local max_snap = get("max_snap", 2)
    _, max_snap = imgui.SliderInt("Maximum snap", max_snap, 1, 16, "1/%d")
    set("max_snap", max_snap)
    
    local min_note_count = get("min_note_count", 3)
    _, min_note_count = imgui.SliderInt("Minimum note count", min_note_count, 2, 6)
    set("min_note_count", min_note_count)
    
    local find
    if #state.SelectedHitObjects == 0 then
        imgui.TextColored(RED, "No objects selected.")
    else
        find = imgui.Button("Find")
    end
    
    local anchors = get("anchors", {})
    for _, anchor in pairs(anchors) do
        if imgui.Button(anchor.go_to:gsub(",.+", "")) then
            actions.GoToObjects(anchor.go_to)
        end
        
        imgui.SameLine()
        imgui.Text(" - " .. anchor.count .. " notes")
    end
    
    if not find then
        return
    end
    
    anchors = {}
    
    local function is_anchor(prev, next)
        local bpm = map.GetTimingPointAt(prev).Bpm
        local limit = 60000 / bpm / max_snap + 1
        return next - prev <= limit
    end
    
    local notes = {}
    for _, note in pairs(state.SelectedHitObjects) do
        if notes[note.Lane] and is_anchor(notes[note.Lane][#notes[note.Lane]].StartTime, note.StartTime) then
            table.insert(notes[note.Lane], note)
        else
            if notes[note.Lane] and #notes[note.Lane] >= min_note_count then
                local go_to = ""
                for _, anchor_note in pairs(notes[note.Lane]) do
                    go_to = go_to .. "," .. anchor_note.StartTime .. "|" .. anchor_note.Lane
                end
                
                table.insert(anchors, { go_to = go_to:sub(2), count = #notes[note.Lane] })
            end
            
            notes[note.Lane] = {note}
        end
    end
    
    for _, lane_notes in pairs(notes) do
        if #lane_notes >= min_note_count then
            local go_to = ""
            for _, anchor_note in pairs(lane_notes) do
                go_to = go_to .. "," .. anchor_note.StartTime .. "|" .. anchor_note.Lane
            end
            
            table.insert(anchors, { go_to = go_to:sub(2), count = #lane_notes })
        end
    end
    
    set("anchors", anchors)
end
