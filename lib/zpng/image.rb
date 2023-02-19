require 'stringio'

module ZPNG
  class Image
    attr_accessor :chunks, :scanlines, :imagedata, :extradata, :format, :verbose

    # now only for (limited) BMP support
    attr_accessor :color_class

    include DeepCopyable
    alias :clone :deep_copy
    alias :dup   :deep_copy

    include BMP::Reader

    PNG_HDR = "\x89PNG\x0d\x0a\x1a\x0a".force_encoding('binary')
    BMP_HDR = "BM".force_encoding('binary')

    # possible input params:
    #   IO      of opened image file
    #   String  with image file already readed
    #   Hash    of image parameters to create new blank image
    def initialize x, h={}
      @chunks = []
      @extradata = []
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
          raise NotSupported, "unsupported input data type #{x.class}"
      end
      if palette && hdr && hdr.depth
        palette.max_colors = 2**hdr.depth
      end
    end

    def inspect
      "#<ZPNG::Image " +
      %w'width height bpp chunks scanlines'.map do |k|
        v = case (v = send(k))
          when Array
            "[#{v.size} entries]"
          when String
            v.size > 40 ? "[#{v.bytesize} bytes]" : v.inspect
          else v.inspect
        end
        "#{k}=#{v}"
      end.compact.join(", ") + ">"
    end

    def adam7
      @adam7 ||= Adam7Decoder.new(width, height, bpp)
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
    def save fname, options={}
      File.open(fname,"wb"){ |f| f << export(options) }
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

    HEUR_CHUNK_SIZE_RANGE = -16..16

    # assume previous chunk size is not right, try to iterate over neighbour data
    def _apply_heuristics io, prev_chunk, chunk
      prev_pos = io.tell
      HEUR_CHUNK_SIZE_RANGE.each do |delta|
        next if delta == 0
        next if prev_chunk.data.size + delta < 0
        io.seek(chunk.offset+delta, IO::SEEK_SET)
        potential_chunk = Chunk.new(io)
        if potential_chunk.valid?
          STDERR.puts "[!] heuristics: found invalid #{chunk.type.inspect} chunk at offset #{chunk.offset}, but valid #{potential_chunk.type.inspect} at #{chunk.offset+delta}. using latter".red
          if delta > 0
            io.seek(chunk.offset, IO::SEEK_SET)
            data = io.read(delta)
            STDERR.puts "[!] #{delta} extra bytes of data: #{data.inspect}".red
          else
            io.seek(chunk.offset+delta, IO::SEEK_SET)
          end
          return true
        end
      end
      false
    end

    def _read_png io
      prev_chunk = nil
      while !io.eof?
        chunk = Chunk.from_stream(io)
        # heuristics
        if prev_chunk && prev_chunk.check(type: true, crc: false) &&
            chunk.check(type: false, crc: false) && chunk.data
          redo if _apply_heuristics(io, prev_chunk, chunk)
        end
        chunk.idx = @chunks.size
        @chunks << chunk
        prev_chunk = chunk
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
          raise NotSupported, "Unsupported header #{hdr.inspect} in #{io.inspect}"
        end
      end

      unless io.eof?
        offset     = io.tell
        @extradata << io.read
        STDERR.puts "[?] #{@extradata.last.size} bytes of extra data after image end (IEND), offset = 0x#{offset.to_s(16)}".red if @verbose >= 1
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
          raise Exception, "color2alpha only intended for GRAYSCALE & RGB color modes"
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

    # unpack zlib,
    # on errors keep going and try to return maximum possible data
    def _safe_inflate data
      zi = Zlib::Inflate.new
      pos = 0; r = ''
      begin
        # save some memory by not using String#[] when not necessary
        r << zi.inflate(pos==0 ? data : data[pos..-1])
        if zi.total_in < data.size
          @extradata << data[zi.total_in..-1]
          STDERR.puts "[?] #{@extradata.last.size} bytes of extra data after zlib stream".red if @verbose >= 1
        end
        # decompress OK
      rescue Zlib::BufError
        # tried to decompress, but got EOF - need more data
        STDERR.puts "[!] #{$!.inspect}".red if @verbose >= -1
        # collect any remaining data in decompress buffer
        r << zi.flush_next_out
      rescue Zlib::DataError
        STDERR.puts "[!] #{$!.inspect}".red if @verbose >= -1
        #p [pos, zi.total_in, zi.total_out, data.size, r.size]
        r << zi.flush_next_out
        # XXX TODO try to skip error and continue
