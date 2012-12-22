require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
include ZPNG

describe Image do
  def _new_img bpp, color
    Image.new(:width => 16, :height => 1, :bpp => bpp, :color => color)
  end

#  before :all do
#    $html = "<style>img {width:64px}</style>\n<div style='background-color:#ccc'>\n"
#  end

  [1,2,4,8,16,24,32].each do |bpp|
    [true, false].each do |color|
      next if bpp == 16 && color
      describe "new( :bpp => #{bpp}, :color => #{color} )" do
        16.times do |x|
          it "should set pixel at pos #{x}" do
            bg = Color::BLACK
            fg = Color::WHITE

            img = _new_img bpp, color
            if img.palette
              img.palette << bg if img.palette
            else
              img.width.times{ |i| img[i,0] = bg }
            end
            img[x,0] = fg

            s = '#'*16
            s[x] = ' '
            img.to_ascii('# ').should == s

  #          fname = "out-#{x}-#{bpp}-#{color}.png"
  #          img.save fname
  #          $html << "<img src='#{fname}'><br/>\n"
          end
        end
      end
    end
  end

#  after :all do
#    $html << "</div>"
#    File.open("index.html","w"){ |f| f<<$html }
#  end
end
