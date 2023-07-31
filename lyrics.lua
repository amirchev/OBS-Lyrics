--- Copyright 2020 amirchev/wzaggle

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

-- http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

obs = obslua
bit = require("bit")

-- source definitions
source_data = {}
source_def = {}
source_def.id = "Prepare_Lyrics"
source_def.type = OBS_SOURCE_TYPE_INPUT
source_def.output_flags = bit.bor(obs.OBS_SOURCE_CUSTOM_DRAW)

-- text sources
source_name = ""
alternate_source_name = ""
static_source_name = ""
static_text = ""
title_source_name = ""

-- settings
windows_os = false
first_open = true

display_lines = 0
ensure_lines = true

-- lyrics/alternate lyrics by page
lyrics = {}
alternate = {}

-- verse indicies if marked
verses = {}

page_index = 0 -- current page of lyrics being displayed
prepared_index = 0 -- TODO: avoid setting prepared_index directly, use prepare_selected

song_directory = {} -- holds list of current songs from song directory TODO: Multiple Song Books (Directories)
prepared_songs = {} -- holds pre-prepared list of songs to use
extra_sources = {} -- holder for extra sources settings

link_text = false -- true if Title and Static should fade with text only during hide/show
link_extras = false -- extras fade with text always when true, only during hide/show when false
all_sources_fade = false -- Title and Static should only fade when lyrics are changing or during show/hide
source_song_title = "" -- The song title from a source loaded song
using_source = false -- true when a lyric load song is being used instead of a pre-prepared song
source_active = false -- true when a lyric load source is active in the current scene (song is loaded or available to load)

load_scene = "" -- name of scene loading a lyric with a source
last_prepared_song = "" -- name of the last prepared song (prevents duplicate loading of already loaded song)

-- hotkeys
hotkey_n_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_p_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_c_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_n_p_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_p_p_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_home_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_reset_id = obs.OBS_INVALID_HOTKEY_ID

hotkey_n_key = ""
hotkey_p_key = ""
hotkey_c_key = ""
hotkey_n_p_key = ""
hotkey_p_p_key = ""
hotkey_home_key = ""
hotkey_reset_key = ""

-- script placeholders
script_sets = nil
script_props = nil
source_sets = nil
source_props = nil
hotkey_props = nil

--monitor variables
mon_song = ""
mon_lyric = ""
mon_verse = 0
mon_nextlyric = ""
mon_alt = ""
mon_nextalt = ""
mon_nextsong = ""
meta_tags = ""
source_meta_tags = ""

-- text status & fade
TEXT_VISIBLE = 0 -- text is visible
TEXT_HIDDEN = 1 -- text is hidden
TEXT_SHOWING = 3 -- going from hidden -> visible
TEXT_HIDING = 4 -- going from visible -> hidden
TEXT_TRANSITION_OUT = 5 -- fade out transition to next lyric
TEXT_TRANSITION_IN = 6 -- fade in transition after lyric change
TEXT_HIDE = 7 -- turn off the text and ignore fade if selected
TEXT_SHOW = 8 -- turn on the text and ignore fade if selected

text_status = TEXT_VISIBLE
text_opacity = 100
text_fade_speed = 1
text_fade_enabled = false
load_source = nil
expandcollapse = true
showhelp = false

transition_enabled = false -- transitions are a work in progress to support duplicate source mode (not very stable)
transition_completed = false

source_saved = false --  ick...  A saved toggle to keep from repeating the save function for every song source.  Works for now

editVisSet = false

-- simple debugging/print mechanism
DEBUG = false -- on switch for entire debugging mechanism
DEBUG_METHODS = true -- print method names
DEBUG_INNER = true -- print inner method breakpoints
DEBUG_CUSTOM = true -- print custom debugging messages
DEBUG_BOOL = true -- print message with bool state true/false

--------
----------------
------------------------ CALLBACKS
----------------
--------