#        printf "[d] pos=%d/%d t_in=%d t_out=%d bytes_ok=%d\n".gray, pos, data.size,
#          zi.total_in, zi.total_out, r.size
#        if pos < zi.total_in
#          pos = zi.total_in
#        else
#          pos += 1
#        end
#        pos = 0
#        retry if pos < data.size
      rescue Zlib::NeedDict
        STDERR.puts "[!] #{$!.inspect}".red if @verbose >= -1
        # collect any remaining data in decompress buffer
        r << zi.flush_next_out
      end

      r == "" ? nil : r
    ensure
      zi.close if zi && !zi.closed?
    end

    public

    def imagedata
      @imagedata ||=
        begin
          STDERR.puts "[?] no image header, assuming non-interlaced RGB".yellow unless header
          data = _imagedata
          (data && data.size > 0) ? _safe_inflate(data) : ''
        end
    end

    def imagedata_size
      if new_image?
        @scanlines.map(&:size).inject(&:+)
      else
        imagedata&.size
      end
    end

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
      # extracting this check into a module => +1-2% speed
      x,y = adam7.convert_coords(x,y) if interlaced?
      scanlines[y][x]
    end

    def []= x, y, newcolor
      # extracting these checks into a module => +1-2% speed
      decode_all_scanlines
      x,y = adam7.convert_coords(x,y) if interlaced?
      scanlines[y][x] = newcolor
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

    def export options = {}
      # allow :zlib_level => nil
      options[:zlib_level] = 9 unless options.key?(:zlib_level)

      if options.fetch(:repack, true)
        data = Zlib::Deflate.deflate(scanlines.map(&:export).join, options[:zlib_level])

        idats = @chunks.find_all{ |c| c.is_a?(Chunk::IDAT) }
        case idats.size
        when 0
          # add new IDAT
          @chunks << Chunk::IDAT.new( :data => data )
        when 1
          idats[0].data = data
        else
          idats[0].data = data
          # delete other IDAT chunks
          @chunks -= idats[1..-1]
        end
      end

      unless @chunks.last.is_a?(Chunk::IEND)
        # delete old IEND chunk(s) b/c IEND must be the last one
        @chunks.delete_if{ |c| c.is_a?(Chunk::IEND) }

        # add fresh new IEND
        @chunks << Chunk::IEND.new
      end

      PNG_HDR + @chunks.map(&:export).join
    end

    # modifies this image
    def crop! params
      decode_all_scanlines

      x,y,h,w = (params[:x]||0), (params[:y]||0), params[:height], params[:width]
      raise ArgumentError, "negative params not allowed" if [x,y,h,w].any?{ |x| x < 0 }

      # adjust crop sizes if they greater than image sizes
      h = self.height-y if (y+h) > self.height
      w = self.width-x if (x+w) > self.width
      raise ArgumentError, "negative params not allowed (p2)" if [x,y,h,w].any?{ |x| x < 0 }

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
      return false unless other_image.is_a?(Image)
      return false if width  != other_image.width
      return false if height != other_image.height
      each_pixel do |c,x,y|
        return false if c != other_image[x,y]
      end
      true
    end

    def each_pixel &block
      e = Enumerator.new do |ee|
        height.times do |y|
          width.times do |x|
            ee.yield(self[x,y], x, y)
          end
        end
      end
      block_given? ? e.each(&block) : e
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
