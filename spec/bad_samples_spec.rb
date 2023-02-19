require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'zpng/cli'

each_sample("bad/*.png") do |fname|
  describe fname do
    before(:all) do
      @img = ZPNG::Image.load(fname, :verbose => -2)
    end

    it "returns dimensions" do
      lambda{
        @img.width
        @img.height
      }.should_not raise_error
    end

    it "should access 1st pixel" do
      skip "no BPP" unless @img.bpp
      @img[0,0].should be_instance_of(ZPNG::Color)
    end

    it "accessess all pixels" do
      skip "no BPP" unless @img.bpp
      skip if fname == 'samples/bad/b1.png'
      skip if fname == 'samples/bad/000000.png'
      n = 0
      @img.each_pixel do |px|
        px.should be_instance_of(ZPNG::Color)
        n += 1
      end
      n.should == @img.width*@img.height
    end

    describe "CLI" do
      it "shows info & chunks" do
        orig_stdout, out = $stdout, ""
        begin
          $stdout = StringIO.new(out)
          lambda { ZPNG::CLI.new([fname, "-qqq"]).run }.should_not raise_error
        ensure
          $stdout = orig_stdout
        end
        out.should include("#{@img.width}x#{@img.height}")
      end

      it "shows scanlines" do
        skip "no BPP" unless @img.bpp
        orig_stdout, out = $stdout, ""
        begin
          $stdout = StringIO.new(out)
          lambda { ZPNG::CLI.new([fname, "-qqq", "--scanlines"]).run }.should_not raise_error
        ensure
          $stdout = orig_stdout
        end
        sl = out.scan(/scanline/i)
        sl.size.should > 0
        sl.size.should == @img.scanlines.size
      end
    end
  end
end
