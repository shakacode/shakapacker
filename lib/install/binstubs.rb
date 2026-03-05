require "shakapacker/install/env"

@conflict_option ||= Shakapacker::Install::Env.conflict_option

say "Copying binstubs"
directory "#{__dir__}/bin", "bin", @conflict_option

chmod "bin", 0755 & ~File.umask, verbose: false
