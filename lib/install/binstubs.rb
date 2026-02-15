force_option = if ENV["FORCE"]
  { force: true }
elsif ENV["SKIP"]
  { skip: true }
else
  {}
end

say "Copying binstubs"
directory "#{__dir__}/bin", "bin", force_option

chmod "bin", 0755 & ~File.umask, verbose: false
