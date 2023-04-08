# OBS-Lyrics
An OBS Lua script for managing and displaying lyrics to any text source in your OBS scene. 

## Table of Contents
1. [Basic usage](#basic-usage)
2. [Useful facts](#useful-facts)
3. [Notation](#notation)
    1. [Mark songs with with `meta` tags for filtering on future selection](#mark-songs-with-with-meta-tags-for-filtering-on-future-selection)
    2. [Single blank line/padding](#single-blank-linepadding)
    3. [Multiple blank lines/padding](#multiple-blank-linespadding)
    4. [End the current page](#end-the-current-page)
    5. [Repeat line](#repeat-line)
    6. [Set number of lines to be displayed per page](#set-number-of-lines-to-be-displayed-per-page)
    7. [Comment out line of text](#comment-out-line-of-text)
    8. [Comment out block of text](#comment-out-block-of-text)
    9. [Define refrain and show it right away](#define-refrain-and-show-it-right-away)
    10. [Define refrain but DON'T show it right away](#define-refrain-but-dont-show-it-right-away)
    11. [Play refrain](#play-refrain)
    12. [Static text](#static-text)
    13. [Single static text line](#single-static-text-line)
    14. [Override title](#override-title)
    15. [Alternate text block](#alternate-text-block)
    16. [Single line alternate text repeated for `n` pages](#single-line-alternate-text-repeated-for-n-pages)
    17. [Mark verses](#mark-verses)
4. [The UI](#the-ui)
5. [That's it](#thats-it)

## Basic usage
1. Download the script and open it with OBS.
2. Add some songs to the script and save them.
3. Select the text source for displaying the lyrics. Set the amount of lines to display, default is 2. Optionally, you can setup hotkeys to control the lyrics display. 
4. Select a song from the song directory and click "Prepare Song". Do that to as many songs as you will need for the session.
5. Once you are ready to display the lyrics, select the song you'd like to display from the "Prepared Songs" list and click "Show/Hide Lyrics" button or the appropriate hotkey.
6. Advance lyrics as needed using the buttons or appropriate hotkeys. You can also advance to the next prepared song using hotkeys.
7. When you're finished with the current song, hide the lyrics and select the next song from the "Prepared Songs" list.

[Back to Top](#table-of-contents)
## Useful facts
- To display a specific song when a scene is activated, add a "Source" to the scene by clicking the + sign in the scene, adding a "Prepare Lyric" source, and selecting the song to open.
- Use "Home" hotkey to return to the beginning of your prepared songs, perhaps after practicing the songs.
- Continue clicking `Advance lyrics` after the end of a song to begin the next prepared song.
- Ensure a constant number of lines displayed using the checkbox, e.g., if the song ends and only one line is left, lyrics will be padded with blank lines to ensure you hava a minimum number of lines. (See Display Options)
- A Monitor.htm file is created with current/next song, lyrics and alternate lyrics that can be docked in OBS with custom browser docks. Use Open Songs Folder button, open Monitor.htm with browser, copy url and paste it into an OBS custom browser dock.
- Prepared songs are stored in the Settings for the scene collection unless the option to use an external Prepared.dat file is selected in the Edit Prepared Songs subgroup.  

[Back to Top](#table-of-contents)
## Notation
### Mark songs with with `meta` tags for filtering on future selection
(`//meta tag1, tag2, ... , tag n`)

Using //meta tags on the __1st line__ of lyrics allows song files to be labeled as belonging to different genre.  Example genre are Hymn, Contemporary, Gospel, Country, Blues, Spritual, Rock, Chant, Reggae, Metal, or HipHop.  However, any tag can be used to organize and cross organize Lyric/Text files into categories. Other meta groups could be Call/Response or Scripture.  Meta tags must match exactly, so the tag __*hymn*__ is different from the tag __*Hymn*__. 
Try it: 
```
//meta Hymn, Blues, Spiritual
```
[Back to Top](#table-of-contents)
### Single blank line/padding
(`##P` or `##B`)

Use on any line that you want to keep as an empty line (for line padding, etc.)
Try it: 
```
This is line 1
##B
This is line 3
```
[Back to Top](#table-of-contents)
### Multiple blank lines/padding
(`#B:3` or `#P:3`)

Use on any line to create 3 empty lines (you may use any number)
Try it: 
```
This is line 1
#B:2
This is line 4!!
```
[Back to Top](#table-of-contents)
### End the current page
(`###`)

Append `###` to the end of any line to end the current page with this line.
Try it: 
```
This line will show first
This line will be the last one regardless of page size ###
This line will be the only one on the 2nd page ###
```
[Back to Top](#table-of-contents)
### Repeat line
(`#D:3`)

Duplicate a line multiple times.
Try it: 
```
#D:3 Sing this line 3 times!!!
```
[Back to Top](#table-of-contents)
### Set number of lines to be displayed per page
(`#L:3`)

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

Another way would be to use a page break
Try it:
```
#L:3
For the verse,
I only want to see two lines.###
But in the chorus,
it needs to show
all three!
```
[Back to Top](#table-of-contents)
### Comment out line of text
(`//`)

Use `//` to write a comment that will not display to your viewers.
Try it:
```
We sing to you God //long pause/guitar solo after this
```
[Back to Top](#table-of-contents)
### Comment out block of text
(`//[` and `//]`)

Use these blocks to write a comment that will not display to your viewers.
Try it:
```
//[ 
    This is an example of using Block Text to add user documentations to a song
    Note 3rd verse of this song is not Public Domain
//]
```
[Back to Top](#table-of-contents)
### Define refrain and show it right away
(`#R[` and `#R]`)

Use this notation to define a refrain that will be displayed right away as well. 

[Back to Top](#table-of-contents)
### Define refrain but DON'T show it right away
(`#r[` and `#r]`)

Used in the same way as `#R[` and `#R]`, but the refrain is not shown in the beginning. It will only be displayed when `##R` or `##r` is called.

[Back to Top](#table-of-contents)
### Play refrain
(`##R`)

Use this annotation to show where a refrain should be inserted. See above.
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
[Back to Top](#table-of-contents)
### Static text
(`#S[` and `#S]`)

Use this anotation to define a block of text lines shown in the selected Static Source that remain constant during the scene (no paging).
Try it:
```
#S[
The song Amazing Grace was written by John Newton 
who was a former Slave Trader
#S]
```
[Back to Top](#table-of-contents)
### Single static text line
(`#S: line`)

Use this to define a simple single line of Static text
Try it:
```
#S: The song Amazing Grace was written by John Newton who was a former Slave Trader
```
[Back to Top](#table-of-contents)
### Override title
(`#T: new title`)

Use this to specifically define the song title. This is useful if title has special characters, not valid as a filename.
Try it:
```
#T: How Great Thou Art (주하나님지으신모든세계)
```
[Back to Top](#table-of-contents)
### Alternate text block
(`#A[` and `#A]`)

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
 [Back to Top](#table-of-contents)
### Single line alternate text repeated for `n` pages
(`#A:n line`)

Use this annotation to include a simple single line of Alternate Text to be used for n pages.
Try it:
```
#A:2 This alaternate line shows for the next two pages of Lyrics.  
```
[Back to Top](#table-of-contents)
### Mark verses
(`##V`)

Use this annotation to mark where new verses start.  Verse number will be displayed in the monitor.
Try it:

```
#R[ optional comment
#L:2
This song starts with this refrain!
It will only show these two lines!!!
#R] optional comment
#L:3
##V
Now the verse begins,
after the refrain.
And all three lines will show!
##R
##V
Now the second verse begins,
it will also continue with three lines per verse.
Now hit the refrain again!
##R
```
[Back to Top](#table-of-contents)
## The UI
### Song Title (filename) and Lyrics Information

![Title Lyrics](https://github.com/amirchev/OBS-Lyrics/blob/cleanup/images/Title%20Lyrics.gif)

The song Title is also used as a filename to store the lyrics.  If the text of the title is not a valid OS filename then the filename will be encoded to create a valid filename.   Providing a valid filename for this field instead of a song Title the actual Title can be included using the #T: markup.  Song lyrics can be added in the dialog, saved, and deleted.  Songs can also be opened and edited with the default system text editor.  

[Back to Top](#table-of-contents)
### Manage Prepared Songs/Text

![image-20211022010733511](https://github.com/amirchev/OBS-Lyrics/blob/cleanup/images/Manage%20Prepared.gif)

Songs saved in the Song Title and Lyrics Information can be selected in the Manage Prepared section to be added to the Prepared Songs/Text list.  Selecting a song from this Prepared List loads the contents of the Song/Text into the selected Text Sources.  If songs are marked with //meta tags, they can be filtered by specifying one or more tags and refreshing the directory.  Prepared songs can be edited as a list where they can be individually ordered or deleted.  *(New songs can be typed into the edit list manually if they exist in the directory exactly as typed)*

[Back to Top](#table-of-contents)
### Lyric Control Buttons

Control Buttons perform the seven different functions of the Lyrics Script.   Additionally, Hot Keys can be assigned within OBS to perform these same functions.

![img](https://github.com/amirchev/OBS-Lyrics/blob/cleanup/images/Lyric%20Control%20Buttons.gif)

[Back to Top](#table-of-contents)
### Display Options

![image-20211021232744449](https://github.com/amirchev/OBS-Lyrics/blob/cleanup/images/Display%20Options.gif)

Enabling Fade Transitions will offer additional options to cause lyrics and other sources to fade to transparent before changing to a different page and fading back to opaque.  The Use 0-100% option is set by default.  Unchecking this option will cause Lyrics to restore faded sources back to their "marked" original opacity levels if specific graphic effects have been applied to text.   Background color fading is optional and can be further configured per text source if enabled.  
[Back to Top](#table-of-contents)
### Text Sources in Scenes

![image-20211021234545740](https://github.com/amirchev/OBS-Lyrics/blob/cleanup/images/Text%20Sources.gif)

Lyrics will modify the text content of existing text sources within OBS and a given scene.  These Text, Title, Alternate and Static text sources are defined in the Text Sources in Scenes section.  New text sources added to OBS while the script properties window is open, can be included by clicking the Refresh All Sources button. Additional visual sources can be added and linked to show/hide/fade with the Title and Static text sources if desired, such as with a background image for Lyrics, etc.  Optionally, these sources can be faded with the Lyrics and Alternate text.    

[Back to Top](#table-of-contents)
### Lyrics Monitor Browser Dock

![image-20211021235826735](https://github.com/amirchev/OBS-Lyrics/blob/cleanup/images/monitor.gif)

A Lyrics Monitor Page updated in HTML is available in the Songs Folder as Monitor.htm.  Press the Open Songs Folder to find the file and open it in a browser.  It is also possible to add this url as a dockable window in OBS/View/Docks/Custom Browser Docks. The page shows:

- Prepared Song x of n (or Scene if current lyric is loaded from a source)
- Lyric Page x of n
- Current Verse if marked in Lyrics
- The Song Title, Current Lyrics Page Text, Next Lyrics Page Text
- Current Alternate Lyrics Page if marked in song/text file
- Next Alternate Lyrics Page Text if marked in song/text file
- The Next Prepared Song/Text file

 Note: <font color=red>Red backgrounds</font> in the Monitor Page indicate lyrics are not currently visible, or the selected text sources do not exist in the current Active scene.

[Back to Top](#table-of-contents)
## That's it
Please post any bugs or feature requests here or to the OBS forum. 

Feel free to make pull requests for any features you implement yourself, I'll be happy to take a look at them.

amirchev and DC Strato
with significant contributions from taxilian

[Back to Top](#table-of-contents)
