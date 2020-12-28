# OBS-Lyrics
Manage and display lyrics to any text source in your OBS scene. 

## How to use
1. Download the script and open it with OBS.
2. Add some songs to the script and save them.
3. Select the text source for displaying the lyrics. Set the amount of lines to display, default is 2. Optionally, you can setup hotkeys to control the lyrics display. 
4. Select a song from the song directory and click "Prepare Song". Do that to as many songs as you will need for the session.
5. Once you are ready to display the lyrics, select the song you'd like to display from the "Prepared Songs" list and click "Show/Hide Lyrics" button or the appropriate hotkey.
6. Advance lyrics as needed using the buttons or appropriate hotkeys. You can also advance to the next prepared song using hotkeys.
7. When you're finished with the current song, hide the lyrics and select the next song from the "Prepared Songs" list. 

There is a much more in-depth guide [here](https://obsproject.com/forum/resources/display-lyrics-as-subtitles.1005/).

## Things to know
- Add `##P` on any line that you want to keep as an empty line (for line padding, etc.)
- Add `#L:3` in the start of the lyrics to specify that a particular song is to be displayed 3 lines at a time (works with any number).
- To display a specific song when a scene is activated, add a "Source" to the scene by clicking the + sign in the scene, adding a "Prepare Lyric" source, and selecting the song to open.
- Use "Home" hotkey to return to the beginning of your prepared songs, perhaps after practicing the songs.
- Append `###` to the end of a line to display it by itself.
- Use `//` to write a comment that will not display to your viewers, e.g., `We sing to you God //repeats 5 times`
- Continue clicking `Advance lyrics` after the end of a song to begin the next prepared song.
- Ensure a constant number of lines displayed using the checkbox, e.g., if the song ends and only one line is left, lyrics will be padded with blank lines to ensure you hava a minimum number of lines.

## That's it
Please post any bugs or feature requests here or to the OBS forum. 

Feel free to make pull requests for any features you implement yourself, I'll be happy to take a look at them.

amirchev
with significant contributions from taxilian and DC Strato
