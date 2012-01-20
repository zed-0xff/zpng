zpng
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

    Usage: zpng [options]
        -v, --verbose                    Run verbosely (can be used multiple times)
        -q, --quiet                      Silent any warnings (can be used multiple times)
        -I, --info                       General image info
        -C, --chunks                     Show file chunks (default)
        -A, --ascii                      Try to display image as ASCII (works best with monochrome images)
        -S, --scanlines                  Show scanlines info
        -P, --palette                    Show palette

### Info

    # zpng --info qr_rgb.png

    [.] image size 35x35
    [.] uncompressed imagedata size = 3710 bytes

### Chunks

    # zpng --chunks qr_aux_chunks.png

    [.] #<ZPNG::Chunk  IHDR size=   13, crc=36a28ef4, width=35, height=35, depth=1, color=0, compression=0, filter=0, interlace=0> CRC OK
    [.] #<ZPNG::Chunk  gAMA size=    4, crc=0bfc6105 > CRC OK
    [.] #<ZPNG::Chunk  sRGB size=    1, crc=aece1ce9 > CRC OK
    [.] #<ZPNG::Chunk  cHRM size=   32, crc=9cba513c > CRC OK
    [.] #<ZPNG::Chunk  pHYs size=    9, crc=46c96b3e > CRC OK
    [.] #<ZPNG::Chunk  IDAT size=  213, crc=5f3f1ff9 > CRC OK
    [.] #<ZPNG::Chunk  tEXt size=   37, crc=8d62fd1a > CRC OK
    [.] #<ZPNG::Chunk  tEXt size=   37, crc=fc3f45a6 > CRC OK
    [.] #<ZPNG::Chunk  IEND size=    0, crc=ae426082 > CRC OK

### ASCII

source image: ![qr_rgb.png](https://github.com/zed-0xff/zpng/raw/master/samples/qr_rgb.png)

    # zpng --ascii qr_rgb.png

                                       
     ####### ##     ## # ##    ####### 
     #     #       ## # ##     #     # 
     # ### # #  #####  # #  ## # ### # 
     # ### # ## #    # #### ## # ### # 
     # ### # #### #    # ####  # ### # 
     #     #  #  # #  #####    #     # 
     ####### # # # # # # # # # ####### 
              # # ##     ## ##         
     ####  # #    ## # ##    ##  ### # 
      # ##   ##     ## # ## # ###   ## 
     # ### ##      ## # ##  ## # ### # 
        ### #   #####  # #   ## #   #  
     ## ## #  # #    # ####  ## ##     
       #  # ## ## #    # ### ##    ##  
     # ###### ## # #  #####  #######   
     # ####  ### ## # ##    #   ## #   
       ## ##  ###     ## # ## ######## 
         #  ###  ##     ## ######### # 
     #### ##### ##     ## #   #   # #  
      ## #  #  # #  #####  # #  ##   # 
       ###### ##### #    # ##      #   
      ###     #  #### #    ### #   ### 
     ###  #### ####  # #  #######   ## 
     # # ## ## #     ## # ## ###### #  
      # #######  # ##     ## #####   # 
             # ### # ##     ##   # #   
     #######    # # ##     ### # #     
     #     #  ###  # #  ######   ### # 
     # ### #     # #### #   ########   
     # ### # ###   # #### # # #        
     # ### # ###  #####  # ##  #  #    
     #     # #### ##     ## ###      # 
     ####### # #  ## # ##   # ##   #

### Scanlines

    # zpng --scanlines qr_rgb.png

    [#<ZPNG::ScanLine idx=0, bpp=24, BPP=3, offset=1, filter=1>,
     #<ZPNG::ScanLine idx=1, bpp=24, BPP=3, offset=107, filter=4>,
     #<ZPNG::ScanLine idx=2, bpp=24, BPP=3, offset=213, filter=4>,
     #<ZPNG::ScanLine idx=3, bpp=24, BPP=3, offset=319, filter=4>,
     #<ZPNG::ScanLine idx=4, bpp=24, BPP=3, offset=425, filter=2>,
     #<ZPNG::ScanLine idx=5, bpp=24, BPP=3, offset=531, filter=2>,
     #<ZPNG::ScanLine idx=6, bpp=24, BPP=3, offset=637, filter=4>,
     #<ZPNG::ScanLine idx=7, bpp=24, BPP=3, offset=743, filter=0>,
     #<ZPNG::ScanLine idx=8, bpp=24, BPP=3, offset=849, filter=1>,
     #<ZPNG::ScanLine idx=9, bpp=24, BPP=3, offset=955, filter=0>,
     #<ZPNG::ScanLine idx=10, bpp=24, BPP=3, offset=1061, filter=0>,
     #<ZPNG::ScanLine idx=11, bpp=24, BPP=3, offset=1167, filter=0>,
     #<ZPNG::ScanLine idx=12, bpp=24, BPP=3, offset=1273, filter=1>,
     #<ZPNG::ScanLine idx=13, bpp=24, BPP=3, offset=1379, filter=2>,
     #<ZPNG::ScanLine idx=14, bpp=24, BPP=3, offset=1485, filter=4>,
     #<ZPNG::ScanLine idx=15, bpp=24, BPP=3, offset=1591, filter=0>,
     #<ZPNG::ScanLine idx=16, bpp=24, BPP=3, offset=1697, filter=4>,
     #<ZPNG::ScanLine idx=17, bpp=24, BPP=3, offset=1803, filter=0>,
     #<ZPNG::ScanLine idx=18, bpp=24, BPP=3, offset=1909, filter=4>,
     #<ZPNG::ScanLine idx=19, bpp=24, BPP=3, offset=2015, filter=4>,
     #<ZPNG::ScanLine idx=20, bpp=24, BPP=3, offset=2121, filter=0>,
     #<ZPNG::ScanLine idx=21, bpp=24, BPP=3, offset=2227, filter=1>,
     #<ZPNG::ScanLine idx=22, bpp=24, BPP=3, offset=2333, filter=2>,
     #<ZPNG::ScanLine idx=23, bpp=24, BPP=3, offset=2439, filter=0>,
     #<ZPNG::ScanLine idx=24, bpp=24, BPP=3, offset=2545, filter=2>,
     #<ZPNG::ScanLine idx=25, bpp=24, BPP=3, offset=2651, filter=1>,
     #<ZPNG::ScanLine idx=26, bpp=24, BPP=3, offset=2757, filter=1>,
     #<ZPNG::ScanLine idx=27, bpp=24, BPP=3, offset=2863, filter=4>,
     #<ZPNG::ScanLine idx=28, bpp=24, BPP=3, offset=2969, filter=4>,
     #<ZPNG::ScanLine idx=29, bpp=24, BPP=3, offset=3075, filter=4>,
     #<ZPNG::ScanLine idx=30, bpp=24, BPP=3, offset=3181, filter=4>,
     #<ZPNG::ScanLine idx=31, bpp=24, BPP=3, offset=3287, filter=2>,
     #<ZPNG::ScanLine idx=32, bpp=24, BPP=3, offset=3393, filter=4>,
     #<ZPNG::ScanLine idx=33, bpp=24, BPP=3, offset=3499, filter=4>,
     #<ZPNG::ScanLine idx=34, bpp=24, BPP=3, offset=3605, filter=1>]

### Palette

    # zpng --palette qr_plte_bw.png

    #<ZPNG::Chunk  PLTE size=    6, crc=55c2d37e >
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


License
-------
Released under the MIT License.  See the [LICENSE](https://github.com/zed-0xff/zpng/blob/master/LICENSE.txt) file for further details.
