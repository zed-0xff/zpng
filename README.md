zpng    [![Build Status](https://secure.travis-ci.org/zed-0xff/zpng.png)](http://secure.travis-ci.org/zed-0xff/zpng)  [![Dependency Status](https://gemnasium.com/zed-0xff/zpng.png)](https://gemnasium.com/zed-0xff/zpng)
======


Description
-----------
A pure ruby PNG file manipulation & validation

Installation
------------
    gem install zpng

Usage
-----

    # zpng -h

    Usage: zpng [options] filename.png
        -v, --verbose                    Run verbosely (can be used multiple times)
        -q, --quiet                      Silent any warnings (can be used multiple times)
        -C, --chunks                     Show file chunks (default)
        -i, --info                       General image info (default)
        -S, --scanlines                  Show scanlines info
        -P, --palette                    Show palette
        -E, --extract-chunk ID           extract a single chunk
        -U, --unpack-imagedata           unpack Image Data (IDAT) chunk(s), output to stdout
    
        -c, --crop GEOMETRY              crop image, {WIDTH}x{HEIGHT}+{X}+{Y},
                                         puts results on stdout unless --ascii given
    
        -A, --ascii                      Try to convert image to ASCII (works best with monochrome images)
        -N, --ansi                       Try to display image as ANSI colored text
        -2, --256                        Try to display image as 256-colored text
        -W, --wide                       Use 2 horizontal characters per one pixel

### Info

    # zpng --info qr_rgb.png

    [.] image size 35x35
    [.] uncompressed imagedata size = 3710 bytes

### Chunks

    # zpng --chunks qr_aux_chunks.png

    [.] <Chunk #00 IHDR size=    13, crc=36a28ef4, idx=0, interlace=0, filter=0, compression=0, height=35, width=35, depth=1, color=0> CRC OK
    [.] <Chunk #01 gAMA size=     4, crc=0bfc6105 > CRC OK
    [.] <Chunk #02 sRGB size=     1, crc=aece1ce9 > CRC OK
    [.] <Chunk #03 cHRM size=    32, crc=9cba513c > CRC OK
    [.] <Chunk #04 pHYs size=     9, crc=46c96b3e > CRC OK
    [.] <Chunk #05 IDAT size=   213, crc=5f3f1ff9 > CRC OK
    [.] <Chunk #06 tEXt size=    37, crc=8d62fd1a > CRC OK
    [.] <Chunk #07 tEXt size=    37, crc=fc3f45a6 > CRC OK
    [.] <Chunk #08 IEND size=     0, crc=ae426082 > CRC OK

### ASCII

source image: ![qr_rgb.png](https://github.com/zed-0xff/zpng/raw/master/samples/qr_rgb.png)

    # zpng --ascii --wide qr_rgb.png

                                                                          
      ##############  ####          ####  ##  ####        ##############  
      ##          ##              ####  ##  ####          ##          ##  
      ##  ######  ##  ##    ##########    ##  ##    ####  ##  ######  ##  
      ##  ######  ##  ####  ##        ##  ########  ####  ##  ######  ##  
      ##  ######  ##  ########  ##        ##  ########    ##  ######  ##  
      ##          ##    ##    ##  ##    ##########        ##          ##  
      ##############  ##  ##  ##  ##  ##  ##  ##  ##  ##  ##############  
                        ##  ##  ####          ####  ####                  
      ########    ##  ##        ####  ##  ####        ####    ######  ##  
        ##  ####      ####          ####  ##  ####  ##  ######      ####  
      ##  ######  ####            ####  ##  ####    ####  ##  ######  ##  
            ######  ##      ##########    ##  ##      ####  ##      ##    
      ####  ####  ##    ##  ##        ##  ########    ####  ####          
          ##    ##  ####  ####  ##        ##  ######  ####        ####    
      ##  ############  ####  ##  ##    ##########    ##############      
      ##  ########    ######  ####  ##  ####        ##      ####  ##      
          ####  ####    ######          ####  ##  ####  ################  
              ##    ######    ####          ####  ##################  ##  
      ########  ##########  ####          ####  ##      ##      ##  ##    
        ####  ##    ##    ##  ##    ##########    ##  ##    ####      ##  
          ############  ##########  ##        ##  ####            ##      
        ######          ##    ########  ##        ######  ##      ######  
      ######    ########  ########    ##  ##    ##############      ####  
      ##  ##  ####  ####  ##          ####  ##  ####  ############  ##    
        ##  ##############    ##  ####          ####  ##########      ##  
                      ##  ######  ##  ####          ####      ##  ##      
      ##############        ##  ##  ####          ######  ##  ##          
      ##          ##    ######    ##  ##    ############      ######  ##  
      ##  ######  ##          ##  ########  ##      ################      
      ##  ######  ##  ######      ##  ########  ##  ##  ##                
      ##  ######  ##  ######    ##########    ##  ####    ##    ##        
      ##          ##  ########  ####          ####  ######            ##  
      ##############  ##  ##    ####  ##  ####      ##  ####      ##

### Scanlines

    # zpng --scanlines qr_rgb.png

    [#<ZPNG::ScanLine idx=0  offset=1   size=106 bpp=24 filter=1>,
     #<ZPNG::ScanLine idx=1  offset=107 size=106 bpp=24 filter=4>,
     #<ZPNG::ScanLine idx=2  offset=213 size=106 bpp=24 filter=4>,
     #<ZPNG::ScanLine idx=3  offset=319 size=106 bpp=24 filter=4>,
     #<ZPNG::ScanLine idx=4  offset=425 size=106 bpp=24 filter=2>,
     #<ZPNG::ScanLine idx=5  offset=531 size=106 bpp=24 filter=2>,
     #<ZPNG::ScanLine idx=6  offset=637 size=106 bpp=24 filter=4>,
     #<ZPNG::ScanLine idx=7  offset=743 size=106 bpp=24 filter=0>,
     #<ZPNG::ScanLine idx=8  offset=849 size=106 bpp=24 filter=1>,
     #<ZPNG::ScanLine idx=9  offset=955 size=106 bpp=24 filter=0>,
     #<ZPNG::ScanLine idx=10 offset=1061 size=106 bpp=24 filter=0>,
     #<ZPNG::ScanLine idx=11 offset=1167 size=106 bpp=24 filter=0>,
     #<ZPNG::ScanLine idx=12 offset=1273 size=106 bpp=24 filter=1>,
     #<ZPNG::ScanLine idx=13 offset=1379 size=106 bpp=24 filter=2>,
     #<ZPNG::ScanLine idx=14 offset=1485 size=106 bpp=24 filter=4>,
     #<ZPNG::ScanLine idx=15 offset=1591 size=106 bpp=24 filter=0>,
     #<ZPNG::ScanLine idx=16 offset=1697 size=106 bpp=24 filter=4>,
     #<ZPNG::ScanLine idx=17 offset=1803 size=106 bpp=24 filter=0>,
     #<ZPNG::ScanLine idx=18 offset=1909 size=106 bpp=24 filter=4>,
     #<ZPNG::ScanLine idx=19 offset=2015 size=106 bpp=24 filter=4>,
     #<ZPNG::ScanLine idx=20 offset=2121 size=106 bpp=24 filter=0>,
     #<ZPNG::ScanLine idx=21 offset=2227 size=106 bpp=24 filter=1>,
     #<ZPNG::ScanLine idx=22 offset=2333 size=106 bpp=24 filter=2>,
     #<ZPNG::ScanLine idx=23 offset=2439 size=106 bpp=24 filter=0>,
     #<ZPNG::ScanLine idx=24 offset=2545 size=106 bpp=24 filter=2>,
     #<ZPNG::ScanLine idx=25 offset=2651 size=106 bpp=24 filter=1>,
     #<ZPNG::ScanLine idx=26 offset=2757 size=106 bpp=24 filter=1>,
     #<ZPNG::ScanLine idx=27 offset=2863 size=106 bpp=24 filter=4>,
     #<ZPNG::ScanLine idx=28 offset=2969 size=106 bpp=24 filter=4>,
     #<ZPNG::ScanLine idx=29 offset=3075 size=106 bpp=24 filter=4>,
     #<ZPNG::ScanLine idx=30 offset=3181 size=106 bpp=24 filter=4>,
     #<ZPNG::ScanLine idx=31 offset=3287 size=106 bpp=24 filter=2>,
     #<ZPNG::ScanLine idx=32 offset=3393 size=106 bpp=24 filter=4>,
     #<ZPNG::ScanLine idx=33 offset=3499 size=106 bpp=24 filter=4>,
     #<ZPNG::ScanLine idx=34 offset=3605 size=106 bpp=24 filter=1>]

### Palette

    # zpng --palette qr_plte_bw.png

    <Chunk #02 PLTE size=     6, crc=55c2d37e >
    00000000  ff ff ff 00 00 00                                      |......|


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
