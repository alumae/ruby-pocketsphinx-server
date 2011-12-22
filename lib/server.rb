require 'sinatra/base'
require 'uuidtools'
require 'json'
require 'iconv'
require 'set'
require 'yaml'
require 'open-uri'
require 'md5'
require 'uri'
require 'rack/throttle'
require 'gdbm'
require 'maruku'

module PocketsphinxServer

require 'raw_recognizer'

  class PocketsphinxServer::Server < Sinatra::Base
  
    configure do
      enable :static
      set :root, File.expand_path(".")

      set :public_folder, 'static'
      
      enable :logging
      disable :show_exceptions

      LOGGER = Logger.new(STDOUT)
      set :logger, LOGGER
      def LOGGER.puts(*s)
        s.flatten.each { |item| info(item.to_s) }
      end

      def LOGGER.write(*s)
        s.flatten.each { |item| info(item.to_s) }
      end

      $stdout = LOGGER      
      $stderr = LOGGER      
      
      set :config, YAML.load_file('conf.yaml')
  
      set :handlers, []
      config['handlers'].each do |handler_config|
        className = handler_config['name']
        requireName = handler_config['require']
        require requireName
        puts "Creating handler #{className}"
        handler = PocketsphinxServer.const_get(className).new(self, handler_config)  
        handlers << handler    
      end

      begin
        set :outdir, config["request_dump_dir"]
      rescue
      end
      
      CHUNK_SIZE = 4*1024
      
      # FIXME: make it work with many instances
      #throttiling_config = config.fetch('throttling', {})
      #use Rack::Throttle::Daily,   :max =>  throttiling_config.fetch('max-daily', 1000)
      #use Rack::Throttle::Hourly,   :max => throttiling_config.fetch('max-hourly', 100)
      #use Rack::Throttle::Interval, :min => throttiling_config.fetch('min-interval', 1)
      #use Rack::Throttle::Interval, :cache => GDBM.new('throttle.db')
    end

    get '/' do
       markdown :index, :layout_engine => :erb
    end
    
    get '/stats_data.js' do
        
    end
    
    post '/recognize' do
      do_post()
    end
  
    put '/recognize' do
      do_post()
    end
  
    put '/recognize/*' do
      do_post()
    end
  
    helpers do
      def logger
        LOGGER
      end
    end
  
    def do_post()
      id = SecureRandom.hex
      
      logger.info "Request ID: " + id
      req = Rack::Request.new(env)
      
      logger.info "Determining request handler..."
      
      @req_handler = nil
      settings.handlers.each do |handler|
        if handler.can_handle?(req)
          @req_handler = handler
          break
        end
      end
      logger.info "Request will be handled by #{@req_handler}"
      
      logger.info "Preparing request handler recognizer..."
      @req_handler.prepare_rec(req)

      nbest_n = 5
      if req.params.has_key? 'nbest'
        nbest_n = req.params['nbest'].to_i
      end
      
      if settings.outdir != nil
         File.open("#{settings.outdir}/#{id}.info", 'w') { |f|
           req.env.select{ |k,v|
              f.write "#{k}: #{v}\n"
           }
        }
      end
      logger.info "User agent: " + req.user_agent
      
      device_id = get_user_device_id(req.user_agent)
      logger.info "Device ID : #{device_id}"
      cmn_mean = get_cmn_mean(device_id)
      if cmn_mean != nil
        logger.info "Setting CMN mean to #{cmn_mean}"
        @req_handler.recognizer.set_cmn_mean(cmn_mean)
      end
        
      logger.info "Parsing content type " + req.content_type
      caps_str = content_type_to_caps(req.content_type)
      logger.info "CAPS string is " + caps_str
      @req_handler.recognizer.clear(id, caps_str)
      
      length = 0
      
      left_over = ""
      req.body.each do |chunk|
        chunk_to_rec = left_over + chunk
        if chunk_to_rec.length > CHUNK_SIZE
          chunk_to_send = chunk_to_rec[0..(chunk_to_rec.length / 2) * 2 - 1]
          @req_handler.recognizer.feed_data(chunk_to_send)
          left_over = chunk_to_rec[chunk_to_send.length .. -1]
        else
          left_over = chunk_to_rec
        end
        length += chunk.size
      end
      @req_handler.recognizer.feed_data(left_over)
        
      
      logger.info "Data end received"
      if length > 0
        @req_handler.recognizer.feed_end()
        result,nbest = @req_handler.recognizer.wait_final_result(max_nbest=nbest_n)
        set_cmn_mean(device_id, @req_handler.recognizer.get_cmn_mean())
        
        nbest_results = []
        
        nbest.collect! do |hyp| 
          @req_handler.postprocess_hypothesis(hyp) 
        end
        
        nbest_results = []
        nbest.collect do |hyp|
          nbest_result = {}
          nbest_result[:utterance] = hyp
          extras_map  = @req_handler.get_hyp_extras(req, hyp)
          nbest_result.merge!(extras_map)
          nbest_results << nbest_result
        end
        
        source_encoding = settings.config["recognizer_encoding"]
        if source_encoding != "utf-8"
          # convert all strings in nbest_results from source encoding to UTF-8
          traverse( nbest_results ) do |node|
              if node.is_a? String
                node = Iconv.iconv('utf-8', source_encoding, node)[0]
              end
              node
          end
        end
        
        headers "Content-Type" => "application/json; charset=utf-8", "Content-Disposition" => "attachment"
        JSON.pretty_generate({:status => 0, :id => id, :hypotheses => nbest_results})
      else
        @req_handler.recognizer.stop
        headers "Content-Type" => "application/json; charset=utf-8", "Content-Disposition" => "attachment"
        JSON.pretty_generate({:status => 0, :id => id, :hypotheses => [:utterance => ""]})
      end
    end
    
    
    # Handle /fetch-lm requests and backward compatible fetch requests
    get %r{/fetch-((lm)|(jsgf)|(pgf))} do
      handled = false
      settings.handlers.each do |handler|
        if handler.can_handle_fetch_lm?(request)
          handler.handle_fetch_lm(request)
          handled = true
          break
        end
      end
      if !handled
        status 409
        "Don't know how to handle this type of language model"
      else
        "Request completed"
      end
    end
    
    error do
        logger.info "Error: " + env['sinatra.error']
        logger.info "Inspecting #{@req_handler}..."
        if @req_handler != nil and @req_handler.recognizer.recognizing?
          logger.info "Trying to clear recognizer.."
          @req_handler.recognizer.stop
          logger.info "Cleared recognizer"
        end
        #consume request body to avoid proxy error
        begin
          request.body.read
        rescue
        end
        'Sorry, failed to process request. Reason: ' + env['sinatra.error'] + "\n"
    end
  
    # Traverses a structure of hashes and arrays and applied blk to the values
    def traverse(obj, &blk)
      case obj
      when Hash
        # Forget keys because I don't know what to do with them
        obj.each {|k,v| obj[k] = traverse(v, &blk) }
      when Array
        obj.collect! {|v| traverse(v, &blk) }
      else
        blk.call(obj)
      end
    end
  
    # Parses Content-type ans resolves it to GStreamer Caps string
    def content_type_to_caps(content_type)
      if not content_type
        content_type = "audio/x-raw-int"
        return "audio/x-raw-int,rate=16000,channels=1,signed=true,endianness=1234,depth=16,width=16"
      end
      parts = content_type.split(%r{[,; ]})
      result = ""
      allowed_types = Set.new ["audio/x-flac", "audio/x-raw-int", "application/ogg", "audio/mpeg", "audio/x-wav"]
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

    # TODO: make this configurable and modular
    def get_user_device_id(user_agent)
      # try to identify android device
      if user_agent =~ /.*\(RecognizerIntentActivity.* ([\w-]+); .*/
        return $1
      end
      return "default"
    end
  
    def get_cmn_mean(device_id)
      cmn_means = {}
      begin
        cmn_means = YAML.load_file('cmn_means.yaml')
      rescue
      end
      return cmn_means.fetch(device_id, nil)
    end 
  
    def set_cmn_mean(device_id, mean)
      cmn_means = {}
      begin
        cmn_means = YAML.load_file('cmn_means.yaml')
      rescue
      end
      cmn_means[device_id] = mean
      uid = Process.uid
      File.open("cmn_means.yaml.#{uid}", 'w' ) do |out|
        YAML.dump( cmn_means, out )
      end
      `mv cmn_means.yaml.#{uid} cmn_means.yaml`
    end
  end


end
