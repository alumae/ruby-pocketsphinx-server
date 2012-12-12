require 'gst'
Gst.init

class PocketsphinxServer::Recognizer
  attr :result
  attr :queue
  attr :pipeline
  attr :appsrc
  attr :asr
  attr :clock
  attr :appsink
  attr :recognizing
         
  def initialize(server, config={})
    @server = server
    @data_buffers = []
    @clock = Gst::SystemClock.new
    @result = ""
    @recognizing = false

    @outdir = nil
    begin
      @outdir = server.config.fetch('request_dump_dir' '')
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
    
    config.map{ |k,v|
      log "Setting #{k} to #{v}..."
      @asr.set_property(k, v) 
    }
    # This returns when ASR engine has been fully loaded
    @asr.set_property('configured', true)

    create_pipeline()
  end


  def log(str)
    @server.logger.debug(str)
  end
 
  def create_pipeline()
    @pipeline = Gst::Pipeline.new "pipeline"
    @pipeline.add @appsrc, @decoder, @audioconvert, @audioresample, @tee, @queue1, @filesink, @queue2, @asr, @appsink
    @appsrc >> @decoder
    @audioconvert >> @audioresample >> @tee
    @tee >> @queue1 >> @asr >> @appsink
    @tee >> @queue2 >> @filesink
    
    @decoder.signal_connect('pad-added') { | element, pad, last, data |
      log "---- pad-added ---- "
      pad.link @audioconvert.get_pad("sink")
    }

    @queue = Queue.new
    
    
    @asr.signal_connect('partial_result') { |asr, text, uttid|
        #log "PARTIAL: " + text
        @result = text
    }

    @asr.signal_connect('result') { |asr, text, uttid|
        #log "FINAL: " + text
        if text.nil?
          text = ""
        end
        @result = text
        @queue.push(1)
    }
    
    @appsink = @pipeline.get_child("appsink")
    
    @appsink.signal_connect('eos') { |appsink, data|
        log "##### EOS #####"
    }

    @bus = @pipeline.bus
    @bus.signal_connect('message::state-changed') { |appsink, data|
        log "##### STATE-CHANGED #####"
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
    @recognizing = true
  end
  
  # Notify recognizer of utterance end
  def feed_end
    appsrc.end_of_stream
  end
  
  # Wait for the recognizer to recognize the current utterance
  # Returns the final recognition result
  def wait_final_result(max_nbest = 5)
    queue.pop
    # we request more N-best hyps than needed since we don't care about 
    # differences in fillers
    @asr.set_property("nbest_size", max_nbest * 3)
    nbest = @asr.get_property("nbest")
    nbest.uniq!
    #nbest.map!{ |hyp| if hyp.nil? then hyp = "" end }
    @pipeline.ready
    @data_buffers.clear
    @recognizing = false
    log "CMN mean after: #{@asr.get_property("cmn_mean")}"
    return result, nbest[0..max_nbest-1]
  end  
  
  def stop
    #@pipeline.play
    appsrc.end_of_stream
    wait_final_result    
  end
  
  def set_fsg(fsg_file, dict_file)
    @asr.set_property('fsg', 'dummy.fsg')  
    log "Trying to use dict #{dict_file}"
    @asr.set_property('dict', dict_file)    
    log "Trying to use FSG #{fsg_file}"
    @asr.set_property('fsg', fsg_file)
    @asr.set_property('configured', true)    
    log "FSG configured"
  end
  
  def recognizing?()
    @recognizing
  end
end
