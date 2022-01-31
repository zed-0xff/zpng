zpng    [![Build Status](https://secure.travis-ci.org/zed-0xff/zpng.png)](http://secure.travis-ci.org/zed-0xff/zpng)  [![Dependency Status](https://gemnasium.com/zed-0xff/zpng.png)](https://gemnasium.com/zed-0xff/zpng)
======


Description
-----------
A pure ruby PNG file manipulation & validation

(If you need a high-level PNG creation toolkit - take a look at [SugarPNG](https://github.com/zed-0xff/sugar_png))

Installation
------------
    gem install zpng

Comparison
----------
 * supports `iTXt` (international text) chunks
 * full support of 16-bit color & alpha depth

Usage
-----

    # zpng -h

    Usage: zpng [options] filename.png
    
        -i, --info                       General image info (default)
        -c, --chunk(s) [ID]              Show chunks (default) or single chunk by its #
        -m, --metadata                   Show image metadata, if any (default)
    
        -S, --scanlines                  Show scanlines info
        -P, --palette                    Show palette
            --colors                     Show colors used
        -E, --extract-chunk ID           extract a single chunk
        -D, --imagedata                  dump unpacked Image Data (IDAT) chunk(s) to stdout
    
        -C, --crop GEOMETRY              crop image, {WIDTH}x{HEIGHT}+{X}+{Y},
                                         puts results on stdout unless --ascii given
        -R, --rebuild NEW_FILENAME       rebuild image, useful in restoring borked images
    
        -A, --ascii                      Try to convert image to ASCII (works best with monochrome images)
            --ascii-string STRING        Use specific string to map pixels to ASCII characters
        -N, --ansi                       Try to display image as ANSI colored text
        -2, --256                        Try to display image as 256-colored text
        -W, --wide                       Use 2 horizontal characters per one pixel
    
        -v, --verbose                    Run verbosely (can be used multiple times)
        -q, --quiet                      Silent any warnings (can be used multiple times)
        -I, --console                    opens IRB console with specified image loaded

### Info

    # zpng qr_rgb.png

    [.] image size 35x35, 24bpp, COLOR_RGB
    [.] uncompressed imagedata size = 3710 bytes
    [.] <Chunk #00 IHDR size=    13, crc=91bb240e, color=2, compression=0, depth=8, filter=0, height=35, interlace=0, offset=8, width=35> CRC OK
    [.] <Chunk #01 sRGB size=     1, crc=aece1ce9 > CRC OK
    [.] <Chunk #02 IDAT size=   399, crc=59790716 > CRC OK
    [.] <Chunk #03 IEND size=     0, crc=ae426082 > CRC OK

### Info (verbose)

    # zpng -v qr_rgb.png

    [.] image size 35x35, 24bpp, COLOR_RGB
    [.] uncompressed imagedata size = 3710 bytes
        01 ff ff ff 00 00 00 00  00 00 00 00 00 00 00 00  |................|
        00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................| + 3678 bytes
    
    [.] <Chunk #00 IHDR size=    13, crc=91bb240e, color=2, compression=0, depth=8, filter=0, height=35, idx=0, interlace=0, offset=8, width=35> CRC OK
        00 00 00 23 00 00 00 23  08 02 00 00 00           |...#...#.....   |
    
    [.] <Chunk #01 sRGB size=     1, crc=aece1ce9 > CRC OK
        00                                                |.               |
    
    [.] <Chunk #02 IDAT size=   399, crc=59790716 > CRC OK
        48 c7 bd 56 41 12 c4 20  08 d3 8e ff ff b2 7b 70  |H..VA.. ......{p|
        86 d2 24 44 db c3 7a d8  d9 b6 08 18 03 a1 cf 39  |..$D..z........9| + 367 bytes
    
    [.] <Chunk #03 IEND size=     0, crc=ae426082 > CRC OK

( add more `-v`'s for even more verbose output)

### Chunks

    # zpng --chunks qr_aux_chunks.png

    [.] <Chunk #00 IHDR size=    13, crc=36a28ef4, color=0, compression=0, depth=1, filter=0, height=35, interlace=0, offset=8, width=35> CRC OK
    [.] <Chunk #01 gAMA size=     4, crc=0bfc6105 > CRC OK
    [.] <Chunk #02 sRGB size=     1, crc=aece1ce9 > CRC OK
    [.] <Chunk #03 cHRM size=    32, crc=9cba513c > CRC OK
    [.] <Chunk #04 pHYs size=     9, crc=46c96b3e > CRC OK
    [.] <Chunk #05 IDAT size=   213, crc=5f3f1ff9 > CRC OK
    [.] <Chunk #06 tEXt size=    37, crc=8d62fd1a, keyword="date:create"> CRC OK
    [.] <Chunk #07 tEXt size=    37, crc=fc3f45a6, keyword="date:modify"> CRC OK
    [.] <Chunk #08 IEND size=     0, crc=ae426082 > CRC OK

### ASCII

source image: ![qr_rgb.png](https://github.com/zed-0xff/zpng/raw/master/samples/qr_rgb.png)

    # zpng --ascii --wide qr_rgb.png

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @@              @@    @@@@@@@@@@    @@  @@    @@@@@@@@              @@
    @@  @@@@@@@@@@  @@@@@@@@@@@@@@    @@  @@    @@@@@@@@@@  @@@@@@@@@@  @@
    @@  @@      @@  @@  @@@@          @@@@  @@  @@@@    @@  @@      @@  @@
    @@  @@      @@  @@    @@  @@@@@@@@  @@        @@    @@  @@      @@  @@
    @@  @@      @@  @@        @@  @@@@@@@@  @@        @@@@  @@      @@  @@
    @@  @@@@@@@@@@  @@@@  @@@@  @@  @@@@          @@@@@@@@  @@@@@@@@@@  @@
    @@              @@  @@  @@  @@  @@  @@  @@  @@  @@  @@              @@
    @@@@@@@@@@@@@@@@@@@@  @@  @@    @@@@@@@@@@    @@    @@@@@@@@@@@@@@@@@@
    @@        @@@@  @@  @@@@@@@@    @@  @@    @@@@@@@@    @@@@      @@  @@
    @@@@  @@    @@@@@@    @@@@@@@@@@    @@  @@    @@  @@      @@@@@@    @@
    @@  @@      @@    @@@@@@@@@@@@    @@  @@    @@@@    @@  @@      @@  @@
    @@@@@@@@      @@  @@@@@@          @@@@  @@  @@@@@@    @@  @@@@@@  @@@@
    @@    @@    @@  @@@@  @@  @@@@@@@@  @@        @@@@    @@    @@@@@@@@@@
    @@@@@@  @@@@  @@    @@    @@  @@@@@@@@  @@      @@    @@@@@@@@    @@@@
    @@  @@            @@    @@  @@  @@@@          @@@@              @@@@@@
    @@  @@        @@@@      @@    @@  @@    @@@@@@@@  @@@@@@    @@  @@@@@@
    @@@@@@    @@    @@@@      @@@@@@@@@@    @@  @@    @@                @@
    @@@@@@@@@@  @@@@      @@@@    @@@@@@@@@@    @@                  @@  @@
    @@        @@          @@    @@@@@@@@@@    @@  @@@@@@  @@@@@@  @@  @@@@
    @@@@    @@  @@@@  @@@@  @@  @@@@          @@@@  @@  @@@@    @@@@@@  @@
    @@@@@@            @@          @@  @@@@@@@@  @@    @@@@@@@@@@@@  @@@@@@
    @@@@      @@@@@@@@@@  @@@@        @@  @@@@@@@@      @@  @@@@@@      @@
    @@      @@@@        @@        @@@@  @@  @@@@              @@@@@@    @@
    @@  @@  @@    @@    @@  @@@@@@@@@@    @@  @@    @@            @@  @@@@
    @@@@  @@              @@@@  @@    @@@@@@@@@@    @@          @@@@@@  @@
    @@@@@@@@@@@@@@@@@@  @@      @@  @@    @@@@@@@@@@    @@@@@@  @@  @@@@@@
    @@              @@@@@@@@  @@  @@    @@@@@@@@@@      @@  @@  @@@@@@@@@@
    @@  @@@@@@@@@@  @@@@      @@@@  @@  @@@@            @@@@@@      @@  @@
    @@  @@      @@  @@@@@@@@@@  @@        @@  @@@@@@                @@@@@@
    @@  @@      @@  @@      @@@@@@  @@        @@  @@  @@  @@@@@@@@@@@@@@@@
    @@  @@      @@  @@      @@@@          @@@@  @@    @@@@  @@@@  @@@@@@@@
    @@  @@@@@@@@@@  @@        @@    @@@@@@@@@@    @@      @@@@@@@@@@@@  @@
    @@              @@  @@  @@@@    @@  @@    @@@@@@  @@    @@@@@@  @@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

### Scanlines

    # zpng --scanlines qr_rgb.png

    #<ZPNG::ScanLine idx=0  offset=0   size=106 bpp=24 filter=1>
    #<ZPNG::ScanLine idx=1  offset=106 size=106 bpp=24 filter=4>
    #<ZPNG::ScanLine idx=2  offset=212 size=106 bpp=24 filter=4>
    #<ZPNG::ScanLine idx=3  offset=318 size=106 bpp=24 filter=4>
    #<ZPNG::ScanLine idx=4  offset=424 size=106 bpp=24 filter=2>
    #<ZPNG::ScanLine idx=5  offset=530 size=106 bpp=24 filter=2>
    #<ZPNG::ScanLine idx=6  offset=636 size=106 bpp=24 filter=4>
    #<ZPNG::ScanLine idx=7  offset=742 size=106 bpp=24 filter=0>
    #<ZPNG::ScanLine idx=8  offset=848 size=106 bpp=24 filter=1>
    #<ZPNG::ScanLine idx=9  offset=954 size=106 bpp=24 filter=0>
    #<ZPNG::ScanLine idx=10 offset=1060 size=106 bpp=24 filter=0>
    #<ZPNG::ScanLine idx=11 offset=1166 size=106 bpp=24 filter=0>
    #<ZPNG::ScanLine idx=12 offset=1272 size=106 bpp=24 filter=1>
    #<ZPNG::ScanLine idx=13 offset=1378 size=106 bpp=24 filter=2>
    #<ZPNG::ScanLine idx=14 offset=1484 size=106 bpp=24 filter=4>
    #<ZPNG::ScanLine idx=15 offset=1590 size=106 bpp=24 filter=0>
    #<ZPNG::ScanLine idx=16 offset=1696 size=106 bpp=24 filter=4>
    #<ZPNG::ScanLine idx=17 offset=1802 size=106 bpp=24 filter=0>
    #<ZPNG::ScanLine idx=18 offset=1908 size=106 bpp=24 filter=4>
    #<ZPNG::ScanLine idx=19 offset=2014 size=106 bpp=24 filter=4>
    #<ZPNG::ScanLine idx=20 offset=2120 size=106 bpp=24 filter=0>
    #<ZPNG::ScanLine idx=21 offset=2226 size=106 bpp=24 filter=1>
    #<ZPNG::ScanLine idx=22 offset=2332 size=106 bpp=24 filter=2>
    #<ZPNG::ScanLine idx=23 offset=2438 size=106 bpp=24 filter=0>
    #<ZPNG::ScanLine idx=24 offset=2544 size=106 bpp=24 filter=2>
    #<ZPNG::ScanLine idx=25 offset=2650 size=106 bpp=24 filter=1>
    #<ZPNG::ScanLine idx=26 offset=2756 size=106 bpp=24 filter=1>
    #<ZPNG::ScanLine idx=27 offset=2862 size=106 bpp=24 filter=4>
    #<ZPNG::ScanLine idx=28 offset=2968 size=106 bpp=24 filter=4>
    #<ZPNG::ScanLine idx=29 offset=3074 size=106 bpp=24 filter=4>
    #<ZPNG::ScanLine idx=30 offset=3180 size=106 bpp=24 filter=4>
    #<ZPNG::ScanLine idx=31 offset=3286 size=106 bpp=24 filter=2>
    #<ZPNG::ScanLine idx=32 offset=3392 size=106 bpp=24 filter=4>
    #<ZPNG::ScanLine idx=33 offset=3498 size=106 bpp=24 filter=4>
    #<ZPNG::ScanLine idx=34 offset=3604 size=106 bpp=24 filter=1>

### Palette

    # zpng --palette qr_plte_bw.png

    <Chunk #02 PLTE size=     6, crc=55c2d37e >
      color   #0:  ff ff ff  |...|
      color   #1:  00 00 00  |...|


## Image manipulation

    #!/usr/bin/env ruby
    require 'zpng'
    include ZPNG

    img = Image.new(File.join(File.dirname(__FILE__),"http.png"))

    puts "[.] original:"
    puts img.to_s
    puts

    img.width.times do |x|
      img[x,0] = (x % 2 == 0) ? Color::WHITE : Color::BLACK
    end

    puts "[.] modified:"
    puts img.to_s

    File.open("http-modified.png","wb") do |f|
      f << img.export
    end

## Create 16x16 transparent PNG

    #!/usr/bin/env ruby
    require 'zpng'
    include ZPNG

    img = Image.new :width => 16, :height => 16
    File.open("16x16.png","wb") do |f|
      f << img.export
    end

License
-------
Released under the MIT License.  See the [LICENSE](https://github.com/zed-0xff/zpng/blob/master/LICENSE.txt) file for further details.
