require 'gst'
Gst.init

class Recognizer
  attr :result
  attr :queue
  attr :pipeline
  attr :appsrc
  attr :asr
  attr :clock
  attr :appsink
         
	def initialize()
		@clock = Gst::SystemClock.new
		@result = ""
		# construct pipeline
		@pipeline = Gst::Parse.launch("appsrc name=appsrc ! decodebin2 ! audioconvert ! audioresample ! pocketsphinx name=asr ! appsink name=appsink")
		
		# define input audio properties
		@appsrc = @pipeline.get_child("appsrc")
		caps = Gst::Caps.parse("audio/x-flac, rate=(int)16000;")
		@appsrc.set_property("caps", caps)
		
		# define behaviour for ASR output
		@asr = @pipeline.get_child("asr")

		
		@queue = Queue.new
		
		# This returns when ASR engine has been fully loaded
		@asr.set_property('configured', true)
		
		@asr.signal_connect('partial_result') { |asr, text, uttid| 
				#puts "PARTIAL: " + text 
				@result = text 
		}

		@asr.signal_connect('result') { |asr, text, uttid| 
				#puts "FINAL: " + text 
				@result = text  
				@queue.push(1)
		}
		
		@appsink = @pipeline.get_child("appsink")
		
		@appsink.signal_connect('eos') { |appsink, data|
				puts "##### EOS #####"
		}
		
		#@pipeline.pause
	end

 
    
  # Call this before starting a new recognition
  def clear
    @result = ""
    queue.clear
    pipeline.pause
  end
  
  # Feed new chunk of audio data to the recognizer
  def feed_data(data)
    @pipeline.play      
    buffer = Gst::Buffer.new
    buffer.data = data
    buffer.timestamp = clock.time
    @appsrc.push_buffer(buffer)
  end
  
  # Notify recognizer of utterance end
  def feed_end
    appsrc.end_of_stream
  end
  
  # Wait for the recognizer to recognize the current utterance
  # Returns the final recognition result
  def wait_final_result
    queue.pop
    @appsrc.ready
    return result
  end  
end
