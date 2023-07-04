class Webpacker
  def self.method_missing(method_name, *args, &block)
    puts "The Webpacker constant has been superseded by the Shakapacker constant. "\
         "Please change all references to the Webpacker constant, such as Webpacker.#{method_name}, "\
         "to their Shakpacker equivalent, such as Shakapacker.#{method_name}"
    Shakapacker.send(method_name, *args, &block)
  end
end
