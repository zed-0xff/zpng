module ZPNG
  class Chunk
    attr_accessor :size, :type, :data, :crc

    def self.from_stream io
      size, type = io.read(8).unpack('Na4')
      io.seek(-8,IO::SEEK_CUR)
      begin
        if const_defined?(type.upcase)
          klass = const_get(type.upcase)
          klass.new(io)
        else
          Chunk.new(io)
        end
      rescue NameError
        # invalid chunk type?
        Chunk.new(io)
      end
    end

    def initialize io
      @size, @type = io.read(8).unpack('Na4')
      @data        = io.read(size)
      @crc         = io.read(4).to_s.unpack('N').first
    end

    def export
      @data = self.export_data # virtual
      @crc = Zlib.crc32(data, Zlib.crc32(type))
      [@size,@type].pack('Na4') + @data + [@crc].pack('N')
    end

    def export_data
      STDERR.puts "[!] Chunk::#{type} must realize 'export_data' virtual method".yellow if @size != 0
      @data
    end

    def inspect
      size = @size ? sprintf("%5d",@size) : sprintf("%5s","???")
      crc  = @crc  ? sprintf("%08x",@crc) : sprintf("%8s","???")
      type = @type.to_s.gsub(/[^0-9a-z]/i){ |x| sprintf("\\x%02X",x.ord) }
      sprintf("#<ZPNG::Chunk  %4s size=%s, crc=%s >", type, size, crc)
    end

    def crc_ok?
      expected_crc = Zlib.crc32(data, Zlib.crc32(type))
      expected_crc == crc
    end

    class IHDR < Chunk
      attr_accessor :width, :height, :depth, :color, :compression, :filter, :interlace

      COLOR_GRAYSCALE  = 0  # Each pixel is a grayscale sample
      COLOR_RGB        = 2  # Each pixel is an R,G,B triple.
      COLOR_INDEXED    = 3  # Each pixel is a palette index; a PLTE chunk must appear.
      COLOR_GRAY_ALPHA = 4  # Each pixel is a grayscale sample, followed by an alpha sample.
      COLOR_RGBA       = 6  # Each pixel is an R,G,B triple, followed by an alpha sample.

      SAMPLES_PER_COLOR = {
        COLOR_GRAYSCALE  => 1,
        COLOR_RGB        => 3,
        COLOR_INDEXED    => 1,
        COLOR_GRAY_ALPHA => 2,
        COLOR_RGBA       => 4
      }

      FORMAT = 'NNC5'

      def initialize io
        super
        @width, @height, @depth, @color, @compression, @filter, @interlace = data.unpack(FORMAT)
      end

      def export_data
        [@width, @height, @depth, @color, @compression, @filter, @interlace].pack(FORMAT)
      end

      # bits per pixel
      def bpp
        SAMPLES_PER_COLOR[@color] * depth
      end

      def inspect
        super.sub(/ *>$/,'') + ", " +
          (instance_variables-[:@type, :@crc, :@data, :@size]).
          map{ |var| "#{var.to_s.tr('@','')}=#{instance_variable_get(var)}" }.
          join(", ") + ">"
      end
    end

    class PLTE < Chunk
    end

    class IEND < Chunk
    end
  end
end
