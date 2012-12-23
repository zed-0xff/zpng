#!/usr/bin/env ruby

module ZPNG
  module Hexdump

    def hexdump *args, &block
      print Hexdump.dump(*args, &block)
    end

    class << self
      def dump data, h = {}
        offset = h[:offset] || 0
        add    = h[:add]    || 0
        size   = h[:size]   || (data.size-offset)
        tail   = h[:tail]   || "\n"
        width  = h[:width]  || 0x10                 # row width, in bytes

        h[:show_offset] = true unless h.key?(:show_offset)
        h[:dedup]       = true unless h.key?(:dedup)

        size = data.size-offset if size+offset > data.size

        r = ''; prevhex = ''; c = nil; prevdup = false
        while true
          ascii = ''; hex = ''
          width.times do |i|
            hex << ' ' if i%8==0 && i>0
            if c = ((size > 0) && data[offset+i])
              hex << "%02x " % c.ord
              ascii << ((32..126).include?(c.ord) ? c : '.')
            else
              hex << '   '
              ascii << ' '
            end
            size-=1
          end

          if h[:dedup] && hex == prevhex
            row = "*"
            yield(row, offset+add, ascii) if block_given?
            r << row << "\n" unless prevdup
            prevdup = true
          else
            row = (h[:show_offset] ?  ("%08x: " % (offset + add)) : '') + hex + ' |' + ascii + "|"
            yield(row, offset+add, ascii) if block_given?
            r << row << "\n"
            prevdup = false
          end

          offset += width
          prevhex = hex
          break if size <= 0
        end
        if h[:show_offset] && prevdup
          row = "%08x: " % (offset + add)
          yield(row) if block_given?
          r << row
        end
        r.chomp + tail
      end
    end
  end
end

if $0 == __FILE__
  h = {}
  case ARGV.size
    when 0
      puts "gimme fname [offset] [size]"
      exit
    when 1
      fname = ARGV[0]
    when 2
      fname = ARGV[0]
      h[:offset] = ARGV[1].to_i
    when 3
      fname = ARGV[0]
      h[:offset] = ARGV[1].to_i
      h[:size]   = ARGV[2].to_i
  end
  File.open(fname,"rb") do |f|
    f.seek h[:offset] if h[:offset]
    @data = f.read(h[:size])
  end
  puts ZPNG::Hexdump.dump(@data)
end
