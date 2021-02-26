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

obs = obslua
bit = require("bit")

source_data = {}
source_def = {}
source_def.id = "Prepare_Lyrics"
source_def.type = OBS_SOURCE_TYPE_INPUT;
source_def.output_flags = bit.bor(obs.OBS_SOURCE_CUSTOM_DRAW )

obs = obslua
source_name = ""
alternate_source_name = ""
current_scene = ""
preview_scene = ""
title_source_name = ""
windows_os = false
first_open = true
in_timer = false
in_Load = false
in_directory = false
pause_timer = false
useAlternate = false
display_lines = 1
ensure_lines = true
visible = false
displayed_song = ""
lyrics = {}
refrain = {}
alternate = {}
display_index = 1
prepared_index = 1---
song_directory = {}
prepared_songs = {}
TextSources = {}
hotkey_n_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_p_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_c_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_n_p_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_p_p_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_home_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_reset_id = obs.OBS_INVALID_HOTKEY_ID

script_sets = nil
script_props = nil

text_opacity = 100
text_fade_dir = 0
text_fade_speed = 1
text_fade_enabled = true

------------------------------------------------------------------------- EVENTS
function sourceShowing()
	local source = obs.obs_get_source_by_name(source_name)
	local showing = false
	if source ~= nil then
		showing = obs.obs_source_showing(source)
	end
	obs.obs_source_release(source)	
	return showing
end

function sourceActive()

	local source = obs.obs_get_source_by_name(source_name)
	local active = false
	if source ~= nil then
		--if preview_scene ~= current_scene then
			active = obs.obs_source_active(source)
		--end
		obs.obs_source_release(source)
    end		
	return active
end

function next_lyric(pressed)
	if not pressed or not sourceShowing() then
		return
	end
	if display_index + 1 <= #lyrics then
		display_index = display_index + 1
	else
		next_prepared(true) 
	end
	fade_lyrics_display()
end

function prev_lyric(pressed)
	if not pressed or not sourceShowing() then
		return
	end
	if display_index > 1 then
		display_index = display_index - 1
	else
		prev_prepared(true) 
	end
	fade_lyrics_display()
end

function clear_lyric(pressed)
	if not pressed or not sourceShowing() then
		return
	end
	visible = not visible
	update_lyrics_display()
end


function fade_lyrics_display() 
	if text_fade_enabled then
		if text_opacity == 100 then 
			text_opacity = 99
			text_fade_dir = 1  -- fade out
		end
   	    if text_opacity == 0 then 
			text_opacity = 1
			text_fade_dir = 2  -- fade in
		end
	else
		text_opacity = 100
		text_fade_dir = 2
		update_lyrics_display()
	end
end

function next_prepared(pressed)
	if not pressed then return false end
	if prepared_index >= #prepared_songs then
	   return false
	end
   prepared_index = prepared_index + 1
   prepare_selected(prepared_songs[prepared_index])
   return true
end
                
function prev_prepared(pressed)
	if not pressed then return false end
	if prepared_index == 1 then 
	   return false
	end
	prepared_index = prepared_index - 1
	prepare_selected(prepared_songs[prepared_index])
	return true
end

function get_load_lyric_song()
	local scene = obs.obs_frontend_get_current_scene()
	local scene_items = obs.obs_scene_enum_items(scene)					-- Get list of all items in this scene
	local song = nil
	if scene_items ~= nil then
		for _, scene_item in ipairs(scene_items) do						-- Loop through all scene source items
			local source = obs.obs_sceneitem_get_source(scene_item)		-- Get item source pointer
			local source_id = obs.obs_source_get_unversioned_id(source)	-- Get item source_id
			if source_id == "Prepare_Lyrics" then						-- Skip if not a Prepare_Lyric source item
				local settings = obs.obs_source_get_settings(source)	-- Get settings for this Prepare_Lyric source
				 song = obs.obs_data_get_string(settings, "song")	-- Get index for this source (set earlier)
				obs.obs_data_release(settings)							-- release memory	
			end
		end
	end
	obs.sceneitem_list_release(scene_items)						-- Free scene list
	return song
end

function home_prepared(pressed)
	if not pressed then return false end
	text_opacity = 0
	text_fade_dir = 2
	visible = true
	display_index = 1
	prepared_index = 1
	prepare_selected(prepared_songs[prepared_index])   -- redundant from above
	update_lyrics_display() 
	return true
end

