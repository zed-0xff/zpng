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
      c.g.should == 2*17
      c.b.should == 3*17
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

  it "sorts" do
    c1 = ZPNG::Color.new 0x11, 0x11, 0x11
    c2 = ZPNG::Color.new 0x22, 0x22, 0x22
    c3 = ZPNG::Color.new    0,    0, 0xff

    [c3,c1,c2].sort.should == [c1,c2,c3]
    [c3,c2,c1].sort.should == [c1,c2,c3]
    [c1,c3,c2].sort.should == [c1,c2,c3]
  end

  describe "#from_html" do
    it "should understand short notation" do
      ZPNG::Color.from_html('#ff1133').should == ZPNG::Color.new(0xff,0x11,0x33)
    end
    it "should understand long notation" do
      ZPNG::Color.from_html('#f13').should == ZPNG::Color.new(0xff,0x11,0x33)
    end
    it "should understand short notation w/o '#'" do
      ZPNG::Color.from_html('ff1133').should == ZPNG::Color.new(0xff,0x11,0x33)
    end
    it "should understand long notation w/o '#'" do
      ZPNG::Color.from_html('f13').should == ZPNG::Color.new(0xff,0x11,0x33)
    end
    it "should set alpha" do
      ZPNG::Color.from_html('f13', :alpha => 0x11).should ==
        ZPNG::Color.new(0xff,0x11,0x33, 0x11)

      ZPNG::Color.from_html('#f13', :a => 0x44).should ==
        ZPNG::Color.new(0xff,0x11,0x33, 0x44)

      ZPNG::Color.from_html('f13').should_not ==
        ZPNG::Color.new(0xff,0x11,0x33, 0x11)
    end
  end
end
