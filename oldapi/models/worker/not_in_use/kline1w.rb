module Worker
  class Kline1w

  
  def initialize
      @runtimeTrades = {}
  end
  
  def redis
      @r ||= KlineDB.redis
  end
  
    def process(payload, metadata, delivery_info)
      @trade = Trade.new payload
      #Rails.logger.info "DBG: KLINE-WRITER: prepare Received trade : #{@trade.inspect}"
      create_global_keys_kline1w 
    end
    

    
    def create_global_keys_kline1w
        lasttid = @trade.id  
		
		#Rails.logger.info "DBG: KLINE-WRITER: kline1w received trade : #{lasttid}"		  
    	
	    trade_time = (@trade.tradetime/1000).to_i		
    	
    	#1h pusher
    	t1h = (trade_time/(60*60)).to_i*60*60
    	
    	
    	
    	#1w pusher
    	#t1w = (trade_time/(10080*60)).to_i*10080*60
    	t1w = Time.at(@trade.tradetime.to_i).beginning_of_week.to_time.to_i
    	key1w = "ktio:#{@trade.market}:1w:#{t1w}"
    	tdiff = t1h-t1w
    	limit = (tdiff/3600)-1    	
    	k60key = "ktio:#{@trade.market}:k:60"
    	tsarray=[]
    	if k60keylength > 0
    	ts = JSON.parse(redis.lindex(k60key, 0)).first
    	offset = (t1w - ts) / 60 / 60
    	offset = 0 if offset < 0 	
    	tsarray = JSON.parse('[%s]' % redis.lrange(k60key, offset, offset + limit).join(','))
    	end 
    	tsarray.push(Rails.cache.read "ktio:#{@trade.market}:1h:#{t1h}")    
    	_, _, high, low, _, volumes = tsarray.transpose
  		output1w = [t1w, tsarray.first[1], high.max, low.min, tsarray.last[4], volumes.sum.round(8), lasttid]	
    	Rails.cache.write key1w, output1w, expires_in: 60.minutes
    	
    	
    	
    	#Rails.logger.info "DBG: KLINE-WRITER: kline1w completed trade : #{lasttid}"
    	
    	
    end


  end
end