function home_song(pressed)
	if not pressed then return false end
	text_opacity = 0
	text_fade_dir = 2
	visible = true
	display_index = 1
	prepare_selected(prepared_songs[prepared_index])   -- redundant from above
	update_lyrics_display() 
	return true
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
	save_prepared()
	return true
end


function prepare_selection_made(props, prop, settings)
	local name = obs.obs_data_get_string(settings, "prop_prepared_list")
    prepare_selected(name)
	return true
end

function prepare_selected(name)
	if name == nil then return end
	if name == "" then return end
	if name == displayed_song then return end
	prepare_lyrics(name)
	text_opacity = 0
	text_fade_dir = 2
	if displayed_song ~= name then
		display_index = 1
		visible = true   
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
	save_prepared()
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
	else
		tex= ""
	end
	if visible and #alternate > 0 then
		alttext = alternate[display_index]
	else
		alttext = ""
	end		
	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", text)
		obs.obs_data_set_int(settings, "opacity", 0)    
		obs.obs_data_set_int(settings, "outline_opacity", 0)    
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
	end
	obs.obs_source_release(source)
	local alt_source = obs.obs_get_source_by_name(alternate_source_name)
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", alttext)
		obs.obs_data_set_int(settings, "opacity", 0)    
		obs.obs_data_set_int(settings, "outline_opacity", 0)    
		obs.obs_source_update(alt_source, settings)
		obs.obs_data_release(settings)
	end
	obs.obs_source_release(alt_source)	
	local title_source = obs.obs_get_source_by_name(title_source_name)
	if title_source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", displayed_song)
		obs.obs_source_update(title_source, settings)
		obs.obs_data_release(settings)
	end
	obs.obs_source_release(title_source)	
	if visible then
		text_fade_dir = 2   -- new text so just fade up if not already
	end
end

-- text_fade_dir = 1 to fade out and 2 to fade in
function timer_callback()
	if not in_timer and not pause_timer then
		in_timer = true
		if text_fade_dir > 0 then 
			local real_fade_speed = 10 + (text_fade_speed * 3)
			if text_fade_dir == 1 then	
				if text_opacity > real_fade_speed then
				   text_opacity = text_opacity - real_fade_speed
				else
				   text_fade_dir = 0  -- stop fading
				   text_opacity = 0  -- set to 0%
				   update_lyrics_display()
				end   
			else
				if text_opacity < 100 - real_fade_speed then
				   text_opacity = text_opacity + real_fade_speed
				else
				   text_fade_dir = 0  -- stop fading
				   text_opacity = 100 -- set to 100%  (TODO: REad initial text/outline opacity and scale it from there to zero instead)
				end 
			end
			local source = obs.obs_get_source_by_name(source_name)
			if source ~= nil then
				local settings = obs.obs_data_create()
				obs.obs_data_set_int(settings, "opacity", text_opacity)  -- Set new text opacity to zero
				obs.obs_data_set_int(settings, "outline_opacity", text_opacity)  -- Set new text outline opacity to zero			
				obs.obs_source_update(source, settings)
				obs.obs_data_release(settings)
			end
			obs.obs_source_release(source)
			local alt_source = obs.obs_get_source_by_name(alternate_source_name)
			if source ~= nil then
				local settings = obs.obs_data_create()
				obs.obs_data_set_int(settings, "opacity", text_opacity)  -- Set new text opacity to zero
				obs.obs_data_set_int(settings, "outline_opacity", text_opacity)  -- Set new text outline opacity to zero			
				obs.obs_source_update(alt_source, settings)
				obs.obs_data_release(settings)
			end
			obs.obs_source_release(alt_source)				
		end
		in_timer = false
	end
	return
end

