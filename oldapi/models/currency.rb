class Currency < ActiveYamlBase
  include International
  include ActiveHash::Associations

  field :visible, default: true

  self.singleton_class.send :alias_method, :all_with_invisible, :all
  def self.all
    all_with_invisible.select &:visible
  end

  def self.enumerize
    all_with_invisible.inject({}) {|memo, i| memo[i.code.to_sym] = i.id; memo}
  end

  def self.codes
    @keys ||= all.map &:code
  end

  def self.ids
    @ids ||= all.map &:id
  end

  def self.assets(code)
    find_by_code(code)[:assets]
  end

  def precision
    self[:precision]
  end

  def api
    raise unless coin?
    CoinRPC[code]
  end

  def fiat?
    not coin?
  end

  def balance_cache_key
    "ktio:hotwallet:#{code}:balance"
  end

  def balance
    Rails.cache.read(balance_cache_key) || 0
  end

  def decimal_digit
    self.try(:default_decimal_digit) || (fiat? ? 2 : 4)
  end

  def refresh_balance
    Rails.cache.write(balance_cache_key, api.safe_getbalance) if coin?
  end
  
 

  

  def address_url(address)
    raise unless coin?
    self[:address_url].try :gsub, '#{address}', address
  end

  def quick_withdraw_max
    @quick_withdraw_max ||= BigDecimal.new self[:quick_withdraw_max].to_s
  end

  def as_json(options = {})
    {
      key: key,
      code: code,
      coin: coin
    }
  end
  
  def userasset_info
  
    enableChargeKey = "ktio:#{code}:enableCharge"
	if Rails.cache.exist?(enableChargeKey)
		enableChargeVal = Rails.cache.read(enableChargeKey)
	else
		enableChargeVal = enableCharge
	end
	
	enableWithdrawKey = "ktio:#{code}:enableWithdraw"
	if Rails.cache.exist?(enableWithdrawKey)
		enableWithdrawVal = Rails.cache.read(enableWithdrawKey)
	else
		enableWithdrawVal = enableWithdraw
	end
	
	
	depositTipKey = "ktio:#{code}:depositTip"
	if Rails.cache.exist?(depositTipKey)
		depositTipVal = Rails.cache.read(depositTipKey)
	else
		depositTipVal = depositTip
	end
	
	depositTipLinkKey = "ktio:#{code}:depositTipLink"
	if Rails.cache.exist?(depositTipLinkKey)
		depositTipLinkVal = Rails.cache.read(depositTipLinkKey)
	else
		depositTipLinkVal = depositTipLink
	end
	
	
  
    {id: id, key: key, code: code,   assetName: assetName,  asset: asset,  coin: coin, escrowCoin: escrowCoin, family: family, enableCharge: enableChargeVal, enableWithdraw: enableWithdrawVal, depositTip: depositTipVal, depositTipLink: depositTipLinkVal }   
  end
  

  def walletControl_info
  
	
	enableChargeKey = "ktio:#{code}:enableCharge"
	if Rails.cache.exist?(enableChargeKey)
		enableChargeVal = Rails.cache.read(enableChargeKey)
	else
		enableChargeVal = enableCharge
	end
	
	enableWithdrawKey = "ktio:#{code}:enableWithdraw"
	if Rails.cache.exist?(enableWithdrawKey)
		enableWithdrawVal = Rails.cache.read(enableWithdrawKey)
	else
		enableWithdrawVal = enableWithdraw
	end
	
	
	depositTipKey = "ktio:#{code}:depositTip"
	if Rails.cache.exist?(depositTipKey)
		depositTipVal = Rails.cache.read(depositTipKey)
	else
		depositTipVal = depositTip
	end
	
	depositTipLinkKey = "ktio:#{code}:depositTipLink"
	if Rails.cache.exist?(depositTipLinkKey)
		depositTipLinkVal = Rails.cache.read(depositTipLinkKey)
	else
		depositTipLinkVal = depositTipLink
	end
	
	
	
	
    
    {id: id, assetCode: assetCode, assetName: assetName,  enableCharge: enableChargeVal, enableWithdraw: enableWithdrawVal, depositTip: depositTipVal, depositTipLink: depositTipLinkVal }    
  end
  
  def getallasset_info
     enableChargeKey = "ktio:#{code}:enableCharge"
	if Rails.cache.exist?(enableChargeKey)
		enableChargeVal = Rails.cache.read(enableChargeKey)
	else
		enableChargeVal = enableCharge
	end
	
	enableWithdrawKey = "ktio:#{code}:enableWithdraw"
	if Rails.cache.exist?(enableWithdrawKey)
		enableWithdrawVal = Rails.cache.read(enableWithdrawKey)
	else
		enableWithdrawVal = enableWithdraw
	end
	
	
	depositTipKey = "ktio:#{code}:depositTip"
	if Rails.cache.exist?(depositTipKey)
		depositTipVal = Rails.cache.read(depositTipKey)
	else
		depositTipVal = depositTip
	end
	
	depositTipLinkKey = "ktio:#{code}:depositTipLink"
	if Rails.cache.exist?(depositTipLinkKey)
		depositTipLinkVal = Rails.cache.read(depositTipLinkKey)
	else
		depositTipLinkVal = depositTipLink
	end
	
	
	
    {id: id, assetCode: assetCode, assetName: assetName, coin: coin, escrowCoin: escrowCoin, transactionFee: transactionFee, commissionRate: commissionRate, minProductWithdraw: minProductWithdraw, withdrawIntegerMultiple: withdrawIntegerMultiple, confirmTimes: confirmTimes,  url: url, addressUrl: addressUrl,  regEx: regEx, regExTag: regExTag,  legalMoney: legalMoney, enableCharge: enableChargeVal, enableWithdraw: enableWithdrawVal, depositTip: depositTipVal, depositTipLink: depositTipLinkVal }  
  end
  
  def getasset_info
    enableChargeKey = "ktio:#{code}:enableCharge"
	if Rails.cache.exist?(enableChargeKey)
		enableChargeVal = Rails.cache.read(enableChargeKey)
	else
		enableChargeVal = enableCharge
	end
	
	enableWithdrawKey = "ktio:#{code}:enableWithdraw"
	if Rails.cache.exist?(enableWithdrawKey)
		enableWithdrawVal = Rails.cache.read(enableWithdrawKey)
	else
		enableWithdrawVal = enableWithdraw
	end
	
	
	depositTipKey = "ktio:#{code}:depositTip"
	if Rails.cache.exist?(depositTipKey)
		depositTipVal = Rails.cache.read(depositTipKey)
	else
		depositTipVal = depositTip
	end
	
	depositTipLinkKey = "ktio:#{code}:depositTipLink"
	if Rails.cache.exist?(depositTipLinkKey)
		depositTipLinkVal = Rails.cache.read(depositTipLinkKey)
	else
		depositTipLinkVal = depositTipLink
	end
	
	
    {id: id, assetCode: assetCode, assetName: assetName, transactionFee: transactionFee, commissionRate: commissionRate, minProductWithdraw: minProductWithdraw, withdrawIntegerMultiple: withdrawIntegerMultiple, confirmTimes: confirmTimes, enableCharge: enableChargeVal, enableWithdraw: enableWithdrawVal, depositTip: depositTipVal, depositTipLink: depositTipLinkVal }   
  end
  
  
  
  def getassetpic_info
    {pic: pic, asset: asset }   
  end


  def summary
    locked = Account.locked_sum(code)
    balance = Account.balance_sum(code)
    sum = locked + balance

    coinable = self.coin?
    hot = coinable ? self.balance : nil

    {
      name: self.code.upcase,
      sum: sum,
      balance: balance,
      locked: locked,
      coinable: coinable,
      hot: hot
    }
  end
end
