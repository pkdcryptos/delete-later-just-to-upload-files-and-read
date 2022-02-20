module Worker
  class Kline12h

  
  def initialize
      @runtimeTrades = {}
  end
  
  def redis
      @r ||= KlineDB.redis
  end
  
    def process(payload, metadata, delivery_info)
      @trade = Trade.new payload
      #Rails.logger.info "DBG: KLINE-WRITER: prepare Received trade : #{@trade.inspect}"
      create_global_keys_kline12h 
    end
    

    
    def create_global_keys_kline12h
        lasttid = @trade.id  
		
		#Rails.logger.info "DBG: KLINE-WRITER: kline12h received trade : #{lasttid}"	
		
		trade_time = (@trade.tradetime/1000).to_i		
    	
    	#1h pusher
    	t1h = (trade_time/(60*60)).to_i*60*60
    	
    	#12h pusher
    	t12h = (trade_time/(720*60)).to_i*720*60
    	key12h = "ktio:#{@trade.market}:12h:#{t12h}"
		tdiff = t1h-t12h
    	limit = (tdiff/3600)-1    	
    	k60key = "ktio:#{@trade.market}:k:60"
    	tsarray=[]
    	if tdiff>=3600 && k60keylength > 0
    	ts = JSON.parse(redis.lindex(k60key, 0)).first
    	offset = (t12h - ts) / 60 / 60
    	offset = 0 if offset < 0 	
    	tsarray = JSON.parse('[%s]' % redis.lrange(k60key, offset, offset + limit).join(','))
    	end 
    	tsarray.push(Rails.cache.read "ktio:#{@trade.market}:1h:#{t1h}")  
    	_, _, high, low, _, volumes = tsarray.transpose
  		output12h = [t12h, tsarray.first[1], high.max, low.min, tsarray.last[4], volumes.sum.round(8), lasttid]	
    	Rails.cache.write key12h, output12h, expires_in: 60.minutes
    	
    	
    	
    	
    	#Rails.logger.info "DBG: KLINE-WRITER: kline12h completed trade : #{lasttid}"
    	
    	
    end


  end
end
