force_option = ENV["FORCE"] ? { force: true } : {}

say "Copying binstubs"
directory "#{__dir__}/bin", "bin", force_option

chmod "bin", 0755 & ~File.umask, verbose: false
