module Worker
  class Kline2h

  
  def initialize
      @runtimeTrades = {}
  end
  
  def redis
      @r ||= KlineDB.redis
  end
  
    def process(payload, metadata, delivery_info)
      @trade = Trade.new payload
      #Rails.logger.info "DBG: KLINE-WRITER: prepare Received trade : #{@trade.inspect}"
      create_global_keys_kline2h 
    end
    

    
    def create_global_keys_kline2h
        lasttid = @trade.id  
		
		#Rails.logger.info "DBG: KLINE-WRITER: kline2h received trade : #{lasttid}"		  
    	
	    trade_time = (@trade.tradetime/1000).to_i		
    	
    	#1h pusher
    	t1h = (trade_time/(60*60)).to_i*60*60
    	
    	#2h pusher
    	t2h = (trade_time/(120*60)).to_i*120*60
    	key2h = "ktio:#{@trade.market}:2h:#{t2h}"		
    	tdiff = t1h-t2h
    	limit = (tdiff/3600)-1    	
    	k60key = "ktio:#{@trade.market}:k:60"
    	k60keylength = redis.llen(k60key)
    	tsarray=[]
    	if tdiff>=3600 && k60keylength > 0
    	ts = JSON.parse(redis.lindex(k60key, 0)).first
    	offset = (t2h - ts) / 60 / 60
    	offset = 0 if offset < 0 	
    	tsarray = JSON.parse('[%s]' % redis.lrange(k60key, offset, offset + limit).join(','))
    	end 
    	tsarray.push(Rails.cache.read "ktio:#{@trade.market}:1h:#{t1h}")   
    	_, _, high, low, _, volumes = tsarray.transpose
  		output2h = [t2h, tsarray.first[1], high.max, low.min, tsarray.last[4], volumes.sum.round(8), lasttid]	
    	Rails.cache.write key2h, output2h, expires_in: 60.minutes
    	
    	
    	
    	
    	
    	#Rails.logger.info "DBG: KLINE-WRITER: kline2h completed trade : #{lasttid}"
    	
    	
    end


  end
end
