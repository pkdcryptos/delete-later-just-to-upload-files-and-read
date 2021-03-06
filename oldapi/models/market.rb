# People exchange commodities in markets. Each market focuses on certain
# commodity pair `{A, B}`. By convention, we call people exchange A for B
# *sellers* who submit *ask* orders, and people exchange B for A *buyers*
# who submit *bid* orders.
#
# ID of market is always in the form "#{B}#{A}". For example, in 'btceur'
# market, the commodity pair is `{btc, eur}`. Sellers sell out _btc_ for
# _eur_, buyers buy in _btc_ with _eur_. _btc_ is the `base_unit`, while
# _eur_ is the `quote_unit`.

class Market < ActiveYamlBase
  field :visible, default: true

  attr :name

  self.singleton_class.send :alias_method, :all_with_invisible, :all
  def self.all
    all_with_invisible.select &:visible
  end

  def self.enumerize
    all_with_invisible.inject({}) {|hash, i| hash[i.id.to_sym] = i.code; hash }
  end

  def self.to_hash
    return @markets_hash if @markets_hash

    @markets_hash = {}
    all.each {|m| @markets_hash[m.id.to_sym] = m.unit_info }
    @markets_hash
  end

  def initialize(*args)
    super

    raise "missing base_unit or quote_unit: #{args}" unless base_unit.present? && quote_unit.present?
    @name = self[:name] || "#{base_unit}/#{quote_unit}".upcase
  end

  def latest_price
    Traade.latest_price(id.to_sym)
  end

  # type is :ask or :bid
  def fix_number_precision(type, d)
    digits = send(type)['fixed']
    d.round digits, 2
  end

  # shortcut of global access
  def bids;   global.bids   end
  def asks;   global.asks   end
  def trades; global.trades end
  def ticker; global.ticker end

  def to_s
    id
  end

  def ask_currency
    Currency.find_by_code(ask["currency"])
  end

  def bid_currency
    Currency.find_by_code(bid["currency"])
  end

  def scope?(account_or_currency)
    code = if account_or_currency.is_a? Account
             account_or_currency.currency
           elsif account_or_currency.is_a? Currency
             account_or_currency.code
           else
             account_or_currency
           end

    base_unit == code || quote_unit == code
  end

  def unit_info
   
		
	tickSizeKey = "ktio:#{id}:tickSize"
	#Rails.logger.info "DBG: tickSizeKey #{tickSizeKey}"
	if Rails.cache.exist?(tickSizeKey)
		tickSizeVal = Rails.cache.read(tickSizeKey)
	else
		tickSizeVal = tickSize
	end
	
	minTradeKey = "ktio:#{id}:minTrade"
	if Rails.cache.exist?(minTradeKey)
		minTradeVal = Rails.cache.read(minTradeKey)
	else
		minTradeVal = minTrade
	end
	
	minOrderValueKey = "ktio:#{id}:minOrderValue"
	if Rails.cache.exist?(minOrderValueKey)
		minOrderValueVal = Rails.cache.read(minOrderValueKey)
	else
		minOrderValueVal = minOrderValue
	end
	
	 {name: name, base_unit: base_unit, quote_unit: quote_unit, symbol: symbol,   baseAssetName: baseAssetName, baseAsset: baseAsset, tickSize: tickSizeVal,   quoteAsset: quoteAsset,minTrade: minTradeVal,  decimalPlaces: decimalPlaces,  minOrderValue: minOrderValueVal, startingprice: startingprice}   
  end
  
  def tradefee_info
    {symbol: symbol}   
  end
  
  def getsymbol_info
    {baseAsset: baseAsset, quoteAsset: quoteAsset}   
  end
  
  
  


  private

  def global
    @global || Global[self.id]
  end

end
