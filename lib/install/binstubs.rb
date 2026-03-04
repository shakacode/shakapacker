# Define truthy_env? here so binstubs.rb works both standalone (e.g., rake
# shakapacker:binstubs) and when called via `apply` from template.rb.
# Keep in sync with the identical definition in lib/install/template.rb.
def truthy_env?(name)
  %w[true 1 yes].include?(ENV[name].to_s.downcase)
end

# conflict_option must be computed here because apply creates a new local variable scope.
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
