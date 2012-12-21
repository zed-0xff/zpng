require 'rainbow'

class String
  [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white].each do |color|
    unless instance_methods.include?(color)
      define_method color do
        self.send(:color, color)
      end
    end
  end
end
