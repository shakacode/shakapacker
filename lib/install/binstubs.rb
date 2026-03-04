# truthy_env? is defined in template.rb and shared via apply (same generator instance).
# @conflict_option is an instance variable set in template.rb, also shared via apply.
#
# For standalone execution (e.g., rake shakapacker:binstubs), define fallbacks:
unless respond_to?(:truthy_env?, true)
  def truthy_env?(name)
    %w[true 1 yes].include?(ENV[name].to_s.downcase)
  end
end

@conflict_option ||= if truthy_env?("FORCE")
  { force: true }
elsif truthy_env?("SKIP")
  { skip: true }
else
  {}
end

say "Copying binstubs"
directory "#{__dir__}/bin", "bin", @conflict_option

chmod "bin", 0755 & ~File.umask, verbose: false
