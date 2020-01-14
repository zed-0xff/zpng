module ZPNG
  class TextChunk < Chunk
    attr_accessor :keyword, :text

    if RUBY_VERSION > "2.4"
      INTEGER_CLASS = Integer
    else
      INTEGER_CLASS = Fixnum
    end

    def inspect verbosity = 10
      vars = %w'keyword text language translated_keyword cmethod cflag'
      vars -= %w'text translated_keyword' if verbosity <=0
      super.sub(/ *>$/,'') + ", " +
        vars.map do |var|
          t = instance_variable_get("@#{var}")
          unless t.is_a?(INTEGER_CLASS)
            t = t.to_s
            t = t[0..20] + "..." if t.size > 20
          end
          if t.nil? || t == ''
            nil
          else
            "#{var.to_s.tr('@','')}=#{t.inspect}"
          end
        end.compact.join(", ") + ">"
    end

    def to_hash
      { :keyword => keyword, :text => text}
    end
  end

  class Chunk
    class TEXT < TextChunk
      def initialize *args
        super
        @keyword,@text = data.unpack('Z*a*')
      end
    end

    class ZTXT < TextChunk
      attr_accessor :cmethod # compression method
      def initialize *args
        super
        @keyword,@cmethod,@text = data.unpack('Z*Ca*')
        # current only @cmethod value is 0 - deflate
        if @text
          @text = Zlib::Inflate.inflate(@text)
        end
      end
    end

    class ITXT < TextChunk
      attr_accessor :cflag, :cmethod # compression flag & method
      attr_accessor :language, :translated_keyword
      def initialize *args
        super
        # The text, unlike the other strings, is not null-terminated; its length is implied by the chunk length.
        # http://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html#C.iTXt
        @keyword, @cflag, @cmethod, @language, @translated_keyword, @text = data.unpack('Z*CCZ*Z*a*')
        if @cflag == 1 && @cmethod == 0
          @text = Zlib::Inflate.inflate(@text)
        end
        if @text
          @text.force_encoding('utf-8') rescue nil
        end
        if @translated_keyword
          @translated_keyword.force_encoding('utf-8') rescue nil
        end
      end

      def to_hash
        super.tap do |h|
          h[:language] = @language if @language || !@language.empty?
          h[:translated_keyword] = @translated_keyword if @translated_keyword || !@translated_keyword.empty?
        end
      end
    end
  end
end
