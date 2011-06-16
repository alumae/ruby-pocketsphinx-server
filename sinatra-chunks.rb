require 'sinatra'

#require '../playground/speech-api/speech-api'
require 'raw_recognizer'
require 'uuidtools'
require 'json'
require 'iconv'
#require 'gst'

configure do
	RECOGNIZER = Recognizer.new
end

post '/' do
  id = SecureRandom.hex
  puts "Request ID: " + id
  req = Rack::Request.new(env)
  puts "Parsing content type", req.content_type
  caps = Gst::Caps.parse(req.content_type)
  RECOGNIZER.appsrc.set_property("caps", caps)  
  RECOGNIZER.clear()
  req.body.each do |chunk|
    print "."
    RECOGNIZER.feed_data(chunk)   
  end
  puts "Got feed end"
  RECOGNIZER.feed_end()
  result = RECOGNIZER.wait_final_result()
  puts "RESULT:" + result
                        
  result = Iconv.iconv('utf-8', 'latin1', result)
  
  headers "Content-Type" => "application/json; charset=utf-8", "Content-Disposition" => "attachment"
  JSON.pretty_generate({:status => 0, :id => id, :hypotheses => [:utterance => result]})
end
