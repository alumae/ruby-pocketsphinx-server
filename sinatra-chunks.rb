require 'sinatra'
require 'raw_recognizer'
require 'uuidtools'
require 'json'
require 'iconv'
require 'set'

configure do
	RECOGNIZER = Recognizer.new
end

post '/' do
  id = SecureRandom.hex
  puts "Request ID: " + id
  req = Rack::Request.new(env)
  puts "Parsing content type " + req.content_type
  caps_str = content_type_to_caps(req.content_type)
  puts "CAPS string is " + caps_str
  caps = Gst::Caps.parse(caps_str)
  RECOGNIZER.appsrc.set_property("caps", caps)  
  RECOGNIZER.clear(caps)
  
  length = 0
  req.body.each do |chunk|
    print "."
    RECOGNIZER.feed_data(chunk)   
    length += chunk.size
  end
  puts "Got feed end"
  if length > 0
		RECOGNIZER.feed_end()
		result = RECOGNIZER.wait_final_result()
		puts "RESULT:" + result
													
		result = Iconv.iconv('utf-8', 'latin1', result)
		
		headers "Content-Type" => "application/json; charset=utf-8", "Content-Disposition" => "attachment"
		JSON.pretty_generate({:status => 0, :id => id, :hypotheses => [:utterance => result]})
	else
	  RECOGNIZER.stop
		headers "Content-Type" => "application/json; charset=utf-8", "Content-Disposition" => "attachment"
		JSON.pretty_generate({:status => 0, :id => id, :hypotheses => [:utterance => ""]})
	end
end

def content_type_to_caps(content_type)
  if not content_type
		return "audio/x-raw-int,rate=16000,channels=1,signed=true,endianness=1234,depth=16,width=16"
	end
  parts = content_type.split(";")
  result = ""
  allowed_types = Set.new ["audio/x-flac", "audio/x-raw-int", "application/ogg", "audio/mpeg"]
  if allowed_types.include? parts[0]
    result = parts[0]
    if parts[0] == "audio/x-raw-int"
      result = ",".join(parts)
     end
  end
	return result
end


