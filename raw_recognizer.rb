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
  attr :recognizing
         
  def initialize(config={}, rec_config_name='')
    @data_buffers = []
    @clock = Gst::SystemClock.new
    @result = ""
    
    @outdir = nil
    begin
      @outdir = config.fetch('logging', {}).fetch('request-debug', '')
    rescue
    end

    @appsrc = Gst::ElementFactory.make "appsrc", "appsrc"
    @decoder = Gst::ElementFactory.make "decodebin2", "decoder"
    @audioconvert = Gst::ElementFactory.make "audioconvert", "audioconvert"
    @audioresample = Gst::ElementFactory.make "audioresample", "audioresample"    
    @tee = Gst::ElementFactory.make "tee", "tee"
    @queue1 = Gst::ElementFactory.make "queue", "queue1"
    @filesink = Gst::ElementFactory.make "filesink", "filesink"
    @queue2 = Gst::ElementFactory.make "queue", "queue2"   
    @asr = Gst::ElementFactory.make "pocketsphinx", "asr"
    @appsink = Gst::ElementFactory.make "appsink", "appsink"

    @filesink.set_property("location", "/dev/null")
    
    rec_config = config[rec_config_name]
    if rec_config != nil
      rec_config.map{ |k,v|
        puts "Setting #{k} to #{v}..."
        @asr.set_property(k, v) 
      }
      # This returns when ASR engine has been fully loaded
      @asr.set_property('configured', true)
    end

    create_pipeline()
    recognizing = false
  end


 
  def create_pipeline()
    @pipeline = Gst::Pipeline.new "pipeline"
    @pipeline.add @appsrc, @decoder, @audioconvert, @audioresample, @tee, @queue1, @filesink, @queue2, @asr, @appsink
    @appsrc >> @decoder
    @audioconvert >> @audioresample >> @tee
    @tee >> @queue1 >> @asr >> @appsink
    @tee >> @queue2 >> @filesink
    
    @decoder.signal_connect('pad-added') { | element, pad, last, data |
      puts "---- pad-added ---- "
      pad.link @audioconvert.get_pad("sink")
    }

    @queue = Queue.new
    
    
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
  def clear(id, caps_str)
    caps = Gst::Caps.parse(caps_str)
    @appsrc.set_property("caps", caps)
    @result = ""
    queue.clear
    pipeline.pause
    if @outdir != nil
      @filesink.set_state(Gst::State::NULL)
      @filesink.set_property('location', "#{@outdir}/#{id}.raw")
    end
    @filesink.set_state(Gst::State::PLAYING)
  end  
  
  def set_cmn_mean(mean)
    @asr.set_property("cmn_mean", mean)
  end

  def get_cmn_mean()
    return @asr.get_property("cmn_mean")
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
    pipeline.play
    recognizing = true
  end
  
  # Notify recognizer of utterance end
  def feed_end
    appsrc.end_of_stream
  end
  
  # Wait for the recognizer to recognize the current utterance
  # Returns the final recognition result
  def wait_final_result
    queue.pop
    @pipeline.ready
    @data_buffers.clear
    recognizing = false
    puts "CMN mean after: #{@asr.get_property("cmn_mean")}"
    return result
  end  
  
  def stop
    #@pipeline.play
    appsrc.end_of_stream
    wait_final_result    
  end
  
  def set_fsg_file(fsg_file)
    puts "Trying to use FSG #{fsg_file}"
    @asr.set_property('fsg', fsg_file)
    @asr.set_property('configured', true)    
  end
end
