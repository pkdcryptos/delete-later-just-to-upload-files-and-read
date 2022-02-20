module Worker
  class Kline1h

  
  def initialize
      @runtimeTrades = {}
  end
  
  def redis
      @r ||= KlineDB.redis
  end
  
    def process(payload, metadata, delivery_info)
      @trade = Trade.new payload
      #Rails.logger.info "DBG: KLINE-WRITER: prepare Received trade : #{@trade.inspect}"
      create_global_keys_kline1h
    end
    

    
    def create_global_keys_kline1h
        lasttid = @trade.id  
		
		#Rails.logger.info "DBG: KLINE-WRITER: kline1h received trade : #{lasttid}"	
		
		trade_time = (@trade.tradetime/1000).to_i		
    	
    	#5m pusher
    	t5m = (trade_time/(5*60)).to_i*5*60  
    	
	  
    	
    	#1h pusher
    	t1h = (trade_time/(60*60)).to_i*60*60
    	key1h = "ktio:#{@trade.market}:1h:#{t1h}"
		tdiff = t5m-t1h
    	limit = (tdiff/300)-1    	
    	k5key = "ktio:#{@trade.market}:k:5"
    	tsarray=[]
    	if tdiff>=300 && k5keylength > 0
    	ts = JSON.parse(redis.lindex(k5key, 0)).first
    	offset = (t1h - ts) / 60 / 5
    	offset = 0 if offset < 0 	
    	tsarray = JSON.parse('[%s]' % redis.lrange(k5key, offset, offset + limit).join(','))
    	end 
    	tsarray.push(Rails.cache.read "ktio:#{@trade.market}:5m:#{t5m}")  
    	_, _, high, low, _, volumes = tsarray.transpose
  		output1h = [t1h, tsarray.first[1], high.max, low.min, tsarray.last[4], volumes.sum.round(8), lasttid]	
    	Rails.cache.write key1h, output1h, expires_in: 60.minutes
    	
    	
    	
    	#Rails.logger.info "DBG: KLINE-WRITER: kline1h completed trade : #{lasttid}"
    	
    	
    end


  end
end
