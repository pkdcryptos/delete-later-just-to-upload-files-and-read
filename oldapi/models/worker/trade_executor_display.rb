module Worker
  class TradeExecutorDisplay
  
  


    def process(payload, metadata, delivery_info)
      payload.symbolize_keys!
      
      @payload = payload
      @market  = Market.find payload[:market_id]
      @price   = BigDecimal.new payload[:strike_price]
      @volume  = BigDecimal.new payload[:volume]
      @funds   = BigDecimal.new payload[:funds]
      @ask = OrderAsk.find(@payload[:ask_id])
      @bid = OrderBid.find(@payload[:bid_id])
	  @tradetime = payload[:tradetime]
	  
      
      
      

	  last_price = @price
      trend = @price >= @market.latest_price ? 'up' : 'down'
	  
	  
	  # create parallel database only for maintaining 24hr trades records	  
	  @traade = Traade.create!(ask_id: @ask.id, ask_member_id: @ask.member_id, ask_member_user_type: @ask.user_type,
                               bid_id: @bid.id, bid_member_id: @bid.member_id, bid_member_user_type: @bid.user_type, ask_aid: @ask.aid, bid_aid: @bid.aid,
                               price: @price, volume: @volume, funds: @funds,
                               currency: @market.id.to_sym, trend: trend, tradetime: @tradetime,  last_price: last_price, ask_fee: @ask.fee, bid_fee: @bid.fee, baseAsset: @market.base_unit, quoteAsset: @market.quote_unit)
							   
	#delete all entries more than 2 days back, for now do not do it. we can do it later.
   
	@trade = {id: @traade.id, ask_id: @ask.id, ask_member_id: @ask.member_id,  bid_id: @bid.id, bid_member_id: @bid.member_id, ask_aid: @ask.aid, bid_aid: @bid.aid,  price: @price, volume: @volume, funds: @funds,	currency: @market.id.to_sym, trend: trend, tradetime: @tradetime,  last_price: last_price, ask_fee: @ask.fee, bid_fee: @bid.fee, baseAsset: @market.base_unit, quoteAsset: @market.quote_unit }                             
  
                               
      AMQPQueue.publish(
        :trade_display,
        @trade,
        { headers: {
            market: @market.id,
            ask_member_id: @ask.member_id,
            bid_member_id: @bid.member_id
          }
        }
      )
      
      
      
    rescue
      #todo temporarily disabled, but need to enable in production
      #SystemMailer.trade_execute_error(payload, $!.message, $!.backtrace.join("\n")).deliver
	#Rails.logger.info "DBG: FATAL SystemMailer trade_execute_error #{payload.inspect}, #{$!.message}, #{$!.backtrace.join("\n")}"

      raise $!
    end

  end
end
