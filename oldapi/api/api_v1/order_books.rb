module APIv1
  class OrderBook < Struct.new(:asks, :bids); end
  class OrderBooks < Grape::API
  
    helpers ::APIv1::NamedParams
	
desc 'Get depth or specified market. Both asks and bids are sorted from highest price to lowest.'
params do
	use :market
	optional :limit, type: Integer, default: 300, range: 1..1000, desc: 'Limit the number of returned price levels. Default to 300.'
end
get "/depth" do
	global = Global[params[:market]]
	#asks = global.asks[0,params[:limit]].reverse
	#bids = global.bids[0,params[:limit]]
	asks = global.asks
	bids = global.bids
	asksKeys = asks.nil? || asks.empty? ? [] : asks.keys
	bidsKeys = bids.nil? || bids.empty? ? [] : bids.keys
	{timestamp: Time.now.to_i, asks: asks, bids: bids, asksKeys: asksKeys, bidsKeys: bidsKeys}
end
	
	
  end
end