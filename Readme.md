Description
-----------
Gallury is an image sharing and organizing platform where images are organized by tags.

To build it run make then set up the database with `sqlite3 gallury.db < schema.sql`, then `LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib" ./gallury.exe` to run it. The LD path may not be needed on some systems.

Querying is done by providing a comma-separated list of tags, where some tags may by prefixed by a - to mean that results containing that tag will not be included. Tags may be added to images in a similar manner, except that prefixing a tag with a - removes that tag from the image.

Main page:
![](http://i.imgur.com/xmWKlIl.png)

Searching:
![](http://i.imgur.com/yZpMO29.png)