-- prepares lyrics of the song
function prepare_lyrics(name)
	if name == nil then return end
	local song_lines = get_song_text(name)
	local cur_line = 1
	local cur_aline = 1
	local recordRefrain = false
	local playRefrain = false
	local showText = true
	refrain = {}
	lyrics = {}
	alternate = {}
	local adjusted_display_lines = display_lines
	for _, line in ipairs(song_lines) do
		local new_lines = 1
		local single_line = false
		if line:find("###") ~= nil then
			line = line:gsub("%s*###%s*", "")
			single_line = true
		end
		local comment_index = line:find("%s*//")
		if comment_index ~= nil then
			line = line:sub(1, comment_index - 1)
			new_lines = 0							--ignore line
		end
		local newcount_index = line:find("#L:")
		if newcount_index ~= nil then
			local iS,iE = line:find("%d+",newcount_index+3)
			adjusted_display_lines = tonumber(line:sub(iS,iE))
			line = line:sub(1, newcount_index - 1)
			new_lines = 0							--ignore line
		end		
		local newcount_index = line:find("#D:")
		if newcount_index ~= nil then 
			local newcount_indexStart,newcount_indexEnd = line:find("%d+",newcount_index+3)		
			new_lines = tonumber(line:sub(newcount_indexStart,newcount_indexEnd))
			_, newcount_indexEnd = line:find("%s+",newcount_indexEnd+1)
			line = line:sub(newcount_indexEnd + 1)	
		end			
		local refrain_index = line:find("#R%[")
		if refrain_index ~= nil then
			if next(refrain) ~= nil then
				for i, _ in ipairs(refrain) do refrain[i] = nil end
			end
			recordRefrain = true
			showText = true
			line = line:sub(1, refrain_index - 1)
			new_lines = 0	
		end
		local refrain_index = line:find("#r%[")
		if refrain_index ~= nil then
			if next(refrain) ~= nil then
				for i, _ in ipairs(refrain) do refrain[i] = nil end
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
		local alternate_index = line:find("#A%[")
		if alternate_index ~= nil then
			useAlternate = true
			line = line:sub(1, alternate_index - 1)
			new_lines = 0	
		end
		alternate_index = line:find("#A]")
		if alternate_index ~= nil then
			useAlternate = false
			line = line:sub(1, alternate_index - 1)
			new_lines = 0	
		end			
		local newcount_index = line:find("#P:")
		if newcount_index ~= nil then
			new_lines = tonumber(line:sub(newcount_index+3))
			line = line:sub(1, newcount_index - 1)	
		end	
		local newcount_index = line:find("#B:")
		if newcount_index ~= nil then
			new_lines = tonumber(line:sub(newcount_index+3))
			line = line:sub(1, newcount_index - 1)
		end			
		local phantom_index = line:find("##P")
		if phantom_index ~= nil then
			line = line:sub(1, phantom_index - 1)
		end	
		local phantom_index = line:find("##B")
		if phantom_index ~= nil then
			line = line:sub(1, phantom_index - 1)
		end
		if useAlternate then
			if new_lines > 0 then 		
				while (new_lines > 0) do
					if showText and line ~= nil then
						if (cur_aline == 1) then
							alternate[#alternate + 1] = line
						else
							alternate[#alternate] = alternate[#alternate] .. "\n" .. line
						end
					end
					cur_aline = cur_aline + 1
					if single_line or cur_aline > adjusted_display_lines then
						if ensure_lines then
							for i = cur_aline, display_lines, 1 do
								cur_aline = i
								if showText and alternate[#alternate] ~= nil then
									alternate[#alternate] = alternate[#alternate] .. "\n"
								end
							end
						end
						cur_aline = 1
					end
					new_lines = new_lines - 1
				end
			end
		else
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
					if single_line or cur_line > adjusted_display_lines then
						if ensure_lines then
							for i = cur_line, display_lines, 1 do
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
		if playRefrain == true then
			for _, refrain_line in ipairs(refrain) do
				lyrics[#lyrics + 1] = refrain_line
			end
		end
	end
	if ensure_lines and lyrics[#lyrics] ~= nil and cur_line > 1 then
		for i = cur_line, display_lines, 1 do
			cur_line = i
			if useAlternate then
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
end

-- loads the song directory
function load_song_directory()
	pause_timer = true
	song_directory = {}
	local filenames = {}
	local dir = obs.os_opendir(get_songs_folder_path())--get_songs_folder_path())
	local entry
	local songExt
	local songTitle
	repeat
	  entry = obs.os_readdir(dir)
	  if entry and not entry.directory and obs.os_get_path_extension(entry.d_name)==".txt" then
		songExt = obs.os_get_path_extension(entry.d_name)
		songTitle=string.sub(entry.d_name, 0, string.len(entry.d_name) - string.len(songExt))
		song_directory[#song_directory + 1] = songTitle
	  end
	until not entry
	obs.os_closedir(dir)
	pause_timer = false
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

-- saves preprepared songs
function save_prepared()
	local file = io.open(get_songs_folder_path() .. "/" .. "Prepared.dat", "w")
    for i, name in ipairs(prepared_songs) do
		file:write(name, "\n")
	end
	file:close()
	return true
end

function load_prepared()
	pause_timer = true
	local file = io.open(get_songs_folder_path() .. "/" .. "Prepared.dat", "r")
	if file ~= nil then
		for line in file:lines() do
			prepared_songs[#prepared_songs + 1] = line
		end
		
		file:close()
	end
	pause_timer = false
	return true
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
		pause_timer = true
		for line in file:lines() do
			song_lines[#song_lines + 1] = line
		end
		file:close()
		pause_timer = false
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
	table.sort(song_directory)
	for _, name in ipairs(song_directory) do
		obs.obs_property_list_add_string(prop_dir_list, name, name)
	end
	obs.obs_property_set_modified_callback(prop_dir_list, preview_selection_made)
	obs.obs_properties_add_button(script_props, "prop_prepare_button", "Prepare Song", prepare_song_clicked)
	obs.obs_properties_add_button(script_props, "prop_delete_button", "Delete Song", delete_song_clicked)
	obs.obs_properties_add_button(script_props, "prop_open_button", "Open Songs Folder", open_button_clicked)

	obs.obs_properties_add_int(script_props, "prop_lines_counter", "Lines to Display", 1, 100, 1)
	obs.obs_properties_add_bool(script_props, "prop_lines_bool", "Strictly ensure number of lines")
	obs.obs_properties_add_bool(script_props, "text_fade_enabled", "Fade Text Out/In for Next Lyric")	-- Fade Enable (WZ)
	obs.obs_properties_add_int_slider(script_props, "text_fade_speed", "Fade Speed", 1, 10, 1)
	local source_prop = obs.obs_properties_add_list(script_props, "prop_source_list", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local title_source_prop = obs.obs_properties_add_list(script_props, "prop_title_list", "Title Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local alternate_source_prop = obs.obs_properties_add_list(script_props, "prop_alternate_list", "Alternate Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		local n = {}
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_unversioned_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
				n[#n+1] = obs.obs_source_get_name(source)
			end
		end
		table.sort(n)
		for _, name in ipairs(n) do
			obs.obs_property_list_add_string(source_prop, name, name)
			obs.obs_property_list_add_string(title_source_prop, name, name)	
			obs.obs_property_list_add_string(alternate_source_prop, name, name)	
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
	obs.obs_properties_add_button(script_props, "prop_home_button", "Reset to Song Start", home_button_clicked)
	obs.obs_properties_add_button(script_props, "prop_reset_button", "Reset to First Song", reset_button_clicked)	
	obs.obs_data_set_string(script_sets, "prop_prepared_list", prepared_songs[1])
	obs.obs_properties_apply_settings(script_props, script_sets)
	
	return script_props
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Manage song lyrics to be displayed as subtitles -  author: amirchev & DC Strato; with significant contributions from taxilian. Alt-Text Test V1.0"
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
    text_fade_enabled = obs.obs_data_get_bool(settings, "text_fade_enabled")   -- 	Fade Enable (WZ)
	text_fade_speed = obs.obs_data_get_int(settings, "text_fade_speed")   -- 	Fade Speed (WZ)	
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
	if reload then
		prepare_lyrics(displayed_song)
		display_index = 1
		--update_lyrics_display()
	end
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	obs.obs_data_set_default_int(settings, "prop_lines_counter", 2)
	obs.obs_data_set_default_string(settings, "prop_source_list", prepared_songs[1] )
	if #prepared_songs ~= 0 then 
	    displayed_song = prepared_songs[1]
	else
		displayed_song = ""
	end
	if os.getenv("HOME") == nil then windows_os = true end -- must be set prior to calling any file functions
	if windows_os then
		os.execute("mkdir \"" .. get_songs_folder_path() .. "\"")
	else
		os.execute("mkdir -p \"" .. get_songs_folder_path() .. "\"")
	end
end

-- A function named script_save will be called when the script is saved
function script_save(settings)
    save_prepared()
	local hotkey_save_array = obs.obs_hotkey_save(hotkey_n_id)
	obs.obs_data_set_array(settings, "lyric_next_hotkey", hotkey_save_array)
	--hotkey_save_array = obs.obs_hotkey_save(hotkey_n_id)
	obs.obs_data_array_release(hotkey_save_array)
	
	hotkey_save_array = obs.obs_hotkey_save(hotkey_p_id)
	obs.obs_data_set_array(settings, "lyric_prev_hotkey", hotkey_save_array)
	--hotkey_save_array = obs.obs_hotkey_save(hotkey_p_id)
	obs.obs_data_array_release(hotkey_save_array)
	
	hotkey_save_array = obs.obs_hotkey_save(hotkey_c_id)
	obs.obs_data_set_array(settings, "lyric_clear_hotkey", hotkey_save_array)
	--hotkey_save_array = obs.obs_hotkey_save(hotkey_c_id)
	obs.obs_data_array_release(hotkey_save_array)
                
	hotkey_save_array = obs.obs_hotkey_save(hotkey_n_p_id)
	obs.obs_data_set_array(settings, "next_prepared_hotkey", hotkey_save_array)
	--hotkey_save_array = obs.obs_hotkey_save(hotkey_n_p_id)
	obs.obs_data_array_release(hotkey_save_array)
                
	hotkey_save_array = obs.obs_hotkey_save(hotkey_p_p_id)
	obs.obs_data_set_array(settings, "previous_prepared_hotkey", hotkey_save_array)
	--hotkey_save_array = obs.obs_hotkey_save(hotkey_p_p_id)
	obs.obs_data_array_release(hotkey_save_array)
	
	hotkey_save_array = obs.obs_hotkey_save(hotkey_home_id)
	obs.obs_data_set_array(settings, "home_song_hotkey", hotkey_save_array)
	--hotkey_save_array = obs.obs_hotkey_save(hotkey_home_id)
	obs.obs_data_array_release(hotkey_save_array)
	
	hotkey_save_array = obs.obs_hotkey_save(hotkey_reset_id)
	obs.obs_data_set_array(settings, "reset_prepared_hotkey", hotkey_save_array)
	--hotkey_save_array = obs.obs_hotkey_save(hotkey_home_id)
	obs.obs_data_array_release(hotkey_save_array)
end

-- a function named script_load will be called on startup
function script_load(settings)
	hotkey_n_id = obs.obs_hotkey_register_frontend("lyric_next_hotkey", "Advance Lyrics", next_lyric)
	local hotkey_save_array = obs.obs_data_get_array(settings, "lyric_next_hotkey")
	obs.obs_hotkey_load(hotkey_n_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
	
	hotkey_p_id = obs.obs_hotkey_register_frontend("lyric_prev_hotkey", "Go Back Lyrics", prev_lyric)
	hotkey_save_array = obs.obs_data_get_array(settings, "lyric_prev_hotkey")
	obs.obs_hotkey_load(hotkey_p_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
	
	hotkey_c_id = obs.obs_hotkey_register_frontend("lyric_clear_hotkey", "Show/Hide Lyrics", clear_lyric)
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
	
	hotkey_reset_id = obs.obs_hotkey_register_frontend("reset_prepared_hotkey", "Reset to First Song", home_prepared)
	hotkey_save_array = obs.obs_data_get_array(settings, "reset_prepared_hotkey")
	obs.obs_hotkey_load(hotkey_reset_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)

	--obs.obs_data_addref(settings)
	script_sets = settings
	source_name = obs.obs_data_get_string(settings, "prop_source_list")
	if os.getenv("HOME") == nil then windows_os = true end -- must be set prior to calling any file functions
	load_song_directory()
	load_prepared()
	if #prepared_songs ~= 0 then
	  prepare_selected(prepared_songs[1])
	end

	obs.obs_frontend_add_event_callback(on_event)    -- Setup Callback for Source * Marker (WZ)
	obs.timer_add(timer_callback, 100)	-- Setup callback for text fade effect
end

-- Function renames source to a unique descriptive name and marks duplicate sources with *  (WZ)
function rename_prepareLyric()  
	pause_timer = true
	TextSources = {}
	local sources = obs.obs_enum_sources()
	if (sources ~= nil) then
			-- count and index sources
		local t = 1
		for _, source in ipairs(sources) do
			local source_id = obs.obs_source_get_unversioned_id(source)
			if source_id == "Prepare_Lyrics" then
				local settings = obs.obs_source_get_settings(source)
				obs.obs_data_set_string(settings, "index", t)		-- add index to source data
				t = t + 1
				obs.obs_data_release(settings)		-- release memory
			end
		end
		-- Find and mark Duplicates in loadLyric_items table
		local loadLyric_items = {}													-- Start Table for all load Sources	
		local scenes = obs.obs_frontend_get_scenes()								-- Get list of all scene items 
		if scenes ~= nil then
			for _, scenesource in ipairs(scenes) do									-- Loop through all scenes	
				local scene = obs.obs_scene_from_source(scenesource)				-- Get scene pointer	
				local scene_name = obs.obs_source_get_name(scenesource)				-- Get scene name
				local scene_items = obs.obs_scene_enum_items(scene)					-- Get list of all items in this scene
				if scene_items ~= nil then
					for _, scene_item in ipairs(scene_items) do						-- Loop through all scene source items
						local source = obs.obs_sceneitem_get_source(scene_item)		-- Get item source pointer
						local source_id = obs.obs_source_get_unversioned_id(source)	-- Get item source_id
						if source_id == "Prepare_Lyrics" then						-- Skip if not a Prepare_Lyric source item
							local settings = obs.obs_source_get_settings(source)	-- Get settings for this Prepare_Lyric source
							local index = obs.obs_data_get_string(settings, "index")	-- Get index for this source (set earlier)
							if loadLyric_items[index] == nil then					
								loadLyric_items[index] = "x"							-- First time to find this source so mark with x
							else
								loadLyric_items[index] = "*"							-- Found this source again so mark with *
							end
							obs.obs_data_release(settings)							-- release memory	
						end
					end
				end
				obs.sceneitem_list_release(scene_items)						-- Free scene list
			end
			obs.source_list_release(scenes)											-- Free source list
		end
		
		-- Name Source with Song Title
		local i = 1
		for _, source in ipairs(sources) do
			local source_id = obs.obs_source_get_unversioned_id(source)						-- Get source
			if source_id == "Prepare_Lyrics" then									-- Skip if not a Load Lyric source
				local c_name = obs.obs_source_get_name(source)				-- Get current Source Name
				local settings = obs.obs_source_get_settings(source)				-- Get settings for this source
				local song = obs.obs_data_get_string(settings, "songs")		-- Get the current song name to load
				local index = obs.obs_data_get_string(settings, "index")		-- get index
				if (song ~= nil) then 
					local name = t-i .. ". Load lyrics for: <i><b>" .. song .. "</i></b>"	-- use index for compare
					-- Mark Duplicates
					if index ~= nil then
						if loadLyric_items[index] == "*" then
							name =  "<span style=\"color:#FF6050;\">" .. name .. " * </span>"
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
	pause_timer = false
end

source_def.get_name = function()
	return "Prepare Lyric"
end

source_def.update = function (data, settings)
		rename_prepareLyric()						-- Rename and Mark sources instantly on update (WZ)
end

source_def.get_properties = function (data)
	rename_prepareLyric()  
	load_song_directory()
	local props = obs.obs_properties_create()
	local source_dir_list = obs.obs_properties_add_list(props, "songs", "Song Directory", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	table.sort(song_directory)
	for _, name in ipairs(song_directory) do
		obs.obs_property_list_add_string(source_dir_list, name, name)
	end
	obs.obs_properties_add_bool(props,"inPreview","Change Lyrics in Preview Mode")  -- Option to load new lyric in preview mode
	obs.obs_properties_add_bool(props,"autoHome","Home Lyrics with Scene")  -- Option to home new lyric in preview mode	return props
	return props
end

source_def.create = function(settings, source)
    data = {}
	sh = obs.obs_source_get_signal_handler(source)
	obs.signal_handler_connect(sh,"activate",active)   --Set Active Callback
	obs.signal_handler_connect(sh,"show",showing)	   --Set Preview Callback
	return data
end

source_def.get_defaults = function(settings) 
   obs.obs_data_set_default_bool(settings, "inPreview", false)
   obs.obs_data_set_default_string(settings,"index","0")
end

source_def.destroy = function(source)

end

function on_event(event)
	if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
		rename_prepareLyric()  	
	end
end

function loadSong(source, preview)
	local settings = obs.obs_source_get_settings(source)
	if not preview or (preview and obs.obs_data_get_bool(settings, "inPreview")) then 
		local song = obs.obs_data_get_string(settings, "songs")
		if song ~= displayed_song then 
		    --prepared_songs[1] = song
			prepare_selected(song)
			prepared_index = 1
			displayed_song = song
		end
		if obs.obs_data_get_bool(settings, "autoHome") then
		    home_prepared(true)
		end
		fade_lyrics_display()    
	end
	obs.obs_data_release(settings)
end

function active(cd)
	local source = obs.calldata_source(cd,"source")
	if source == nil then 
		return
	end
	loadSong(source,false)
end

function showing(cd)
    local source = obs.calldata_source(cd,"source")
	if source == nil then
		return
	end
	if sourceActive() then return end
	loadSong(source,true)
end


obs.obs_register_source(source_def);
