conflict_option = if truthy_env?("FORCE")
  { force: true }
elsif truthy_env?("SKIP")
  { skip: true }
else
  {}
end

say "Copying binstubs"
directory "#{__dir__}/bin", "bin", conflict_option

chmod "bin", 0755 & ~File.umask, verbose: false
