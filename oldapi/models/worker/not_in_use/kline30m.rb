module Worker
  class Kline30m

  
  def initialize
      @runtimeTrades = {}
  end
  
  def redis
      @r ||= KlineDB.redis
  end
  
    def process(payload, metadata, delivery_info)
      @trade = Trade.new payload
      #Rails.logger.info "DBG: KLINE-WRITER: prepare Received trade : #{@trade.inspect}"
      create_global_keys_kline30m 
    end
    

    
    def create_global_keys_kline30m
        lasttid = @trade.id  
		
		#Rails.logger.info "DBG: KLINE-WRITER: kline30m received trade : #{lasttid}"		  
    	
		trade_time = (@trade.tradetime/1000).to_i		
    	
    	#5m pusher
    	t5m = (trade_time/(5*60)).to_i*5*60  
	    	
    	
    	#30m pusher
    	t30m = (trade_time/(30*60)).to_i*30*60
    	key30m = "ktio:#{@trade.market}:30m:#{t30m}"		
    	tdiff = t5m-t30m
    	limit = (tdiff/300)-1    	
    	k5key = "ktio:#{@trade.market}:k:5"
    	tsarray=[]
	    if tdiff>=300 && k5keylength > 0
    	ts = JSON.parse(redis.lindex(k5key, 0)).first
    	offset = (t30m - ts) / 60 / 5
    	offset = 0 if offset < 0 	    	
    	tsarray = JSON.parse('[%s]' % redis.lrange(k5key, offset, offset + limit).join(','))
    	end
    	tsarray.push(Rails.cache.read "ktio:#{@trade.market}:5m:#{t5m}")  
    	_, _, high, low, _, volumes = tsarray.transpose
  		output30m = [t30m, tsarray.first[1], high.max, low.min, tsarray.last[4], volumes.sum.round(8), lasttid]    	
    	Rails.cache.write key30m, output30m, expires_in: 60.minutes   	
    	
    	
    	
    	#Rails.logger.info "DBG: KLINE-WRITER: kline30m completed trade : #{lasttid}"
    	
    	
    end


  end
end
