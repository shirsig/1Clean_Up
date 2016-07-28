# Clean Up - WoW 1.12 addOn 

This addon automatically stacks and sorts your items.

![Alt text](http://i.imgur.com/DZgQPaa.png)

### Commands
**/cleanupbags framename** (Changes the frame the "Clean Up Bags"-button is attached to to **framename**, requires **/reload**)<br/>
**/cleanupbank framename** (Changes the frame the "Clean Up Bank"-button is attached to to **framename**, requires **/reload**)<br/>
**/cleanupreverse** (Makes the sorting start at the top of your bags instead of the bottom)

### Sort order
The primary sort order is:<br/>
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
**conjured items**<br/><br/>
The basic intuition for the primary sort order is the time items are expected to be kept around. The more "permanent" an item is the lower it is placed in your bags.<br/><br/>Within the primary groups items are further sorted by itemclass, itemequiploc, itemsubclass, itemname and stacksize/charges in this order of priority.
