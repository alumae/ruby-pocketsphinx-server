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
         
  def initialize(config={})
    @data_buffers = []
    @clock = Gst::SystemClock.new
    @result = ""

    @appsrc = Gst::ElementFactory.make "appsrc", "appsrc"
    @decoder = Gst::ElementFactory.make "decodebin2", "decoder"
    @audioconvert = Gst::ElementFactory.make "audioconvert", "audioconvert"
    @audioresample = Gst::ElementFactory.make "audioresample", "audioresample"    
    @asr = Gst::ElementFactory.make "pocketsphinx", "asr"
    @appsink = Gst::ElementFactory.make "appsink", "appsink"


    pocketsphinx_config = config['pocketsphinx']
    if  pocketsphinx_config != nil
      pocketsphinx_config.map{ |k,v|
        puts "Setting #{k} to #{v}..."
        @asr.set_property(k, v) 
      }
    end


    create_pipeline()
    
  end

  def create_pipeline()
    @pipeline = Gst::Pipeline.new "pipeline"
    @pipeline.add @appsrc, @decoder, @audioconvert, @audioresample, @asr, @appsink
    @appsrc >> @decoder   
    @audioconvert >> @audioresample >> @asr >> @appsink
    
    @decoder.signal_connect('pad-added') { | element, pad, last, data | 
      puts "---- pad-added ---- "
      pad.link @audioconvert.get_pad("sink")
    }

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

    @bus = @pipeline.bus
    @bus.signal_connect('message::state-changed') { |appsink, data|
        puts "##### STATE-CHANGED #####"
    }
  end 
 
    
  # Call this before starting a new recognition
  def clear(caps_str)
    caps = Gst::Caps.parse(caps_str)
    @appsrc.set_property("caps", caps)  
    @result = ""
    queue.clear
    pipeline.pause
  end
  
  # Feed new chunk of audio data to the recognizer
  def feed_data(data)
    buffer = Gst::Buffer.new
    my_data = data.dup
    buffer.data = my_data
    buffer.timestamp = clock.time
    appsrc.push_buffer(buffer)
    # HACK: we need to reference the buffer so that ruby won't overwrite it
    @data_buffers.push my_data
  end
  
  # Notify recognizer of utterance end
  def feed_end
    appsrc.end_of_stream
  end
  
  # Wait for the recognizer to recognize the current utterance
  # Returns the final recognition result
  def wait_final_result
    queue.pop
    @pipeline.stop
    @data_buffers.clear
    return result
  end  
  
  def stop
    @pipeline.play
    @pipeline.stop
  end
end
