module Worker
  class Kline6h

  
  def initialize
      @runtimeTrades = {}
  end
  
  def redis
      @r ||= KlineDB.redis
  end
  
    def process(payload, metadata, delivery_info)
      @trade = Trade.new payload
      #Rails.logger.info "DBG: KLINE-WRITER: prepare Received trade : #{@trade.inspect}"
      create_global_keys_kline6h
    end
    

    
    def create_global_keys_kline6h
        lasttid = @trade.id  
		
		#Rails.logger.info "DBG: KLINE-WRITER: kline6h received trade : #{lasttid}"		  
    	
	  
    	trade_time = (@trade.tradetime/1000).to_i		
    	
    	#1h pusher
    	t1h = (trade_time/(60*60)).to_i*60*60
    	
    	#6h pusher
    	t6h = (trade_time/(360*60)).to_i*360*60
    	key6h = "ktio:#{@trade.market}:6h:#{t6h}"
		tdiff = t1h-t6h
    	limit = (tdiff/3600)-1    	
    	k60key = "ktio:#{@trade.market}:k:60"
    	tsarray=[]
    	if tdiff>=3600 && k60keylength > 0
    	ts = JSON.parse(redis.lindex(k60key, 0)).first
    	offset = (t6h - ts) / 60 / 60
    	offset = 0 if offset < 0 	
    	tsarray = JSON.parse('[%s]' % redis.lrange(k60key, offset, offset + limit).join(','))
    	end 
    	tsarray.push(Rails.cache.read "ktio:#{@trade.market}:1h:#{t1h}")   
    	_, _, high, low, _, volumes = tsarray.transpose
  		output6h = [t6h, tsarray.first[1], high.max, low.min, tsarray.last[4], volumes.sum.round(8), lasttid]	
    	Rails.cache.write key6h, output6h, expires_in: 60.minutes
    	
    	
    	
    	
    	#Rails.logger.info "DBG: KLINE-WRITER: kline6h completed trade : #{lasttid}"
    	
    	
    end


  end
end
