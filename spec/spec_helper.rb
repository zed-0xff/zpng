$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'zpng'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

SAMPLES_DIR = File.join(
  File.dirname(
    File.dirname(
      File.expand_path(__FILE__))),
  "samples")

SAMPLES =
  if ENV['SAMPLES']
    ENV['SAMPLES'].split(' ')
  else
    Dir[File.join(SAMPLES_DIR,'qr_*.png')]
  end

PNG_SUITE_URL = "http://www.schaik.com/pngsuite/PngSuite-2011apr25.tgz"

def get_png_suite
  dir = File.join(SAMPLES_DIR, "png_suite")
  if Dir.exist?(dir)
    if Dir[File.join(dir, "*.png")].size > 100
      # already fetched and unpacked
      return
    end
  else
    Dir.mkdir(dir)
  end
  require 'open-uri'
  puts "[.] fetching PNG test-suite from #{PNG_SUITE_URL} .. "
  data = open(PNG_SUITE_URL).read

  fname = File.join(dir, "png_suite.tgz")
  File.open(fname, "wb"){ |f| f<<data }
  puts "[.] unpacking .. "
  system "tar", "xzf", fname, "-C", dir
end

RSpec.configure do |config|
  config.before :suite do
    get_png_suite
  end
end

