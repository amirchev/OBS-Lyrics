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



--TODO: refresh properties after next prepared selection
--TODO: add text formatting guide
obs = obslua
source_name = ""
windows_os = false
first_open = true

display_lines = 1
ensure_lines = true
visible = false
displayed_song = ""
lyrics = {}
display_index = 1
song_directory = {}
prepared_songs = {}

hotkey_n_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_p_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_c_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_n_p_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_p_p_id = obs.OBS_INVALID_HOTKEY_ID

script_sets = nil
script_props = nil

------------------------------------------------------------------------- EVENTS

function next_lyric(pressed)
	if not pressed then
		return
	end
	if display_index + 1 <= #lyrics then
		display_index = display_index + 1
	else
		if next_prepared(true) then visible = true end
	end
	update_lyrics_display()
end

function prev_lyric(pressed)
	if not pressed then
		return
	end
	if display_index > 1 then
		display_index = display_index - 1
		update_lyrics_display()
	end
end

function clear_lyric(pressed)
	if not pressed then
		return
	end
	visible = not visible
	update_lyrics_display()
end
                
function next_prepared(pressed)
	if not pressed then return false end
	--if current index < size, then current index ++
	local prop_prep_list = obs.obs_properties_get(script_props, "prop_prepared_list")
	local prepared_song_amount = obs.obs_property_list_item_count(prop_prep_list)
	if prepared_song_amount < 2 then return end
	for i = 0, prepared_song_amount - 2 do
		if obs.obs_property_list_item_string(prop_prep_list, i) == displayed_song then
			local next_song = obs.obs_property_list_item_string(prop_prep_list, i + 1)
			obs.obs_data_set_string(script_sets, "prop_prepared_list", next_song)
			obs.obs_properties_apply_settings(script_props, script_sets)
			return true
		end
	end
	return false
end
                
function prev_prepared(pressed)
	if not pressed then return end
	--if current index > 0, then current index ++
	local prop_prep_list = obs.obs_properties_get(script_props, "prop_prepared_list")
	local prepared_song_amount = obs.obs_property_list_item_count(prop_prep_list)
	if prepared_song_amount < 2 then return end
	for i = 1, prepared_song_amount - 1 do
		if obs.obs_property_list_item_string(prop_prep_list, i) == displayed_song then
			local next_song = obs.obs_property_list_item_string(prop_prep_list, i - 1)
			obs.obs_data_set_string(script_sets, "prop_prepared_list", next_song)
			obs.obs_properties_apply_settings(script_props, script_sets)
			return
		end
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

function clear_button_clicked(props, p)
	clear_lyric(true)
	return true
end

function save_song_clicked(props, p)
	local name = obs.obs_data_get_string(script_sets, "prop_edit_song_title")
	local text = obs.obs_data_get_string(script_sets, "prop_edit_song_text")
	if save_song(name, text) then -- this is a new song
		local prop_dir_list = obs.obs_properties_get(props, "prop_directory_list")
		obs.obs_property_list_add_string(prop_dir_list, name, name)
		obs.obs_data_set_string(script_sets, "prop_directory_list", name)
		obs.obs_properties_apply_settings(props, script_sets)
	elseif displayed_song == name then
		prepare_lyrics(name)
		update_lyrics_display()
	end
	return true
end

