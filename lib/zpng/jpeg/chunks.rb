# -*- coding:binary; frozen_string_literal: true -*-

module ZPNG
  module JPEG

    class Chunk
      attr_accessor :marker, :size, :data

      def initialize marker, io
        @marker = marker
        @size = io.read(2).unpack('n')[0]
        @data = io.read(@size-2)
      end

      def type
        r = self.class.name.split("::").last.ljust(4)
        r = "ch_%02X" % @marker[1].ord if r == "Chunk"
        r
      end

      def crc
        :no_crc
      end

      def inspect *args
        size = @size ? sprintf("%6d",@size) : sprintf("%6s","???")
        sprintf "<%4s size=%s >", type, size
      end

      def export *args
        @marker + [@size].pack('n') + @data
      end
    end

    class APP < Chunk
      attr_accessor :name

      # BYTE Version[2];      /* 07h  JFIF Format Revision      */
      # BYTE Units;           /* 09h  Units used for Resolution */
      # BYTE Xdensity[2];     /* 0Ah  Horizontal Resolution     */
      # BYTE Ydensity[2];     /* 0Ch  Vertical Resolution       */
      # BYTE XThumbnail;      /* 0Eh  Horizontal Pixel Count    */
      # BYTE YThumbnail;      /* 0Fh  Vertical Pixel Count      */
      class JFIF < IOStruct.new( 'vcnncc', :version, :units, :xdensity, :ydensity, :xthumbnail, :ythumbnail )
        def inspect *args
          r = "<" + super.split(' ',3).last
          r.sub!(/version=\d+/, "version=#{version >> 8}.#{version & 0xff}") if version
          r
        end
      end

      def initialize marker, io
        super
        @id  = marker[1].ord & 0xf
        @name = @data.unpack('Z*')[0]
        if @name == 'JFIF'
          @jfif = JFIF.read(@data[5..-1])
          # TODO: read thumbnail, see https://en.wikipedia.org/wiki/JPEG_File_Interchange_Format
        end
      end

      def type
        "APP#{@id}"
      end

      def inspect *args
        r = super.chop + ("name=%s >" % name.inspect)
        if @jfif
          r = r.chop + ("jfif=%s>" % @jfif.inspect)
        end
        r
      end
    end

    class SOF < Chunk
      def initialize marker, io
        super
        @id = marker[1].ord & 0xf
      end

      def type
        "SOF#{@id}"
      end
    end

    class SOF0 < SOF
      attr_accessor :bpp, :width, :height, :components
      attr_accessor :color # for compatibility with IHDR

      def initialize marker, io
        super
        @bpp, @height, @width, @components = @data.unpack('CnnC')
      end

      def inspect *args
        super.chop + ("bpp=%d width=%d height=%d components=%d >" % [bpp, width, height, components])
      end
    end

    class SOF2 < SOF
      attr_accessor :precision, :width, :height, :components
      attr_accessor :color # for compatibility with IHDR

      def initialize marker, io
        super
        @precision, @height, @width, @components = @data.unpack('CnnC')
      end

      def bpp
        precision
      end

      def inspect *args
        super.chop + ("precision=%d width=%d height=%d components=%d >" % [precision, width, height, components])
      end
    end

    class DHT < Chunk
      attr_accessor :id, :lengths, :values

      def initialize marker, io
        super
        @id, *@lengths = @data.unpack("CC16")
        @values = @data.unpack("x17C" + @lengths.inject(:+).to_s)
      end

      def inspect verbose = 0
        r = super.chop + ("id=%02x lengths=%s >" % [id, lengths.inspect])
        r = r.chop + ("values=%s >" % [values.inspect]) if verbose > 0
        r
      end
    end

    class SOS < Chunk; end
    class DRI < Chunk; end
    class DQT < Chunk; end
    class DAC < Chunk; end

    class COM < Chunk
      def inspect *args
        super.chop + ("data=%s>" % data.inspect)
      end
    end

    # Its length is unknown in advance, nor defined in the file.
    # The only way to get its length is to either decode it or to fast-forward over it:
    # just scan forward for a FF byte. If it's a restart marker (followed by D0 - D7) or a data FF (followed by 00), continue.
    class ECS < Chunk
      def initialize io
        @data = io.read
        if (pos = @data.index(/\xff[^\x00\xd0-\xd7]/))
          io.seek(pos-@data.size, :CUR) # seek back
          @data = @data[0, pos]
        end
        @size = @data.size
      end

      def export *args
        @data
      end
    end

  end
end
