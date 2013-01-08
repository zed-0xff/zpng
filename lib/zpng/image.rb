require 'stringio'

module ZPNG
  class Image
    attr_accessor :chunks, :scanlines, :imagedata, :extradata, :format, :verbose

    # now only for (limited) BMP support
    attr_accessor :color_class

    include DeepCopyable
    include BMP::Reader

    PNG_HDR = "\x89PNG\x0d\x0a\x1a\x0a".force_encoding('binary')
    BMP_HDR = "BM".force_encoding('binary')

    # possible input params:
    #   IO      of opened image file
    #   String  with image file already readed
    #   Hash    of image parameters to create new blank image
    def initialize x, h={}
      @chunks = []
      @color_class = Color
      @format = :png
      @verbose =
        case h[:verbose]
        when true;  1
        when false; 0
        else h[:verbose].to_i
        end

      case x
        when IO
          _from_io x
        when String
          _from_io StringIO.new(x)
        when Hash
          _from_hash x
        else
          raise "unsupported input data type #{x.class}"
      end
      if palette && hdr && hdr.depth
        palette.max_colors = 2**hdr.depth
      end
    end

    def adam7
      @adam7 ||= Adam7Decoder.new(self)
    end

    class << self
      # load image from file
      def load fname, h={}
        open(fname,"rb") do |f|
          self.new(f,h)
        end
      end
      alias :load_file :load
      alias :from_file :load # as in ChunkyPNG
    end

    # save image to file
    def save fname
      File.open(fname,"wb"){ |f| f << export }
    end

    # flag that image is just created, and NOT loaded from file
    # as in Rails' ActiveRecord::Base#new_record?
    def new_image?
      @new_image
    end
    alias :new? :new_image?

    private

    def _from_hash h
      @new_image = true
      @chunks << Chunk::IHDR.new(h)
      if header.palette_used?
        if h.key?(:palette)
          if h[:palette]
            @chunks << h[:palette]
          else
            # :palette => nil
            # assume palette will be added later
          end
        else
          @chunks << Chunk::PLTE.new
          palette[0] = h[:background] || h[:bg] || Color::BLACK # add default bg color
        end
      end
    end

    def _read_png io
      while !io.eof?
        chunk = Chunk.from_stream(io)
        chunk.idx = @chunks.size
        @chunks << chunk
        break if chunk.is_a?(Chunk::IEND)
      end
    end

    def _from_io io
      # Puts ios into binary mode.
      # Once a stream is in binary mode, it cannot be reset to nonbinary mode.
      io.binmode

      hdr = io.read(BMP_HDR.size)
      if hdr == BMP_HDR
        _read_bmp io
      else
        hdr << io.read(PNG_HDR.size - BMP_HDR.size)
        if hdr == PNG_HDR
          _read_png io
        else
          raise "Unsupported header #{hdr.inspect} in #{io.inspect}"
        end
      end

      unless io.eof?
        offset     = io.tell
        @extradata = io.read
        puts "[?] #{@extradata.size} bytes of extra data after image end (IEND), offset = 0x#{offset.to_s(16)}".red if @verbose >= 1
      end
    end

    public

    # internal helper method for color types 0 (grayscale) and 2 (truecolor)
    def _alpha_color color
      return nil unless trns

      # For color type 0 (grayscale), the tRNS chunk contains a single gray level value, stored in the format:
      #
      #   Gray:  2 bytes, range 0 .. (2^bitdepth)-1
      #
      # For color type 2 (truecolor), the tRNS chunk contains a single RGB color value, stored in the format:
      #
      #   Red:   2 bytes, range 0 .. (2^bitdepth)-1
      #   Green: 2 bytes, range 0 .. (2^bitdepth)-1
      #   Blue:  2 bytes, range 0 .. (2^bitdepth)-1
      #
      # (If the image bit depth is less than 16, the least significant bits are used and the others are 0)
      # Pixels of the specified gray level are to be treated as transparent (equivalent to alpha value 0);
      # all other pixels are to be treated as fully opaque ( alpha = (2^bitdepth)-1 )

      @alpha_color ||=
        case hdr.color
        when COLOR_GRAYSCALE
          v = trns.data.unpack('n')[0] & (2**hdr.depth-1)
          Color.from_grayscale(v, :depth => hdr.depth)
        when COLOR_RGB
          a = trns.data.unpack('n3').map{ |v| v & (2**hdr.depth-1) }
          Color.new(*a, :depth => hdr.depth)
        else
          raise "color2alpha only intended for GRAYSCALE & RGB color modes"
        end

      color == @alpha_color ? 0 : (2**hdr.depth-1)
    end

    public

    ###########################################################################
    # chunks access

    def ihdr
      @ihdr ||= @chunks.find{ |c| c.is_a?(Chunk::IHDR) }
    end
    alias :header :ihdr
    alias :hdr :ihdr

    def trns
      # not used "@trns ||= ..." here b/c it will call find() each time of there's no TRNS chunk
      defined?(@trns) ? @trns : (@trns=@chunks.find{ |c| c.is_a?(Chunk::TRNS) })
    end

    def plte
      @plte ||= @chunks.find{ |c| c.is_a?(Chunk::PLTE) }
    end
    alias :palette :plte

    ###########################################################################
    # image attributes

    def bpp
      ihdr && @ihdr.bpp
    end

    def width
      ihdr && @ihdr.width
    end

    def height
      ihdr && @ihdr.height
    end

    def grayscale?
      ihdr && @ihdr.grayscale?
    end

    def interlaced?
      ihdr && @ihdr.interlace != 0
    end

    def alpha_used?
      ihdr && @ihdr.alpha_used?
    end

    private
    def _imagedata
      data_chunks = @chunks.find_all{ |c| c.is_a?(Chunk::IDAT) }
      case data_chunks.size
      when 0
        # no imagedata chunks ?!
        nil
      when 1
        # a single chunk - save memory and return a reference to its data
        data_chunks[0].data
      else
        # multiple data chunks - join their contents
        data_chunks.map(&:data).join
      end
    end
    public

    def imagedata
      @imagedata ||=
        begin
          puts "[?] no image header, assuming non-interlaced RGB".yellow unless header
          data = _imagedata
          #check_zlib_extradata data
          (data && data.size > 0) ? Zlib::Inflate.inflate(data) : ''
        end
    end

    def imagedata_size
      if new_image?
        @scanlines.map(&:size).inject(&:+)
      else
        imagedata.size
      end
    end

