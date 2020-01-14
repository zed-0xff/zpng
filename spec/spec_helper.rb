$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'rspec/its'
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

def each_sample glob="*.png"
  Dir[File.join(SAMPLES_DIR, glob)].each do |fname|
    yield fname.sub(Dir.pwd+'/','')
  end
end

def sample fname
  File.join(SAMPLES_DIR, fname)
end

PNGSuite.init( File.join(SAMPLES_DIR, "png_suite") )

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
  config.before :suite do
  end
end

