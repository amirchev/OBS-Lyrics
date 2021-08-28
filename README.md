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
- To display a specific song when a scene is activated, add a "Source" to the scene by clicking the + sign in the scene, adding a "Prepare Lyric" source, and selecting the song to open.
- Use "Home" hotkey to return to the beginning of your prepared songs, perhaps after practicing the songs.
- Continue clicking `Advance lyrics` after the end of a song to begin the next prepared song.
- Ensure a constant number of lines displayed using the checkbox, e.g., if the song ends and only one line is left, lyrics will be padded with blank lines to ensure you hava a minimum number of lines.
- A Monitor.htm file is created with current/next song, lyrics and alternate lyrics that can be docked in OBS with custom browser docks. Use Open Songs Folder button, open Monitor.htm with browser, copy url and paste it into an OBS custom browser dock.

## Notation
### Single blank line/padding (`##P` or `##B`)
Use on any line that you want to keep as an empty line (for line padding, etc.)
Try it: 
```
This is line 1
##B
This is line 3
```
### Multiple blank lines/padding (`#B:3` or `#P:3`)
Use on any line to create 3 empty lines (you may use any number)
Try it: 
```
This is line 1
#B:2
This is line 4!!
```
### End the current page (`###`)
Append `###` to the end of any line to end the current page with this line.
Try it: 
```
This line will show first
This line will be the last one regardless of page size ###
This line will be the only one on the 2nd page ###
```
### Repeat line (`#D:3`)
Duplicate a line multiple times.
Try it: 
```
#D3: Sing this line 3 times!!!
```
### Set number of lines to be displayed per page (`#L:3`)
Change the amount of lines displayed at one time throughout the same song.
Try it:
```
#L:2
For the verse,
I only want to see two lines.
#L:3
But in the chorus,
it needs to show
all three!
```
### Another way would be to use a page break
Try it:
```
#L:3
For the verse,
I only want to see two lines.###
But in the chorus,
it needs to show
all three!
```
### Comment out text (`//`)
Use `//` to write a comment that will not display to your viewers.
Try it:
```
We sing to you God //long pause/guitar solo after this
```
### Comment out text (`//`)
Use `//` to write a comment that will not display to your viewers.
Try it:
```
//[ 
    This is an example of using Block Text to add user documentations to a song
    Note 3rd verse of this song is not Public Domain
//]
```
### Define refrain and show it right away (`#R[` and `#R]`)
Use this notation to define a refrain that will be displayed right away as well. 
Try it:
```
#R[ optional comment
#L:2
This song starts with this refrain!
It will only show these two lines!!!
#R] optional comment
#L:3
Now the verse begins,
after the refrain.
And all three lines will show!
##R
Now the second verse begins,
it will also continue with three lines per verse.
Now hit the refrain again!
##R
```
### Play refrain (`##R`)
Use this annotation to show where a refrain should be inserted. See above.
### Define refrain but DON'T show it right away (`#r[` and `#r]`)
Used in the same way as `#R[` and `#R]`, but the refrain is not shown in the beginning. It will only be displayed when `##R` or `##r` is called.

### Static Text (`#S[` and `#S]`)
Use this anotation to define a block of text lines shown in the selected Static Source that remain constant during the scene (no paging).
Try it:
```
#S[
The song Amazing Grace was written by John Newton 
who was a former Slave Trader
#S]
```
### Single static text line (`#S: line`)
Use this to define a simple single line of Static text
Try it:
```
#S: The song Amazing Grace was written by John Newton who was a former Slave Trader
```
### Alternate Text Block (`#A[` and `#A]`)
Use this annotation to mark additional verses or text to show and page in the selected Alternate Source.
Note: The page length will be governed by text in the main block if it exists and its Text Source exists in the scene.
      The alternate block should have the same number of lines per page as the main block if both are used.
 ```
Amazing grace! How sweet the sound
That saved a wretch like me!
I once was lost, but now am found;
Was blind, but now I see.
#A[
Sublime gracia cuán dulce el sonido
Que salvo a un desgraciado como yo
Alguna vez estuve perdido, pero ahora me he encontrado
Estuve ciego pero ahora veo
#A]
``` 
### Single Line Alternate Text repeated for n pages (`#A:n line`)
Use this annotation to include a simple single line of Alternate Text to be used for n pages.
Try it:
```
#A:2 This alaternate line shows for the next two pages of Lyrics.  
```
### Lyrics Monitor Browser Dock
A Lyrics Monitor Page updated in HTML is available in the Songs Folder as Monitor.htm. Press the Open Songs Folder to find the file and open it in a browser.  It is also possible to add this url as a dockable window in OBS/View/Docks/Custom Browser Docks. The page shows Prepared Song x of n, Lyric Page x of n, Scene if current lyric is loaded from a source, The Song Title, Current Lyrics Page, Next Lyrics Page, Current Alternate Lyrics Page, Next Alternate Lyrics Page, and the Next Prepared Song.

Note: Lyrics loaded by a source in a scene are always prepared to the first prepared lyric location, and existing prepared lyrics are shifted up. Scene prepared lyrics are NOT saved in the prepared lyrics list.    

## That's it
Please post any bugs or feature requests here or to the OBS forum. 

Feel free to make pull requests for any features you implement yourself, I'll be happy to take a look at them.

amirchev and DC Strato
with significant contributions from taxilian