#    # check for extradata in zlib datastream after the end of compressed stream
#    def check_zlib_extradata data
#      zi = Zlib::Inflate.new(Zlib::MAX_WBITS)
#      io = StringIO.new(data)
#      while !io.eof? && !zi.finished?
#        zi.inflate(io.read(16384))
#      end
#      zi.finish unless zi.finished?
#      if data.size != zi.total_in
#        p [data.size, zi.total_in, zi.total_out]
#        raise
#      end
#      zi.close if zi && !zi.closed?
#    end

#    # try to get imagedata size in bytes, w/o storing entire decompressed
#    # stream in memory. used in bin/zpng
#    # result: less memory used on big images, but speed gain near 1-2% in best case,
#    #         and 2x slower in worst case because imagedata decoded 2 times
#    def imagedata_size
#      if @imagedata
#        # already decompressed
#        @imagedata.size
#      else
#        zi = nil
#        @imagedata_size ||=
#          begin
#            zi = Zlib::Inflate.new(Zlib::MAX_WBITS)
#            io = StringIO.new(_imagedata)
#            while !io.eof? && !zi.finished?
#              n = zi.inflate(io.read(16384))
#            end
#            zi.finish unless zi.finished?
#            zi.total_out
#          ensure
#            zi.close if zi && !zi.closed?
#          end
#      end
#    end

    def metadata
      @metadata ||= Metadata.new(self)
    end

    def [] x, y
      x,y = adam7.convert_coords(x,y) if interlaced?
      scanlines[y][x]
    end

    def []= x, y, newpixel
      decode_all_scanlines
      x,y = adam7.convert_coords(x,y) if interlaced?
      scanlines[y][x] = newpixel
    end

    # we must decode all scanlines before doing any modifications
    # or scanlines decoded AFTER modification of UPPER ones will be decoded wrong
    def decode_all_scanlines
      return if @all_scanlines_decoded || new_image?
      @all_scanlines_decoded = true
      scanlines.each(&:decode!)
    end

    def scanlines
      @scanlines ||=
        begin
          r = []
          n = interlaced? ? adam7.scanlines_count : height.to_i
          n.times do |i|
            r << ScanLine.new(self,i)
          end
          r.delete_if(&:bad?)
          r
        end
    end

    def to_ascii *args
      if scanlines.any?
        if interlaced?
          height.times.map{ |y| width.times.map{ |x| self[x,y].to_ascii(*args) }.join }.join("\n")
        else
          scanlines.map{ |l| l.to_ascii(*args) }.join("\n")
        end
      else
        super()
      end
    end

    def extract_block x,y=nil,w=nil,h=nil
      if x.is_a?(Hash)
        Block.new(self,x[:x], x[:y], x[:width], x[:height])
      else
        Block.new(self,x,y,w,h)
      end
    end

    def each_block bw,bh, &block
      0.upto(height/bh-1) do |by|
        0.upto(width/bw-1) do |bx|
          b = extract_block(bx*bw, by*bh, bw, bh)
          yield b
        end
      end
    end

    def export
      # fill @imagedata, if not already filled
      imagedata unless new_image?

      # delete old IDAT chunks
      @chunks.delete_if{ |c| c.is_a?(Chunk::IDAT) }

      # fill first_idat @data with compressed imagedata
      @chunks << Chunk::IDAT.new(
        :data => Zlib::Deflate.deflate(scanlines.map(&:export).join, 9)
      )

      # delete IEND chunk(s) b/c we just added a new chunk and IEND must be the last one
      @chunks.delete_if{ |c| c.is_a?(Chunk::IEND) }

      # add fresh new IEND
      @chunks << Chunk::IEND.new

      PNG_HDR + @chunks.map(&:export).join
    end

    # modifies this image
    def crop! params
      decode_all_scanlines

      x,y,h,w = (params[:x]||0), (params[:y]||0), params[:height], params[:width]
      raise "negative params not allowed" if [x,y,h,w].any?{ |x| x < 0 }

      # adjust crop sizes if they greater than image sizes
      h = self.height-y if (y+h) > self.height
      w = self.width-x if (x+w) > self.width
      raise "negative params not allowed (p2)" if [x,y,h,w].any?{ |x| x < 0 }

      # delete excess scanlines at tail
      scanlines[(y+h)..-1] = [] if (y+h) < scanlines.size

      # delete excess scanlines at head
      scanlines[0,y] = [] if y > 0

      # crop remaining scanlines
      scanlines.each{ |l| l.crop!(x,w) }

      # modify header
      hdr.height, hdr.width = h, w

      # return self
      self
    end

    # returns new image
    def crop params
      decode_all_scanlines
      # deep copy first, then crop!
      deep_copy.crop!(params)
    end

    def pixels
      Pixels.new(self)
    end

    def == other_image
      width  == other_image.width &&
      height == other_image.height &&
      pixels == other_image.pixels
    end

    def each_pixel &block
      height.times do |y|
        width.times do |x|
          yield(self[x,y], x, y)
        end
      end
    end

    # returns new deinterlaced image if deinterlaced
    # OR returns self if no need to deinterlace
    def deinterlace
      return self unless interlaced?

      # copy all but 'interlace' header params
      h = Hash[*%w'width height depth color compression filter'.map{ |k| [k.to_sym, hdr.send(k)] }.flatten]

      # don't auto-add palette chunk
      h[:palette] = nil

      # create new img
      new_img = self.class.new h

      # copy all but hdr/imagedata/end chunks
      chunks.each do |chunk|
        next if chunk.is_a?(Chunk::IHDR)
        next if chunk.is_a?(Chunk::IDAT)
        next if chunk.is_a?(Chunk::IEND)
        new_img.chunks << chunk.deep_copy
      end

      # pixel-by-pixel copy
      each_pixel do |c,x,y|
        new_img[x,y] = c
      end

      new_img
    end
  end
end
