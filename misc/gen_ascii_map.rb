#!/usr/bin/env ruby
$: << "../lib"
require 'zpng'

h = Hash.new{ |k,v| k[v] = "" }
a = []

big_img = ZPNG::Image.load("chars.png").deinterlace

(big_img.width/13).times do |idx|
  img = big_img.crop(:x=>idx*13, :y=>0, :width=>13, :height =>big_img.height)
  s = img.to_ascii(' ##')
  puts s

  c = (idx+32).chr
  next if c == "_"
  n = s.count('#')
  h[n] << c
  a[n] ||= ''
  a[n] << c
end

puts "[.] step1 results:"
p a
while a.index(nil)
  prevset = false
  0.upto(a.size-1) do |i|
    c = a[i]
    a[i] = c[0] if c && c.size > 1
    if !c && a[i-1] && !prevset
      a[i] = a[i-1]
      prevset = true
    else
      prevset = false
    end
  end
  (a.size-1).downto(0) do |i|
    c = a[i]
    a[i] = c[0] if c && c.size > 1
    if !c && a[i+1] && !prevset
      a[i] = a[i+1]
      prevset = true
    else
      prevset = false
    end
  end
end
puts "[.] normalized:"
p a
puts

h.keys.sort.each do |n|
  printf "[.] %3d: %s\n", n, h[n]
end
puts

require 'pp'
puts "[.] final array:"
puts "a = ["
a.each_slice(20).map(&:join).each do |slice|
  puts "  #{slice.inspect},"
end
puts "].join"
