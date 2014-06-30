CFLAGS=-I/usr/local/include/urweb -I/usr/include/urweb `Magick-config --cflags`

all: thumbnailer.o gallury.exe

gallury.exe: gallury.ur gallury.urs gallury.urp
	urweb -dbms sqlite -db gallury.db gallury

gallury.db: gallury.exe
	sqlite3 gallury.db < schema.sql

clean:
	rm -f thumbnailer.o
	rm -f gallury.exe
	rm -f schema.sql
	mv gallury.db ..
