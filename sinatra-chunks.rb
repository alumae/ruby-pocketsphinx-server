require 'sinatra'
require 'raw_recognizer'
require 'uuidtools'
require 'json'
require 'iconv'
require 'set'
require 'yaml'

configure do
	FULL_BODY = false
	config = YAML.load_file('conf.yaml')
	RECOGNIZER = Recognizer.new(config)
	$prettifier = nil
	if config['prettifier'] != nil
	  $prettifier = IO.popen(config['prettifier'], mode="r+")
	end
	disable :show_exceptions
	OUTDIR = "out/"
	CHUNK_SIZE = 1
end

post '/' do
  id = SecureRandom.hex
  puts "Request ID: " + id
  req = Rack::Request.new(env)
  puts "Parsing content type " + req.content_type
  caps_str = content_type_to_caps(req.content_type)
  puts "CAPS string is " + caps_str
  RECOGNIZER.clear(caps_str)
  
  length = 0
  
  if not FULL_BODY
		
    full_body = ""
    left_over = ""
		req.body.each do |chunk|
			#puts "got chunk of size #{chunk.length}"
			chunk_to_rec = left_over + chunk
			#puts "chunk_to_rec is of size #{chunk_to_rec.length}"
			if chunk_to_rec.length > CHUNK_SIZE
				chunk_to_send = chunk_to_rec[0..(chunk_to_rec.length / 2) * 2 - 1]
				puts "chunk_to_send is of size #{chunk_to_send.length}"
				RECOGNIZER.feed_data(chunk_to_send)
				full_body += chunk_to_send
				left_over = chunk_to_rec[chunk_to_send.length .. -1]
			else
			  left_over = chunk_to_rec
			end
			#puts "left_over is of size #{left_over.length}"
			length += chunk.size
		end
		RECOGNIZER.feed_data(left_over)
		full_body += left_over
		
	  File.open(OUTDIR + id +".raw", "wb") { |f|
			f.write full_body
		}
  else
		length = request.body.size
		RECOGNIZER.feed_data(request.body.read)   
	end
  
  puts "Got feed end"
  if length > 0
		RECOGNIZER.feed_end()
		result = RECOGNIZER.wait_final_result()
		puts "RESULT:" + result
		result = prettify(result)
		puts "PRETTY RESULT:" + result													
		result = Iconv.iconv('utf-8', 'latin1', result)
		
		headers "Content-Type" => "application/json; charset=utf-8", "Content-Disposition" => "attachment"
		JSON.pretty_generate({:status => 0, :id => id, :hypotheses => [:utterance => result]})
	else
	  RECOGNIZER.stop
		headers "Content-Type" => "application/json; charset=utf-8", "Content-Disposition" => "attachment"
		JSON.pretty_generate({:status => 0, :id => id, :hypotheses => [:utterance => ""]})
	end
end


error do
    'Sorry, failed to process request. Reason: ' + env['sinatra.error'] + "\n"
end

def content_type_to_caps(content_type)
  if not content_type
		content_type = "audio/x-raw-int"
		return "audio/x-raw-int,rate=16000,channels=1,signed=true,endianness=1234,depth=16,width=16"
	end
  parts = content_type.split(%r{[,; ]})
  result = ""
  allowed_types = Set.new ["audio/x-flac", "audio/x-raw-int", "application/ogg", "audio/mpeg", "audio/x-wav",  ]
  if allowed_types.include? parts[0]
    result = parts[0]
    if parts[0] == "audio/x-raw-int"
			attributes = {"rate"=>"16000", "channels"=>"1", "signed"=>"true", "endianness"=>"1234", "depth"=>"16", "width"=>"16"}
			user_attributes = Hash[*parts[1..-1].map{|s| s.split('=', 2) }.flatten]
			attributes.merge!(user_attributes)
			result += ", " + attributes.map{|k,v| "#{k}=#{v}"}.join(", ")
    end
    return result
  else
		raise IOError, "Unsupported content type: #{parts[0]}. Supported types are: " + allowed_types.to_a.join(", ") + "." 
  end
end

def prettify(hyp)
	if $prettifier != nil
		$prettifier.puts hyp
		$prettifier.flush
		return $prettifier.gets.strip
	end
	return hyp
end


