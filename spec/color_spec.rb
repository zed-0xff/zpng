require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe ZPNG::Color do

  ZPNG::Color::ANSI_COLORS.each do |color_sym|
    it "finds closest color for #{color_sym}" do
      color = ZPNG::Color.const_get(color_sym.to_s.upcase)
      color.to_ansi.should == color_sym
    end
  end

  describe "to_depth" do
    it "decreases color depth" do
      c = ZPNG::Color.new 0x10, 0x20, 0x30
      c = c.to_depth(4)
      c.depth.should == 4
      c.r.should == 1
      c.g.should == 2
      c.b.should == 3
    end

    it "increases color depth" do
      c = ZPNG::Color.new 0,2,3, :depth => 4
      c = c.to_depth(8)
      c.depth.should == 8
      c.r.should == 0
      c.g.should == 0x20
      c.b.should == 0x3f
    end

    it "keeps color depth" do
      c = ZPNG::Color.new 0x11, 0x22, 0x33
      c = c.to_depth(8)
      c.depth.should == 8
      c.r.should == 0x11
      c.g.should == 0x22
      c.b.should == 0x33
    end
  end
end
