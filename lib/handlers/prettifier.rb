require 'handlers/handler'

###
# This handler postprocesses hyps using an external script that can 
# syncronously process text, i.e., for each input line it instantly
# flushes an output line
###
class PocketsphinxServer::PrettifyingHandler < PocketsphinxServer::Handler

  def initialize(server, config={})
    super
    @prettifier
    if config['prettifier'] != nil
      @prettifier = IO.popen(config['prettifier'], mode="r+")
    end
  end

  def postprocess_hypothesis(hyp)
    if @prettifier != nil && hyp && !hyp.empty?
      log "PRETTIFYING: #{hyp}"
      @prettifier.puts "#{hyp}"
      @prettifier.flush
      result = @prettifier.gets.strip
      log "RESULT:      #{result}"
      return result
    end
    hyp
  end
end
