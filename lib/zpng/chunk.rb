module ZPNG
  class Chunk
    attr_accessor :size, :type, :data, :crc, :idx

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

    def initialize x = {}
      if x.respond_to?(:read)
        # IO
        @size, @type = x.read(8).unpack('Na4')
        @data        = x.read(size)
        @crc         = x.read(4).to_s.unpack('N').first
      elsif x.respond_to?(:[])
        # Hash
        %w'size type data crc'.each do |k|
          instance_variable_set "@#{k}", x[k.to_sym]
        end
        if !@type && self.class.superclass == ZPNG::Chunk
          # guess @type from self class name, e.g. ZPNG::Chunk::IHDR => "IHDR"
          @type = self.class.to_s.split("::").last
        end
        if !@size && @data
          # guess @size from @data
          @size = @data.size
        end
      end
    end

    def export
      @data = self.export_data # virtual
      @size = @data.size # XXX hmm.. is it always is?
      @crc = Zlib.crc32(data, Zlib.crc32(type))
      [@size,@type].pack('Na4') + @data + [@crc].pack('N')
    end

    def export_data
      #STDERR.puts "[!] Chunk::#{type} must realize 'export_data' virtual method".yellow if @size != 0
      @data || ''
    end

    def inspect
      size = @size ? sprintf("%5d",@size) : sprintf("%5s","???")
      crc  = @crc  ? sprintf("%08x",@crc) : sprintf("%8s","???")
      type = @type.to_s.gsub(/[^0-9a-z]/i){ |x| sprintf("\\x%02X",x.ord) }
      sprintf "<Chunk #%02d %4s size=%s, crc=%s >", idx.to_i, type, size, crc
    end

    def crc_ok?
      expected_crc = Zlib.crc32(data, Zlib.crc32(type))
      expected_crc == crc
    end

    class IHDR < Chunk
      attr_accessor :width, :height, :depth, :color, :compression, :filter, :interlace

      PALETTE_USED = 1
      COLOR_USED   = 2
      ALPHA_USED   = 4

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

      def initialize x
        super
        vars = %w'width height depth color compression filter interlace' # order is important
        if x.respond_to?(:read)
          # IO
        elsif x.respond_to?(:[])
          # Hash
          vars.each do |k|
            instance_variable_set "@#{k}", x[k.to_sym]
          end
        end
        if data
          data.unpack(FORMAT).each_with_index do |value,idx|
            instance_variable_set "@#{vars[idx]}", value
          end
        end
      end

      def export_data
        [@width, @height, @depth, @color, @compression, @filter, @interlace].pack(FORMAT)
      end

      # bits per pixel
      def bpp
        SAMPLES_PER_COLOR[@color] * depth
      end

      def color_used?
        (@color & COLOR_USED) != 0
      end

      def grayscale?
        !color_used?
      end

      def palette_used?
        (@color & PALETTE_USED) != 0
      end

      def alpha_used?
        (@color & ALPHA_USED) != 0
      end

      def inspect
        super.sub(/ *>$/,'') + ", " +
          (instance_variables-[:@type, :@crc, :@data, :@size]).
          map{ |var| "#{var.to_s.tr('@','')}=#{instance_variable_get(var)}" }.
          join(", ") + ">"
      end
    end

    class PLTE < Chunk
      def [] idx
        rgb = @data[idx*3,3]
        rgb && ZPNG::Color.new(*rgb.split('').map(&:ord))
      end

      def ncolors
        @size/3
      end

      def index color
        ncolors.times do |i|
          c = self[i]
          return i if c.r == color.r && c.g == color.g && c.b == color.b
        end
        nil
      end
    end

    class IDAT < Chunk; end
    class IEND < Chunk; end

    class ZTXT < Chunk
      attr_accessor :keyword, :comp_method, :text
      def initialize *args
        super
        @keyword,@comp_method,@text = data.unpack('Z*Ca*')
        if @text
          @text = Zlib::Inflate.inflate(@text)
        end
      end
      def inspect
        super.sub(/ *>$/,'') + ", " +
          (instance_variables-[:@type, :@crc, :@data, :@size]).
          map do |var|
            t = instance_variable_get(var).to_s
            t = t[0..10] + "..." if t.size > 10
            "#{var.to_s.tr('@','')}=#{t}"
          end.join(", ") + ">"
      end
    end
  end
end
