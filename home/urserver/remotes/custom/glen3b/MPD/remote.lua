local tid = -1;
local toggleButtonUpdateTId = -1;

-- https://github.com/GUI/lua-shell-games
local shell = require "shell-games"

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

events.focus = function ()
	-- pass "forceArtUpdate" to be aggressive about art display
	update_status();
	update_library();
end

events.blur = function ()
	last_file = "";
	libs.timer.cancel(tid);
end

function magiclines(s)
	if s:sub(-1)~="\n" then s=s.."\n" end
	return s:gmatch("(.-)\n")
end

function callCommandEscaped(args)
	local result, err = shell.capture_combined(args)
	if err then
		return nil;
	end
	
	if result["status"] ~= 0 then
		return nil;
	end

	return result["output"];
end

function art(file)
	return callCommandEscaped({ "/home/glen/bin/mpc-song-img", file });
end

function callCommand(cmd)
	local success, ex = pcall(function ()
		pout,perr,presult = libs.script.shell(cmd);
	end);

	if (not success or presult ~= 0) then return nil; end

	return pout;
end

function toggleButtonUpdate(verb, isChecked)
	if (togglebuttons_uifromstatus_update) then return; end

	togglebuttons_updating = true;
	if (verb == "singleoneshot") then
		if (isChecked) then callCommand("/home/glen/bin/mpc-single-oneshot");
		else callCommand("mpc single 0"); end
	else
		callCommand("mpc " .. verb .. " " .. (isChecked and "1" or "0"));
	end
	-- Add delay so that buttons don't "jump" due to an incoming status update
	if (toggleButtonUpdateTId ~= -1) then libs.timer.cancel(toggleButtonUpdateTId); end
	toggleButtonUpdateTId = libs.timer.timeout(function ()
		togglebuttons_updating = false;
	end, 1500);
end

------------------------------------------------------------------------
-- Status
------------------------------------------------------------------------

local pos = 0;
local length = 0;
local seeking = false;
local seeking_pos = 0;
local last_file = "";

local togglebuttons_updating = false;
-- a hack: don't call our event handlers when we change status
local togglebuttons_uifromstatus_update = false;

function update_status_core(specialKey)
	local resp = callCommand("/home/glen/bin/mpc-state-xml");
	if (resp == nil or resp == "") then
		return false;
	end
	
	local root = libs.data.fromxml(resp);
	local title = "";
	local file = "";
	local playing = false;
	local isRepeat = false;
	local isRandom = false;
	local isSingle = false;
	local isConsume = false;
	local vol = 0;

	for k,v in pairs(root.children) do
		if (v.name == "state") then playing = v.text == "play"; end
		if (v.name == "time") then pos = tonumber(v.text); end
		if (v.name == "length") then length = tonumber(v.text); end
		if (v.name == "volume") then vol = tonumber(v.text); end
		if (v.name == "repeat") then isRepeat = string.lower(v.text) == "true"; end
		if (v.name == "random") then isRandom = string.lower(v.text) == "true"; end
		if (v.name == "singleoneshot") then isSingle = string.lower(v.text) == "true"; end
		if (v.name == "consume") then isConsume = string.lower(v.text) == "true"; end
		if (v.name == "information") then
			for k2,v2 in pairs(v.children) do
				if (v2.name == "title") then title = v2.text; end
				if (v2.name == "file") then file = v2.text; end
			end
		end
		if (v.name == "playlist") then update_playlist(v); end
	end
	
	local icon = "play";
	if (playing) then
		icon = "pause";
	end
	
	local image = nil;
	if (last_file ~= file or specialKey == "forceArtUpdate") then
		resp = art(file);
		if (resp ~= nil) then
			image = resp;
		else
			image = "";
		end
		last_file = file;
	end
	
	if (title == "") then
		if (file == "") then
			title = "[Not Playing]";
		else
			title = file;
		end
	end
	
	if (seeking) then
		pos = seeking_pos;
	end
	
	libs.server.update(
		{ id = "title", text = title },
		{ id = "info", text = info },
		{ id = "pos", progress = math.floor(pos), progressmax = math.floor(length), text = libs.data.sec2span(pos) .. " / " .. libs.data.sec2span(length) },
		{ id = "vol", progress = vol, progressmax = 100},
		{ id = "play", icon = icon }
	);

	if (image ~= nill) then
		libs.server.update({ id = "art", image = image });
	end

	if (not togglebuttons_updating) then
		togglebuttons_uifromstatus_update = true;
		libs.server.update(
			{ id = "playback_random_toggle", checked = isRandom },
			{ id = "playlist_random_toggle", checked = isRandom },
			{ id = "playback_repeat_toggle", checked = isRepeat },
			{ id = "playlist_consume_toggle", checked = isConsume },
			{ id = "playlist_singleoneshot_toggle", checked = isSingle }
		);
		-- ah, timeouts, the sign of impeccably clean code
		libs.timer.timeout(function()
			togglebuttons_uifromstatus_update = false;
		end, 250);
	end

	return true;
