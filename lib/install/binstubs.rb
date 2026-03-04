# truthy_env? is defined in template.rb (the parent template).
# It is accessible here because apply shares the same generator instance.
# However, conflict_option must be recomputed because apply creates a new local variable scope.
# IMPORTANT: Keep this logic in sync with the conflict_option block in lib/install/template.rb.
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
