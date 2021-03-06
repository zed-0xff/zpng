require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

ASCII_MODIFIED_QR = <<EOF
.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.
.#######.##.....##.#.##....#######.
.#.....#.......##.#.##.....#.....#.
.#.###.#.#..#####..#.#..##.#.###.#.
.#.###.#.##.#....#.####.##.#.###.#.
.#.###.#.####.#....#.####..#.###.#.
.#.....#..#..#.#..#####....#.....#.
.#######.#.#.#.#.#.#.#.#.#.#######.
..........#.#.##.....##.##.........
.####..#.#....##.#.##....##..###.#.
..#.##...##.....##.#.##.#.###...##.
.#.###.##......##.#.##..##.#.###.#.
....###.#...#####..#.#...##.#...#..
.##.##.#..#.#....#.####..##.##.....
...#..#.##.##.#....#.###.##....##..
.#.######.##.#.#..#####..#######...
.#.####..###.##.#.##....#...##.#...
...##.##..###.....##.#.##.########.
.....#..###..##.....##.#########.#.
.####.#####.##.....##.#...#...#.#..
..##.#..#..#.#..#####..#.#..##...#.
...######.#####.#....#.##......#...
..###.....#..####.#....###.#...###.
.###..####.####..#.#..#######...##.
.#.#.##.##.#.....##.#.##.######.#..
..#.#######..#.##.....##.#####...#.
.........#.###.#.##.....##...#.#...
.#######....#.#.##.....###.#.#.....
.#.....#..###..#.#..######...###.#.
.#.###.#.....#.####.#...########...
.#.###.#.###...#.####.#.#.#........
.#.###.#.###..#####..#.##..#..#....
.#.....#.####.##.....##.###......#.
.#######.#.#..##.#.##...#.##...#...
...................................
EOF

describe "ZPNG modify" do
  it "should have QR examples" do
    SAMPLES.should_not be_empty
  end
  SAMPLES.each do |fname|
    describe fname.sub(File.dirname(SAMPLES_DIR)+'/','') do
      img = ZPNG::Image.load(fname)
      it "modifies img - color=#{img.hdr.color}, depth=#{img.hdr.depth}, bpp=#{img.hdr.bpp}" do
        img.width.times do |x|
          img[x,0] = (x%2==0) ? ZPNG::Color::WHITE : ZPNG::Color::BLACK
        end
        img.to_ascii('#.').strip.should == ASCII_MODIFIED_QR.strip
      end
    end
  end
end
