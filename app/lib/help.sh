help() {
    printf %s "\
torrentwatcher version $VERSION

$LICENSE

torrentwatcher is a simple yet functional script to help with the automation of torrent download and classification

Usage: torrentwatcher [OPTIONS]

Options
     --log FILE              location for the main log file
     --log-filebot FILE      location for the filebot operations log file
     --incomplete PATH       path for all the incomplete downloads
     --incoming PATH         path for the downloaded movies and tv shows
     --incoming-other PATH   path for the other downloaded stuff
     --output-movies PATH    classified movies archive
     --output-tvshows PATH   classified tv shows archive
     --cloud PATH            absolute path for movies and tv shows incoming torrent files in the cloud storage
     --cloud-other PATH      absolute path for other stuff incoming torrent files in the cloud storage
     --filebot-cmd FILE      filebot executable name with path. Default is trying to find with 'which'
     --vpn COUNTRY-ID        Country where VPN IP should be geolocated. Format: ISO 3166-1 alpha-2 (2 characters)
     --no-vpn                VPN is extern

 -f, --file FILE             read configurations from specified file (bash syntax)
 -v, --verbose               increase verbosity
     --version               show version and exit
 -h, --help                  show this help message


"
}

version() {
    printf %s "\
torrentwatcher version $VERSION
"
}

unknow_syntax() {
    version
    printf %s "\
Unknown option or incorrect syntax. Try ussing -h,--help option
"
}
