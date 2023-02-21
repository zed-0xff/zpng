# -*- coding:binary; frozen_string_literal: true -*-

# https://github.com/corkami/formats/blob/master/image/jpeg.md
# https://docs.fileformat.com/image/jpeg/
# https://www.file-recovery.com/jpg-signature-format.htm
# https://exiftool.org/TagNames/JPEG.html

module ZPNG
  module JPEG

    SOI = "\xff\xd8" # Start of Image
    EOI = "\xff\xd9" # End of Image

    MAGIC = SOI

    module Reader
      def _read_jpeg io
        @format = :jpeg

        while !io.eof?
          marker = io.read(2)
          break if marker == EOI

          case marker[1].ord
          when 0xc0
            @chunks << (@ihdr=SOF0.new(marker, io))
          when 0xc2
            @chunks << (@ihdr=SOF2.new(marker, io))
          when 0xc4
            @chunks << DHT.new(marker, io)
          when 0xcc
            @chunks << DAC.new(marker, io)
          when 0xc1..0xcf
            @chunks << SOF.new(marker, io)
          when 0xda
            @chunks << SOS.new(marker, io)
            # Entropy-Coded Segment starts
            @chunks << ECS.new(io)
          when 0xdb
            @chunks << DQT.new(marker, io)
          when 0xdd
            @chunks << DRI.new(marker, io)
          when 0xe0..0xef
            @chunks << APP.new(marker, io)
          when 0xfe
            @chunks << COM.new(marker, io)
          else
            $stderr.puts "[?] Unknown JPEG marker #{marker.inspect}".yellow
            @chunks << Chunk.new(marker, io)
          end
        end
      end
    end
  end
end
