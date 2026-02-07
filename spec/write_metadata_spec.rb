require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

include ZPNG

describe Image do
  it("should write metadata") do
    img = Image.new(:width => 8, :height => 8)
    img.chunks << Chunk::TEXT.new(keyword: "foo", text: "bar")
    Image.new(img.export).metadata["foo"].should == "bar"
  end
end
