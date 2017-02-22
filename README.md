# torrentwatcher

This is a work in progress. The current version works but is under heavy development, so expect many changes and/or bugs. 

This is a theoretical project. If someone would want to download movies and tv shows using torrents through a VPN connection to avoid being observed by the Watchers, this bash script and instructions would come in handy. 

## Description
There are some other bash or python scripts out there but this one is mine. I was never happy with other scripts or programs like couchpotato or sickbeard or similars, so I just put together (stole) some great tools and ideas and made them work to my liking. 

This was programmed and tested using FreeNAS 9.10. There are plans to containerize everything with Docker and make it even easier to deploy (provided that your platform supports Docker). 

This project tries to address the following problems:
 - Add torrents on the go
 - Check status on the go
 - Receive some kind of notification when download is available
 - Automatically separate movies and tvshows and clean names
 - Automatically remove torrent from list when finished
 - Keep seeding until ratio is achieved BUT make it available as soon as it is 100% downloaded
 
### What it does
It relies on transmission as a torrent client, Dropbox and dropbox_uploader to add torrents on the go, filebot for renaming and classifying, telegram-bash-bot for notifications and of course bash. 

This is how the data flows:
 - Out of a sudden someone talks to you about this great movie: "Braineaters Olympics" You go to your torrentz2.eu or wherever you look for torrents 
 - And there it is, a nice pristine sparks, evo or whatever 1080p release in 4,6 or 9GB size, you name it. You click on limetorrents, kat or any torrent indexer and download the torrent file to a specific Dropbox folder. 
 - That folder is configured to be monitorized for changes by the torrentwatcher. 
 - Torrentwatcher detects the new file and adds it to transmission notifying you per Telegram. 
 - As soon as the movie is downloaded, filebot processes and copies it to the movies folder, also notifying you. 
 - Transmission keeps seeding until ratio is achieved. 
 - When the torrent reaches the configured ratio, torrentwatcher removes the torrent from the list deleting also the data on disk. 
 - There is also an alternative Dropbox folder for "other" stuff: programs, games, Ubuntu ISOs or whatever the people download these days (not me!). That folder will not be processed by filebot and the torrent must be deleted manually. 

## Installation
There is no installation. Just run it!! ... I'm kidding, of course there is no installation as this is a bash script, but there are some (many) requirements. 

## Configuration
You need to configure the folders where the torrents will be downloaded to, copied to after download, etc. 
