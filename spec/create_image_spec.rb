require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

include ZPNG

describe Image do
  def _new_img bpp, color
    Image.new(:width => 8, :height => 8, :bpp => bpp, :color => color)
  end

  [1,2,4,8].each do |bpp|
    [true, false].each do |color|
      describe "new( :bpp => #{bpp}, :color => #{color} )" do
        subject(:img){ _new_img(bpp,color) }
        it("should export"){ img.export.should start_with(Image::PNG_HDR) }
        it("should to_ascii")  {  img.to_ascii.split("\n").size.should == 8 }

        subject{ img.hdr }
        its(:depth) { should == bpp }
        its(:color) { should == (color ? COLOR_INDEXED : COLOR_GRAYSCALE) }
      end
    end
  end

  describe "new( :bpp => 16, :color => false )" do
    subject(:img){ _new_img(16,false) }
    it("should export"){ img.export.should start_with(Image::PNG_HDR) }
    it("should to_ascii")  {  img.to_ascii.split("\n").size.should == 8 }

    subject{ img.hdr }
    its(:depth) { should == 8 } # 8 bits per color + 8 per alpha = 16 bpp
    its(:color) { should == COLOR_GRAY_ALPHA }
  end

  describe "new( :bpp => 16, :color => true )" do
    it "raises error" do
      lambda { _new_img(16,true) }.should raise_error(RuntimeError)
    end
  end

  describe "new( :bpp => 24, :color => false )" do
    subject(:img){ _new_img(24,false) }
    it("should export"){ img.export.should start_with(Image::PNG_HDR) }
    it("should to_ascii")  {  img.to_ascii.split("\n").size.should == 8 }

    subject{ img.hdr }
    its(:depth) { should == 8 } # each channel depth = 8
    its(:color) { should == COLOR_RGB }
  end

  describe "new( :bpp => 24, :color => true )" do
    subject(:img){ _new_img(24,true) }
    it("should export"){ img.export.should start_with(Image::PNG_HDR) }
    it("should to_ascii")  {  img.to_ascii.split("\n").size.should == 8 }

    subject{ img.hdr }
    its(:depth) { should == 8 } # each channel depth = 8
    its(:color) { should == COLOR_RGB }
  end

  describe "new( :bpp => 32, :color => false )" do
    subject(:img){ _new_img(32,false) }
    it("should export"){ img.export.should start_with(Image::PNG_HDR) }
    it("should to_ascii")  {  img.to_ascii.split("\n").size.should == 8 }

    subject{ img.hdr }
    its(:depth) { should == 8 } # each channel depth = 8
    its(:color) { should == COLOR_RGBA }
  end

  describe "new( :bpp => 32, :color => true )" do
    subject(:img){ _new_img(32,true) }
    it("should export"){ img.export.should start_with(Image::PNG_HDR) }
    it("should to_ascii")  {  img.to_ascii.split("\n").size.should == 8 }

    subject{ img.hdr }
    its(:depth) { should == 8 } # each channel depth = 8
    its(:color) { should == COLOR_RGBA }
  end
end
