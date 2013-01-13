require 'zlib'
require 'stringio'

module ZPNG
  class Exception < ::StandardError; end
  class NotSupported  < Exception; end
  class ArgumentError < Exception; end
end

require 'zpng/string_ext'
require 'zpng/deep_copyable'

require 'zpng/color'
require 'zpng/block'
require 'zpng/scan_line'
require 'zpng/scan_line/mixins'
require 'zpng/chunk'
require 'zpng/text_chunk'
require 'zpng/readable_struct'
require 'zpng/adam7_decoder'
require 'zpng/hexdump'
require 'zpng/metadata'
require 'zpng/pixels'

require 'zpng/bmp/reader'
require 'zpng/image'