end

-- one-time special key for behavior
function update_status(specialKey)
	update_status_core(specialKey);
	tid = libs.timer.timeout(update_status, 500);
end

------------------------------------------------------------------------
-- Library
------------------------------------------------------------------------

local libraryListLevel = nil;
local librarySelectedArtist = nil;
local librarySelectedAlbum = nil;
local libraryWidgetList = {};

function update_library_widget(elemList)
	libraryWidgetList = elemList;
	libs.server.update({ id = "library_list", children = elemList });
end

-- select: clicked on something
actions.library_select = function (i)
	local itemName = libraryWidgetList[i+1].text;
	if (libraryListLevel == "song") then
		if i == 0 then
			libs.device.toast("Enqueueing album " .. librarySelectedAlbum .. "...");
			enqueue_current_album();
		else
			libs.device.toast("Enqueueing " .. itemName .. "...");
			play_item(itemName);
		end
	elseif (libraryListLevel == "album") then
		librarySelectedAlbum = itemName;
		library_song_list();
	elseif (libraryListLevel == "artist") then
		librarySelectedArtist = itemName;
		library_album_list();
	end
end

function enqueue_current_album()
	callCommandEscaped({"mpc", "findadd", "album", librarySelectedAlbum });
end

function play_item (title)
	local songFiles = callCommandEscaped({"mpc", "find",
		"album", librarySelectedAlbum, "title", title});
	-- by no means clean
	-- get first file in list
	local songToQueue = string.gmatch(songFiles,"[^\n]*")();

	callCommandEscaped({"mpc", "add", songToQueue});
end

-- back: go up a level
actions.library_back = function ()
	if (libraryListLevel == nil or libraryListLevel == "artist") then
		libs.device.toast("Cannot go back any more.");
	elseif (libraryListLevel == "album") then
		library_artist_list();
	elseif (libraryListLevel == "song") then
		library_album_list();
	end
end

actions.library_refresh = function ()
	libs.device.toast("Refreshing...");
	update_library();
end

function library_artist_list()
	libraryListLevel = "artist";
	librarySelectedArtist = nil;
	librarySelectedAlbum = nil;
	local artistList = {};
	
	for s in magiclines(callCommand("mpc list artist")) do
		table.insert(artistList, { type = "item", text = s });
	end

	update_library_widget(artistList);
end

function library_album_list()
	libraryListLevel = "album";
	librarySelectedAlbum = nil;
	local albumList = {};
	
	for s in magiclines(callCommandEscaped(
		{ "mpc", "list", "album", "artist", librarySelectedArtist })) do
		table.insert(albumList, { type = "item", text = s });
	end

	update_library_widget(albumList);
end

function library_song_list()
	libraryListLevel = "song";
	local songList = {};
	
	table.insert(songList, { type = "item", text = "[ALL SONGS]" });

	for s in magiclines(callCommandEscaped({ "mpc", "-f", "%title%", "find", "album", librarySelectedAlbum })) do
			table.insert(songList, { type = "item", text = s });
	end

	update_library_widget(songList);
end

function update_library()
	library_artist_list();
end

------------------------------------------------------------------------
-- Seeking
------------------------------------------------------------------------

function seek(pos)
	seeking = true;
	
	-- Calculate the seek percentage from the time position
	local v = 0;
	if (length > 0) then
		v = (pos / length) * 100;
	end
	callCommand("mpc seek " .. v .. "%");
	
	-- Add delay so that the slider doesn't "jump" due to an incoming status update
	libs.timer.timeout(function ()
		seeking = false;
	end, 1000);
end

actions.position_change = function (pos)
	-- Trigger seeking mode so that the slider text updates
	seeking = true;
	seeking_pos = pos;
end
--@help Change position
--@param pos:number Set Position
actions.position_stop = function (pos)
	seek(pos);
end

