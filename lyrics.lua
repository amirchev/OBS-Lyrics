-- Copyright 2020 amirchev

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

-- http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- TODO: refresh properties after next prepared selection
-- TODO: add text formatting guide (Done 7/31/21)

-- Source updates by W. Zaggle (DCSTRATO) 12/3/2020
-- Fading Text Out/In with transition option 12/8/2020

-- Source updates by W. Zaggle (DCSTRATO) 1/24/2021
-- Added ##B as alternative to ##P
-- Added #B:n and #P:n as way to add multiple blank lines all at once
-- Added #R:n preceding text as a way to Duplicate the following text line n times
-- Corrected possible timer recursion where timer function could take longer than 100ms callback interval and hang OBS

-- Source updates by W. Zaggle (DCSTRATO) 2/4/2021
-- Changed #R:n to #D:n (Duplicate Lines)
-- Added #R[ and #R] on lines by themselves to bracket lines of Refrain
-- Added ##R to repeat the lines bracketed by #R[ and #R] lines
-- Made chage to showing() function maybe work better if not in studio mode

-- Source updates by W. Zaggle (DCSTRATO) 2/13/21
-- Stability Issues
-- #r[ loads refrain without showing lines. Used if you want to have the refrain at the top of the text but only use it with ##R

-- Source updates by W. Zaggle (DCSTRATO) 2/17/21
-- Removed auto HOME when using source to prepare Lyric and returning to scene without a lyric change
-- Added option to Home lyric when return to scene without a lyric change
-- Added code to instantly show/hide lyrics ignoring fade option  (Should fade be optional?)
-- New option to modify Title Text object with Song Title
-- Added code to allow text to change in Preview mode if preview and active scene are the same (normally active text object prevents this change in preview)
-- CLeared up Home and Reset.  Home returns to start of current song.  Reset goes back to 1st song.
-- Added new button/hot-key to allow for both Home and Reset functions.
-- Allow Comment after #L:n markup in Lyrics

-- Source update by W. Zaggle (DCSTRATO) 3/6/21
-- Added Alternate Text Source that syncs with Lyrics marked with #A[ and #A]
-- Added Static Source that loads once with #S[ and #S]

-- Source update by W. Zaggle (DCSTRATO) 5/15/21
-- Added lyric index update on Alternate if number of lyrics is zero, Text Source is not in Scene or Undefined

-- Source update by W. Zaggle (DCSTRATO) 7/11/2021
-- Added encoding/decoding of song titles that are invalid file names. Files are encoded and saved as .enc files instead -- .txt files to maintain compatibility with prior versions.  Invalid includes Unicoded titles and characters
--  /:*?\"<>| which allows for a song title to include prior invalid characters and support other languages.
--  For example a song title can now be "What Child is This?" or "Ơn lạ lùng" (Vietnamese for Amazing Grace)

-- Source update by W. Zaggle (DCSTRATO) 7/31/2021
-- Added ablility to elect to link Title and Static text to blank with Lyrics at end of song (Requested Feature)
-- Added html quick guide table to Script Page (Text Formatting Guide TODO)

-- Source update by W. Zaggle (DCSTRATO) 8/6/2021
-- Added html Monitor Page for use in Browser Dock
-- Added ##r with same funcation as ##R
-- Added #A:n Line Where n is number of pages to apply line to in Alternate Text Block
-- Added #S: Line that adds a single Static Line to the static block
-- #L:n now sets Lyrics, Refrain and Alternate Text block default number of lines per page (If in Alternate block or Refrain block it will override those lines per page)

-- Source update by W. Zaggle (DCSTRATO) 8/16/2021
-- UPdated HTM monitor page and limited support for duplicate sources in Studio Mode

