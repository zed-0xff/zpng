#!/usr/bin/env ruby
require 'zlib'
require 'stringio'

require 'zpng/string_ext'
require 'zpng/deep_copyable'

require 'zpng/color'
require 'zpng/block'
require 'zpng/scan_line'
require 'zpng/chunk'
require 'zpng/image'
require 'zpng/adam7_decoder'

# see alse http://github.com/wvanbergen/chunky_png/

if $0 == __FILE__
  if ARGV.size == 0
    puts "gimme a png filename!"
  else
    img = ZPNG::Image.new(ARGV[0])
    img.dump
    puts "[.] image size #{img.width}x#{img.height}"
    puts "[.] uncompressed imagedata size=#{img.imagedata.size}"
    puts "[.] palette =#{img.palette}"
#    puts "[.] imagedata: #{img.imagedata[0..30].split('').map{|x| sprintf("%02X",x.ord)}.join(' ')}"

    require 'hexdump'
    #Hexdump.dump(img.imagedata, :width => 6)
    require 'pp'
    pp img.scanlines[0..5]
#    puts Hexdump.dump(img.imagedata[0,60])
#    img.scanlines.each do |l|
#      puts l.to_s
#    end
    puts img.to_s
    img[1,0]= ZPNG::Color.new(0,0,0)
    puts img.to_s
    File.open 'export.png','wb' do |f|
      f << img.export
    end
  end
end

