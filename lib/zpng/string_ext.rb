require 'rainbow/ext/string'

class String
  [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white].each do |color|
    unless instance_methods.include?(color)
      define_method color do
        color(color)
      end
      define_method "bright_#{color}" do
        color(color).bright
      end
    end
  end

  [:gray, :grey].each do |color|
    unless instance_methods.include?(color)
      define_method color do
        color(:black).bright
      end
    end
  end
end
