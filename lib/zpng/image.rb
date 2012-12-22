module ZPNG
  class Image
    attr_accessor :data, :header, :chunks, :scanlines, :imagedata, :palette
    alias :hdr :header

    include DeepCopyable

    PNG_HDR = "\x89PNG\x0d\x0a\x1a\x0a"

    def initialize x
      @chunks = []
      case x
        when IO
          _from_string x.read
        when String
          _from_string x
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

    # load image from file
    def self.load fname
      open(fname,"rb") do |f|
        Image.new(f)
      end
    end
    alias :load_file :load

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
      @chunks << (@header  = Chunk::IHDR.new(h))
      if @header.palette_used?
        @chunks << (@palette = Chunk::PLTE.new)
        @palette[0] = h[:background] || h[:bg] || Color::BLACK # add default bg color
      end
    end

    def _from_string x
      if x
        if PNG_HDR.size.times.all?{ |i| x[i].ord == PNG_HDR[i].ord } # encoding error workaround
          # raw image data
          @data = x
        elsif File.exist?(x)
          # filename
          @data = File.binread(x)
        else
          raise "Don't know what #{x.inspect} is"
        end
      end

      d = data[0,PNG_HDR.size]
      if d != PNG_HDR
        puts "[!] first #{PNG_HDR.size} bytes must be #{PNG_HDR.inspect}, but got #{d.inspect}".red
      end

      io = StringIO.new(data)
      io.seek PNG_HDR.size
      while !io.eof?
        chunk = Chunk.from_stream(io)
        chunk.idx = @chunks.size
        @chunks << chunk
        case chunk
        when Chunk::IHDR
          @header = chunk
        when Chunk::PLTE
          @palette = chunk
        when Chunk::IEND
          break
        end
      end
      unless io.eof?
        offset    = io.tell
        extradata = io.read
        puts "[?] #{extradata.size} bytes of extra data after image end (IEND), offset = 0x#{offset.to_s(16)}".red
      end
    end

    public
    def dump
      @chunks.each do |chunk|
        puts "[.] #{chunk.inspect} #{chunk.crc_ok? ? 'CRC OK'.green : 'CRC ERROR'.red}"
      end
    end

    def bpp
      @header && @header.bpp
    end

    def width
      @header && @header.width
    end

    def height
      @header && @header.height
    end

    def grayscale?
      @header && @header.grayscale?
    end

    def interlaced?
      @header && @header.interlace != 0
    end

    def imagedata
      @imagedata ||=
        begin
          puts "[?] no image header, assuming non-interlaced RGB".yellow unless @header
          data = @chunks.find_all{ |c| c.is_a?(Chunk::IDAT) }.map(&:data).join
          (data && data.size > 0) ? Zlib::Inflate.inflate(data) : ''
        end
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
      return if @all_scanlines_decoded
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
      imagedata # fill @imagedata, if not already filled

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
      require 'pp'
      pp chunks

      # copy all but 'interlace' header params
      h = Hash[*%w'width height depth color compression filter'.map{ |k| [k.to_sym, hdr.send(k)] }.flatten]
      new_img = Image.new h
      chunks.each do |chunk|
        next if chunk.is_a?(Chunk::IHDR)
        next if chunk.is_a?(Chunk::IDAT)
        next if chunk.is_a?(Chunk::IEND)
        new_img.chunks << chunk.deep_copy
      end
      each_pixel do |c,x,y|
        new_img[x,y] = c
      end
      p new_img.scanlines
      new_img
    end
  end
end
