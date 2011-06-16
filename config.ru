



# the below script is a standalone Sinatra application; absolutely
# nothing special needs to be done in this Sinatra app for running
# with Unicorn

puts "-----------STARTING?----------"
puts Dir.pwd
require 'sinatra-chunks'

# the following hash needs to be the last statement, as unicorn
# will eval this entire file
run Sinatra::Application


