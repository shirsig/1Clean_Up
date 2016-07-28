# Clean Up - WoW 1.12 addOn 

This addOn automatically stacks and sorts your items.

![Alt text](http://i.imgur.com/DZgQPaa.png)

### Commands
**/cleanupreverse** (Makes the sorting start at the top of your bags instead of the bottom)<br/>
**/cleanupbags framename** (Changes the frame the "Clean Up Bags"-button is attached to to **framename**, requires **/reload**)<br/>
**/cleanupbank framename** (Changes the frame the "Clean Up Bank"-button is attached to to **framename**, requires **/reload**)

Configuring the buttons for OneBag:

```
/cleanupbags OneBagFrame
/cleanupbank OneBankFrame
/reload
```

Configuring the buttons for Bagnon:

```
/cleanupbags Bagnon
/cleanupbank Banknon
/reload
```

The buttons can be positioned on their frames by dragging while holding down the Alt-key.

Alt-left-click on a bag item will permanently assign its slot to that item.<br/>
Alt-right-click on a bag slot will clear its assignment.

### Sort order
The primary sort order is:

**hearthstone**<br/>
**mounts**<br/>
**special items** (items of arbitrary categories that tend to be kept for a long time for some reason. e.g., cosmetic items like dartol's rod, items that give you some ability like cenarion beacon)<br/>
**key items** (keys that aren't actual keys. e.g., mara scepter, zf hammer, ubrs key)<br/>
**tools**<br/>
**other soulbound items**<br/>
**reagents**<br/>
**consumables**<br/>
**quest items**<br/>
**high quality items** (which aren't in any other category)<br/>
**common quality items** (which aren't in any other category)<br/>
**junk**<br/>
**conjured items**

The basic intuition for the primary sort order is the time items are expected to be kept around. The more "permanent" an item is the lower it is placed in your bags.

Within the primary groups items are further sorted by itemclass, itemequiploc, itemsubclass, itemname and stacksize/charges in this order of priority.