-- Source update by W. Zaggle (DCSTRATO) 8/28/2021
-- minor bug fix to show/hide lyrics
-- added Refresh Sources button to update script with new sources as they are added.  (Can't find Callback for new/removed sources to replace button)

-- Source update by W. Zaggle (DCSTRATO) 9/6/2021
-- more work on show/hide and fade to be more compatible
-- corrected Refrain to honor page size
-- restored blank page at end of song
-- added refresh song directory to refresh sources button (songs are sources of a sort)
-- added button to edit song text in default system editor for .txt or .enc file types.

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
-- current_scene = ""
-- preview_scene = ""
title_source_name = ""

-- settings
windows_os = false
first_open = true
-- in_timer = false
-- in_Load = false
-- in_directory = false
-- pause_timer = false
display_lines = 0
ensure_lines = true
-- visible = false

-- lyrics status
-- TODO: removed displayed_song and use prepared_songs[prepared_index]
-- displayed_song = ""
lyrics = {}
-- refrain = {}
alternate = {}
page_index = 1
prepared_index = 0 -- TODO: avoid setting prepared_index directly, use prepare_selected
song_directory = {}
prepared_songs = {}
link_text = false
source_song_title = ""
using_source = false
transition_enabled = false

timer_exists = false

-- hotkeys
hotkey_n_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_p_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_c_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_n_p_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_p_p_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_home_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_reset_id = obs.OBS_INVALID_HOTKEY_ID

-- script placeholders
script_sets = nil
script_props = nil

-- text status & fade
TEXT_VISIBLE = 0 -- text is visible
TEXT_HIDDEN = 1 -- text is hidden
TEXT_SHOWING = 3 -- going from hidden -> visible
TEXT_HIDING = 4 -- going from visible -> hidden
TEXT_TRANSITION_OUT = 5 -- fade out transition to next lyric
TEXT_TRANSITION_IN = 6 -- fade in transition after lyric change
text_status = TEXT_VISIBLE
text_opacity = 100
text_fade_speed = 1
text_fade_enabled = false

-- scene_load_complete = false
-- update_lyrics_in_fade = false
-- load_scene = ""

transition_completed = false

-- simple debugging/print mechanism
DEBUG = true -- on/off switch for entire debugging mechanism
DEBUG_METHODS = true -- print method names
DEBUG_INNER = true -- print inner method breakpoints
DEBUG_CUSTOM = true -- print custom debugging messages

--------
----------------
------------------------ CALLBACKS
----------------
--------

-- function sourceShowing()
-- local source = obs.obs_get_source_by_name(source_name)
-- local showing = false
-- if source ~= nil then
-- showing = obs.obs_source_showing(source)
-- end
-- obs.obs_source_release(source)
-- return showing
-- end

-- function alternateShowing()
-- local source = obs.obs_get_source_by_name(alternate_source_name)
-- local showing = false
-- if source ~= nil then
-- obs.os_sleep_ms(10)   -- Workaround Timing Bug in OBS Lua that delays correctly reporting source status
-- showing = obs.obs_source_showing(source)
-- end
-- obs.obs_source_release(source)
-- return showing
-- end

-- function titleShowing()
-- local source = obs.obs_get_source_by_name(title_source_name)
-- local showing = false
-- if source ~= nil then
-- obs.os_sleep_ms(10)   -- Workaround Timing Bug in OBS Lua that delays correctly reporting source status
-- showing = obs.obs_source_showing(source)
-- end
-- obs.obs_source_release(source)
-- return showing
-- end

-- function staticShowing()
-- local source = obs.obs_get_source_by_name(static_source_name)
-- local showing = false
-- if source ~= nil then
-- obs.os_sleep_ms(10)   -- Workaround Timing Bug in OBS Lua that delays correctly reporting source status
-- showing = obs.obs_source_showing(source)
-- end
-- obs.obs_source_release(source)
-- return showing
-- end

-- function anythingActive()
-- return sourceActive() or alternateActive() or titleActive() or staticActive()
-- end

-- function sourceActive()

-- local source = obs.obs_get_source_by_name(source_name)
-- local active = false
-- if source ~= nil then
-- obs.os_sleep_ms(10)   -- Workaround Timing Bug in OBS Lua that delays correctly reporting source status
-- active = obs.obs_source_active(source)
-- obs.obs_source_release(source)
-- end
-- return active
-- end

-- function alternateActive()

-- local source = obs.obs_get_source_by_name(alternate_source_name)
-- local active = false
-- if source ~= nil then
-- obs.os_sleep_ms(10)   -- Workaround Timing Bug in OBS Lua that delays correctly reporting source status
-- active = obs.obs_source_active(source)
-- obs.obs_source_release(source)
-- end
-- return active
-- end

-- function titleActive()

-- local source = obs.obs_get_source_by_name(title_source_name)
-- local active = false
-- if source ~= nil then
-- obs.os_sleep_ms(10)   -- Workaround Timing Bug in OBS Lua that delays correctly reporting source status
-- active = obs.obs_source_active(source)
-- obs.obs_source_release(source)
-- end
-- return active
-- end

-- function staticActive()

-- local source = obs.obs_get_source_by_name(static_source_name)
-- local active = false
-- if source ~= nil then
-- obs.os_sleep_ms(10)   -- Workaround Timing Bug in OBS Lua that delays correctly reporting source status
-- active = obs.obs_source_active(source)
-- obs.obs_source_release(source)
-- end
-- return active
-- end

function next_lyric(pressed)
    if not pressed then
        return
    end
    dbg_method("next_lyric")
    -- check if transition enabled
    if transition_enabled then
        if not transition_completed then
            obs.obs_frontend_preview_program_trigger_transition()
            transition_completed = true
            return
        end
    end

    if #lyrics > 0 or #alternate > 0 then -- and sourceShowing() then  -- Lyrics is driving paging
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
    if #lyrics > 0 or #alternate > 0 then -- and sourceShowing() then  -- Lyrics is driving paging
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
    if prepared_index > 1 then
        using_source = false
        prepare_selected(prepared_songs[prepared_index - 1])
    end
end

function next_prepared(pressed)
    if not pressed then
        return
    end
    if prepared_index < #prepared_songs then
        using_source = false
        prepare_selected(prepared_songs[prepared_index + 1])
    end
end

function toggle_lyrics_visibility(pressed)
    dbg_method("toggle_lyrics_visibility")
    if not pressed then
        return
    end
    -- if #lyrics > 0 and not sourceShowing() then
    -- return
    -- end
    -- if #alternate > 0 and not alternateShowing() then
    -- return
    -- end
    -- visible = not visible
    -- showHelp = not showHelp
    if text_status ~= TEXT_HIDDEN then
        dbg_inner("hiding")
        set_text_visiblity(TEXT_HIDDEN)
    else
        dbg_inner("showing")
        set_text_visiblity(TEXT_VISIBLE)
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
    -- visible = true
    -- set_text_visiblity(TEXT_VISIBLE)
    -- page_index = 0
    -- prepared_index = 0
    using_source = false
    page_index = 0
    -- prepared_index = 1
    local prop_prep_list = obs.obs_properties_get(props, "prop_prepared_list")
    if #prepared_songs > 0 then
        obs.obs_data_set_string(script_sets, "prop_prepared_list", prepared_songs[1])
        prepare_selected(prepared_songs[1])
    else
        obs.obs_data_set_string(script_sets, "prop_prepared_list", "")
    end
    obs.obs_properties_apply_settings(props, script_sets)

    return true
end

function home_song(pressed)
    if not pressed then
        return false
    end
    dbg_method("home_song")
    -- visible = true
    -- set_text_visiblity(TEXT_VISIBLE)
    if #prepared_songs > 0 then
        page_index = 1
        transition_lyric_text(false)
    end
    -- prepare_selected(prepared_songs[prepared_index])   -- redundant from above
    return true
end

-- function set_current_scene_name()
-- local scene = obs.obs_frontend_get_current_preview_scene()
-- current_scene = obs.obs_source_get_name(scene)
-- obs.obs_source_release(scene);
-- end

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
    prepared_songs[#prepared_songs + 1] = obs.obs_data_get_string(script_sets, "prop_directory_list")
    local prop_prep_list = obs.obs_properties_get(props, "prop_prepared_list")
    obs.obs_property_list_add_string(prop_prep_list, prepared_songs[#prepared_songs], prepared_songs[#prepared_songs])
    if #prepared_songs == 1 then
        obs.obs_data_set_string(script_sets, "prop_prepared_list", prepared_songs[#prepared_songs])
        prepare_song_by_index(#prepared_songs)
    end
    obs.obs_properties_apply_settings(props, script_sets)
    save_prepared()
    -- update_source_text()
    return true
end

function refresh_button_clicked(props, p)
    local source_prop = obs.obs_properties_get(props, "prop_source_list")
    local alternate_source_prop = obs.obs_properties_get(props, "prop_alternate_list")
    local static_source_prop = obs.obs_properties_get(props, "prop_static_list")
    local title_source_prop = obs.obs_properties_get(props, "prop_title_list")
    obs.obs_property_list_clear(source_prop) -- clear current properties list
    obs.obs_property_list_clear(alternate_source_prop) -- clear current properties list
    obs.obs_property_list_clear(static_source_prop) -- clear current properties list
    obs.obs_property_list_clear(title_source_prop) -- clear current properties list

    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        local n = {}
        for _, source in ipairs(sources) do
            source_id = obs.obs_source_get_unversioned_id(source)
            if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
                n[#n + 1] = obs.obs_source_get_name(source)
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
    load_song_directory()
    return true
end

function prepare_selection_made(props, prop, settings)
    dbg_method("prepare_selection_made")
    local name = obs.obs_data_get_string(settings, "prop_prepared_list")
    using_source = false
    prepare_selected(name)
    return true
end

function prepare_selected(name)
    dbg_method("prepare_selected: " .. name)
    if name == nil then
        return false
    end
    if name == "" then
        return false
    end
    if name == prepared_songs[prepared_index] or (using_source and name == source_song_title) then
        return false
    end
    prepare_song_by_name(name)
    page_index = 1
    if not using_source then
        prepared_index = get_index_in_list(prepared_songs, name)
        transition_lyric_text(false)
    else
        source_song_title = name
        transition_lyric_text(true)
    end
    -- visible = true
    -- set_text_visiblity(TEXT_VISIBLE)
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

-- removes prepared songs
function clear_prepared_clicked(props, p)
    dbg_method("clear_prepared_clicked")
    -- scene_load_complete = false
    prepared_songs = {}
    -- lyrics = {}
    -- alternate = {}
    -- static = ""
    set_text_visiblity(TEXT_HIDDEN)
    -- clear the list
    local prep_prop = obs.obs_properties_get(props, "prop_prepared_list")
    obs.obs_property_list_clear(prep_prop)
    obs.obs_data_set_string(script_sets, "prop_prepared_list", "")
    obs.obs_properties_apply_settings(props, script_sets)
    save_prepared()
    --page_index = 0
    prepared_index = 0
    transition_lyric_text(false)
    -- displayed_song = ""
    return true
end

function open_song_clicked(props, p)
    local name = obs.obs_data_get_string(script_sets, "prop_directory_list")
    if testValid(name) then
        path = get_song_file_path(name, ".txt")
    else
        path = get_song_file_path(enc(name), ".enc")
    end
    print(path)
    if windows_os then
        os.execute('explorer "' .. path .. '"')
    else
        os.execute('xdg-open "' .. path .. '"')
    end
    return true
end

function open_button_clicked(props, p)
    local path = get_songs_folder_path()
    if windows_os then
        os.execute('explorer "' .. path .. '"')
    else
        os.execute('xdg-open "' .. path .. '"')
    end
end

--------
----------------
------------------------ PROGRAM FUNCTIONS
----------------
--------

-- updates the displayed lyrics
function update_source_text()
    dbg_method("update_source_text")
    if prepared_index == nil or prepared_index == 0 then
        return
    end
    local text = ""
    local alttext = ""
    local next_lyric = ""
    local next_alternate = ""
    local static = static_text
    local title = ""

    if not using_source then
        title = prepared_songs[prepared_index]
    else
        title = source_song_title
    end
    -- init_opacity = 0;

    local source = obs.obs_get_source_by_name(source_name)
    local alt_source = obs.obs_get_source_by_name(alternate_source_name)
    local stat_source = obs.obs_get_source_by_name(static_source_name)
    local title_source = obs.obs_get_source_by_name(title_source_name)

    -- if visible then
    -- text_fade_dir = 2
    -- init_opacity = 100
    -- get text
    if #lyrics > 0 then -- and sourceShowing() then
        if lyrics[page_index] ~= nil then
            text = lyrics[page_index]
        end
    end
    if #alternate > 0 then -- and alternateShowing() then
        if alternate[page_index] ~= nil then
            alttext = alternate[page_index]
        end
    end

    -- end

    if link_text then
        if string.len(text) == 0 and string.len(alttext) == 0 then
            static = ""
            title = ""
        end
    end

    -- update source texts
    if source ~= nil then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", text)
        -- obs.obs_data_set_int(settings, "opacity", init_opacity)
        -- obs.obs_data_set_int(settings, "outline_opacity", init_opacity)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)

        next_lyric = lyrics[page_index + 1]
        if (next_lyric == nil) then
            next_lyric = ""
        end
    end
    if alt_source ~= nil then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", alttext)
        -- obs.obs_data_set_int(alt_settings, "opacity", init_opacity)
        -- obs.obs_data_set_int(alt_settings, "outline_opacity", init_opacity)
        obs.obs_source_update(alt_source, settings)
        obs.obs_data_release(settings)

        next_alternate = alternate[page_index + 1]
        if (next_alternate == nil) then
            next_alternate = ""
        end
    end
    if stat_source ~= nil then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", static)
        obs.obs_source_update(stat_source, settings)
        obs.obs_data_release(settings)
    end
    if title_source ~= nil then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", title)
        obs.obs_source_update(title_source, settings)
        obs.obs_data_release(settings)
    end
    -- release source references
    obs.obs_source_release(source)
    obs.obs_source_release(alt_source)
    obs.obs_source_release(stat_source)
    obs.obs_source_release(title_source)

    local next_prepared = prepared_songs[prepared_index + 1]
    if (next_prepared == nil) then
        next_prepared = ""
    end
    update_monitor(
        title,
        text:gsub("\n", "<br>&bull; "),
        next_lyric:gsub("\n", "<br>&bull; "),
        alttext:gsub("\n", "<br>&bull; "),
        next_alternate:gsub("\n", "<br>&bull; "),
        next_prepared
    )
    -- if obs.obs_data_get_bool(script_sets, "transition_enabled") then
    -- if transition_completed then
    -- obs.obs_frontend_preview_program_trigger_transition()
    -- transition_completed = true
    -- end
    -- end
end

function apply_source_opacity()
    local settings = obs.obs_data_create()
    local source = obs.obs_get_source_by_name(source_name)
    if source ~= nil then
        obs.obs_data_set_int(settings, "opacity", text_opacity) -- Set new text opacity to zero
        obs.obs_data_set_int(settings, "outline_opacity", text_opacity) -- Set new text outline opacity to zero
        obs.obs_source_update(source, settings)
    end
    obs.obs_source_release(source)
    local alt_source = obs.obs_get_source_by_name(alternate_source_name)
    if alt_source ~= nil then
        obs.obs_data_set_int(settings, "opacity", text_opacity) -- Set new text opacity to zero
        obs.obs_data_set_int(settings, "outline_opacity", text_opacity) -- Set new text outline opacity to zero
        obs.obs_source_update(alt_source, settings)
    end
    obs.obs_source_release(alt_source)
    if text_status ~= TEXT_TRANSITION_IN and text_status ~= TEXT_TRANSITION_OUT then
        local title_source = obs.obs_get_source_by_name(title_source_name)
        if title_source ~= nil then
            obs.obs_data_set_int(settings, "opacity", text_opacity) -- Set new text opacity to zero
            obs.obs_data_set_int(settings, "outline_opacity", text_opacity) -- Set new text outline opacity to zero
            obs.obs_source_update(title_source, settings)
        end
        obs.obs_source_release(title_source)
        local static_source = obs.obs_get_source_by_name(static_source_name)
        if static_source ~= nil then
            obs.obs_data_set_int(settings, "opacity", text_opacity) -- Set new text opacity to zero
            obs.obs_data_set_int(settings, "outline_opacity", text_opacity) -- Set new text outline opacity to zero
            obs.obs_source_update(static_source, settings)
        end
        obs.obs_source_release(static_source)
    end
    obs.obs_data_release(settings)
end

function set_text_visiblity(end_status)
    dbg_method("set_text_visiblity")
    -- if already at desired visibility, then exit
    if text_status == end_status then
        return
    end
    -- if fade is disabled, change visibility immediately
    if not text_fade_enabled then
        if end_status == TEXT_HIDDEN then
            opacity = 0
        elseif end_status == TEXT_VISIBLE then
            opacity = 100
        end
        text_status = end_status
        apply_source_opacity()
        dbg_inner("immediate visibility change")
    else
        -- if fade enabled, begin fade in or out
        if end_status == TEXT_HIDDEN then
            text_status = TEXT_HIDING
        elseif end_status == TEXT_VISIBLE then
            text_status = TEXT_SHOWING
        end
        start_fade_timer()
    end
end

-- transition to the next lyrics, use fade if enabled
-- if lyrics are hidden, force_show set to true will make them visible
function transition_lyric_text(force_show)
    dbg_method("transition_lyric_text")
    -- update the lyrics display immediately on 2 conditions
    -- a) the text is hidden or hiding, and we will not force it to show
    -- b) text fade is not enabled
    -- otherwise, start text transition out and update the lyrics once
    -- fade out transition is complete
    if (text_status == TEXT_HIDDEN or text_status == TEXT_HIDING) and not force_show then
        update_source_text()
        dbg_inner("hidden")
    elseif not text_fade_enabled then
        update_source_text()
        set_text_visiblity(TEXT_VISIBLE)
        dbg_inner("no text fade")
    else
        text_status = TEXT_TRANSITION_OUT
        start_fade_timer()
    end
end

function start_fade_timer()
    if not timer_exists then
        timer_exists = true
        obs.timer_add(fade_callback, 50)
        dbg_inner("started fade timer")
    end
end

function fade_callback()
    dbg_method("fade_callback")
    -- if not in a transitory state, exit callback
    if text_status == TEXT_HIDDEN or text_status == TEXT_VISIBLE then
        timer_exists = false
        obs.remove_current_callback()
        dbg_inner("ended fade timer")
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
                update_source_text()
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
    if index <= #prepared_songs then
        prepare_song_by_name(prepared_songs[index])
    end
end

-- prepares lyrics of the song
function prepare_song_by_name(name)
    -- pause_timer = true
    if name == nil then
        return false
    end
    -- if using transition on lyric change, first transition
    -- would be reset with new song prepared
    transition_completed = false
    local song_lines = get_song_text(name)
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
    alternate = {}
    static_text = ""
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
                local static_indexEnd = line:find("%s+", static_index + 1)
                line = line:sub(static_indexEnd + 1)
                static_text = line
                new_lines = 0
            end
            local alt_index = line:find("#A:")
            if alt_index ~= nil then
                local alt_indexStart, alt_indexEnd = line:find("%d+", alt_index + 3)
                new_lines = tonumber(line:sub(alt_indexStart, alt_indexEnd))
                _, alt_indexEnd = line:find("%s+", alt_indexEnd + 1)
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
                line = line:sub(1, newcount_index - 1)
            end
            local phantom_index = line:find("##P")
            if phantom_index ~= nil then
                line = line:sub(1, phantom_index - 1)
            end
            phantom_index = line:find("##B")
            if phantom_index ~= nil then
                line = line:gsub("%s*##B%s*", "") .. "\n"
            -- line = line:sub(1, phantom_index - 1)
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

-- loads the song directory
function load_song_directory()
    -- pause_timer = true
    song_directory = {}
    local filenames = {}
    local dir = obs.os_opendir(get_songs_folder_path())
     -- get_songs_folder_path())
    local entry
    local songExt
    local songTitle
    repeat
        entry = obs.os_readdir(dir)
        if
            entry and not entry.directory and
                (obs.os_get_path_extension(entry.d_name) == ".enc" or obs.os_get_path_extension(entry.d_name) == ".txt")
         then
            songExt = obs.os_get_path_extension(entry.d_name)
            songTitle = string.sub(entry.d_name, 0, string.len(entry.d_name) - string.len(songExt))
            if songExt == ".enc" then
                song_directory[#song_directory + 1] = dec(songTitle)
            else
                song_directory[#song_directory + 1] = songTitle
            end
        end
    until not entry
    obs.os_closedir(dir)
    -- pause_timer = false
end

-- delete previewed song
function delete_song(name)
    if testValid(name) then
        path = get_song_file_path(name, ".txt")
    else
        path = get_song_file_path(enc(name), ".enc")
    end
    os.remove(path)
    table.remove(song_directory, get_index_in_list(song_directory, name))
    load_song_directory()
end

local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-" -- encoding alphabet

-- encoding
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

-- saves preprepared songs
function save_prepared()
    dbg_method("save_prepared")
    local file = io.open(get_songs_folder_path() .. "/" .. "Prepared.dat", "w")
    for i, name in ipairs(prepared_songs) do
        -- if not scene_load_complete or i > 1 then  -- don't save scene prepared songs
        file:write(name, "\n")
        -- end
    end
    file:close()
    return true
end

function load_prepared()
    dbg_method("load_prepared")
    -- pause_timer = true
    local file = io.open(get_songs_folder_path() .. "/" .. "Prepared.dat", "r")
    if file ~= nil then
        for line in file:lines() do
            prepared_songs[#prepared_songs + 1] = line
        end
        prepared_index = 1
        file:close()
    end
    -- pause_timer = false
    return true
end

function update_monitor(song, lyric, nextlyric, alt, nextalt, nextsong)
    dbg_method("update_monitor")
    local tableback = "#000000"
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
    if not using_source then
        text =
            text ..
            "<div style = 'background-color:#332222;'><div style = 'color: #B0E0E6; float: left; width: 160px; margin: 2px; '>Prepared Song: <B style='color: #FFEF00;'>" ..
                prepared_index
        text =
            text ..
            "</B><B style='color: #B0E0E6;'> of </B><B style='color: #FFEF00;'>" .. #prepared_songs .. "</B></div>"
    end
    text =
        text ..
        "<div style = 'color: #B0E0E6; float: left; width: 145px; margin: 2px; '>Lyric Page: <B style='color: #FFEF00;'>" ..
            page_index
    text = text .. "</B><B style='color: #B0E0E6;'> of </B><B style='color: #FFEF00;'>" .. #lyrics .. "</b></div>"
    text = text .. "<div style = 'color: #B0E0E6; float: left;  margin: 2px; '>"
    -- show if song is from source or prepared songs
    text = text .. "From: <B style = 'color: #FFEF00;'> "
    if using_source then
        text = text .. "Source</B>"
    else
        text = text .. "Prepared</B>"
    end

    text =
        text ..
        "</div><table bgcolor=" ..
            tableback .. " cellpadding='3' cellspacing='3' width=100% style = 'border-collapse: collapse;'>"
    if song ~= "" then
        text =
            text ..
            "<tr style='border-bottom: 1px solid #ccc; border-top: 1px solid #ccc; border-color: #98AFC7;'><td bgcolor=#262626 style='border-right: 1px solid #ccc; border-color: #98AFC7; color: White; width: 50px; text-align: center;'>Song<br>Title</td>"
        text = text .. "<td style='color: White;'><Strong>" .. song .. "</strong></td></tr>"
    end
    if lyric ~= "" then
        text =
            text ..
            "<tr style='border-bottom: 1px solid #ccc; border-color: #98AFC7;'><td bgcolor=#262626 style='border-right: 1px solid #ccc; border-color: #98AFC7; color: PaleGreen;  text-align: center;'>Current<br>Page</td>"
        text = text .. "<td style='color: PaleGreen;'> &bull; " .. lyric .. "</td></tr>"
    end
    if nextlyric ~= "" then
        text =
            text ..
            "<tr style='border-bottom: 1px solid #ccc; border-color: #98AFC7;'><td bgcolor=#262626 style='border-right: 1px solid #ccc; border-color: #98AFC7; color: Lavender;  text-align: center;'>Next<br>Page</td>"
        text = text .. "<td  style='color: Lavender;'> &bull; " .. nextlyric .. "</td></tr>"
    end
    if alt ~= "" then
        text =
            text ..
            "<tr style='border-bottom: 1px solid #ccc; border-color: #98AFC7;'><td bgcolor=#262626 style='border-right: 1px solid #ccc; border-color: #98AFC7; color: SpringGreen; text-align: center;'>Alt<br>Lyric</td>"
        text = text .. "<td  style='color: SpringGreen;'> &bull; " .. alt .. "</td></tr>"
    end
    if nextalt ~= "" then
        text =
            text ..
            "<tr style='border-bottom: 1px solid #ccc; border-color: #98AFC7;'><td bgcolor=#262626 style='border-right: 1px solid #ccc; border-color: #98AFC7; color: Plum; text-align: center;'>Next<br>Alt</td>"
        text = text .. "<td style='color: Plum;'> &bull; " .. nextalt .. "</td></tr>"
    end
    if nextsong ~= "" then
        text =
            text ..
            "<tr style='border-bottom: 2px solid #ccc; border-color: #98AFC7;' ><td bgcolor=#262626 style='border-right: 1px solid #ccc; border-color: #98AFC7; color: Gold; text-align: center;'>Next<br>Song:</td>"
        text = text .. "<td style='color: Gold;'>" .. nextsong .. "</td></tr>"
    end
    text = text .. "</table></body></html>"
    local file = io.open(get_songs_folder_path() .. "/" .. "Monitor.htm", "w")
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
    end

    return song_lines
end

-- ------
----------------
------------------------ OBS DEFAULT FUNCTIONS
-- --------------
--------

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
    dbg_method("script_properties")
    script_props = obs.obs_properties_create()
    obs.obs_properties_add_text(script_props, "prop_edit_song_title", "Song Title", obs.OBS_TEXT_DEFAULT)
    local lyric_prop =
        obs.obs_properties_add_text(script_props, "prop_edit_song_text", "Song Lyrics", obs.OBS_TEXT_MULTILINE)
    obs.obs_property_set_long_description(lyric_prop, "Lyric Text with Markup")
    obs.obs_properties_add_button(script_props, "prop_save_button", "Save Song", save_song_clicked)
    local prop_dir_list =
        obs.obs_properties_add_list(
        script_props,
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

    obs.obs_properties_add_button(script_props, "prop_prepare_button", "Prepare Song", prepare_song_clicked)
    obs.obs_properties_add_button(script_props, "prop_delete_button", "Delete Song", delete_song_clicked)
    obs.obs_properties_add_button(
        script_props,
        "prop_opensong_button",
        "Edit Song with System Editor",
        open_song_clicked
    )
    obs.obs_properties_add_button(script_props, "prop_open_button", "Open Songs Folder", open_button_clicked)
    local lines_prop = obs.obs_properties_add_int(script_props, "prop_lines_counter", "Lines to Display", 1, 100, 1)
    obs.obs_property_set_long_description(
        lines_prop,
        "Sets default lines per page of lyric, overwritten by Markup: #L:n"
    )

    local prop_lines = obs.obs_properties_add_bool(script_props, "prop_lines_bool", "Strictly ensure number of lines")
    obs.obs_property_set_long_description(prop_lines, "Guarantees fixed number of lines per page")

    local link_prop =
        obs.obs_properties_add_bool(script_props, "link_text", "Only show title and static text with lyrics")
    obs.obs_property_set_long_description(link_prop, "Hides title and static text at end of lyrics")

    local transition_prop =
        obs.obs_properties_add_bool(script_props, "transition_enabled", "Transition Preview to Program on lyric change")
    obs.obs_property_set_modified_callback(transition_prop, change_transition_property)
    obs.obs_property_set_long_description(
        transition_prop,
        "Use with Studio Mode, duplicate sources, and OBS source transitions"
    )

    local fade_prop = obs.obs_properties_add_bool(script_props, "text_fade_enabled", "Enable text fade") -- Fade Enable (WZ)
    obs.obs_property_set_modified_callback(fade_prop, change_fade_property)
    obs.obs_properties_add_int_slider(script_props, "text_fade_speed", "Fade Speed", 1, 10, 1)

    local source_prop =
        obs.obs_properties_add_list(
        script_props,
        "prop_source_list",
        "Text Source",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    obs.obs_property_set_long_description(source_prop, "Shows main lyric text")
    local title_source_prop =
        obs.obs_properties_add_list(
        script_props,
        "prop_title_list",
        "Title Source",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    obs.obs_property_set_long_description(title_source_prop, "Shows text from song title")
    local alternate_source_prop =
        obs.obs_properties_add_list(
        script_props,
        "prop_alternate_list",
        "Alternate Source",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    obs.obs_property_set_long_description(alternate_source_prop, "Shows text annotated with #A[ and #A]")
    local static_source_prop =
        obs.obs_properties_add_list(
        script_props,
        "prop_static_list",
        "Static Source",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    obs.obs_property_set_long_description(static_source_prop, "Shows text annotated with #S[ and #S]")
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        local n = {}
        for _, source in ipairs(sources) do
            source_id = obs.obs_source_get_unversioned_id(source)
            if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
                n[#n + 1] = obs.obs_source_get_name(source)
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
    obs.obs_properties_add_button(script_props, "prop_refresh", "Refresh Sources", refresh_button_clicked)
    local prep_prop =
        obs.obs_properties_add_list(
        script_props,
        "prop_prepared_list",
        "Prepared Songs",
        obs.OBS_COMBO_TYPE_EDITABLE,
        obs.OBS_COMBO_FORMAT_STRING
    )
    for _, name in ipairs(prepared_songs) do
        obs.obs_property_list_add_string(prep_prop, name, name)
    end
    obs.obs_property_set_modified_callback(prep_prop, prepare_selection_made)
    obs.obs_properties_add_button(script_props, "prop_clear_button", "Clear Prepared Songs", clear_prepared_clicked)
    obs.obs_properties_add_button(script_props, "prop_prev_button", "Previous Lyric", prev_button_clicked)
    obs.obs_properties_add_button(script_props, "prop_next_button", "Next Lyric", next_button_clicked)
    obs.obs_properties_add_button(script_props, "prop_hide_button", "Show/Hide Lyrics", toggle_button_clicked)
    obs.obs_properties_add_button(script_props, "prop_home_button", "Reset to Song Start", home_button_clicked)
    obs.obs_properties_add_button(
        script_props,
        "prop_reset_button",
        "Reset to First Prepared Song",
        reset_button_clicked
    )
    if #prepared_songs > 0 and prepared_index > 0 then
        obs.obs_data_set_string(script_sets, "prop_prepared_list", prepared_songs[prepared_index])
    end

    obs.obs_properties_apply_settings(script_props, script_sets)

    return script_props
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
    return "Manage song lyrics to be displayed as subtitles (Version: September 2021 (beta2)  Author: Amirchev & DC Strato; with significant contributions from taxilian. <br><table border = '1'><tr><td><table border='0' cellpadding='0' cellspacing='3'> <tr><td><b><u>Markup</u></b></td><td>&nbsp;&nbsp;</td><td><b><u>Syntax</u></b></td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td><b><u>Markup</u></b></td><td>&nbsp;&nbsp;</td><td><b><u>Syntax</u></b></td></tr><tr><td>Display n Lines</td><td>&nbsp;&nbsp;</td><td>#L:<i>n</i></td><td></td><td>End Page after Line</td><td>&nbsp;&nbsp;</td><td>Line ###</td></tr><tr><td>Blank(Pad) Line</td><td>&nbsp;&nbsp;</td><td>##B or ##P</td><td></td><td>Blank(Pad) Lines</td><td>&nbsp;&nbsp;</td><td>#B:<i>n</i> or #P:<i>n</i></td></tr><tr><td>External Refrain</td><td>&nbsp;&nbsp;</td><td>#r[ and #r]</td><td></td><td>In-Line Refrain</td><td>&nbsp;&nbsp;</td><td>#R[ and #R]</td></tr><tr><td>Repeat Refrain</td><td>&nbsp;&nbsp;</td><td>##R or ##r</td><td></td><td>Duplicate Line <i>n</i> times</td><td>&nbsp;&nbsp;</td><td>#D:<i>n</i> Line</td></tr><tr><td>Define Static Lines</td><td>&nbsp;&nbsp;</td><td>#S[ and #S]</td><td></td><td>Single Static Line</td><td>&nbsp;&nbsp;</td><td>#S: Line</td></tr><tr><td>Define Alternate Text</td><td>&nbsp;&nbsp;</td><td>#A[ and #A]</td><td></td><td>Alt Repeat <i>n</i> Pages</td><td>&nbsp;&nbsp;</td><td>#A:<i>n</i> Line</td></tr><tr><td>Comment Line</td><td>&nbsp;&nbsp;</td><td>// Line</td><td></td><td>Block Comments</td><td>&nbsp;&nbsp;</td><td>//[ and //]</td></tr></table></td></tr></table>"
end

function change_fade_property(props, prop, settings)
    local text_fade_set = obs.obs_data_get_bool(settings, "text_fade_enabled")
    local transition_set_prop = obs.obs_properties_get(props, "transition_enabled")
    obs.obs_property_set_enabled(transition_set_prop, not text_fade_set)
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
-- A function named script_update will be called when settings are changed
function script_update(settings)
    text_fade_enabled = obs.obs_data_get_bool(settings, "text_fade_enabled") -- 	Fade Enable (WZ)
    text_fade_speed = obs.obs_data_get_int(settings, "text_fade_speed") -- 	Fade Speed (WZ)
    reload = false
    local cur_display_lines = obs.obs_data_get_int(settings, "prop_lines_counter")
    if display_lines ~= cur_display_lines then
        display_lines = cur_display_lines
        reload = true
    end
    local cur_source_name = obs.obs_data_get_string(settings, "prop_source_list")
    if source_name ~= cur_source_name then
        source_name = cur_source_name
        reload = true
    end
    local alt_source_name = obs.obs_data_get_string(settings, "prop_alternate_list")
    if alternate_source_name ~= alt_source_name then
        alternate_source_name = alt_source_name
        reload = true
    end
    local stat_source_name = obs.obs_data_get_string(settings, "prop_static_list")
    if static_source_name ~= stat_source_name then
        static_source_name = stat_source_name
        reload = true
    end
    local cur_title_source = obs.obs_data_get_string(settings, "prop_title_list")
    if title_source_name ~= cur_title_source then
        title_source_name = cur_title_source
        reload = true
    end
    local cur_ensure_lines = obs.obs_data_get_bool(settings, "prop_lines_bool")
    if cur_ensure_lines ~= ensure_lines then
        ensure_lines = cur_ensure_lines
        reload = true
    end
    local cur_link_text = obs.obs_data_get_bool(settings, "link_text")
    if cur_link_text ~= link_text then
        link_text = cur_link_text
        reload = true
    end

    if reload then
        if #prepared_songs > 0 and prepared_songs[prepared_index] ~= "" then
            prepare_selected(prepared_songs[prepared_index])
        -- page_index = 1
        -- transition_lyric_text(false)
        end
    end
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
    dbg_method("script_defaults")
    obs.obs_data_set_default_int(settings, "prop_lines_counter", 2)
    -- obs.obs_data_set_default_string(settings, "prop_source_list", prepared_songs[1] )
    -- if #prepared_songs ~= 0 then
    --    prepared_songs[prepared_index] = prepared_songs[1]
    -- 	prepared_index = 1
    -- else
    --	prepared_songs[prepared_index] = ""
    -- end
    if os.getenv("HOME") == nil then
        windows_os = true
    end -- must be set prior to calling any file functions
    if windows_os then
        os.execute('mkdir "' .. get_songs_folder_path() .. '"')
    else
        os.execute('mkdir -p "' .. get_songs_folder_path() .. '"')
    end
end

-- A function named script_save will be called when the script is saved
function script_save(settings)
    save_prepared()
    local hotkey_save_array = obs.obs_hotkey_save(hotkey_n_id)
    obs.obs_data_set_array(settings, "lyric_next_hotkey", hotkey_save_array)
    -- hotkey_save_array = obs.obs_hotkey_save(hotkey_n_id)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_save_array = obs.obs_hotkey_save(hotkey_p_id)
    obs.obs_data_set_array(settings, "lyric_prev_hotkey", hotkey_save_array)
    -- hotkey_save_array = obs.obs_hotkey_save(hotkey_p_id)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_save_array = obs.obs_hotkey_save(hotkey_c_id)
    obs.obs_data_set_array(settings, "lyric_clear_hotkey", hotkey_save_array)
    -- hotkey_save_array = obs.obs_hotkey_save(hotkey_c_id)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_save_array = obs.obs_hotkey_save(hotkey_n_p_id)
    obs.obs_data_set_array(settings, "next_prepared_hotkey", hotkey_save_array)
    -- hotkey_save_array = obs.obs_hotkey_save(hotkey_n_p_id)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_save_array = obs.obs_hotkey_save(hotkey_p_p_id)
    obs.obs_data_set_array(settings, "previous_prepared_hotkey", hotkey_save_array)
    -- hotkey_save_array = obs.obs_hotkey_save(hotkey_p_p_id)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_save_array = obs.obs_hotkey_save(hotkey_home_id)
    obs.obs_data_set_array(settings, "home_song_hotkey", hotkey_save_array)
    -- hotkey_save_array = obs.obs_hotkey_save(hotkey_home_id)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_save_array = obs.obs_hotkey_save(hotkey_reset_id)
    obs.obs_data_set_array(settings, "reset_prepared_hotkey", hotkey_save_array)
    -- hotkey_save_array = obs.obs_hotkey_save(hotkey_home_id)
    obs.obs_data_array_release(hotkey_save_array)
end

-- a function named script_load will be called on startup
function script_load(settings)
    dbg_method("script_load")
    hotkey_n_id = obs.obs_hotkey_register_frontend("lyric_next_hotkey", "Advance Lyrics", next_lyric)
    local hotkey_save_array = obs.obs_data_get_array(settings, "lyric_next_hotkey")
    obs.obs_hotkey_load(hotkey_n_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_p_id = obs.obs_hotkey_register_frontend("lyric_prev_hotkey", "Go Back Lyrics", prev_lyric)
    hotkey_save_array = obs.obs_data_get_array(settings, "lyric_prev_hotkey")
    obs.obs_hotkey_load(hotkey_p_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_c_id = obs.obs_hotkey_register_frontend("lyric_clear_hotkey", "Show/Hide Lyrics", toggle_lyrics_visibility)
    hotkey_save_array = obs.obs_data_get_array(settings, "lyric_clear_hotkey")
    obs.obs_hotkey_load(hotkey_c_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_n_p_id = obs.obs_hotkey_register_frontend("next_prepared_hotkey", "Prepare Next", next_prepared)
    hotkey_save_array = obs.obs_data_get_array(settings, "next_prepared_hotkey")
    obs.obs_hotkey_load(hotkey_n_p_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_p_p_id = obs.obs_hotkey_register_frontend("previous_prepared_hotkey", "Prepare Previous", prev_prepared)
    hotkey_save_array = obs.obs_data_get_array(settings, "previous_prepared_hotkey")
    obs.obs_hotkey_load(hotkey_p_p_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_home_id = obs.obs_hotkey_register_frontend("home_song_hotkey", "Reset to Song Start", home_song)
    hotkey_save_array = obs.obs_data_get_array(settings, "home_song_hotkey")
    obs.obs_hotkey_load(hotkey_home_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_reset_id =
        obs.obs_hotkey_register_frontend("reset_prepared_hotkey", "Reset to First Prepared Song", home_prepared)
    hotkey_save_array = obs.obs_data_get_array(settings, "reset_prepared_hotkey")
    obs.obs_hotkey_load(hotkey_reset_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    script_sets = settings
    source_name = obs.obs_data_get_string(settings, "prop_source_list")
    if os.getenv("HOME") == nil then
        windows_os = true
    end -- must be set prior to calling any file functions
    load_song_directory()
    load_prepared()
    -- obs.obs_frontend_add_event_callback(on_event)    -- Setup Callback for Source * Marker (WZ)
    -- obs.timer_add(timer_callback, 50)	-- Setup callback for text fade effect
end

--------
----------------
------------------------ SOURCE FUNCTIONS
----------------
--------

-- Function renames source to a unique descriptive name and marks duplicate sources with *  (WZ)
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
                                loadLyric_items[index] = "x" -- First time to find this source so mark with x
                            else
                                loadLyric_items[index] = "*" -- Found this source again so mark with *
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
                    local name = t - i .. ". Load lyrics for: <i><b>" .. song .. "</i></b>" -- use index for compare
                    -- Mark Duplicates
                    if index ~= nil then
                        if loadLyric_items[index] == "*" then
                            name = '<span style="color:#FF6050;">' .. name .. " * </span>"
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

source_def.get_name = function()
    return "Prepare Lyric"
end

source_def.update = function(data, settings)
    rename_source() -- Rename and Mark sources instantly on update (WZ)
end

source_def.get_properties = function(data)
    load_song_directory()
    local props = obs.obs_properties_create()
    local source_dir_list =
        obs.obs_properties_add_list(
        props,
        "songs",
        "Song Directory",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    table.sort(song_directory)
    for _, name in ipairs(song_directory) do
        obs.obs_property_list_add_string(source_dir_list, name, name)
    end
    obs.obs_properties_add_bool(props, "source_activate_in_preview", "Activate song in Preview mode") -- Option to load new lyric in preview mode
    obs.obs_properties_add_bool(props, "source_home_on_active", "Go to lyrics home on source activation") -- Option to home new lyric in preview mode
    return props
end

source_def.create = function(settings, source)
    data = {}
    sh = obs.obs_source_get_signal_handler(source)
    obs.signal_handler_connect(sh, "activate", source_active) -- Set Active Callback
    obs.signal_handler_connect(sh, "show", source_showing) -- Set Preview Callback
    obs.signal_handler_connect(sh, "hide", source_hidden) -- Set Preview Callback
    return data
end

source_def.get_defaults = function(settings)
    obs.obs_data_set_default_bool(settings, "source_activate_in_preview", false)
    obs.obs_data_set_default_string(settings, "index", "0")
end

source_def.destroy = function(source)
end

-- function on_event(event)
-- if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
-- set_current_scene_name()
-- rename_source()
-- -- update_source_text()
-- transition_lyric_text(false)
-- end

-- end

function load_song(source, preview)
    dbg_method("load_song")
    local settings = obs.obs_source_get_settings(source)
    if not preview or (preview and obs.obs_data_get_bool(settings, "source_activate_in_preview")) then
        local song = obs.obs_data_get_string(settings, "songs")
        -- if song ~= prepared_songs[prepared_index] then
        if song == nil or song == "" then
            return
        end
        dbg_inner("load_song: " .. song)
        -- local prop_prep_list = obs.obs_properties_get(script_props, "prop_prepared_list")
        -- if scene_load_complete then
        -- 	obs.obs_property_list_item_remove(prop_prep_list, 0)
        -- 	table.remove(prepared_songs , 1)  -- clear older scene loaded song
        -- end
        -- obs.obs_property_list_insert_string(prop_prep_list, 0, song, song)
        -- table.insert(prepared_songs, 1, song)
        -- scene_load_complete = true
        -- obs.obs_data_set_string(script_sets, "prop_prepared_list", song)
        -- obs.obs_properties_apply_settings(script_props, script_sets)

        -- update scene info
        -- set_current_scene_name()
        -- load_scene = current_scene

        using_source = true

        -- prepare song and update lyrics
        -- if (song ~= prepared_songs[prepared_index]) then
        prepare_selected(song)
        -- end

        -- save_prepared()
        -- page_index = 1
        -- prepared_index = 1

        -- update_source_text()
        -- text_opacity = 99
        -- text_fade_dir = 2
        -- transition_lyric_text(true)
        -- end
        -- TODO: ensure home on activate working correctly
        if obs.obs_data_get_bool(settings, "source_home_on_active") then
            home_prepared(true)
        end
    end
    obs.obs_data_release(settings)
end

function source_active(cd)
    local source = obs.calldata_source(cd, "source")
    if source == nil then
        return
    end
    load_song(source, false)
end

function source_showing(cd)
    local source = obs.calldata_source(cd, "source")
    if source == nil then
        return
    end
    -- if sourceActive() then return end
    load_song(source, true)
end

function dbg(message)
    if DEBUG then
        print(message)
    end
end

function dbg_inner(message)
    if DEBUG_INNER then
        dbg("INNER: " .. message)
    end
end

function dbg_method(message)
    if DEBUG_METHODS then
        dbg("METHOD: " .. message)
    end
end

function dbg_custom(message)
    if DEBUG_CUSTOM then
        dbg("CUSTOM: " .. message)
    end
end

obs.obs_register_source(source_def)