function next_lyric(pressed)
    if not pressed then
        return
    end
    dbg_method("next_lyric")
    -- check if transition enabled
    if transition_enabled and not transition_completed then
        obs.obs_frontend_preview_program_trigger_transition()
        transition_completed = true
        return
    end
    dbg_inner("next page")
    if (#lyrics > 0 or #alternate > 0) and sourceShowing() then -- only change if defined and showing
        if page_index < #lyrics then
            page_index = page_index + 1
            dbg_inner("page_index: " .. page_index)
            transition_lyric_text(false)
        else
            next_prepared(true)
        end
    end
end

function prev_lyric(pressed)
    if not pressed then
        return
    end
    dbg_method("prev_lyric")
    if (#lyrics > 0 or #alternate > 0) and sourceShowing() then -- only change if defined and showing
        if page_index > 1 then
            page_index = page_index - 1
            dbg_inner("page_index: " .. page_index)
            transition_lyric_text(false)
        else
            prev_prepared(true)
        end
    end
end

function prev_prepared(pressed)
    if not pressed then
        return
    end
    if #prepared_songs == 0 then
        return
    end
    if using_source then
        using_source = false
        prepare_selected(prepared_songs[prepared_index])
        return
    end
    if prepared_index > 1 then
        using_source = false
        prepare_selected(prepared_songs[prepared_index - 1])
        return
    end
    if not source_active or using_source then
        using_source = false
        prepare_selected(prepared_songs[#prepared_songs]) -- cycle through prepared
    else
        using_source = true
        prepared_index = #prepared_songs -- wrap prepared index to end so ready if leaving load source
        load_source_song(load_source, false)
    end
end

function next_prepared(pressed)
    if not pressed then
        return
    end
    if #prepared_songs == 0 then
        return
    end
    if using_source then
        using_source = false
        dbg_custom("do current prepared")
        prepare_selected(prepared_songs[prepared_index]) -- if source load song showing then goto curren prepared song
        return
    end
    if prepared_index < #prepared_songs then
        using_source = false
        dbg_custom("do next prepared")
        prepare_selected(prepared_songs[prepared_index + 1]) -- if prepared then goto next prepared
        return
    end
    if not source_active or using_source then
        using_source = false
        dbg_custom("do first prepared")
        prepare_selected(prepared_songs[1]) -- at the end so go back to start if no source load available
    else
        using_source = true
        dbg_custom("do source prepared")
        prepared_index = 1 -- wrap prepared index to beginning so ready if leaving load source
        load_source_song(load_source, false)
    end
end

function toggle_lyrics_visibility(pressed)
    dbg_method("toggle_lyrics_visibility")
    if not pressed then
        return
    end
    if link_text then
        all_sources_fade = true
    end
    if text_status ~= TEXT_HIDDEN then
        dbg_inner("hiding")
        set_text_visibility(TEXT_HIDDEN)
    else
        dbg_inner("showing")
        set_text_visibility(TEXT_VISIBLE)
    end
end

function get_load_lyric_song()
    local scene = obs.obs_frontend_get_current_scene()
    local scene_items = obs.obs_scene_enum_items(scene) -- Get list of all items in this scene
    local song = nil
    if scene_items ~= nil then
        for _, scene_item in ipairs(scene_items) do -- Loop through all scene source items
            local source = obs.obs_sceneitem_get_source(scene_item) -- Get item source pointer
            local source_id = obs.obs_source_get_unversioned_id(source) -- Get item source_id
            if source_id == "Prepare_Lyrics" then -- Skip if not a Prepare_Lyric source item
                local settings = obs.obs_source_get_settings(source) -- Get settings for this Prepare_Lyric source
                song = obs.obs_data_get_string(settings, "song") -- Get index for this source (set earlier)
                obs.obs_data_release(settings) -- release memory
            end
        end
    end
    obs.sceneitem_list_release(scene_items) -- Free scene list
    return song
end

function home_prepared(pressed)
    if not pressed then
        return false
    end
    dbg_method("home_prepared")
    using_source = false
    page_index = 0

    local prop_prep_list = obs.obs_properties_get(props, "prop_prepared_list")
    if #prepared_songs > 0 then
        obs.obs_data_set_string(script_sets, "prop_prepared_list", prepared_songs[1])
    else
        obs.obs_data_set_string(script_sets, "prop_prepared_list", "")
    end
    obs.obs_properties_apply_settings(props, script_sets)
    prepared_index = 1
    prepare_selected(prepared_songs[prepared_index])
    return true
end

function home_song(pressed)
    if not pressed then
        return false
    end
    dbg_method("home_song")
    page_index = 1
    transition_lyric_text(false)
    return true
end

function get_current_scene_name()
    dbg_method("get_current_scene_name")
    local scene = obs.obs_frontend_get_current_scene()
    local current_scene = obs.obs_source_get_name(scene)
    obs.obs_source_release(scene)
    if current_scene ~= nil then
        return current_scene
    else
        return "-"
    end
end

function next_button_clicked(props, p)
    next_lyric(true)
    return true
end

function prev_button_clicked(props, p)
    prev_lyric(true)
    return true
end

function toggle_button_clicked(props, p)
    toggle_lyrics_visibility(true)
    return true
end

function home_button_clicked(props, p)
    home_song(true)
    return true
end

function reset_button_clicked(props, p)
    home_prepared(true)
    return true
end
function prev_prepared_clicked(props, p)
    prev_prepared(true)
    return true
end

function next_prepared_clicked(props, p)
    next_prepared(true)
    return true
end

function save_song_clicked(props, p)
    local name = obs.obs_data_get_string(script_sets, "prop_edit_song_title")
    local text = obs.obs_data_get_string(script_sets, "prop_edit_song_text")
    -- if this is a new song, add it to the directory
    if save_song(name, text) then
        local prop_dir_list = obs.obs_properties_get(props, "prop_directory_list")
        obs.obs_property_list_add_string(prop_dir_list, name, name)
        obs.obs_data_set_string(script_sets, "prop_directory_list", name)
        obs.obs_properties_apply_settings(props, script_sets)
    elseif prepared_songs[prepared_index] == name then
        -- if this song is being displayed, then prepare it anew
        prepare_song_by_name(name)
        transition_lyric_text(false)
    end
    return true
end

-- callback for the delete song button
-- deletes the selected song and updates the UI
function delete_song_clicked(props, p)
    dbg_method("delete_song_clicked")
    -- call delete song function
    local name = obs.obs_data_get_string(script_sets, "prop_directory_list")
    delete_song(name)
    -- update
    local prop_dir_list = obs.obs_properties_get(props, "prop_directory_list")
    for i = 0, obs.obs_property_list_item_count(prop_dir_list) do
        if obs.obs_property_list_item_string(prop_dir_list, i) == name then
            obs.obs_property_list_item_remove(prop_dir_list, i)
            if i > 1 then
                i = i - 1
            end
            if #song_directory > 0 then
                obs.obs_data_set_string(script_sets, "prop_directory_list", song_directory[i])
            else
                obs.obs_data_set_string(script_sets, "prop_directory_list", "")
                obs.obs_data_set_string(script_sets, "prop_edit_song_title", "")
                obs.obs_data_set_string(script_sets, "prop_edit_song_text", "")
            end
            local prop_prep_list = obs.obs_properties_get(props, "prop_prepared_list")
            if get_index_in_list(prepared_songs, name) ~= nil then
                if obs.obs_property_list_item_string(prop_prep_list, i) == name then
                    obs.obs_property_list_item_remove(prop_prep_list, i)
                    if i > 1 then
                        i = i - 1
                    end
                    if #prepared_songs > 0 then
                        obs.obs_data_set_string(script_sets, "prop_prepared_list", prepared_songs[i])
                    else
                        obs.obs_data_set_string(script_sets, "prop_prepared_list", "")
                    end
                end
            end
            obs.obs_properties_apply_settings(props, script_sets)
            return true
        end
    end
    return true
end

-- prepare song button clicked
function prepare_song_clicked(props, p)
    dbg_method("prepare_song_clicked")
    if #prepared_songs == 0 then
        set_text_visibility(TEXT_HIDDEN)
    end
    prepared_songs[#prepared_songs + 1] = obs.obs_data_get_string(script_sets, "prop_directory_list")
    local prop_prep_list = obs.obs_properties_get(props, "prop_prepared_list")
    obs.obs_property_list_add_string(prop_prep_list, prepared_songs[#prepared_songs], prepared_songs[#prepared_songs])

    obs.obs_data_set_string(script_sets, "prop_prepared_list", prepared_songs[#prepared_songs])

    obs.obs_properties_apply_settings(props, script_sets)

    return true
end

function refresh_button_clicked(props, p)
    local source_prop = obs.obs_properties_get(props, "prop_source_list")
    local alternate_source_prop = obs.obs_properties_get(props, "prop_alternate_list")
    local static_source_prop = obs.obs_properties_get(props, "prop_static_list")
    local title_source_prop = obs.obs_properties_get(props, "prop_title_list")
    local extra_source_prop = obs.obs_properties_get(props, "extra_source_list")

    obs.obs_property_list_clear(source_prop) -- clear current properties list
    obs.obs_property_list_clear(alternate_source_prop) -- clear current properties list
    obs.obs_property_list_clear(static_source_prop) -- clear current properties list
    obs.obs_property_list_clear(title_source_prop) -- clear current properties list
    obs.obs_property_list_clear(extra_source_prop) -- clear extra sources list

    obs.obs_property_list_add_string(extra_source_prop, "", "")

    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        local n = {}
        for _, source in ipairs(sources) do
            local name = obs.obs_source_get_name(source)
            if isValid(source) then
                obs.obs_property_list_add_string(extra_source_prop, name, name) -- add source to extra list
            end
            source_id = obs.obs_source_get_unversioned_id(source)
            if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
                n[#n + 1] = name
            end
        end
        table.sort(n)
        obs.obs_property_list_add_string(source_prop, "", "")
        obs.obs_property_list_add_string(title_source_prop, "", "")
        obs.obs_property_list_add_string(alternate_source_prop, "", "")
        obs.obs_property_list_add_string(static_source_prop, "", "")
        for _, name in ipairs(n) do
            obs.obs_property_list_add_string(source_prop, name, name)
            obs.obs_property_list_add_string(title_source_prop, name, name)
            obs.obs_property_list_add_string(alternate_source_prop, name, name)
            obs.obs_property_list_add_string(static_source_prop, name, name)
        end
    end
    obs.source_list_release(sources)
    refresh_directory()

    return true
end

function refresh_directory_button_clicked(props, p)
    dbg_method("refresh directory")
    refresh_directory()
    return true
end

function refresh_directory()
    local prop_dir_list = obs.obs_properties_get(script_props, "prop_directory_list")
    local source_prop = obs.obs_properties_get(props, "prop_source_list")
    source_filter = false
    load_source_song_directory(true)
    table.sort(song_directory)
    obs.obs_property_list_clear(prop_dir_list) -- clear directories
    for _, name in ipairs(song_directory) do
        dbg_inner(name)
        obs.obs_property_list_add_string(prop_dir_list, name, name)
    end
    obs.obs_properties_apply_settings(script_props, script_sets)
end

-- Called with ANY change to the prepared song list
function prepare_selection_made(props, prop, settings)
    obs.obs_property_set_description(
        obs.obs_properties_get(props, "prep_grp"),
        "  Prepared Songs/Text (" .. #prepared_songs .. ")"
    )
    dbg_method("prepare_selection_made")
    local name = obs.obs_data_get_string(settings, "prop_prepared_list")
    using_source = false
    prepare_selected(name)
    return true
end

-- removes prepared songs
function clear_prepared_clicked(props, p)
    dbg_method("clear_prepared_clicked")
    prepared_songs = {} -- required for monitor page
    page_index = 0 -- required for monitor page
    prepared_index = 0 -- required for monitor page
    update_source_text() -- required for monitor page
    -- clear the list
    local prep_prop = obs.obs_properties_get(props, "prop_prepared_list")
    obs.obs_property_list_clear(prep_prop)
    obs.obs_data_set_string(script_sets, "prop_prepared_list", "")
    obs.obs_properties_apply_settings(props, script_sets)
    return true
end

-- prepares the song with the title {name}
function prepare_selected(name)
    dbg_method("prepare_selected")
    -- try to prepare song
    if prepare_song_by_name(name) then
        page_index = 1
        if not using_source then
            prepared_index = get_index_in_list(prepared_songs, name)
        else
            source_song_title = name
            all_sources_fade = true
        end

        transition_lyric_text(using_source)
    else
        -- hide everything if unable to prepare song
        -- TODO: clear lyrics entirely after text is hidden
        set_text_visibility(TEXT_HIDDEN)
    end

    --update_source_text()
    return true
end

-- called when selection is made from directory list
function preview_selection_made(props, prop, settings)
    local name = obs.obs_data_get_string(script_sets, "prop_directory_list")

    if get_index_in_list(song_directory, name) == nil then
        return false
    end -- do nothing if invalid name

    obs.obs_data_set_string(settings, "prop_edit_song_title", name)
    local song_lines = get_song_text(name)
    local combined_text = ""
    for i, line in ipairs(song_lines) do
        if (i < #song_lines) then
            combined_text = combined_text .. line .. "\n"
        else
            combined_text = combined_text .. line
        end
    end
    obs.obs_data_set_string(settings, "prop_edit_song_text", combined_text)
    return true
end

-- callback for when open song in editor button is clicked
-- opens the song in the native text editor
function open_song_clicked(props, p)
    local name = obs.obs_data_get_string(script_sets, "prop_directory_list")
    if testValid(name) then
        path = get_song_file_path(name, ".txt")
    else
        path = get_song_file_path(enc(name), ".enc")
    end
    if windows_os then
        os.execute('explorer "' .. path .. '"')
    else
        os.execute('xdg-open "' .. path .. '"')
    end
    return true
end

-- callback for when open songs folder button is clicked
-- opens the folder containing files of all the saved songs
function open_button_clicked(props, p)
    local path = get_songs_folder_path()
    if windows_os then
        os.execute('explorer "' .. path .. '"')
    else
        os.execute('xdg-open "' .. path .. '"')
    end
end

-- applies current source opacity to the necessary sources
function apply_source_opacity()
    --    dbg_method("apply_source_visiblity")
    local settings = obs.obs_data_create()
    obs.obs_data_set_int(settings, "opacity", text_opacity) -- Set new text opacity to zero
    obs.obs_data_set_int(settings, "outline_opacity", text_opacity) -- Set new text outline opacity to zero
    local source = obs.obs_get_source_by_name(source_name)
    if source ~= nil then
        obs.obs_source_update(source, settings)
    end
    obs.obs_source_release(source)
    obs.obs_data_release(settings)

    local settings = obs.obs_data_create()
    obs.obs_data_set_int(settings, "opacity", text_opacity) -- Set new text opacity to zero
    obs.obs_data_set_int(settings, "outline_opacity", text_opacity) -- Set new text outline opacity to zero
    local alt_source = obs.obs_get_source_by_name(alternate_source_name)
    if alt_source ~= nil then
        obs.obs_source_update(alt_source, settings)
    end
    obs.obs_source_release(alt_source)
    obs.obs_data_release(settings)
    dbg_bool("All Sources Fade:", all_sources_fade)
    dbg_bool("Link Text:", link_text)
    if all_sources_fade then
        local settings = obs.obs_data_create()
        obs.obs_data_set_int(settings, "opacity", text_opacity) -- Set new text opacity to zero
        obs.obs_data_set_int(settings, "outline_opacity", text_opacity) -- Set new text outline opacity to zero
        local title_source = obs.obs_get_source_by_name(title_source_name)
        if title_source ~= nil then
            obs.obs_source_update(title_source, settings)
        end
        obs.obs_source_release(title_source)
        obs.obs_data_release(settings)

        local settings = obs.obs_data_create()
        obs.obs_data_set_int(settings, "opacity", text_opacity) -- Set new text opacity to zero
        obs.obs_data_set_int(settings, "outline_opacity", text_opacity) -- Set new text outline opacity to zero
        local static_source = obs.obs_get_source_by_name(static_source_name)
        if static_source ~= nil then
            obs.obs_source_update(static_source, settings)
        end
        obs.obs_source_release(static_source)
        obs.obs_data_release(settings)
    end
    if link_extras or all_sources_fade then
        local extra_linked_list = obs.obs_properties_get(script_props, "extra_linked_list")
        local count = obs.obs_property_list_item_count(extra_linked_list)
        if count > 0 then
            for i = 0, count - 1 do
                local source_name = obs.obs_property_list_item_string(extra_linked_list, i) -- get extra source by name
                dbg_inner(source_name)
                local extra_source = obs.obs_get_source_by_name(source_name)
                if extra_source ~= nil then
                    source_id = obs.obs_source_get_unversioned_id(extra_source)
                    if source_id == "text_gdiplus" or source_id == "text_ft2_source" then -- just another text object
                        local settings = obs.obs_data_create()
                        obs.obs_data_set_int(settings, "opacity", text_opacity) -- Set new text opacity to zero
                        obs.obs_data_set_int(settings, "outline_opacity", text_opacity) -- Set new text outline opacity to zero
                        obs.obs_source_update(extra_source, settings) -- merge new opacity values
                        obs.obs_data_release(settings)
                    else -- check for filter named "Color Correction"
                        local color_filter = obs.obs_source_get_filter_by_name(extra_source, "Color Correction")
                        if color_filter ~= nil then -- update filters opacity
                            local filter_settings = obs.obs_source_get_settings(color_filter)
                            obs.obs_data_set_double(filter_settings, "opacity", text_opacity / 100)
                            obs.obs_source_update(color_filter, filter_settings)
                            obs.obs_data_release(filter_settings)
                            obs.obs_source_release(color_filter)
                        else -- try to just change visibility in the scene
                            dbg_inner("No Filter")
                            local sceneSource = obs.obs_frontend_get_current_scene()
                            local sceneObj = obs.obs_scene_from_source(sceneSource)
                            local sceneItem = obs.obs_scene_find_source(sceneObj, source_name)
                            obs.obs_source_release(scene)
                            if text_opacity > 50 then
                                obs.obs_sceneitem_set_visible(sceneItem, true)
                            else
                                obs.obs_sceneitem_set_visible(sceneItem, false)
                            end
                        end
                    end
                end
                obs.obs_source_release(extra_source) -- release source ptr
            end
        end
    end
end

-- changes the visibility of the text; called EVERY time text is to be
-- hidden or made visible; not called during transition
function set_text_visibility(end_status)
    dbg_method("set_text_visibility")
    -- if already at desired visibility, then exit
    if text_status == end_status then
        return
    end
    if end_status == TEXT_HIDE then
        text_opacity = 0
        text_status = end_status
        apply_source_opacity()
        return
    elseif end_status == TEXT_SHOW then
        text_opacity = 100
        text_status = end_status
        all_sources_fade = true -- prevent orphaned title/static if link is removed when hidden
        apply_source_opacity()
        return
    end
    if text_fade_enabled then
        -- if fade enabled, begin fade in or out
        if end_status == TEXT_HIDDEN then
            text_status = TEXT_HIDING
        elseif end_status == TEXT_VISIBLE then
            text_status = TEXT_SHOWING
        end
        --all_sources_fade = true
        start_fade_timer()
    else -- change visibility immediately (fade or no fade)
        if end_status == TEXT_HIDDEN then
            text_opacity = 0
            text_status = end_status
        elseif end_status == TEXT_VISIBLE then
            text_opacity = 100
            text_status = end_status
            all_sources_fade = true -- prevent orphaned title/static if link is removed when hidden
        end
        apply_source_opacity()
        --update_source_text()
        all_sources_fade = false
        return
    end
end

-- transition to the next lyrics, use fade if enabled
-- if lyrics are hidden, force_show set to trued will make them visible
function transition_lyric_text(force_show)
    dbg_method("transition_lyric_text")
    dbg_bool("force show", force_show)
    -- update the lyrics display immediately on 2 conditions
    -- a) the text is hidden or hiding, and we will not force it to show
    -- b) text fade is not enabled
    -- otherwise, start text transition out and update the lyrics once
    -- fade out transition is complete
    if (text_status == TEXT_HIDDEN or text_status == TEXT_HIDING) and not force_show then
        update_source_text()
        -- if text is done hiding, we can cancel the all_sources_fade
        if text_status == TEXT_HIDDEN then
            all_sources_fade = false
        end
        dbg_inner("hidden")
    elseif not text_fade_enabled then
        dbg_custom("Instant On")
        -- if text fade is not enabled, then we can cancel the all_sources_fade
        all_sources_fade = false
        set_text_visibility(TEXT_VISIBLE) -- does update_source_text()
        update_source_text()
        dbg_inner("no text fade")
    else -- initiate fade out/in
        dbg_custom("Transition Timer")
        text_status = TEXT_TRANSITION_OUT
        start_fade_timer()
    end
    dbg_bool("using_source", using_source)
end

-- updates the selected lyrics
function update_source_text()
    dbg_method("update_source_text")
    dbg_custom("Page Index: " .. page_index)
    local text = ""
    local alttext = ""
    local next_lyric = ""
    local next_alternate = ""
    local static = static_text
    local mstatic = static -- save static for use with monitor
    local title = ""

    if alt_title ~= "" then
        title = alt_title
    else
        if not using_source then
            if prepared_index ~= nil and prepared_index ~= 0 then
                dbg_custom("Update from prepared: " .. prepared_index)
                title = prepared_songs[prepared_index]
            end
        else
            dbg_custom("Updatefrom source: " .. source_song_title)
            title = source_song_title
        end
    end

    local source = obs.obs_get_source_by_name(source_name)
    local alt_source = obs.obs_get_source_by_name(alternate_source_name)
    local stat_source = obs.obs_get_source_by_name(static_source_name)
    local title_source = obs.obs_get_source_by_name(title_source_name)

    if using_source or (prepared_index ~= nil and prepared_index ~= 0) then
        if #lyrics > 0 then
            if lyrics[page_index] ~= nil then
                text = lyrics[page_index]
            end
        end
        if #alternate > 0 then
            if alternate[page_index] ~= nil then
                alttext = alternate[page_index]
            end
        end

        if link_text then
            if string.len(text) == 0 and string.len(alttext) == 0 then
            --static = ""
            --title = ""
            end
        end
    end
    -- update source texts
    if source ~= nil then
        dbg_inner("Title Load")
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", text)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        next_lyric = lyrics[page_index + 1]
        if (next_lyric == nil) then
            next_lyric = ""
        end
        force_transform_change(source_name)
    end
    if alt_source ~= nil then
        local settings = obs.obs_data_create() -- setup TEXT settings with opacity values
        obs.obs_data_set_string(settings, "text", alttext)
        obs.obs_source_update(alt_source, settings)
        obs.obs_data_release(settings)
        next_alternate = alternate[page_index + 1]
        if (next_alternate == nil) then
            next_alternate = ""
        end
        force_transform_change(alternate_source_name)
    end
    if stat_source ~= nil then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", static)
        obs.obs_source_update(stat_source, settings)
        obs.obs_data_release(settings)
        force_transform_change(static_source_name)
    end
    if title_source ~= nil then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", title)
        obs.obs_source_update(title_source, settings)
        obs.obs_data_release(settings)
        force_transform_change(title_source_name)
    end
    -- release source references
    obs.obs_source_release(source)
    obs.obs_source_release(alt_source)
    obs.obs_source_release(stat_source)
    obs.obs_source_release(title_source)

    local next_prepared = ""
    if using_source then
        next_prepared = prepared_songs[prepared_index] -- plan to go to current prepared song
    elseif prepared_index ~= nil and prepared_index < #prepared_songs then
        next_prepared = prepared_songs[prepared_index + 1] -- plan to go to next prepared song
    else
        if source_active then
            next_prepared = source_song_title -- plan to go back to source loaded song
        else
            next_prepared = prepared_songs[1] -- plan to loop around to first prepared song
        end
    end
    mon_verse = 0
    if #verses ~= nil then --find valid page Index
        for i = 1, #verses do
            if page_index >= verses[i] + 1 then
                mon_verse = i
            end
        end -- v = current verse number for this page
    end
    mon_song = title
    mon_lyric = text:gsub("\n", "<br>&bull; ")
    mon_nextlyric = next_lyric:gsub("\n", "<br>&bull; ")
    mon_alt = alttext:gsub("\n", "<br>&bull; ")
    mon_nextalt = next_alternate:gsub("\n", "<br>&bull; ")
    mon_nextsong = next_prepared

    update_monitor()
end

-- starts the fade timer
function start_fade_timer()
    dbgsp("started fade timer")
    obs.timer_add(fade_callback, 50)
end

-- function is called by the fade timer to increment/decrement opacity value manually
function fade_callback()
    -- if not in a transitory state, exit callback
    if text_status == TEXT_HIDDEN or text_status == TEXT_VISIBLE then
        obs.remove_current_callback()
        all_sources_fade = false
    end
    -- the amount we want to change opacity by
    local opacity_delta = 1 + text_fade_speed
    -- change opacity in the direction of transitory state
    if text_status == TEXT_HIDING or text_status == TEXT_TRANSITION_OUT then
        local new_opacity = text_opacity - opacity_delta
        if new_opacity > 0 then
            text_opacity = new_opacity
        else
            -- completed fade out, determine next move
            text_opacity = 0
            if text_status == TEXT_TRANSITION_OUT then
                -- update to new lyric between fades
                update_source_text()
                -- begin transition back in
                text_status = TEXT_TRANSITION_IN
            else
                text_status = TEXT_HIDDEN
            end
        end
    elseif text_status == TEXT_SHOWING or text_status == TEXT_TRANSITION_IN then
        local new_opacity = text_opacity + opacity_delta
        if new_opacity < 100 then
            text_opacity = new_opacity
        else
            -- completed fade in
            text_opacity = 100
            text_status = TEXT_VISIBLE
        end
    end
    -- apply the new opacity
    apply_source_opacity()
end

function prepare_song_by_index(index)
    dbg_method("prepare_song_by_index")
    if index <= #prepared_songs then
        prepare_song_by_name(prepared_songs[index])
    end
end

-- prepares lyrics of the song
function prepare_song_by_name(name)
    dbg_method("prepare_song_by_name")
    if name == nil then
        return false
    end
    last_prepared_song = name
    -- if using transition on lyric change, first transition
    -- would be reset with new song prepared
    transition_completed = false
    -- load song lines
    local song_lines = get_song_text(name)
    if song_lines == nil then
        return false
    end
    local cur_line = 1
    local cur_aline = 1
    local recordRefrain = false
    local playRefrain = false
    local use_alternate = false
    local use_static = false
    local showText = true
    local commentBlock = false
    local singleAlternate = false
    local refrain = {}
    local arefrain = {}
    lyrics = {}
    verses = {}
    alternate = {}
    static_text = ""
    alt_title = ""
    local adjusted_display_lines = display_lines
    local refrain_display_lines = display_lines
    local alternate_display_lines = display_lines
    local displaySize = display_lines
    for _, line in ipairs(song_lines) do
        local new_lines = 1
        local single_line = false
        local comment_index = line:find("//%[") -- Look for comment block Set
        if comment_index ~= nil then
            commentBlock = true
            line = line:sub(comment_index + 3)
        end
        comment_index = line:find("//]") -- Look for comment block Clear
        if comment_index ~= nil then
            commentBlock = false
            line = line:sub(1, comment_index - 1)
            new_lines = 0
        end
        if not commentBlock then
            local comment_index = line:find("%s*//")
            if comment_index ~= nil then
                line = line:sub(1, comment_index - 1)
                new_lines = 0
            end
            local alternate_index = line:find("#A%[")
            if alternate_index ~= nil then
                use_alternate = true
                line = line:sub(1, alternate_index - 1)
                new_lines = 0
            end
            alternate_index = line:find("#A]")
            if alternate_index ~= nil then
                use_alternate = false
                line = line:sub(1, alternate_index - 1)
                new_lines = 0
            end
            local static_index = line:find("#S%[")
            if static_index ~= nil then
                use_static = true
                line = line:sub(1, static_index - 1)
                new_lines = 0
            end
            static_index = line:find("#S]")
            if static_index ~= nil then
                use_static = false
                line = line:sub(1, static_index - 1)
                new_lines = 0
            end

            local newcount_index = line:find("#L:")
            if newcount_index ~= nil then
                local iS, iE = line:find("%d+", newcount_index + 3)
                local newLines = tonumber(line:sub(iS, iE))
                if use_alternate then
                    alternate_display_lines = newLines
                elseif recordRefrain then
                    refrain_display_lines = newLines
                else
                    adjusted_display_lines = newLines
                    refrain_display_lines = newLines
                    alternate_display_lines = newLines
                end
                line = line:sub(1, newcount_index - 1)
                new_lines = 0 -- ignore line
            end
            local static_index = line:find("#S:")
            if static_index ~= nil then
                line = line:sub(static_index + 3)
                static_text = line
                new_lines = 0
            end
            local title_index = line:find("#T:")
            if title_index ~= nil then
                local title_indexEnd = line:find("%s+", title_index + 1)
                line = line:sub(title_indexEnd + 1)
                alt_title = line
                new_lines = 0
            end
            local alt_index = line:find("#A:")
            if alt_index ~= nil then
                local alt_indexStart, alt_indexEnd = line:find("%d+", alt_index + 3)
                new_lines = tonumber(line:sub(alt_indexStart, alt_indexEnd))
                local alt_indexEnd = line:find("%s+", alt_indexEnd + 1)
                line = line:sub(alt_indexEnd + 1)
                singleAlternate = true
            end
            if line:find("###") ~= nil then -- Look for single line
                line = line:gsub("%s*###%s*", "")
                single_line = true
            end
            local newcount_index = line:find("#D:")
            if newcount_index ~= nil then
                local newcount_indexStart, newcount_indexEnd = line:find("%d+", newcount_index + 3)
                new_lines = tonumber(line:sub(newcount_indexStart, newcount_indexEnd))
                _, newcount_indexEnd = line:find("%s+", newcount_indexEnd + 1)
                line = line:sub(newcount_indexEnd + 1)
            end
            local refrain_index = line:find("#R%[")
            if refrain_index ~= nil then
                if next(refrain) ~= nil then
                    for i, _ in ipairs(refrain) do
                        refrain[i] = nil
                    end
                end
                recordRefrain = true
                showText = true
                line = line:sub(1, refrain_index - 1)
                new_lines = 0
            end
            refrain_index = line:find("#r%[")
            if refrain_index ~= nil then
                if next(refrain) ~= nil then
                    for i, _ in ipairs(refrain) do
                        refrain[i] = nil
                    end
                end
                recordRefrain = true
                showText = false
                line = line:sub(1, refrain_index - 1)
                new_lines = 0
            end
            refrain_index = line:find("#R]")
            if refrain_index ~= nil then
                recordRefrain = false
                showText = true
                line = line:sub(1, refrain_index - 1)
                new_lines = 0
            end
            refrain_index = line:find("#r]")
            if refrain_index ~= nil then
                recordRefrain = false
                showText = true
                line = line:sub(1, refrain_index - 1)
                new_lines = 0
            end

            refrain_index = line:find("##R")
            if refrain_index == nil then
                refrain_index = line:find("##r")
            end
            if refrain_index ~= nil then
                playRefrain = true
                line = line:sub(1, refrain_index - 1)
                new_lines = 0
            else
                playRefrain = false
            end
            newcount_index = line:find("#P:")
            if newcount_index ~= nil then
                new_lines = tonumber(line:sub(newcount_index + 3))
                line = line:sub(1, newcount_index - 1)
            end
            newcount_index = line:find("#B:")
            if newcount_index ~= nil then
                new_lines = tonumber(line:sub(newcount_index + 3))
                line = line:sub(1, newcount_index - 1)
            end
            local phantom_index = line:find("##P")
            if phantom_index ~= nil then
                line = line:sub(1, phantom_index - 1)
            end
            phantom_index = line:find("##B")
            if phantom_index ~= nil then
                line = line:gsub("%s*##B%s*", "") .. "\n"
            end
            local verse_index = line:find("##V")
            if verse_index ~= nil then
                line = line:sub(1, verse_index - 1)
                new_lines = 0
                verses[#verses + 1] = #lyrics
                dbg_inner("Verse: " .. #lyrics)
            end
            if line ~= nil then
                if use_static then
                    if static_text == "" then
                        static_text = line
                    else
                        static_text = static_text .. "\n" .. line
                    end
                else
                    if use_alternate or singleAlternate then
                        if recordRefrain then
                            displaySize = refrain_display_lines
                        else
                            displaySize = alternate_display_lines
                        end
                        if new_lines > 0 then
                            while (new_lines > 0) do
                                if recordRefrain then
                                    if (cur_line == 1) then
                                        arefrain[#refrain + 1] = line
                                    else
                                        arefrain[#refrain] = arefrain[#refrain] .. "\n" .. line
                                    end
                                end
                                if showText and line ~= nil then
                                    if (cur_aline == 1) then
                                        alternate[#alternate + 1] = line
                                    else
                                        alternate[#alternate] = alternate[#alternate] .. "\n" .. line
                                    end
                                end
                                cur_aline = cur_aline + 1
                                if single_line or singleAlternate or cur_aline > displaySize then
                                    if ensure_lines then
                                        for i = cur_aline, displaySize, 1 do
                                            cur_aline = i
                                            if showText and alternate[#alternate] ~= nil then
                                                alternate[#alternate] = alternate[#alternate] .. "\n"
                                            end
                                            if recordRefrain then
                                                arefrain[#refrain] = arefrain[#refrain] .. "\n"
                                            end
                                        end
                                    end
                                    cur_aline = 1
                                end
                                new_lines = new_lines - 1
                            end
                        end
                        if playRefrain == true and not recordRefrain then -- no recursive call of Refrain within Refrain Record
                            for _, refrain_line in ipairs(arefrain) do
                                alternate[#alternate + 1] = refrain_line
                            end
                        end
                        singleAlternate = false
                    else
                        if recordRefrain then
                            displaySize = refrain_display_lines
                        else
                            displaySize = adjusted_display_lines
                        end
                        if new_lines > 0 then
                            while (new_lines > 0) do
                                if recordRefrain then
                                    if (cur_line == 1) then
                                        refrain[#refrain + 1] = line
                                    else
                                        refrain[#refrain] = refrain[#refrain] .. "\n" .. line
                                    end
                                end
                                if showText and line ~= nil then
                                    if (cur_line == 1) then
                                        lyrics[#lyrics + 1] = line
                                    else
                                        lyrics[#lyrics] = lyrics[#lyrics] .. "\n" .. line
                                    end
                                end
                                cur_line = cur_line + 1
                                if single_line or cur_line > displaySize then
                                    if ensure_lines then
                                        for i = cur_line, displaySize, 1 do
                                            cur_line = i
                                            if showText and lyrics[#lyrics] ~= nil then
                                                lyrics[#lyrics] = lyrics[#lyrics] .. "\n"
                                            end
                                            if recordRefrain then
                                                refrain[#refrain] = refrain[#refrain] .. "\n"
                                            end
                                        end
                                    end
                                    cur_line = 1
                                end
                                new_lines = new_lines - 1
                            end
                        end
                    end
                    if playRefrain == true and not recordRefrain then -- no recursive call of Refrain within Refrain Record
                        for _, refrain_line in ipairs(refrain) do
                            lyrics[#lyrics + 1] = refrain_line
                        end
                    end
                end
            end
        end
    end
    if ensure_lines and lyrics[#lyrics] ~= nil and cur_line > 1 then
        for i = cur_line, displaySize, 1 do
            cur_line = i
            if use_alternate then
                if showText and alternate[#alternate] ~= nil then
                    alternate[#alternate] = alternate[#alternate] .. "\n"
                end
            else
                if showText and lyrics[#lyrics] ~= nil then
                    lyrics[#lyrics] = lyrics[#lyrics] .. "\n"
                end
            end
            if recordRefrain then
                refrain[#refrain] = refrain[#refrain] .. "\n"
            end
        end
    end
    lyrics[#lyrics + 1] = ""
    -- pause_timer = false
    return true
end

-- finds the index of a song in the directory
-- if item is not in list, then return nil
function get_index_in_list(list, q_item)
    for index, item in ipairs(list) do
        if item == q_item then
            return index
        end
    end
    return nil
end

--------
----------------
------------------------ FILE FUNCTIONS
----------------
--------

-- delete previewed song
function delete_song(name)
    if testValid(name) then
        path = get_song_file_path(name, ".txt")
    else
        path = get_song_file_path(enc(name), ".enc")
    end
    os.remove(path)
    table.remove(song_directory, get_index_in_list(song_directory, name))
    source_filter = false
    load_source_song_directory(false)
end

-- loads the song directory
function load_source_song_directory(use_filter)
    dbg_method("load_source_song_directory")
    local keytext = meta_tags
    if source_filter then
        keytext = source_meta_tags
    end
    dbg_inner(keytext)
    local keys = ParseCSVLine(keytext)

    song_directory = {}
    local filenames = {}
    local tags = {}
    local dir = obs.os_opendir(get_songs_folder_path())
    -- get_songs_folder_path())
    local entry
    local songExt
    local songTitle
    local goodEntry = true

    repeat
        entry = obs.os_readdir(dir)
        if
            entry and not entry.directory and
                (obs.os_get_path_extension(entry.d_name) == ".enc" or obs.os_get_path_extension(entry.d_name) == ".txt")
         then
            songExt = obs.os_get_path_extension(entry.d_name)
            songTitle = string.sub(entry.d_name, 0, string.len(entry.d_name) - string.len(songExt))
            tags = readTags(songTitle)
            goodEntry = true
            if use_filter and #keys > 0 then -- need to check files
                for k = 1, #keys do
                    if keys[k] == "*" then
                        goodEntry = true -- okay to show untagged files
                        break
                    end
                end
                goodEntry = false -- start assuming file will not be shown
                if #tags == 0 then -- check no tagged option
                    for k = 1, #keys do
                        if keys[k] == "*" then
                            goodEntry = true -- okay to show untagged files
                            break
                        end
                    end
                else -- have keys and tags so compare them
                    for k = 1, #keys do
                        for t = 1, #tags do
                            if tags[t] == keys[k] then
                                goodEntry = true -- found match so show file
                                break
                            end
                        end
                        if goodEntry then -- stop outer key loop on match
                            break
                        end
                    end
                end
            end
            if goodEntry then -- add file if valid match
                if songExt == ".enc" then
                    song_directory[#song_directory + 1] = dec(songTitle)
                else
                    song_directory[#song_directory + 1] = songTitle
                end
            end
        end
    until not entry
    obs.os_closedir(dir)
end
--
-- reads the first line of each lyric file, looks for the //meta comment and returns any CSV tags that exist
--
function readTags(name)
    local meta = ""
    local path = {}
    if testValid(name) then
        path = get_song_file_path(name, ".txt")
    else
        path = get_song_file_path(enc(name), ".enc")
    end
    local file = io.open(path, "r")
    if file ~= nil then
        for line in file:lines() do
            meta = line
            break
        end
        file:close()
    end
    local meta_index = meta:find("//meta ") -- Look for meta block Set
    if meta_index ~= nil then
        meta = meta:sub(meta_index + 7)
        return ParseCSVLine(meta)
    end
    return {}
end

function ParseCSVLine(line)
    local res = {}
    local pos = 1
    sep = ","
    while true do
        local c = string.sub(line, pos, pos)
        if (c == "") then
            break
        end
        if (c == '"') then
            local txt = ""
            repeat
                local startp, endp = string.find(line, '^%b""', pos)
                txt = txt .. string.sub(line, startp + 1, endp - 1)
                pos = endp + 1
                c = string.sub(line, pos, pos)
                if (c == '"') then
                    txt = txt .. '"'
                end
            until (c ~= '"')
            txt = string.gsub(txt, "^%s*(.-)%s*$", "%1")
            dbg_inner("CSV: " .. txt)
            table.insert(res, txt)
            assert(c == sep or c == "")
            pos = pos + 1
        else
            local startp, endp = string.find(line, sep, pos)
            if (startp) then
                local t = string.sub(line, pos, startp - 1)
                t = string.gsub(t, "^%s*(.-)%s*$", "%1")
                dbg_inner("CSV: " .. t)
                table.insert(res, t)
                pos = endp + 1
            else
                local t = string.sub(line, pos)
                t = string.gsub(t, "^%s*(.-)%s*$", "%1")
                dbg_inner("CSV: " .. t)
                table.insert(res, t)
                break
            end
        end
    end
    return res
end

local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-" -- encoding alphabet

-- encode title/filename if it contains invalid filename characters
-- Note: User should use valid filenames to prevent encoding and the override the title with '#t: title' in markup
--
function enc(data)
    return ((data:gsub(
        ".",
        function(x)
            local r, b = "", x:byte()
            for i = 8, 1, -1 do
                r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0")
            end
            return r
        end
    ) .. "0000"):gsub(
        "%d%d%d?%d?%d?%d?",
        function(x)
            if (#x < 6) then
                return ""
            end
            local c = 0
            for i = 1, 6 do
                c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0)
            end
            return b:sub(c + 1, c + 1)
        end
    ) .. ({"", "==", "="})[#data % 3 + 1])
end
-- 
-- decode an encoded title/filename
--
function dec(data)
    data = string.gsub(data, "[^" .. b .. "=]", "")
    return (data:gsub(
        ".",
        function(x)
            if (x == "=") then
                return ""
            end
            local r, f = "", (b:find(x) - 1)
            for i = 6, 1, -1 do
                r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
            end
            return r
        end
    ):gsub(
        "%d%d%d?%d?%d?%d?%d?%d?",
        function(x)
            if (#x ~= 8) then
                return ""
            end
            local c = 0
            for i = 1, 8 do
                c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
            end
            return string.char(c)
        end
    ))
end

-- checks to see if {filename} is a valid name for a file
function testValid(filename)
    if string.find(filename, "[\128-\255]") ~= nil then
        return false
    end
    if string.find(filename, '[\\\\/:*?"<>|]') ~= nil then
        return false
    end
    return true
end

-- saves previewed song, return true if new song
function save_song(name, text)
    local path = {}
    if testValid(name) then
        path = get_song_file_path(name, ".txt")
    else
        path = get_song_file_path(enc(name), ".enc")
    end
    local file = io.open(path, "w")
    if file ~= nil then
        for line in text:gmatch("([^\n]+)") do
            local trimmed = line:match("%s*(%S-.*%S+)%s*")
            if trimmed ~= nil then
                file:write(trimmed, "\n")
            end
        end
        file:close()
        if get_index_in_list(song_directory, name) == nil then
            song_directory[#song_directory + 1] = name
            return true
        end
    end
    return false
end

-- updates the HTML monitor file with current status information
function update_monitor()
    dbg_method("update_monitor")
    local tableback = "black"
    local text = ""
    text = text .. "<!DOCTYPE html><html>"
    text = text .. "<head>"
    text = text .. "<meta http-equiv='cache-control' content='no-cache, must-revalidate, post-check=0, pre-check=0' />"
    text = text .. "<meta http-equiv='cache-control' content='max-age=0' />"
    text = text .. "<meta http-equiv='expires' content='0' />"
    text = text .. "<meta http-equiv='expires' content='Tue, 01 Jan 1980 1:00:00 GMT' />"
    text = text .. "<meta http-equiv='pragma' content='no-cache' />"
    text = text .. "<meta http-equiv='refresh' content='1'>"
    text = text .. "</head>"
    text =
        text ..
        "<body style='background-color:black;'><hr style = 'background-color: #98AFC7; height:2px; border:0px; margin: 0px;'>"
    text =
        text ..
        "<div style = 'background-color:#332222;'><div style = 'color: #B0E0E6; float: left; ; margin: 2px; margin-right: 20px; '>"
    if using_source then
        text = text .. "From Source: <B style='color: #FFEF00;'>" .. load_scene .. "</B></div>"
    else
		local indexText = "N/A"
		if prepared_index ~= nil then
			indexText = prepared_index
		end
        text = text .. "Prepared Song: <B style='color: #FFEF00;'>" .. indexText
        text =
            text ..
            "</B><B style='color: #B0E0E6;'> of </B><B style='color: #FFEF00;'>" .. #prepared_songs .. "</B></div>"
    end
    text =
        text ..
        "<div style = 'color: #B0E0E6; float: left; margin: 2px; margin-right: 20px; '>Lyric Page: <B style='color: #FFEF00;'>" ..
            page_index
    text = text .. "</B><B style='color: #B0E0E6;'> of </B><B style='color: #FFEF00;'>" .. #lyrics .. "</B></div>"
    if #verses ~= nil and mon_verse > 0 then
        text =
            text ..
            "<div style = 'color: #B0E0E6; float: left; margin: 2px; '>Verse: <B style='color: #FFEF00;'>" .. mon_verse
        text = text .. "</B><B style='color: #B0E0E6;'> of </B><B style='color: #FFEF00;'>" .. #verses .. "</B></div>"
    end
    text = text .. "<div style = 'color: #B0E0E6; float: left;  margin: 2px; '>"
    if not anythingActive() then
        tableback = "#440000"
    end
    local visbgTitle = tableback
    local visbgText = tableback
    if text_status == TEXT_HIDDEN or text_status == TEXT_HIDING then
        visbgText = "maroon"
        if link_text then
            visbgTitle = "maroon"
        end
    end

    text =
        text ..
        "</div><table bgcolor=" ..
            tableback .. " cellpadding='3' cellspacing='3' width=100% style = 'border-collapse: collapse;'>"
    if mon_song ~= "" and mon_song ~= nil then
        text =
            text ..
            "<tr style='border-bottom: 1px solid #ccc; border-top: 1px solid #ccc; border-color: #98AFC7;'><td bgcolor=#262626 style='border-right: 1px solid #ccc; border-color: #98AFC7; color: White; width: 50px; text-align: center;'>Song<br>Title</td>"
        text =
            text ..
            "<td bgcolor= '" .. visbgTitle .. "' style='color: White;'><Strong>" .. mon_song .. "</strong></td></tr>"
    end
    if mon_lyric ~= "" and mon_lyric ~= nil then
        text =
            text ..
            "<tr style='border-bottom: 1px solid #ccc; border-color: #98AFC7;'><td bgcolor=#262626 style='border-right: 1px solid #ccc; border-color: #98AFC7; color: PaleGreen;  text-align: center;'>Current<br>Page</td>"
        text =
            text .. "<td bgcolor= '" .. visbgText .. "' style='color: palegreen;'> &bull; " .. mon_lyric .. "</td></tr>"
    end
    if mon_nextlyric ~= "" and mon_nextlyric ~= nil then
        text =
            text ..
            "<tr style='border-bottom: 1px solid #ccc; border-color: #98AFC7;'><td bgcolor=#262626 style='border-right: 1px solid #ccc; border-color: #98AFC7; color: Lavender;  text-align: center;'>Next<br>Page</td>"
        text = text .. "<td  style='color: Lavender;'> &bull; " .. mon_nextlyric .. "</td></tr>"
    end
    if mon_alt ~= "" and mon_alt ~= nil then
        text =
            text ..
            "<tr style='border-bottom: 1px solid #ccc; border-color: #98AFC7;'><td bgcolor=#262626 style='border-right: 1px solid #ccc; border-color: #98AFC7; color: SpringGreen; text-align: center;'>Alt<br>Lyric</td>"
        text =
            text ..
            "<td bgcolor= '" .. visbgText .. "' style='color: SpringGreen; ;'> &bull; " .. mon_alt .. "</td></tr>"
    end
    if mon_nextalt ~= "" and mon_nextalt ~= nil then
        text =
            text ..
            "<tr style='border-bottom: 1px solid #ccc; border-color: #98AFC7;'><td bgcolor=#262626 style='border-right: 1px solid #ccc; border-color: #98AFC7; color: Plum; text-align: center;'>Next<br>Alt</td>"
        text = text .. "<td style='color: Plum;'> &bull; " .. mon_nextalt .. "</td></tr>"
    end
    if mon_nextsong ~= "" and mon_nextsong ~= nil then
        text =
            text ..
            "<tr style='border-bottom: 2px solid #ccc; border-color: #98AFC7;' ><td bgcolor=#262626 style='border-right: 1px solid #ccc; border-color: #98AFC7; color: Gold; text-align: center;'>Next<br>Song:</td>"
        text = text .. "<td style='color: Gold;'>" .. mon_nextsong .. "</td></tr>"
    end
    text = text .. "</table></body></html>"
    local file = io.open(get_songs_folder_path() .. "/" .. "Monitor.htm", "w")
    dbg_inner("write monitor file")
    file:write(text)
    file:close()
    return true
end

-- returns path of the given song name
function get_song_file_path(name, suffix)
    if name == nil then
        return nil
    end
    return get_songs_folder_path() .. "\\" .. name .. suffix
end

-- returns path of the lyrics songs folder
function get_songs_folder_path()
    local sep = package.config:sub(1, 1)
    local path = ""
    if windows_os then
        path = os.getenv("USERPROFILE")
    else
        path = os.getenv("HOME")
    end
    return path .. sep .. ".config" .. sep .. ".obs_lyrics"
end

-- gets the text of a song
function get_song_text(name)
    local song_lines = {}
    local path = {}
    if testValid(name) then
        path = get_song_file_path(name, ".txt")
    else
        path = get_song_file_path(enc(name), ".enc")
    end
    local file = io.open(path, "r")
    if file ~= nil then
        for line in file:lines() do
            song_lines[#song_lines + 1] = line
        end
        file:close()
    else
        return nil
    end

    return song_lines
end

-- ------
----------------
------------------------ OBS DEFAULT FUNCTIONS
-- --------------
--------

local help =
    "▪▪▪▪▪ MARKUP SYNTAX HELP ▪▪▪▪▪▲- CLICK TO CLOSE -▲▪▪▪▪▪\n\n" ..
    " Markup      Syntax          Markup      Syntax \n" ..
        "============ ==========   ============ ==========\n" ..
            " Display n Lines    #L:n      End Page after Line   Line ###\n" ..
                "  Blank (Pad) Line  ##B or ##P     Blank(Pad) Lines   #B:n or #P:n\n" ..
                    " External Refrain   #r[ and #r]      In-Line Refrain     #R[ and #R]\n" ..
                        " Repeat Refrain   ##r or ##R    Duplicate Line n times   #D:n Line\n" ..
                            " Static Lines    #S[ and #s]      Single Static Line      #S: Line \n" ..
                                "Alternate Text    #A[ and #A]    Alt Line Repeat n Pages  #A:n Line \n" ..
                                    "Comment Line     // Line       Block Comments     //[ and //] \n" ..
                                        "Mark Verses     ##V        Override Title     #T: text\n\n" ..
                                            "Optional comma delimited meta tags follow '//meta ' on 1st line"
											
-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
    dbg_method("script_properties")
    editVisSet = false
    script_props = obs.obs_properties_create()
    obs.obs_properties_add_button(script_props, "expand_all_button", "▲- HIDE ALL GROUPS -▲", expand_all_groups)
    -----------
    obs.obs_properties_add_button(script_props, "info_showing", "▲- HIDE SONG INFORMATION -▲", change_info_visible)
    local gp = obs.obs_properties_create()
    obs.obs_properties_add_text(gp, "prop_edit_song_title", "Song Title (Filename)", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_button(gp, "show_help_button", "SHOW MARKUP SYNTAX HELP", show_help_button)
    obs.obs_properties_add_text(gp, "prop_edit_song_text", "\tSong Lyrics", obs.OBS_TEXT_MULTILINE)
    obs.obs_properties_add_button(gp, "prop_save_button", "Save Song", save_song_clicked)
    obs.obs_properties_add_button(gp, "prop_delete_button", "Delete Song", delete_song_clicked)
    obs.obs_properties_add_button(gp, "prop_opensong_button", "Edit Song with System Editor", open_song_clicked)
    obs.obs_properties_add_button(gp, "prop_open_button", "Open Songs Folder", open_button_clicked)
    obs.obs_properties_add_group(
        script_props,
        "info_grp",
        "Song Title (filename) and Lyrics Information",
        obs.OBS_GROUP_NORMAL,
        gp
    )
    ------------
    obs.obs_properties_add_button(
        script_props,
        "prepared_showing",
        "▲- HIDE PREPARED SONGS -▲",
        change_prepared_visible
    )
    gp = obs.obs_properties_create()
    local prop_dir_list =
        obs.obs_properties_add_list(
        gp,
        "prop_directory_list",
        "Song Directory",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    table.sort(song_directory)
    for _, name in ipairs(song_directory) do
        obs.obs_property_list_add_string(prop_dir_list, name, name)
    end
    obs.obs_property_set_modified_callback(prop_dir_list, preview_selection_made)
    obs.obs_properties_add_button(gp, "prop_prepare_button", "Prepare Selected Song/Text", prepare_song_clicked)
    obs.obs_properties_add_button(gp, "filter_songs_button", "Filter Titles by Meta Tags", filter_songs_clicked)
    local gps = obs.obs_properties_create()
    obs.obs_properties_add_text(gps, "prop_edit_metatags", "Filter MetaTags", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_button(gps, "dir_refresh", "Refresh Directory", refresh_directory_button_clicked)
    local meta_group_prop = obs.obs_properties_add_group(gp, "meta", " Filter Songs/Text", obs.OBS_GROUP_NORMAL, gps)
    gps = obs.obs_properties_create()
    local prepare_prop =
        obs.obs_properties_add_list(
        gps,
        "prop_prepared_list",
        "Prepared Songs",
        obs.OBS_COMBO_TYPE_EDITABLE,
        obs.OBS_COMBO_FORMAT_STRING
    )
    for _, name in ipairs(prepared_songs) do
        obs.obs_property_list_add_string(prepare_prop, name, name)
    end
    obs.obs_property_set_modified_callback(prepare_prop, prepare_selection_made)
    obs.obs_properties_add_button(gps, "prop_clear_button", "Clear All Prepared Songs/Text", clear_prepared_clicked)
    obs.obs_properties_add_button(gps, "prop_manage_button", "Edit Prepared List", edit_prepared_clicked)
    local eps = obs.obs_properties_create()
    local edit_prop =
        obs.obs_properties_add_editable_list(
        eps,
        "prep_list",
        "Prepared Songs/Text",
        obs.OBS_EDITABLE_LIST_TYPE_STRINGS,
        nil,
        nil
    )
    obs.obs_property_set_modified_callback(edit_prop, setEditVis)
    obs.obs_properties_add_button(eps, "prop_save_button", "Save Changes", save_edits_clicked)
    local edit_group_prop =
        obs.obs_properties_add_group(
        gps,
        "edit_grp",
        "Edit Prepared Songs - Manually entered Titles (Filenames) must be in directory",
        obs.OBS_GROUP_NORMAL,
        eps
    )
	local saveExtProp = obs.obs_properties_add_bool(eps, "saveExternal", "Use external Prepared.dat file ")
		    obs.obs_property_set_modified_callback(saveExtProp, reLoadPrepared)
    obs.obs_properties_add_group(gp, "prep_grp", "  Prepared Songs", obs.OBS_GROUP_NORMAL, gps)
    obs.obs_properties_add_group(script_props, "mng_grp", "Manage Prepared Songs/Text", obs.OBS_GROUP_NORMAL, gp)
    ------------------
    obs.obs_properties_add_button(script_props, "ctrl_showing", "▲- HIDE LYRIC CONTROLS -▲", change_ctrl_visible)
    hotkey_props = obs.obs_properties_create()
    local hktitletext = obs.obs_properties_add_text(hotkey_props, "hotkey-title", "\t", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_button(hotkey_props, "prop_prev_button", "Previous Lyric", prev_button_clicked)
    obs.obs_properties_add_button(hotkey_props, "prop_next_button", "Next Lyric", next_button_clicked)
    obs.obs_properties_add_button(hotkey_props, "prop_hide_button", "Show/Hide Lyrics", toggle_button_clicked)
    obs.obs_properties_add_button(hotkey_props, "prop_home_button", "Reset to Song Start", home_button_clicked)
    obs.obs_properties_add_button(hotkey_props, "prop_prev_prep_button", "Previous Prepared", prev_prepared_clicked)
    obs.obs_properties_add_button(hotkey_props, "prop_next_prep_button", "Next Prepared", next_prepared_clicked)
    obs.obs_properties_add_button(
        hotkey_props,
        "prop_reset_button",
        "Reset to First Prepared Song",
        reset_button_clicked
    )
    ctrl_grp_prop =
        obs.obs_properties_add_group(
        script_props,
        "ctrl_grp",
        "Lyric Control Buttons (with Assigned HotKeys)",
        obs.OBS_GROUP_NORMAL,
        hotkey_props
    )
    obs.obs_property_set_modified_callback(ctrl_grp_prop, name_hotkeys)
    ------
    obs.obs_properties_add_button(script_props, "options_showing", "▲- HIDE DISPLAY OPTIONS -▲", change_options_visible)
    gp = obs.obs_properties_create()
    local lines_prop = obs.obs_properties_add_int_slider(gp, "prop_lines_counter", "\tLines to Display", 1, 50, 1)
    obs.obs_property_set_long_description(
        lines_prop,
        "Sets default lines per page of lyric, overwritten by Markup: #L:n"
    )
    local prop_lines = obs.obs_properties_add_bool(gp, "prop_lines_bool", "Strictly ensure number of lines")
    obs.obs_property_set_long_description(prop_lines, "Guarantees fixed number of lines per page")
    local link_prop = obs.obs_properties_add_bool(gp, "do_link_text", "Show/Hide All Sources with Lyric Text")
    obs.obs_property_set_long_description(link_prop, "Hides title and static text at end of lyrics")
    local transition_prop =
        obs.obs_properties_add_bool(gp, "transition_enabled", "Transition Preview to Program on lyric change")
    obs.obs_property_set_modified_callback(transition_prop, change_transition_property)
    obs.obs_property_set_long_description(
        transition_prop,
        "Use with Studio Mode, duplicate sources, and OBS source transitions"
    )
    local fade_prop = obs.obs_properties_add_bool(gp, "text_fade_enabled", "Enable text fade") -- Fade Enable (WZ)
    obs.obs_property_set_modified_callback(fade_prop, change_fade_property)
    obs.obs_properties_add_int_slider(gp, "text_fade_speed", "\tFade Speed", 1, 10, 1)
    obs.obs_properties_add_group(script_props, "disp_grp", "Display Options", obs.OBS_GROUP_NORMAL, gp)
    -------------
    obs.obs_properties_add_button(script_props, "src_showing", "▲- HIDE SOURCE TEXT SELECTIONS -▲", change_src_visible)
    gp = obs.obs_properties_create()
    obs.obs_properties_add_button(gp, "prop_refresh", "Refresh All Sources", refresh_button_clicked)
    local source_prop =
        obs.obs_properties_add_list(
        gp,
        "prop_source_list",
        "Text Source",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    local title_source_prop =
        obs.obs_properties_add_list(
        gp,
        "prop_title_list",
        "Title Source",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    local alternate_source_prop =
        obs.obs_properties_add_list(
        gp,
        "prop_alternate_list",
        "Alternate Source",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    local static_source_prop =
        obs.obs_properties_add_list(
        gp,
        "prop_static_list",
        "Static Source",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    obs.obs_properties_add_button(gp, "do_link_button", "Add Additional Linked Sources", do_linked_clicked)
    xgp = obs.obs_properties_create()
    obs.obs_properties_add_bool(xgp, "link_extra_with_text", "Show/Hide Sources with Lyrics Text")
    local extra_linked_prop =
        obs.obs_properties_add_list(
        xgp,
        "extra_linked_list",
        "Linked Sources      ",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    -- initialize previously loaded extra properties from table
    for _, sourceName in ipairs(extra_sources) do
        obs.obs_property_list_add_string(extra_linked_prop, sourceName, sourceName)
    end
    local extra_source_prop =
        obs.obs_properties_add_list(
        xgp,
        "extra_source_list",
        "  Select Source:",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    obs.obs_property_set_modified_callback(extra_source_prop, link_source_selected)
    local clearcall_prop =
        obs.obs_properties_add_button(xgp, "linked_clear_button", "Clear Linked Sources", clear_linked_clicked)
    local extra_group_prop =
        obs.obs_properties_add_group(gp, "xtr_grp", "Additional Visibility Linked Sources ", obs.OBS_GROUP_NORMAL, xgp)
    obs.obs_properties_add_group(script_props, "src_grp", "Text Sources in Scenes", obs.OBS_GROUP_NORMAL, gp)
    local count = obs.obs_property_list_item_count(extra_linked_prop)
    if count > 0 then
        obs.obs_property_set_description(extra_linked_prop, "Linked Sources (" .. count .. ")")
    else
        obs.obs_property_set_visible(extra_group_prop, false)
    end

    local sources = obs.obs_enum_sources()
    obs.obs_property_list_add_string(extra_source_prop, "List of Valid Sources", "")
    if sources ~= nil then
        local n = {}
        for _, source in ipairs(sources) do
            local name = obs.obs_source_get_name(source)
            if isValid(source) then
                obs.obs_property_list_add_string(extra_source_prop, name, name) -- add source to extra list
            end
            source_id = obs.obs_source_get_unversioned_id(source)
            if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
                n[#n + 1] = name
            end
        end
        table.sort(n)
        obs.obs_property_list_add_string(source_prop, "", "")
        obs.obs_property_list_add_string(title_source_prop, "", "")
        obs.obs_property_list_add_string(alternate_source_prop, "", "")
        obs.obs_property_list_add_string(static_source_prop, "", "")
        for _, name in ipairs(n) do
            obs.obs_property_list_add_string(source_prop, name, name)
            obs.obs_property_list_add_string(title_source_prop, name, name)
            obs.obs_property_list_add_string(alternate_source_prop, name, name)
            obs.obs_property_list_add_string(static_source_prop, name, name)
        end
    end
    obs.source_list_release(sources)

    -----------------
    obs.obs_property_set_enabled(hktitletext, false)
    obs.obs_property_set_visible(edit_group_prop, false)
    obs.obs_property_set_visible(meta_group_prop, false)
    return script_props
end

-- script_update is called when settings are changed
function script_update(settings)
    text_fade_enabled = obs.obs_data_get_bool(settings, "text_fade_enabled")
    text_fade_speed = obs.obs_data_get_int(settings, "text_fade_speed")
    display_lines = obs.obs_data_get_int(settings, "prop_lines_counter")
    source_name = obs.obs_data_get_string(settings, "prop_source_list")
    alternate_source_name = obs.obs_data_get_string(settings, "prop_alternate_list")
    static_source_name = obs.obs_data_get_string(settings, "prop_static_list")
    title_source_name = obs.obs_data_get_string(settings, "prop_title_list")
    ensure_lines = obs.obs_data_get_bool(settings, "prop_lines_bool")
    link_text = obs.obs_data_get_bool(settings, "do_link_text")
    link_extras = obs.obs_data_get_bool(settings, "link_extra_with_text")
	saveExternal = obs.obs_data_get_bool(settings, "saveExternal")
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
    dbg_method("script_defaults")
    obs.obs_data_set_default_int(settings, "prop_lines_counter", 2)
    obs.obs_data_set_default_string(settings, "hotkey-title", "Button Function\t\tAssigned Hotkey Sequence")
    if os.getenv("HOME") == nil then
        windows_os = true
    end -- must be set prior to calling any file functions
    if windows_os then
        os.execute('mkdir "' .. get_songs_folder_path() .. '"')
    else
        os.execute('mkdir -p "' .. get_songs_folder_path() .. '"')
    end
end

--verify source has an opacity setting
function isValid(source)
    if source ~= nil then
        local flags = obs.obs_source_get_output_flags(source)
        dbg_inner(obs.obs_source_get_name(source) .. " - " .. flags)
        local targetFlag = bit.bor(obs.OBS_SOURCE_VIDEO, obs.OBS_SOURCE_CUSTOM_DRAW)
        if bit.band(flags, targetFlag) == targetFlag then
            return true
        end
    end
    return false
end

-- adds an extra linked source.
-- Source must be text source, or have 'Color Correction' Filter applied
function link_source_selected(props, prop, settings)
    dbg_method("link_source_selected")
    local extra_source = obs.obs_data_get_string(settings, "extra_source_list")
    if extra_source ~= nil and extra_source ~= "" then
        local extra_linked_list = obs.obs_properties_get(props, "extra_linked_list")
        obs.obs_property_list_add_string(extra_linked_list, extra_source, extra_source)
        obs.obs_data_set_string(script_sets, "extra_linked_list", extra_source)
        obs.obs_data_set_string(script_sets, "extra_source_list", "")
        obs.obs_property_set_description(
            extra_linked_list,
            "Linked Sources (" .. obs.obs_property_list_item_count(extra_linked_list) .. ")"
        )
    end
    return true
end

-- removes linked sources
function do_linked_clicked(props, p)
    dbg_method("do_link_clicked")
    obs.obs_property_set_visible(obs.obs_properties_get(props, "xtr_grp"), true)
    obs.obs_property_set_visible(obs.obs_properties_get(props, "do_link_button"), false)
    obs.obs_properties_apply_settings(props, script_sets)

    return true
end

-- removes linked sources
function clear_linked_clicked(props, p)
    dbg_method("clear_linked_clicked")
    local extra_linked_list = obs.obs_properties_get(props, "extra_linked_list")
    obs.obs_property_list_clear(extra_linked_list)
    obs.obs_property_set_visible(obs.obs_properties_get(props, "xtr_grp"), false)
    obs.obs_property_set_visible(obs.obs_properties_get(props, "do_link_button"), true)
    obs.obs_property_set_description(extra_linked_list, "Linked Sources      ")

    return true
end

-- A function named script_description returns the description shown to
-- the user

function script_description()
    return description
end

function vMode(vis)
    return expandcollapse and "▲- HIDE " or "▼- SHOW ", expandcollapse and "-▲" or "-▼"
end

function expand_all_groups(props, prop, settings)
    expandcollapse = not expandcollapse
    obs.obs_property_set_visible(obs.obs_properties_get(script_props, "info_grp"), expandcollapse)
    obs.obs_property_set_visible(obs.obs_properties_get(script_props, "mng_grp"), expandcollapse)
    obs.obs_property_set_visible(obs.obs_properties_get(script_props, "disp_grp"), expandcollapse)
    obs.obs_property_set_visible(obs.obs_properties_get(script_props, "src_grp"), expandcollapse)
    obs.obs_property_set_visible(obs.obs_properties_get(script_props, "ctrl_grp"), expandcollapse)
    local mode1, mode2 = vMode(expandecollapse)
    obs.obs_property_set_description(obs.obs_properties_get(props, "expand_all_button"), mode1 .. "ALL GROUPS" .. mode2)
    obs.obs_property_set_description(
        obs.obs_properties_get(props, "info_showing"),
        mode1 .. "SONG INFORMATION" .. mode2
    )
    obs.obs_property_set_description(
        obs.obs_properties_get(props, "prepared_showing"),
        mode1 .. "PREPARED SONGS" .. mode2
    )
    obs.obs_property_set_description(
        obs.obs_properties_get(props, "options_showing"),
        mode1 .. "DISPLAY OPTIONS" .. mode2
    )
    obs.obs_property_set_description(
        obs.obs_properties_get(props, "src_showing"),
        mode1 .. "SOURCE TEXT SELECTIONS" .. mode2
    )
    obs.obs_property_set_description(obs.obs_properties_get(props, "ctrl_showing"), mode1 .. "LYRIC CONTROLS" .. mode2)
    return true
end

function all_vis_equal(props)
    if
        (obs.obs_property_visible(obs.obs_properties_get(script_props, "info_grp")) and
            obs.obs_property_visible(obs.obs_properties_get(script_props, "prep_grp")) and
            obs.obs_property_visible(obs.obs_properties_get(script_props, "disp_grp")) and
            obs.obs_property_visible(obs.obs_properties_get(script_props, "src_grp")) and
            obs.obs_property_visible(obs.obs_properties_get(script_props, "ctrl_grp"))) or
            not (obs.obs_property_visible(obs.obs_properties_get(script_props, "info_grp")) or
                obs.obs_property_visible(obs.obs_properties_get(script_props, "mng_grp")) or
                obs.obs_property_visible(obs.obs_properties_get(script_props, "disp_grp")) or
                obs.obs_property_visible(obs.obs_properties_get(script_props, "src_grp")) or
                obs.obs_property_visible(obs.obs_properties_get(script_props, "ctrl_grp")))
     then
        expandcollapse = not expandcollapse
        local mode1, mode2 = vMode(expandecollapse)
        obs.obs_property_set_description(
            obs.obs_properties_get(props, "expand_all_button"),
            mode1 .. "ALL GROUPS" .. mode2
        )
    end
end

function change_info_visible(props, prop, settings)
    local pp = obs.obs_properties_get(script_props, "info_grp")
    local vis = not obs.obs_property_visible(pp)
    obs.obs_property_set_visible(pp, vis)
    local mode1, mode2 = vMode(vis)
    obs.obs_property_set_description(
        obs.obs_properties_get(props, "info_showing"),
        mode1 .. "SONG INFORMATION" .. mode2
    )
    all_vis_equal(props)
    return true
end

function change_prepared_visible(props, prop, settings)
    local pp = obs.obs_properties_get(script_props, "mng_grp")
    local vis = not obs.obs_property_visible(pp)
    obs.obs_property_set_visible(pp, vis)
    local mode1, mode2 = vMode(vis)
    obs.obs_property_set_description(
        obs.obs_properties_get(props, "prepared_showing"),
        mode1 .. "PREPARED SONGS" .. mode2
    )
    all_vis_equal(props)
    return true
end

function change_options_visible(props, prop, settings)
    local pp = obs.obs_properties_get(script_props, "disp_grp")
    local vis = not obs.obs_property_visible(pp)
    obs.obs_property_set_visible(pp, vis)
    local mode1, mode2 = vMode(vis)
    obs.obs_property_set_description(
        obs.obs_properties_get(props, "options_showing"),
        mode1 .. "DISPLAY OPTIONS" .. mode2
    )
    all_vis_equal(props)
    return true
end

function change_src_visible(props, prop, settings)
    local pp = obs.obs_properties_get(script_props, "src_grp")
    local vis = not obs.obs_property_visible(pp)
    obs.obs_property_set_visible(pp, vis)
    local mode1, mode2 = vMode(vis)
    obs.obs_property_set_description(
        obs.obs_properties_get(props, "src_showing"),
        mode1 .. "SOURCE TEXT SELECTIONS" .. mode2
    )
    all_vis_equal(props)
    return true
end

function change_ctrl_visible(props, prop, settings)
    local pp = obs.obs_properties_get(script_props, "ctrl_grp")
    local vis = not obs.obs_property_visible(pp)
    obs.obs_property_set_visible(pp, vis)
    local mode1, mode2 = vMode(vis)
    obs.obs_property_set_description(obs.obs_properties_get(props, "ctrl_showing"), mode1 .. "LYRIC CONTROLS" .. mode2)
    all_vis_equal(props)
    return true
end

function change_fade_property(props, prop, settings)
    local text_fade_set = obs.obs_data_get_bool(settings, "text_fade_enabled")
    dbg_bool("Fade: ", text_fade_set)
    obs.obs_property_set_visible(obs.obs_properties_get(props, "text_fade_speed"), text_fade_set)
    local transition_set_prop = obs.obs_properties_get(props, "transition_enabled")
    obs.obs_property_set_enabled(transition_set_prop, not text_fade_set)
    return true
end

-- force transform change to bitfocus companion sees update
function force_transform_change(source_name)
    local objScene
    local sceneitem
    local colScenes = obs.obs_frontend_get_scenes()
    for _, objScene in ipairs(colScenes) do
        local scene_source = obs.obs_scene_from_source(objScene)
        local sceneitems = obs.obs_scene_enum_items(scene_source)
        for _, sceneitem in ipairs(sceneitems) do
            local itemsource = obs.obs_sceneitem_get_source(sceneitem)
            local isn = obs.obs_source_get_name(itemsource)
            if source_name == isn then
                local pos = obs.vec2()
                obs.obs_sceneitem_get_pos(sceneitem, pos)
                obs.obs_sceneitem_set_pos(sceneitem, pos)
            end
        end
        obs.sceneitem_list_release(sceneitems)
    end
    obs.source_list_release(colScenes)
end

function show_help_button(props, prop, settings)
    dbg_method("show help")
    local hb = obs.obs_properties_get(props, "show_help_button")
    showhelp = not showhelp
    if showhelp then
        obs.obs_property_set_description(hb, help)
    else
        obs.obs_property_set_description(hb, "SHOW MARKUP SYNTAX HELP")
    end
    return true
end

function setEditVis(props, prop, settings) -- hides edit group on initial showing
    dbg_method("setEditVis")
    if not editVisSet then
        local pp = obs.obs_properties_get(script_props, "edit_grp")
        obs.obs_property_set_visible(pp, false)
        pp = obs.obs_properties_get(props, "meta")
        obs.obs_property_set_visible(pp, false)
        editVisSet = true
    end
end

function filter_songs_clicked(props, p)
    local pp = obs.obs_properties_get(props, "meta")
    if not obs.obs_property_visible(pp) then
        obs.obs_property_set_visible(pp, true)
        local mpb = obs.obs_properties_get(props, "filter_songs_button")
        obs.obs_property_set_description(mpb, "Clear Filters") -- change button function
        meta_tags = obs.obs_data_get_string(script_sets, "prop_edit_metatags")
        refresh_directory()
    else
        obs.obs_property_set_visible(pp, false)
        meta_tags = "" -- clear meta tags
        refresh_directory()
        local mpb = obs.obs_properties_get(props, "filter_songs_button") --
        obs.obs_property_set_description(mpb, "Filter Titles by Meta Tags") -- reset button function
    end
    return true
end

function edit_prepared_clicked(props, p)
    local pp = obs.obs_properties_get(props, "edit_grp")
    if obs.obs_property_visible(pp) then
        obs.obs_property_set_visible(pp, false)
        local mpb = obs.obs_properties_get(props, "prop_manage_button")
        obs.obs_property_set_description(mpb, "Edit Prepared List")
        return true
    end
    local prop_prep_list = obs.obs_properties_get(props, "prop_prepared_list")
    local count = obs.obs_property_list_item_count(prop_prep_list)
    local songNames = obs.obs_data_get_array(script_sets, "prep_list")
    local count2 = obs.obs_data_array_count(songNames)
    if count2 > 0 then
        for i = 0, count2 do
            obs.obs_data_array_erase(songNames, 0)
        end
    end

    for i = 0, count - 1 do
        local song = obs.obs_property_list_item_string(prop_prep_list, i)
        local array_obj = obs.obs_data_create()
        obs.obs_data_set_string(array_obj, "value", song)
        obs.obs_data_array_push_back(songNames, array_obj)
        obs.obs_data_release(array_obj)
    end
    obs.obs_data_set_array(script_sets, "prep_list", songNames)
    obs.obs_data_array_release(songNames)
    obs.obs_property_set_visible(pp, true)
    local mpb = obs.obs_properties_get(props, "prop_manage_button")
    obs.obs_property_set_description(mpb, "Cancel Prepared Edits")
    return true
end

-- removes prepared songs
function save_edits_clicked(props, p)
    load_source_song_directory(false)
    prepared_songs = {}
    local prop_prep_list = obs.obs_properties_get(props, "prop_prepared_list")
    obs.obs_property_list_clear(prop_prep_list)
    local songNames = obs.obs_data_get_array(script_sets, "prep_list")
    local count2 = obs.obs_data_array_count(songNames)
    if count2 > 0 then
        for i = 0, count2 - 1 do
            local item = obs.obs_data_array_item(songNames, i)
            local itemName = obs.obs_data_get_string(item, "value")
            if get_index_in_list(song_directory, itemName) ~= nil then
                prepared_songs[#prepared_songs + 1] = itemName
                obs.obs_property_list_add_string(prop_prep_list, itemName, itemName)
            end
            obs.obs_data_release(item)
        end
    end
    obs.obs_data_array_release(songNames)
    save_prepared()
    if #prepared_songs > 0 then
        obs.obs_data_set_string(script_sets, "prop_prepared_list", prepared_songs[1])
        prepared_index = 1
    else
        obs.obs_data_set_string(script_sets, "prop_prepared_list", "")
        prepared_index = 0
    end
    pp = obs.obs_properties_get(script_props, "edit_grp")
    obs.obs_property_set_visible(pp, false)
    local mpb = obs.obs_properties_get(props, "prop_manage_button")
    obs.obs_property_set_description(mpb, "Edit Prepared Songs List")
    obs.obs_properties_apply_settings(props, script_sets)
    return true
end

function change_transition_property(props, prop, settings)
    local transition_set = obs.obs_data_get_bool(settings, "transition_enabled")
    local text_fade_set_prop = obs.obs_properties_get(props, "text_fade_enabled")
    local fade_speed_prop = obs.obs_properties_get(props, "text_fade_speed")
    obs.obs_property_set_enabled(text_fade_set_prop, not transition_set)
    obs.obs_property_set_enabled(fade_speed_prop, not transition_set)
    transition_enabled = transition_set
    return true
end

-- reloads prepared songs if source , settings or file, is changed
function reLoadPrepared(props, prop, settings)
	saveExternal = obs.obs_data_get_bool(settings, "saveExternal")
	load_prepared(settings)
    return true
end

-- loads prepared songs from external file or internal settings array
function load_prepared(settings)
	if saveExternal then -- loads prepared songs from prepared.dat file
		-- load prepared songs from stored file
		--
		if os.getenv("HOME") == nil then
			windows_os = true
		end -- must be set prior to calling any file functions
		load_source_song_directory(false)
		-- load prepared songs from previous
		local file = io.open(get_songs_folder_path() .. "/" .. "Prepared.dat", "r")
		if file ~= nil then
			for line in file:lines() do
				prepared_songs[#prepared_songs + 1] = line
			end
			file:close()
		end
	else
		local prepared_songs_array = obs.obs_data_get_array(settings, "prepared_songs_list")
		local count = obs.obs_data_array_count(prepared_songs_array)
		if count > 0 then
			for i = 0, count do
				local item = obs.obs_data_array_item(prepared_songs_array, i)
				local songName = obs.obs_data_get_string(item, "value")
				if songName ~= "" then
					prepared_songs[#prepared_songs + 1] = songName
				end
				obs.obs_data_release(item)
			end
		end
		obs.obs_data_array_release(prepared_songs_array)
	end
end

-- saves prepared files for use next time OBS is opened
-- can save into an external file called "Prepared.dat" in the songs folder
-- or into internal settings array
function save_prepared(settings)
		if saveExternal then -- saves preprepared songs in prepared.dat file
			local file = io.open(get_songs_folder_path() .. "/" .. "Prepared.dat", "w")
			for i, name in ipairs(prepared_songs) do
				-- if not scene_load_complete or i > 1 then  -- don't save scene prepared songs
				file:write(name, "\n")
				-- end
			end
			file:close()
		else  -- saves prepared songs in settings array
			local prepared_songs_array = obs.obs_data_array_create()
			local prepared_songs_list = obs.obs_properties_get(script_props, "prop_prepared_list")
			for i, song_name in ipairs(prepared_songs) do
				local array_obj = obs.obs_data_create()
				obs.obs_data_set_string(array_obj, "value", song_name)
				obs.obs_data_array_push_back(prepared_songs_array, array_obj)
				obs.obs_data_release(array_obj)
			end
			obs.obs_data_set_array(settings, "Prepared_songs_list", prepared_songs_array)
			obs.obs_data_array_release(prepared_songs_array)
		end
end

-- A function named script_save will be called when the script is saved
function script_save(settings)
    dbg_method("script_save")
    save_prepared()
    local hotkey_save_array = obs.obs_hotkey_save(hotkey_n_id)
    obs.obs_data_set_array(settings, "lyric_next_hotkey", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_save_array = obs.obs_hotkey_save(hotkey_p_id)
    obs.obs_data_set_array(settings, "lyric_prev_hotkey", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_save_array = obs.obs_hotkey_save(hotkey_c_id)
    obs.obs_data_set_array(settings, "lyric_clear_hotkey", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_save_array = obs.obs_hotkey_save(hotkey_n_p_id)
    obs.obs_data_set_array(settings, "next_prepared_hotkey", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_save_array = obs.obs_hotkey_save(hotkey_p_p_id)
    obs.obs_data_set_array(settings, "previous_prepared_hotkey", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_save_array = obs.obs_hotkey_save(hotkey_home_id)
    obs.obs_data_set_array(settings, "home_song_hotkey", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_save_array = obs.obs_hotkey_save(hotkey_reset_id)
    obs.obs_data_set_array(settings, "reset_prepared_hotkey", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
    ---
    ---  Save extra_linked_sources properties to settings so they can be restored when script is reloaded
    ---
    local extra_sources_array = obs.obs_data_array_create()
    local extra_linked_list = obs.obs_properties_get(script_props, "extra_linked_list")
    local count = obs.obs_property_list_item_count(extra_linked_list)
    for i = 0, count - 1 do
        local source_name = obs.obs_property_list_item_string(extra_linked_list, i) -- get extra source by name
        local array_obj = obs.obs_data_create()
        obs.obs_data_set_string(array_obj, "value", source_name)
        obs.obs_data_array_push_back(extra_sources_array, array_obj)
        obs.obs_data_release(array_obj)
    end
    obs.obs_data_set_array(settings, "extra_link_sources", extra_sources_array)
    obs.obs_data_array_release(extra_sources_array)
	
	save_prepared(settings)

end

-- a function named script_load will be called on startup and mostly handles loading hotkey data to OBS
-- sets callback to obs_frontend Event Callback
--
function script_load(settings)
    dbg_method("script_load")
    hotkey_n_id = obs.obs_hotkey_register_frontend("lyric_next_hotkey", "Advance Lyrics", next_lyric)
    hotkey_save_array = obs.obs_data_get_array(settings, "lyric_next_hotkey")
    hotkey_n_key = get_hotkeys(hotkey_save_array, "Next Lyric", " ......................")
    obs.obs_hotkey_load(hotkey_n_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_p_id = obs.obs_hotkey_register_frontend("lyric_prev_hotkey", "Go Back Lyrics", prev_lyric)
    hotkey_save_array = obs.obs_data_get_array(settings, "lyric_prev_hotkey")
    hotkey_p_key = get_hotkeys(hotkey_save_array, "Previous Lyric", " ..................")
    obs.obs_hotkey_load(hotkey_p_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_c_id = obs.obs_hotkey_register_frontend("lyric_clear_hotkey", "Show/Hide Lyrics", toggle_lyrics_visibility)
    hotkey_save_array = obs.obs_data_get_array(settings, "lyric_clear_hotkey")
    hotkey_c_key = get_hotkeys(hotkey_save_array, "Show/Hide Lyrics", " ..............")
    obs.obs_hotkey_load(hotkey_c_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_n_p_id = obs.obs_hotkey_register_frontend("next_prepared_hotkey", "Prepare Next", next_prepared)
    hotkey_save_array = obs.obs_data_get_array(settings, "next_prepared_hotkey")
    hotkey_n_p_key = get_hotkeys(hotkey_save_array, "Next Prepared", " ................")
    obs.obs_hotkey_load(hotkey_n_p_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_p_p_id = obs.obs_hotkey_register_frontend("previous_prepared_hotkey", "Prepare Previous", prev_prepared)
    hotkey_save_array = obs.obs_data_get_array(settings, "previous_prepared_hotkey")
    hotkey_p_p_key = get_hotkeys(hotkey_save_array, "Previous Prepared", "............")
    obs.obs_hotkey_load(hotkey_p_p_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_home_id = obs.obs_hotkey_register_frontend("home_song_hotkey", "Reset to Song Start", home_song)
    hotkey_save_array = obs.obs_data_get_array(settings, "home_song_hotkey")
    hotkey_home_key = get_hotkeys(hotkey_save_array, "Reset to Song Start", " ..........")
    obs.obs_hotkey_load(hotkey_home_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_reset_id =
        obs.obs_hotkey_register_frontend("reset_prepared_hotkey", "Reset to First Prepared Song", home_prepared)
    hotkey_save_array = obs.obs_data_get_array(settings, "reset_prepared_hotkey")
    hotkey_reset_key = get_hotkeys(hotkey_save_array, "Reset to 1st Prepared", " .......")
    obs.obs_hotkey_load(hotkey_reset_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    script_sets = settings
    source_name = obs.obs_data_get_string(settings, "prop_source_list")

    -- load previously defined extra sources from settings array into table
    -- script_properties function will take them from the table and restore them as UI properties
    --
    local extra_sources_array = obs.obs_data_get_array(settings, "extra_link_sources")
    local count = obs.obs_data_array_count(extra_sources_array)
    if count > 0 then
        for i = 0, count do
            local item = obs.obs_data_array_item(extra_sources_array, i)
            local sourceName = obs.obs_data_get_string(item, "value")
            if sourceName ~= "" then
                extra_sources[#extra_sources + 1] = sourceName
            end
            obs.obs_data_release(item)
        end
    end
    obs.obs_data_array_release(extra_sources_array)

	load_prepared(settings)

    name_hotkeys()

    obs.obs_frontend_add_event_callback(on_event) -- Setup Callback for event capture
end

---
------
---------  Source Showing or Source Active Helper Functions
---------  Return true if sourcename given is showing anywhere or on in the Active scene
------
---
function isShowing(sourceName)
    local source = obs.obs_get_source_by_name(sourceName)
    local showing = false
    if source ~= nil then
        showing = obs.obs_source_showing(source)
    end
    obs.obs_source_release(source)
    return showing
end

function isActive(sourceName)
    local source = obs.obs_get_source_by_name(sourceName)
    local active = false
    if source ~= nil then
        active = obs.obs_source_active(source)
    end
    obs.obs_source_release(source)
    return active
end

function anythingShowing()
    return isShowing(source_name) or isShowing(alternate_source_name) or isShowing(title_source_name) or
        isShowing(static_source_name)
end

function sourceShowing()
    return isShowing(source_name)
end

function alternateShowing()
    return isShowing(alternate_source_name)
end

function titleShowing()
    return isShowing(title_source_name)
end

function staticShowing()
    return isShowing(static_source_name)
end

function anythingActive()
    return isActive(source_name) or isActive(alternate_source_name) or isActive(title_source_name) or
        isActive(static_source_name)
end

function sourceActive()
    return isActive(source_name)
end

function alternateActive()
    return isActive(alternate_source_name)
end

function titleActive()
    return isActive(title_source_name)
end

function staticActive()
    return isActive(static_source_name)
end

---
------
---------  Initialization Functions
---------  Manages defined Hotkey Save, Load, Translate and Button rename
---------  Loads inital song directory and any previously prepared lyrics
------
---

----------------------------------------------------------------------------------------------------------
--  get_hotkeys(loaded hotkey array, desired prefix text, leader text (between prefix and hotkey label)
--  Returns translated hotkey text label with prefix and leader
--  e.g. if HotKeyArray contains an assigned hotkey Shift and F1 key combo, then
--  get_hotkeys(HotKeyArray," ....... ", "HotKey") returns "Hotkey ....... Shift + F1"
----------------------------------------------------------------------------------------------------------

function get_hotkeys(hotkey_array, prefix, leader)
    local Translate = {
        ["NUMLOCK"] = "NumLock",
        ["NUMSLASH"] = "Num/",
        ["NUMASTERISK"] = "Num*",
        ["NUMMINUS"] = "Num-",
        ["NUMPLUS"] = "Num+",
        ["NUMPERIOD"] = "NumDel",
        ["INSERT"] = "Insert",
        ["PAGEDOWN"] = "Page-Down",
        ["PAGEUP"] = "Page-Up",
        ["HOME"] = "Home",
        ["END"] = "End",
        ["RETURN"] = "Return",
        ["UP"] = "Up",
        ["DOWN"] = "Down",
        ["RIGHT"] = "Right",
        ["LEFT"] = "Left",
        ["SCROLLLOCK"] = "Scroll-Lock",
        ["BACKSPACE"] = "Backspace",
        ["ESCAPE"] = "Esc",
        ["MENU"] = "Menu",
        ["META"] = "Meta",
        ["PRINT"] = "Prt",
        ["TAB"] = "Tab",
        ["DELETE"] = "Del",
        ["CAPSLOCK"] = "Caps-Lock",
        ["NUMEQUAL"] = "Num=",
        ["PAUSE"] = "Pause",
        ["VK_VOLUME_MUTE"] = "Vol Mute",
        ["VK_VOLUME_DOWN"] = "Vol Dwn",
        ["VK_VOLUME_UP"] = "Vol Up",
        ["VK_MEDIA_PLAY_PAUSE"] = "Media Play",
        ["VK_MEDIA_STOP"] = "Media Stop",
        ["VK_MEDIA_PREV_TRACK"] = "Media Prev",
        ["VK_MEDIA_NEXT_TRACK"] = "Media Next"
    }

    item = obs.obs_data_array_item(hotkey_array, 0)
    local key = string.sub(obs.obs_data_get_string(item, "key"), 9)
    if Translate[key] ~= nil then
        key = Translate[key]
    elseif string.sub(key, 1, 3) == "NUM" then
        key = "Num " .. string.sub(key, 4)
    elseif string.sub(key, 1, 5) == "MOUSE" then
        key = "Mouse " .. string.sub(key, 6)
    end

    obs.obs_data_release(item)
    local val = prefix
    if key ~= nil and key ~= "" then
        val = val .. "  " .. leader .. "  "
        if obs.obs_data_get_bool(item, "control") then
            val = val .. "Ctrl + "
        end
        if obs.obs_data_get_bool(item, "alt") then
            val = val .. "Alt + "
        end
        if obs.obs_data_get_bool(item, "shift") then
            val = val .. "Shift + "
        end
        if obs.obs_data_get_bool(item, "command") then
            val = val .. "Cmd + "
        end
        val = val .. key
    end
    return val
end

-- name_hotkeys function renames the seven hotkeys to include their defined key text
--
function name_hotkeys()
    obs.obs_property_set_description(obs.obs_properties_get(hotkey_props, "prop_prev_button"), hotkey_p_key)
    obs.obs_property_set_description(obs.obs_properties_get(hotkey_props, "prop_next_button"), hotkey_n_key)
    obs.obs_property_set_description(obs.obs_properties_get(hotkey_props, "prop_hide_button"), hotkey_c_key)
    obs.obs_property_set_description(obs.obs_properties_get(hotkey_props, "prop_home_button"), hotkey_home_key)
    obs.obs_property_set_description(obs.obs_properties_get(hotkey_props, "prop_prev_prep_button"), hotkey_p_p_key)
    obs.obs_property_set_description(obs.obs_properties_get(hotkey_props, "prop_next_prep_button"), hotkey_n_p_key)
    obs.obs_property_set_description(obs.obs_properties_get(hotkey_props, "prop_reset_button"), hotkey_reset_key)
end

--------
----------------
------------------------ SOURCE FUNCTIONS
----------------
--------

-- Function renames source to a unique descriptive name and marks duplicate sources with * and Color change
function rename_source()
    -- pause_timer = true
    local sources = obs.obs_enum_sources()
    if (sources ~= nil) then
        -- count and index sources
        local t = 1
        for _, source in ipairs(sources) do
            local source_id = obs.obs_source_get_unversioned_id(source)
            if source_id == "Prepare_Lyrics" then
                local settings = obs.obs_source_get_settings(source)
                obs.obs_data_set_string(settings, "index", t) -- add index to source data
                t = t + 1
                obs.obs_data_release(settings) -- release memory
            end
        end
        -- Find and mark Duplicates in loadLyric_items table
        local loadLyric_items = {} -- Start Table for all load Sources
        local scenes = obs.obs_frontend_get_scenes() -- Get list of all scene items
        if scenes ~= nil then
            for _, scenesource in ipairs(scenes) do -- Loop through all scenes
                local scene = obs.obs_scene_from_source(scenesource) -- Get scene pointer
                local scene_name = obs.obs_source_get_name(scenesource) -- Get scene name
                local scene_items = obs.obs_scene_enum_items(scene) -- Get list of all items in this scene
                if scene_items ~= nil then
                    for _, scene_item in ipairs(scene_items) do -- Loop through all scene source items
                        local source = obs.obs_sceneitem_get_source(scene_item) -- Get item source pointer
                        local source_id = obs.obs_source_get_unversioned_id(source) -- Get item source_id
                        if source_id == "Prepare_Lyrics" then -- Skip if not a Prepare_Lyric source item
                            local settings = obs.obs_source_get_settings(source) -- Get settings for this Prepare_Lyric source
                            local index = obs.obs_data_get_string(settings, "index") -- Get index for this source (set earlier)
                            if loadLyric_items[index] == nil then
                                loadLyric_items[index] = 1 -- First time to find this source so mark with 1
                            else
                                loadLyric_items[index] = loadLyric_items[index] + 1 -- Found this source again so increment
                            end
                            obs.obs_data_release(settings) -- release memory
                        end
                    end
                end
                obs.sceneitem_list_release(scene_items) -- Free scene list
            end
            obs.source_list_release(scenes) -- Free source list
        end

        -- Name Source with Song Title
        local i = 1
        for _, source in ipairs(sources) do
            local source_id = obs.obs_source_get_unversioned_id(source) -- Get source
            if source_id == "Prepare_Lyrics" then -- Skip if not a Load Lyric source
                local c_name = obs.obs_source_get_name(source) -- Get current Source Name
                local settings = obs.obs_source_get_settings(source) -- Get settings for this source
                local song = obs.obs_data_get_string(settings, "songs") -- Get the current song name to load
                local index = obs.obs_data_get_string(settings, "index") -- get index
                if (song ~= nil) then
                    local name = "<meta " .. t - i .. " />Load lyrics for: <i><b>" .. song .. "</i></b>" -- use index for compare
                    -- Mark Duplicates
                    if index ~= nil then
                        if loadLyric_items[index] > 1 then
                            name =
                                '<span style="color:#FF6050;">' ..
                                name .. " <sup>" .. loadLyric_items[index] .. "</sup></span>"
                        end
                        if (c_name ~= name) then
                            obs.obs_source_set_name(source, name)
                        end
                    end
                    i = i + 1
                end
                obs.obs_data_release(settings)
            end
        end
    end
    obs.source_list_release(sources)
    -- pause_timer = false
end

-- Names the initial "Prepare Lyric" source (prior to being renamed to "Load Lyrics for: {song name}
source_def.get_name = function()
    return "Prepare Lyric"
end

-- Called when OBS is saving data.  This will be called on each copy of Load Lyric source
-- Used to initiate rename_source() function when the source dialog closes
-- saved flag prevents it from being called by every source each time.
--
source_def.save = function(data, settings)
    if saved then
        return
    end --  we only need it once, not for every load lyric source copy
    dbg_method("Source_save")
    saved = true
    using_source = true
    rename_source() -- Rename and Mark sources instantly on update (WZ)
end

-- Called when a change is made in the source dialog (Currently Not Used)
--
source_def.update = function(data, settings)
    dbg_method("update")
end

-- Called when the source dialog is loaded (Currently not Used)
--
source_def.load = function(data)
    dbg_method("load")
end

-- Called when the refresh button is pressed in the source dialog
-- It reloads the song directory and applies any meta-tag filters if entered
--
function source_refresh_button_clicked(props, p)
    dbg_method("source_refresh_button")
    source_filter = true
    dbg_inner("tags: " .. source_meta_tags)
    load_source_song_directory(true)
    table.sort(song_directory)
    local prop_dir_list = obs.obs_properties_get(props, "songs")
    obs.obs_property_list_clear(prop_dir_list) -- clear directories
    for _, name in ipairs(song_directory) do
        dbg_inner("SLD: " .. name)
        obs.obs_property_list_add_string(prop_dir_list, name, name)
    end
    return true
end

-- Keeps variable source-meta-tags up-to-date
-- Note: This could be done only when refreshing the directory (see source_refresh_button_clicked)
--
function update_source_metatags(props, p, settings)
    source_meta_tags = obs.obs_data_get_string(settings, "metatags")
    return true
end

-- Called when a user makes a song selection in the source dialog
-- Song is also prepared for a visual confirmation if sources are showing in Active or Preview screens
-- Saved flag is cleared to mark changes have occured for save event
--
function source_selection_made(props, prop, settings)
    dbg_method("source_selection")
    local name = obs.obs_data_get_string(settings, "songs")
    saved = false -- mark properties changed
    using_source = true
    prepare_selected(name)
    return true
end

-- Standard OBS get Properties function for OBS source dialog
--
source_def.get_properties = function(data)
    source_filter = true
    load_source_song_directory(true)
    local source_props = obs.obs_properties_create()
    local source_dir_list =
        obs.obs_properties_add_list(
        source_props,
        "songs",
        "Song Directory",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    obs.obs_property_set_modified_callback(source_dir_list, source_selection_made)
    table.sort(song_directory)
    for _, name in ipairs(song_directory) do
        obs.obs_property_list_add_string(source_dir_list, name, name)
    end
    gps = obs.obs_properties_create()
    source_metatags = obs.obs_properties_add_text(gps, "metatags", "Filter MetaTags", obs.OBS_TEXT_DEFAULT)
    obs.obs_property_set_modified_callback(source_metatags, update_source_metatags)
    obs.obs_properties_add_button(gps, "source_dir_refresh", "Refresh Directory", source_refresh_button_clicked)
    obs.obs_properties_add_group(source_props, "meta", "Filter Songs", obs.OBS_GROUP_NORMAL, gps)
    gps = obs.obs_properties_create()
    obs.obs_properties_add_bool(gps, "source_activate_in_preview", "Activate song in Preview mode") -- Option to load new lyric in preview mode
    obs.obs_properties_add_bool(gps, "source_home_on_active", "Go to lyrics home on source activation") -- Option to home new lyric in preview mode
    obs.obs_properties_add_group(source_props, "source_options", "Load Options", obs.OBS_GROUP_NORMAL, gps)
    dbg_inner("props")
    return source_props
end

-- Called when the source is created
-- saves pointer to settings in global sourc_sets for convienence
-- Sets callbacks for active, showing, deactive, and updated callbacks
--
source_def.create = function(settings, source)
    dbg_method("create")
    data = {}
    source_sets = settings
    obs.signal_handler_connect(obs.obs_source_get_signal_handler(source), "activate", source_isactive) -- Set Active Callback
    obs.signal_handler_connect(obs.obs_source_get_signal_handler(source), "show", source_showing) -- Set Preview Callback
    obs.signal_handler_connect(obs.obs_source_get_signal_handler(source), "deactivate", source_inactive) -- Set Preview Callback
    obs.signal_handler_connect(obs.obs_source_get_signal_handler(source), "updated", source_update) -- Set Preview Callback
    return data
end

-- Sets default settings for Activate Source in Preview
--
source_def.get_defaults = function(settings)
    obs.obs_data_set_default_bool(settings, "source_activate_in_preview", false)
end

--  On Event Functions
--  These manage keeping the HTML monitor page updated when changes happen like scene changes that remove
--  selected Text sources from active scenes.  Also manage rename callbacks when changes like cloned load sources are
--  either created or deleted.  Rename changes color and marks with *, sources that are reference copies of the same source
--  as accidentally changing the settings like the loaded song in one will change it in the reference copies.
--

-- Called via the timed callback, removes the callback and updates the HTML monitor page
--
function update_source_callback()
    obs.remove_current_callback()
    update_monitor()
end

-- called via the timed callback, removes the callback and renames all the load sources
--
function rename_callback()
    obs.remove_current_callback()
    rename_source()
end

-- on_event setup when source load, detects when a scenes content changes or when the scene list changes, ignores other events
function on_event(event)
    dbg_method("on_event: " .. event)
    if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then -- scene changed so update HTML monitor page
        dbg_bool("Active:", source_active)
        obs.timer_add(update_source_callback, 100) -- delay updating source text until all sources have been removed by OBS
    end
    if event == obs.OBS_FRONTEND_EVENT_SCENE_LIST_CHANGED then -- scene list is different so rename sources to reflect changes
        dbg_inner("Scene Change")
        obs.timer_add(rename_callback, 1000) -- delay until OBS has completed list change
    end
end

-- Load Source Song takes song selection made in source properties and prepares it on the fly during scene load.
--
function load_source_song(source, preview)
    dbgsp("load_source_song")
    local settings = obs.obs_source_get_settings(source)
    if not preview or (preview and obs.obs_data_get_bool(settings, "source_activate_in_preview")) then
        local song = obs.obs_data_get_string(settings, "songs")
        using_source = true
        load_source = source
        all_sources_fade = true -- fade title and source the first time
        set_text_visibility(TEXT_HIDE) -- if this is a transition turn it off so it can fade in
        if song ~= last_prepared_song then -- skips prepare if song already prepared just to save some processing cycles
            prepare_selected(song)
        end
        transition_lyric_text()
        if obs.obs_data_get_bool(settings, "source_home_on_active") then
            home_prepared(true)
        end
    end
    obs.obs_data_release(settings)
end

-- Call back when load source (not text source) goes to the Active Scene
-- loads the selected song and sets the current scene name for the HTML monitor
--
function source_isactive(cd)
    dbg_custom("source_active")
    local source = obs.calldata_source(cd, "source")
    if source == nil then
        return
    end
    dbg_inner("source active")
    load_scene = get_current_scene_name()
    load_source_song(source, false)
    source_active = true -- using source lyric
end

-- Call back when load source leaves the current Active Scene
-- just resets the source_active flag
--
function source_inactive(cd)
    dbg_inner("source inactive")
    local source = obs.calldata_source(cd, "source")
    if source == nil then
        return
    end
    source_active = false -- indicates source loading lyric is active (but using prepared lyrics is still possible)
end

-- Call back when load source (not text source) goes to the Active
-- loads the selected song and sets the current scene name for the HTML monitor
--
function source_showing(cd)
    dbg_custom("source_showing")
    local source = obs.calldata_source(cd, "source")
    if source == nil then
        return
    end
    load_source_song(source, true)
end

-- dbg functions
--
function dbg_traceback()
    if DEBUG then
        print("Trace: " .. debug.traceback())
    end
end

function dbg(message)
    if DEBUG then
        print(message)
    end
end

function dbg_inner(message)
    if DEBUG_INNER then
        dbg("INNR: " .. message)
    end
end

function dbg_method(message)
    if DEBUG_METHODS then
        dbg("-- MTHD: " .. message)
    end
end

function dbgsp(message)
    if DEBUG then
        dbg("====SPECIAL=====================>> " .. message)
    end
end
function dbg_custom(message)
    if DEBUG_CUSTOM then
        dbg("CUST: " .. message)
    end
end

function dbg_bool(name, value)
    if DEBUG_BOOL then
        local message = "BOOL: " .. name
        if value then
            message = message .. " = true"
        else
            message = message .. " = false"
        end
        dbg(message)
    end
end

obs.obs_register_source(source_def)

description =
    [[ 
<p><div><img style="float: left; margin: 0px 0px 0px 0px;" width="68"   src="data:image/gif;base64,R0lGODlhRAAoAHcAACH5BAEAAAAALAAAAABEACgAh/8A/wGu9wCr/gC19wmw7wi19w+x7Buy5hi17yC04ym13Sm15zQzMDU4QzC22jO41Tg2LTk5Ozk9SjxASji41ENANkVIUkK6zkC500xFM0tLTEtNVEtOWEtQXE27yEm7zFRLMVVOOlJQSVRWXlZaZ1K8xlK9zlhaY19fYlm9wmFXOmdaNWO/vGPBt2PGvW9xd2nBuXZpQnRpSXJydXJ0fHd5fnLCsHPCsnxtPXl6e33HpHzErIZ0O4J2T4GCg4bFpoLEqo9L6It9Uo7HopVT4ZF/R5KCUZeNcpSVmJPHn5PJnZTOpZdV35xS55xc2JlY3J9f1p+NU5yZk5ueqZrHoZzJmqNm0KFj06ZpzaaSVqWTWKCRYqOWbKafg6Cip6aptKbLlKpuyK1rzq5yxK6aWq6cZK2fdKuiia+xt621tarLkrVzxrR7vLCYTrWcUrafXLWlWrSyrrOztbTNjL17vbuEtL2Evb2Mtb2lXLuxlby2ob29pb7QhL3WhMKMrMiUpMaUrcWsX8W8n8S7ocbWe8bQg8uYos6cnsyZocywVs+7e8y8i9DSfMzRgNacnNanlNKhmdi8YtbBf9bWc9bTeduvjN6tlOCziNq7Wd3AYeHDYd/Ecd/Vc97We+K3hOe1jOi/fuW7geTFXefIYujXa+bVcezBfO+9hO/IdezDee/OWvDPY/LNce/Xae/Wc+/eY+/ea/XRYvjRbfTNcPjXY/jVaffeY/fea/8AAP8A//8JBP8OBv8XC/8hCP8iEP8pEP8vFv85GP9AHv9MJP9SIf9TJ/9cLP9lL/9zMf90N/+EPv+LQf+URf+dSv+mTv+tSv+vUv+0Vf+9Wf/GXf/OWv/MYP/WWv7ZZfzWaP/eVf/dXP7cZP7gaf/lWv/nY/7obf3jev7lgf/tU//vWv/tb//ucP7soP/2dP/3pf731f723P766f//c///1v//3v//5/767f/99QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAj+AAEIHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNCjJeuo8ePIEOKHEnSIzyJ6r5948aypcuXMGPKfKmS5bdw6iKqY7mtp8+fQIMKHfrz27Rq3LZd+wYu58OdSq9JnUq1qtWrWKV+c8aL2bepTJ02hJq1rFmsRnntmsaNaliHZM/KLbttpTBcys6pjLq06dik13zO3aZNbt2V15Lh0rWMmTJlSMH6XQi1FqtZs7Cd3RbqUS2+V1lCSybMF67TqIFdaytZLEKoqcJYYSML9NVtbIJcsk21rTHUwFE7+1r1bUKo2/wQ+RNVm7aezwlLf+RnFvTngZ1v4yZNF65du07+Ays2TNgxwFaNH4Ta7RCRQz1lVap0yVMlUKg8hfJUC1Wo2rPQVxso9KWilDPNQGPaLtKUsxJraE1mEFTa/EEEIj2xYgURdfjxhCFsOCHiI2M4AYosJTpRxyVWWMFEHT19c04zpw2DGF9AXUMLLX25NhCFFmK4TXtEPHJJGLX4oSIboNThRCqIMHHIGGP4AYUnkCACVjGnLUMcVbSsMsomkiwiyCC19DhhUhVe2I0soKQCBRsddvPHE7ttUwcUoTiZCn6hYGGFHwZqxSUu0nwplSJ56BGHHGh8MYUUqyilnkDsuXeIOH+wQUuIV3hi5xOVdKMnn3U8AYo4sqRyCST+swW2WjTAABMZVXp84QUSPsyAggUijMLapcj58aIhT/zRHhNjfGbsI91cw8YTnXF4CJ1jVDJGGLRExU011fB2BAkbTBBBBBWEoIKwrf2YlCnbCoqFJ+LIqewsbAy6DSpjWHEILX9YMe8jYWARRiWgsVTVNrTIEEIMRbSRiCi04JEJaEytg2lS2MjisSy1yMJKKlhcok3HHl+Dcm3byILNNtiE/Nlmq2RRaU0svXExVXWls7FSP3VTiRNYsDGzYIH1JJXSPxm2ChmyTrWNzqBt51RcUqPiRx2FzuX10k93yzPVPHNzNXo8a/f12tuEjePUO0tt9s9TOWf3XHYXdk3+3s05t7DbqzG8jcVVzw0AWdtwwgILKaQAAydn1ZJECSlUsc0cKTDOQiHaNAJDCjcwwrPbbZdxhhlGjFL42VGR8oAADzwQACPa8KgULWlORUsJAlCggAA2FEJAABcE4AApDhDAAvB6B+b2NzxIQMMJEIgCYWCGx6XNDwK0kMQctezgAAVgNEIBBh6wQNgcAlygTSsHEFBKCQboYEAJrSRgQBIszKFUUjsiQ7e+gYMG5OAEDNDE9axGt739IAAGUAAnwCCAElAgAIW4gAAOUALCJEEANyjMBRlRggAcIAAloAUfEiCAD1AiMJjgQhe2EAWpcCMQGqgBCnowM7mxTir+2xNAFbqVAgEwQgkCKAQLDMCJNGlDDRXMBi0SQIBW0I8UvOMDFdRgAwGwoHYg6MALJrACpXEjEniIBNqWlj30kEKD+NPGBy+QgAMwQgEB4IPeWkEBAXigj0CghAFQaAAC8IEAFxgCCLURiwyMwAcTUAF6tqO0hbURaJQogSYZwbAffKAEhchkCYAgtVLs4AIfUMI21KDJC5RgiD/Q5A1KsR0hcIAGGtDC9bLCwMOh7W5AVJvfqpK3YN5NO3rbRivwQAY1DuaSa4umVbbzDd7wEprSzGY2e5mOcpBDJeAMpzjHSc5ymvOc4yRHOXwGgHWY453wjKc850nPetrznvYI1JhG9vmQgAAAOw=="/></div><span style="text-align: center;"><span style="color: #FFD966;"><b>OBS Lyrics+</b></span><span style="color: #B69DBB;"><b> Manages lyrics & other paged text</b></span><br><i>Ver: 2.0</i>&nbsp;&bull;&nbsp;Authors: Amirchev & DC Strato<br>with contributions from Taxilian</span></p>
]]
