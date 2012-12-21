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

% zpng -h

### Info

% zpng --info qr_rgb.png

### Chunks

% zpng --chunks qr_aux_chunks.png

### ASCII

source image: ![qr_rgb.png](https://github.com/zed-0xff/zpng/raw/master/samples/qr_rgb.png)

% zpng --ascii --wide qr_rgb.png

### Scanlines

% zpng --scanlines qr_rgb.png

### Palette

% zpng --palette qr_plte_bw.png


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
