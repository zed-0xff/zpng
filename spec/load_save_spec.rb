require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

each_sample do |fname|
  describe fname do
    before(:all) do
      @src = ZPNG::Image.load(fname)
      @dst = ZPNG::Image.new(@src.export)
    end

    it "should have equal width" do
      @src.width.should == @dst.width
    end

    it "should have equal width" do
      @src.height.should == @dst.height
    end

    it "should have equal data" do
      @src.should == @dst
    end
  end
end
