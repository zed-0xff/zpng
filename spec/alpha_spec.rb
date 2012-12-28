require File.expand_path(File.join(File.dirname(__FILE__), '/spec_helper'))
require 'zpng/cli'

PNGSuite.each('tb','tp1') do |fname|
  describe fname.sub(%r|\A#{Regexp::escape(Dir.getwd)}/?|, '') do
    it "has its very first pixel transparent" do
      img = ZPNG::Image.load(fname)
      img[0,0].should be_transparent
    end
    it "has its very first pixel NOT opaque" do
      img = ZPNG::Image.load(fname)
      img[0,0].should_not be_opaque
    end
  end
end

PNGSuite.each('tp0') do |fname|
  describe fname.sub(%r|\A#{Regexp::escape(Dir.getwd)}/?|, '') do
    it "has its very first pixel NOT transparent" do
      img = ZPNG::Image.load(fname)
      img[0,0].should_not be_transparent
    end
    it "has its very first pixel opaque" do
      img = ZPNG::Image.load(fname)
      img[0,0].should be_opaque
    end
  end
end
