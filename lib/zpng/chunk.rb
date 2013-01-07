module ZPNG
  class Chunk
    attr_accessor :size, :type, :data, :crc, :idx

    include DeepCopyable

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
      fix_crc!
      [@size,@type].pack('Na4') + @data + [@crc].pack('N')
    end

    def export_data
      #STDERR.puts "[!] Chunk::#{type} must realize 'export_data' virtual method".yellow if @size != 0
      @data || ''
    end

    def inspect verbosity = 10
      size = @size ? sprintf("%6d",@size) : sprintf("%6s","???")
      crc  = @crc  ? sprintf("%08x",@crc) : sprintf("%8s","???")
      type = @type.to_s.gsub(/[^0-9a-z]/i){ |x| sprintf("\\x%02X",x.ord) }
      sprintf "<Chunk #%02d %4s size=%s, crc=%s >", idx.to_i, type, size, crc
    end

    def crc_ok?
      expected_crc = Zlib.crc32(data, Zlib.crc32(type))
      expected_crc == crc
    end

    def fix_crc!
      @crc = Zlib.crc32(data, Zlib.crc32(type))
    end

    class IHDR < Chunk
      attr_accessor :width, :height, :depth, :color, :compression, :filter, :interlace

      PALETTE_USED = 1
      COLOR_USED   = 2
      ALPHA_USED   = 4

      # put constants in the scope of ZPNG module
      # to be able to create new images easily with
      # include ZPNG
      # img = Image.new :width => 16, :height => 16, :color => COLOR_RGB

      ZPNG::COLOR_GRAYSCALE  = 0  # Each pixel is a grayscale sample
      ZPNG::COLOR_RGB        = 2  # Each pixel is an R,G,B triple.
      ZPNG::COLOR_INDEXED    = 3  # Each pixel is a palette index; a PLTE chunk must appear.
      ZPNG::COLOR_GRAY_ALPHA = 4  # Each pixel is a grayscale sample, followed by an alpha sample.
      ZPNG::COLOR_RGBA       = 6  # Each pixel is an R,G,B triple, followed by an alpha sample.

      SAMPLES_PER_COLOR = {
        COLOR_GRAYSCALE  => 1,
        COLOR_RGB        => 3,
        COLOR_INDEXED    => 1,
        COLOR_GRAY_ALPHA => 2,
        COLOR_RGBA       => 4
      }

      # http://www.w3.org/TR/PNG/#table111
      ALLOWED_DEPTHS = {
        COLOR_GRAYSCALE  => [ 1, 2, 4, 8, 16 ],
        COLOR_RGB        => [          8, 16 ],
        COLOR_INDEXED    => [ 1, 2, 4, 8     ],
        COLOR_GRAY_ALPHA => [          8, 16 ],
        COLOR_RGBA       => [          8, 16 ],
      }

      FORMAT = 'NNC5'

      def initialize x
        super
        vars = %w'width height depth color compression filter interlace' # order is important
        if x.respond_to?(:read)
          # IO
        elsif x.respond_to?(:[])
          # Hash
          vars.each{ |k| instance_variable_set "@#{k}", x[k.to_sym] }

          raise "[!] width not set" unless @width
          raise "[!] height not set" unless @height

          # allow easier image creation like
          # img = Image.new :width => 16, :height => 16, :bpp => 4, :color => false
          # img = Image.new :width => 16, :height => 16, :bpp => 1, :color => true
          # img = Image.new :width => 16, :height => 16, :bpp => 32
          if x[:bpp]
            unless [true,false,nil].include?(@color)
              raise "[!] :color must be either 'true' or 'false' when :bpp is set"
            end
            if @depth
              raise "[!] don't use :depth when :bpp is set"
            end
            @color, @depth = case x[:bpp]
              when 1,2,4,8; [ @color ? COLOR_INDEXED : COLOR_GRAYSCALE,  x[:bpp] ]
              when 16;
                raise "[!] I don't know how to make COLOR 16 bpp PNG. do you?" if @color
                [ COLOR_GRAY_ALPHA, 8 ]
              when 24;      [ COLOR_RGB,  8 ]
              when 32;      [ COLOR_RGBA, 8 ]
              else
                raise "[!] unsupported bpp=#{x[:bpp].inspect}"
              end
          end

          @color       ||= COLOR_RGBA
          @depth       ||= 8
          @compression ||= 0
          @filter      ||= 0
          @interlace   ||= 0

          unless ALLOWED_DEPTHS[@color].include?(@depth)
            raise "[!] invalid color mode (#{@color.inspect}) / bit depth (#{@depth.inspect}) combination"
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

      def inspect verbosity = 10
        vars = instance_variables - [:@type, :@crc, :@data, :@size]
        vars -= [:@idx] if verbosity <= 0
        super.sub(/ *>$/,'') + ", " +
          vars.sort.map{ |var| "#{var.to_s.tr('@','')}=#{instance_variable_get(var)}" }.
          join(", ") + ">"
      end
    end

    class PLTE < Chunk
      attr_accessor :max_colors

      def [] idx
        rgb = @data[idx*3,3]
        rgb && ZPNG::Color.new(*rgb.unpack('C3'))
      end

      def []= idx, color
        @data ||= ''
        @data[idx*3,3] = [color.r, color.g, color.b].pack('C3')
      end

      def ncolors
        @data.to_s.size/3
      end

      def index color
        ncolors.times do |i|
          c = self[i]
          return i if c.r == color.r && c.g == color.g && c.b == color.b
        end
        nil
      end

      def add color
        raise "palette full (#{ncolors}), cannot add #{color.inspect}" if ncolors >= max_colors
        idx = ncolors
        self[idx] = color
        idx
      end

      def find_or_add color
        index(color) || add(color)
      end
      alias :<< :find_or_add
    end

    class IDAT < Chunk; end
    class IEND < Chunk; end
    class TRNS < Chunk; end

  end
end
