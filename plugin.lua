RED = {.96, .38, .32, 1}

function draw()
    imgui.Begin("YaLTeR's Misc")

    random_small_shift()
    imgui.Separator()
    shift()

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
    if imgui.Button("Left")   then lanes = {1, 2, 3, 4, 5, 6, 7} end
    imgui.SameLine()
    if imgui.Button("Center") then lanes = {4, 5, 3, 6, 2, 7, 1} end
    imgui.SameLine()
    if imgui.Button("Right")  then lanes = {7, 6, 5, 4, 3, 2, 1} end
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