function delete_song_clicked(props, p)
	local name = obs.obs_data_get_string(script_sets, "prop_directory_list")
	delete_song(name)
	local prop_dir_list = obs.obs_properties_get(props, "prop_directory_list")
	for i = 0, obs.obs_property_list_item_count(prop_dir_list) do
		if obs.obs_property_list_item_string(prop_dir_list, i) == name then
			obs.obs_property_list_item_remove(prop_dir_list, i)
			if i > 1 then i = i - 1 end
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
					if i > 1 then i = i - 1 end
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
	prepared_songs[#prepared_songs + 1] = obs.obs_data_get_string(script_sets, "prop_directory_list")
	local prop_prep_list = obs.obs_properties_get(props, "prop_prepared_list")
	obs.obs_property_list_add_string(prop_prep_list, prepared_songs[#prepared_songs], prepared_songs[#prepared_songs])
	if #prepared_songs == 1 then 
		obs.obs_data_set_string(script_sets, "prop_prepared_list", prepared_songs[#prepared_songs])
	end
	obs.obs_properties_apply_settings(props, script_sets)
	return true
end

function prepare_selection_made(props, prop, settings)
	local name = obs.obs_data_get_string(settings, "prop_prepared_list")
	prepare_lyrics(name)
	if displayed_song ~= name then
		display_index = 1
		visible = false
	end
	displayed_song = name
	update_lyrics_display()
	return true
end

-- called when selection is made from directory list
function preview_selection_made(props, prop, settings)
	local name = obs.obs_data_get_string(script_sets, "prop_directory_list")
	
	if get_index_in_list(song_directory, name) == nil then return end -- do nothing if invalid name
	
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
	prepared_songs = {}
	lyrics = {}
	update_lyrics_display()
	local prep_prop = obs.obs_properties_get(props, "prop_prepared_list")
	obs.obs_property_list_clear(prep_prop)
	obs.obs_data_set_string(script_sets, "prop_prepared_list", "")
	obs.obs_properties_apply_settings(props, script_sets)
	return true
end

function open_button_clicked(props, p)
	if windows_os then
		os.execute("explorer \"" .. get_songs_folder_path() .. "\"")
	else
		os.execute("xdg-open \"" .. get_songs_folder_path() .. "\"")
	end
end
-------------------------------------------------------------- PROGRAM FUNCTIONS

-- updates the displayed lyrics
function update_lyrics_display()
	local text = ""
	if visible and #lyrics > 0 then
		text = lyrics[display_index]
	end
	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", text)
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end
end


-- prepares lyrics of the song
function prepare_lyrics(name)
	if name == nil then return end
	local song_lines = get_song_text(name)
	local cur_line = 1
	lyrics = {}
	for _, line in ipairs(song_lines) do
		local single_line = false
		if line:find("###") ~= nil then
			line = line:gsub("%s*###%s*", "")
			single_line = true
		end
		local comment_index = line:find("%s*//")
		if comment_index ~= nil then
			line = line:sub(1, comment_index - 1)
		end
		
		if line:len() > 0 then 
			if single_line then
				lyrics[#lyrics + 1] = line
				cur_line = 1
			else
				if cur_line == 1 then
					lyrics[#lyrics + 1] = line
				else
					lyrics[#lyrics] = lyrics[#lyrics] .. "\n" .. line
				end
				cur_line = cur_line + 1
				if (cur_line > display_lines) then
					cur_line = 1
				end
			end
		end
	end
	if ensure_lines and cur_line <= display_lines then
		for i = cur_line, display_lines, 1 do
			lyrics[#lyrics] = lyrics[#lyrics] .. "\n"
		end
	end
	lyrics[#lyrics + 1] = ""
end

-- loads the song directory
function load_song_directory()
    song_directory = {}
	if windows_os then
		local res = io.popen("dir \"" .. get_songs_folder_path() .. "\" /b")
		if res ~= nil then
			for line in res:lines() do
				song_directory[#song_directory + 1] = line:match("(.-).txt")
			end
		end
	else
		local res = io.popen("ls \"" .. get_songs_folder_path() .. "\"")
		if res ~= nil then
			for line in res:gmatch("%s*(.-).txt") do
				song_directory[#song_directory + 1] = line
			end
		end
	end
end

-- delete previewed song
function delete_song(name)
	os.remove(get_song_file_path(name))
	table.remove(song_directory, get_index_in_list(song_directory, name))
	load_song_directory()
end

-- saves previewed song, return true if new song
function save_song(name, text)
	local file = io.open(get_song_file_path(name), "w")
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

-- finds the index of a song in the directory
function get_index_in_list(list, q_item)
	for index, item in ipairs(list) do
		if item == q_item then return index end
	end
	return nil
end

----------------------------------------------------------------- FILE FUNCTIONS

-- returns path of the given song name
function get_song_file_path(name)
	if name == nil then return nil end
    return get_songs_folder_path() .. "/" .. name .. ".txt"
end

-- returns path of the lyrics songs folder
function get_songs_folder_path()
    local sep = package.config:sub(1,1)
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
	local file = io.open(get_song_file_path(name), "r")
	if file ~= nil then
		for line in file:lines() do
			song_lines[#song_lines + 1] = line
		end
		file:close()
	end
	return song_lines
end

---------------------------------------------------------- OBS DEFAULT FUNCTIONS

-------- UI
-- song title textbox
-- song text textarea
-- save button
-- song directory list
-- preview song button
-- prepare song button
-- delete song button
-- lines to display counter
-- text source list
-- prepared songs list
-- clear prepared button
-- advance lyric button
-- go back lyric button
-- show/hide lyrics button

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
	script_props = obs.obs_properties_create()
	
	obs.obs_properties_add_text(script_props, "prop_edit_song_title", "Song Title", obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_text(script_props, "prop_edit_song_text", "Song Lyrics", obs.OBS_TEXT_MULTILINE)
	obs.obs_properties_add_button(script_props, "prop_save_button", "Save Song", save_song_clicked)
	
	local prop_dir_list = obs.obs_properties_add_list(script_props, "prop_directory_list", "Song Directory", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	for _, name in ipairs(song_directory) do
		obs.obs_property_list_add_string(prop_dir_list, name, name)
	end
	obs.obs_property_set_modified_callback(prop_dir_list, preview_selection_made)
	obs.obs_properties_add_button(script_props, "prop_prepare_button", "Prepare Song", prepare_song_clicked)
	obs.obs_properties_add_button(script_props, "prop_delete_button", "Delete Song", delete_song_clicked)
	obs.obs_properties_add_button(script_props, "prop_open_button", "Open Songs Folder", open_button_clicked)

	obs.obs_properties_add_int(script_props, "prop_lines_counter", "Lines to Display", 1, 100, 1)
	obs.obs_properties_add_bool(script_props, "prop_lines_bool", "Strictly ensure number of lines")
	local source_prop = obs.obs_properties_add_list(script_props, "prop_source_list", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_unversioned_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(source_prop, name, name)
			end
		end
	end
	obs.source_list_release(sources)
	
	
	local prep_prop = obs.obs_properties_add_list(script_props, "prop_prepared_list", "Prepared Songs", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	for _, name in ipairs(prepared_songs) do
		obs.obs_property_list_add_string(prep_prop, name, name)
	end
	obs.obs_property_set_modified_callback(prep_prop, prepare_selection_made)
	obs.obs_properties_add_button(script_props, "prop_clear_button", "Clear Prepared Songs", clear_prepared_clicked)

	obs.obs_properties_add_button(script_props, "prop_next_button", "Next Lyric", next_button_clicked)
	obs.obs_properties_add_button(script_props, "prop_prev_button", "Previous Lyric", prev_button_clicked)
	obs.obs_properties_add_button(script_props, "prop_hide_button", "Show/Hide Lyrics", clear_button_clicked)

	return script_props
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Manage song lyrics to be displayed as subtitles -  author: amirchev"
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
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
	local cur_ensure_lines = obs.obs_data_get_bool(settings, "prop_lines_bool")
	if cur_ensure_lines ~= ensure_lines then
		ensure_lines = cur_ensure_lines
		reload = true
	end
	if reload then
		prepare_lyrics(displayed_song)
		display_index = 1
		update_lyrics_display()
	end
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	obs.obs_data_set_default_int(settings, "prop_lines_counter", 2)
	
	if os.getenv("HOME") == nil then windows_os = true end -- must be set prior to calling any file functions
	if windows_os then
		os.execute("mkdir \"" .. get_songs_folder_path() .. "\"")
	else
		os.execute("mkdir -p \"" .. get_songs_folder_path() .. "\"")
	end
end

-- A function named script_save will be called when the script is saved
function script_save(settings)
	local hotkey_save_array = obs.obs_hotkey_save(hotkey_n_id)
	obs.obs_data_set_array(settings, "lyric_next_hotkey", hotkey_save_array)
	hotkey_save_array = obs.obs_hotkey_save(hotkey_n_id)
	obs.obs_data_array_release(hotkey_save_array)
	
	hotkey_save_array = obs.obs_hotkey_save(hotkey_p_id)
	obs.obs_data_set_array(settings, "lyric_prev_hotkey", hotkey_save_array)
	hotkey_save_array = obs.obs_hotkey_save(hotkey_p_id)
	obs.obs_data_array_release(hotkey_save_array)
	
	hotkey_save_array = obs.obs_hotkey_save(hotkey_c_id)
	obs.obs_data_set_array(settings, "lyric_clear_hotkey", hotkey_save_array)
	hotkey_save_array = obs.obs_hotkey_save(hotkey_c_id)
	obs.obs_data_array_release(hotkey_save_array)
                
	hotkey_save_array = obs.obs_hotkey_save(hotkey_n_p_id)
	obs.obs_data_set_array(settings, "next_prepared_hotkey", hotkey_save_array)
	hotkey_save_array = obs.obs_hotkey_save(hotkey_n_p_id)
	obs.obs_data_array_release(hotkey_save_array)
                
	hotkey_save_array = obs.obs_hotkey_save(hotkey_p_p_id)
	obs.obs_data_set_array(settings, "previous_prepared_hotkey", hotkey_save_array)
	hotkey_save_array = obs.obs_hotkey_save(hotkey_p_p_id)
	obs.obs_data_array_release(hotkey_save_array)
end

-- a function named script_load will be called on startup
function script_load(settings)
	hotkey_n_id = obs.obs_hotkey_register_frontend("lyric_next_hotkey_thing", "Advance Lyrics", next_lyric)
	hotkey_p_id = obs.obs_hotkey_register_frontend("lyric_prev_hotkey_thing", "Go Back Lyrics", prev_lyric)
	hotkey_c_id = obs.obs_hotkey_register_frontend("lyric_clear_hotkey_thing", "Show/Hide Lyrics", clear_lyric)
	hotkey_n_p_id = obs.obs_hotkey_register_frontend("next_prepared_hotkey_thing", "Prepare Next", next_prepared)
	hotkey_p_p_id = obs.obs_hotkey_register_frontend("previous_prepared_hotkey_thing", "Prepare Previous", prev_prepared)
	
	local hotkey_save_array = obs.obs_data_get_array(settings, "lyric_next_hotkey")
	obs.obs_hotkey_load(hotkey_n_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
	
	hotkey_save_array = obs.obs_data_get_array(settings, "lyric_prev_hotkey")
	obs.obs_hotkey_load(hotkey_p_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
	
	hotkey_save_array = obs.obs_data_get_array(settings, "lyric_clear_hotkey")
	obs.obs_hotkey_load(hotkey_c_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
	
	hotkey_save_array = obs.obs_data_get_array(settings, "next_prepared_hotkey")
	obs.obs_hotkey_load(hotkey_n_p_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
	
	hotkey_save_array = obs.obs_data_get_array(settings, "previous_prepared_hotkey")
	obs.obs_hotkey_load(hotkey_p_p_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)

	obs.obs_data_addref(settings)
	script_sets = settings
	if os.getenv("HOME") == nil then windows_os = true end -- must be set prior to calling any file functions
	load_song_directory()
end