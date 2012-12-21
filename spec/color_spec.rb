require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe ZPNG::Color do

  ZPNG::Color::ANSI_COLORS.each do |color_sym|
    it "finds closest color for #{color_sym}" do
      color = ZPNG::Color.const_get(color_sym.to_s.upcase)
      color.closest_ansi_color.should == color_sym
    end
  end
end
