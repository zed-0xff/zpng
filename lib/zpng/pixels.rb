module ZPNG
  class Pixels
    include Enumerable

    module ImageEnum
      def each
        @image.height.times do |y|
          @image.width.times do |x|
            yield @image[x,y]
          end
        end
      end

      def keep_if otherwise = Color::TRANSPARENT
        @image.height.times do |y|
          @image.width.times do |x|
            @image[x,y] = otherwise unless yield(@image[x,y])
          end
        end
      end

      def filter!
        @image.height.times do |y|
          @image.width.times do |x|
            @image[x,y] = yield(@image[x,y])
          end
        end
      end
      alias :map! :filter!
    end

    module ScanLineEnum
      def each
        @scanline.width.times do |x|
          yield @scanline[x]
        end
      end
    end

    def initialize x
      case x
      when Image
        @image = x
        extend ImageEnum
      when ScanLine
        @scanline = x
        extend ScanLineEnum
      else raise ArgumentError, "don't know how to enumerate #{x.inspect}"
      end
    end

    def == other
      self.to_a == other.to_a
    end

    def uniq
      self.to_a.uniq
    end
  end
end
