# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "zpng"
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Andrey \"Zed\" Zaikin"]
  s.date = "2012-12-23"
  s.email = "zed.0xff@gmail.com"
  s.executables = ["zpng"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md",
    "README.md.tpl",
    "TODO"
  ]
  s.files = [
    ".document",
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.md",
    "README.md.tpl",
    "Rakefile",
    "TODO",
    "VERSION",
    "bin/zpng",
    "lib/zpng.rb",
    "lib/zpng/adam7_decoder.rb",
    "lib/zpng/block.rb",
    "lib/zpng/chunk.rb",
    "lib/zpng/cli.rb",
    "lib/zpng/color.rb",
    "lib/zpng/deep_copyable.rb",
    "lib/zpng/image.rb",
    "lib/zpng/scan_line.rb",
    "lib/zpng/string_ext.rb",
    "misc/chars.png",
    "misc/gen_ascii_map.rb",
    "samples/captcha_4bpp.png",
    "samples/modify.rb",
    "samples/qr_aux_chunks.png",
    "samples/qr_bw.png",
    "samples/qr_gray_alpha.png",
    "samples/qr_grayscale.png",
    "samples/qr_plte.png",
    "samples/qr_plte_bw.png",
    "samples/qr_rgb.png",
    "samples/qr_rgba.png",
    "spec/adam7_spec.rb",
    "spec/ascii_spec.rb",
    "spec/color_spec.rb",
    "spec/create_image_spec.rb",
    "spec/crop_spec.rb",
    "spec/image_spec.rb",
    "spec/modify_spec.rb",
    "spec/running_pixel_spec.rb",
    "spec/spec_helper.rb",
    "spec/zpng_spec.rb",
    "zpng.gemspec"
  ]
  s.homepage = "http://github.com/zed-0xff/zpng"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.24"
  s.summary = "pure ruby PNG file manipulation & validation"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<hexdump>, [">= 0"])
      s.add_runtime_dependency(%q<rainbow>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 2.8.0"])
      s.add_development_dependency(%q<bundler>, [">= 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.8.4"])
    else
      s.add_dependency(%q<hexdump>, [">= 0"])
      s.add_dependency(%q<rainbow>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 2.8.0"])
      s.add_dependency(%q<bundler>, [">= 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
    end
  else
    s.add_dependency(%q<hexdump>, [">= 0"])
    s.add_dependency(%q<rainbow>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 2.8.0"])
    s.add_dependency(%q<bundler>, [">= 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
  end
end

