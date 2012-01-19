#!/usr/bin/env ruby
require 'zpng'
include ZPNG

img = Image.new(File.join(File.dirname(__FILE__),"http.png"))

puts "[.] original:"
puts img.to_s
puts

img.width.times do |x|
  img[x,0] = (x % 2 == 0) ? Color::WHITE : Color::BLACK
end

puts "[.] modified:"
puts img.to_s

File.open("http-modified.png","wb") do |f|
  f << img.export
end
