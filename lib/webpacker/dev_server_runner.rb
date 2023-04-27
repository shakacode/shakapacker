# This file exists for backward compatibility
require "shakapacker/dev_server_runner"

Shakapacker.puts_deprecation_message(
  Shakapacker.short_deprecation_message(
    "bin/webpacker-dev-server",
    "bin/shakapacker-dev-server"
  )
)
