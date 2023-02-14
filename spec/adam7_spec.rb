require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe ZPNG::Adam7Decoder do
  describe "scanline_width" do
    {
      "8x8"  => [1,1,2,2,2],
      "8x16" => [1,1,1,1,2],
      "16x8" => [2,2,4,4,4],
      "16x16"=> [2,2,2,2,4],
      "8x9"  => [1,1,1,1,2,2],
      "9x8"  => [2,1,3,2,2,5],
      "9x9"  => [2,2,1,1,3,2]
    }.each do |dims, slw|
      it "should be right for #{dims} image" do
        w,h = dims.split('x').map(&:to_i)
        adam7 = ZPNG::Adam7Decoder.new(w, h, 8)
        slw.size.times.map{ |i| adam7.scanline_width(i) }.should == slw
      end
    end
  end

  describe "scanlines_count" do
    {
      "8x8"  => 15,
      "8x16" => 30,
      "16x8" => 15,
      "16x16"=> 30,
      "8x9"  => 19,
      "9x8"  => 15,
      "9x9"  => 19,
      "1x1"  => 1,
    }.each do |dims, n|
      it "should be right for #{dims} image" do
        w,h = dims.split('x').map(&:to_i)
        adam7 = ZPNG::Adam7Decoder.new(w, h, 8)
        adam7.scanlines_count.should == n
      end
    end
  end

  describe "@pass_starts" do
    {
      "8x8"  => [0, 0, 1, 2, 3,  5,  7, 11, 15],
      "8x16" => [0, 0, 2, 4, 6, 10, 14, 22, 30],
      "16x8" => [0, 0, 1, 2, 3,  5,  7, 11, 15],
      "16x16"=> [0, 0, 2, 4, 6, 10, 14, 22, 30],
      "8x9"  => [0, 0, 2, 4, 5,  8, 10, 15, 19],
      "9x8"  => [0, 0, 1, 2, 3,  5,  7, 11, 15],
      "9x9"  => [0, 0, 2, 4, 5,  8, 10, 15, 19]
    }.each do |dims, pst|
      it "should be right for #{dims} image" do
        w,h = dims.split('x').map(&:to_i)
        adam7 = ZPNG::Adam7Decoder.new(w, h, 8)
        adam7.instance_variable_get("@pass_starts").should == pst
      end
    end
  end
end

PNGSuite.each("???i*.png") do |fname_i|
  fname_n = File.basename(fname_i)
  fname_n[3] = 'n'
  fname_n = File.join(File.dirname(fname_i), fname_n)
  next unless File.exist?(fname_n)

  describe fname_i.sub(%r|\A#{Regexp::escape(Dir.getwd)}/?|, '') do
    it "should be pixel-by-pixel identical to " + fname_n.sub(%r|\A#{Regexp::escape(Dir.getwd)}/?|, '') do
      interlaced = ZPNG::Image.load(fname_i)
      normal     = ZPNG::Image.load(fname_n)

      normal.pixels.to_a.should == interlaced.pixels.to_a

      interlaced.each_pixel do |color,x,y|
        normal[x,y].should == color
      end

      normal.each_pixel do |color,x,y|
        interlaced[x,y].should == color
      end
    end
  end
end
