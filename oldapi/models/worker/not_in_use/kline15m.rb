module Worker
  class Kline15m

  
  def initialize
      @runtimeTrades = {}
  end
  
  def redis
      @r ||= KlineDB.redis
  end
  
    def process(payload, metadata, delivery_info)
      @trade = Trade.new payload
      #Rails.logger.info "DBG: KLINE-WRITER: prepare Received trade : #{@trade.inspect}"
      create_global_keys_kline15m
    end
    

    
    def create_global_keys_kline15m
        lasttid = @trade.id  
		
		#Rails.logger.info "DBG: KLINE-WRITER: kline15m received trade : #{lasttid}"	
		
		trade_time = (@trade.tradetime/1000).to_i		
    	
    	#5m pusher
    	t5m = (trade_time/(5*60)).to_i*5*60  	
	 
    	
    	#15m pusher
    	t15m = (trade_time/(15*60)).to_i*15*60
    	key15m = "ktio:#{@trade.market}:15m:#{t15m}"
		
    	tdiff = t5m-t15m
    	limit = (tdiff/300)-1    	
    	k5key = "ktio:#{@trade.market}:k:5"
    	k5keylength = redis.llen(k5key)
    	#Rails.logger.info "DBG: KLINE-WRITER: Kline15m prepare 15m starting process for tradeid: #{@trade.id}"
    	tsarray=[]
	    if tdiff>=300 && k5keylength > 0
	    	ts = JSON.parse(redis.lindex(k5key, 0)).first
	    	offsetPre = offset = (t15m - ts) / 60 / 5
	    	offset = 0 if offset < 0     	
	    	data = "t15m: #{t15m} t15m: #{t15m} present 5m + limit: #{limit}"
    		tsarray = JSON.parse('[%s]' % redis.lrange(k5key, offset, offset + limit).join(','))
    		if tsarray.size > 0
    		st0, _, high, low, _, volumes, tids = tsarray.transpose
    		st0array = st0.map{|t| Time.at(t)}
    		end	    
	    end    
	    #Rails.logger.info "DBG: KLINE-WRITER: Kline15m prepare 15m k5key #{k5key} k5keylength #{k5keylength} ts #{ts} t15m #{t15m} offsetPre #{offsetPre} offset #{offset} t5m #{t5m} tdiff #{tdiff} limit #{limit}"	    
	    #Rails.logger.info "DBG: KLINE-WRITER: Kline15m prepare 15m other than present  from ktio: #{tsarray.inspect}" 	    	
	    tsarray.push(Rails.cache.read "ktio:#{@trade.market}:5m:#{t5m}")  
	    #Rails.logger.info "DBG: KLINE-WRITER: Kline15m prepare 15m  present  from ktf: #{tsarray.inspect}" 
	    st, _, high, low, _, volumes, tids = tsarray.transpose
	    starray = st.map{|t| Time.at(t)}
	  	output15m = [t15m, tsarray.first[1], high.max, low.min, tsarray.last[4], volumes.sum.round(8), lasttid]	  		
	    #Rails.logger.info "DBG: KLINE-WRITER: Kline15m prepare 15m final array to calculate: t15m #{t15m} #{Time.at(t15m)} tsarray times :  #{starray.inspect} tsarray timestamps #{st.inspect} from ktio:  #{st0.inspect}"  
	    Rails.cache.write key15m, output15m, expires_in: 60.minutes 
  		#Rails.logger.info "DBG: KLINE-WRITER: Kline15m writes key #{key15m}, tid: #{@trade.id}, value: #{output15m}"
    	
    	
    	
    	
    	#Rails.logger.info "DBG: KLINE-WRITER: kline15m completed trade : #{lasttid}"
    	
    	
    end


  end
end