--@help Seek backwards
actions.jump_back = function ()
	-- Seeking precision is only 1% so:
	-- If 1% is greater than 10 sec, then jump 1%
	-- Otherwise just jump 10 sec
	local pc = math.floor(0.01 * length);
	if (pc > 10) then
		seeking_pos = pos - pc;
	else
		seeking_pos = pos - 10;
	end
	seek(seeking_pos);
end

--@help Seek forwards
actions.jump_forward = function ()
	-- Seeking precision is only 1% so:
	-- If 1% is greater than 10 sec, then jump 1%
	-- Otherwise just jump 10 sec
	local pc = math.floor(0.01 * length);
	if (pc > 10) then
		seeking_pos = pos + pc;
	else
		seeking_pos = pos + 10;
	end
	seek(seeking_pos);
end

------------------------------------------------------------------------
-- Playlist
------------------------------------------------------------------------

local playlistItems = {};
local playlistDialogId = nil;

actions.consume_toggle = function(isChecked)
	toggleButtonUpdate("consume", isChecked);
end

actions.singleoneshot_toggle = function(isChecked)
	toggleButtonUpdate("singleoneshot", isChecked);
end

actions.playlist_itemtap = function(i)
	-- play immediately
	update_playlist(libs.data.fromxml(callCommand("/home/glen/bin/mpc-byid --print-playlist-xml play " .. playlistItems[i+1].id)))
end

actions.playlist_dialog_delete = function()
	update_playlist(libs.data.fromxml(callCommand("/home/glen/bin/mpc-byid --print-playlist-xml delete " .. playlistDialogId)))
end

actions.playlist_dialog_asnext = function()
	update_playlist(libs.data.fromxml(callCommand("/home/glen/bin/mpc-byid --print-playlist-xml asnext " .. playlistDialogId)))
end

actions.playlist_itemhold = function(i)
	local song = playlistItems[i + 1];
	playlistDialogId = song.id;

	libs.server.update({ 
		type = "dialog", 
		text = song.title .. "\n" .. (song.artist or "[unknown artist]") .. "\n" .. (song.album or "[unknown album]"),
		children = {
			{ type = "button", text = "Delete", ontap = "playlist_dialog_delete" },
			{ type = "button", text = "Hoist", ontap = "playlist_dialog_asnext" }
		}
	});
end

actions.playlist_clear = function()
	callCommand("mpc clear");
end

function update_playlist(xmlListRoot)
	local uiList = {};
	playlistItems = {};
	
	for k,v in pairs(xmlListRoot.children) do
		if (v.name == "song") then
			-- TODO ideally, highlight currently playing song
			local uiElem = { type = "item", text = v.attributes["title"] };
			if (v.attributes["isPlaying"] == "true") then
				-- there appear to be issues with non-text/type tags? unsure what's going on
				uiElem.text = "▶️ " .. uiElem.text;
			end
			table.insert(uiList, uiElem);
			table.insert(playlistItems, { title = v.attributes["title"],
				artist = v.attributes["artist"], album = v.attributes["album"],
				id = v.attributes["id"], isPlaying = v.attributes["isPlaying"] == "true" });
		end
	end

	libs.server.update({ id = "playlist", children = uiList });
end

------------------------------------------------------------------------
-- General
------------------------------------------------------------------------

--@help Launch MPD application
actions.launch = function()
	return
end

--@help Toggle play/pause
actions.play_pause = function ()
	callCommand("mpc toggle");
end

--@help Start playback
actions.play = function ()
	callCommand("mpc play");
end

--@help Resume playback
actions.resume = function ()
	-- note: not sure how to distinguish this from play
	callCommand("mpc play");
end

--@help Pause playback
actions.pause = function ()
	callCommand("mpc pause");
end

--@help Stop playback
actions.stop = function ()
	callCommand("mpc stop");
end

--@help Play next item
actions.next = function ()
	callCommand("mpc next");
end

--@help Play previous item
actions.previous = function ()
	callCommand("mpc cdprev");
end

--@help Shuffle playlist
actions.shuffle = function (isChecked)
	toggleButtonUpdate("random", isChecked);
end

--@help Toggle repeat
actions.loop_repeat = function (isChecked)
	toggleButtonUpdate("repeat", isChecked);
end

--@help Raise volume
actions.volume_up = function ()
	callCommand("mpc volume +5");
end

--@help Lower volume
actions.volume_down = function ()
	callCommand("mpc volume -5");
end

--@help Mute volume
actions.volume_mute = function ()
	callCommand("mpc volume 0");
end

--@help Change volume
--@param vol:number Set Volume
actions.volume_change = function (vol)
	callCommand("mpc volume " .. vol);
end
