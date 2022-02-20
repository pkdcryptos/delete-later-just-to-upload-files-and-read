module Worker
  class PusherMarket
  
  def initialize
      @runtimeTradesToPush = {}
      queue_the_trades
      @lasttidseen = 0
    end

    def process(payload, metadata, delivery_info)
      @trade = Traade.new payload
	  tradeMarket="#{@trade.baseAsset}#{@trade.quoteAsset}"
      @lasttidseen = @trade.id
      Rails.logger.info "DBG: PusherMarket received  trade : #{@trade.inspect}"
      # The below trigger_notify is culprit to slow down tradebook, this is not needed, so commented & getting good performance
      #trade.trigger_notify
      
      runtimeKey = "#{tradeMarket}"
      #Rails.logger.info "DBG: runtimeKey: #{runtimeKey}"
      @runtimeTradesToPush[runtimeKey] ||= []
    	
    	
      @runtimeTradesToPush[runtimeKey].unshift @trade.for_global
      #Global[trade.market].trigger_trades [trade.for_global]
    end
    
    def pusher_trades
    
      queue = @runtimeTradesToPush
      @runtimeTradesToPush = {}
      
      
      queue.each do |mkt|
      
      
            
      # queuesplit = mkt[1].each_slice(70).to_a      
      # queuesplit.each do |elm|
	      # tradeCountPushing = elm.size
	      # Global[mkt[0]].trigger_trades elm
	      # #Rails.logger.info "DBG: pushed trades inside..#{tradeCountPushing} lasttidseen: #{@lasttidseen} "
	      # #we do not want to send all the chunks, just send latest chunk and get out
	      # break	      
      # end
	  
	  
	  # either we can do above , sends tardes without tid sequence.
	  
	  # or use below method, as long as there are trades, we get from database and push
	  # it sends tids in sequence. when wo do not need to display tid in sequence, then we can switch back to above logic and also in trade.html order by time rather tid
	  
	  trades = Traade.with_currency(mkt[0]).order('id desc').limit(70).map(&:for_global) 
      Global[mkt[0]].trigger_trades trades
        
      
      
      
      end
	  
	  sleep 0.5
      
      
    
    end
    
    
    def queue_the_trades
      Thread.new do
        loop do
          sleep 1
          #Rails.logger.info "DBG: pushing trades.."
          pusher_trades
        end
      end
    end

    

  end
end
