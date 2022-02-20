module Worker
  class DepositCoin

    def process(payload, metadata, delivery_info)
      payload.symbolize_keys!
      
      Rails.logger.info "DBG:DEPOSIT -- deposit_coin tx received .. #{payload}"

      sleep 0.5 # nothing result without sleep by query gettransaction api

      channel_key = payload[:channel_key]
      txid = payload[:txid]      
      
      # if eth_getTransactionReceipt parsing does not have topics1, topics, data (topics1,2 shd start with 0x000000000000000000000000. what about condition on data ??) return
      # if eth_blockNumber does not return /respond or invalid amount -> return
      # this set applicable for refresh confirmations too
      # how to enforce that we get deposit transactions only for our address and only for few times (do not send same transaction again and again. This logic is not part of ktio software, but part of blockchain machine software. ALl our millions of payment address shd be loaded to blockchain machine for lookup and send only relevant transactions.. that way load on ktio system is low
      # refresh_confirmations should handle all coins confirmations
      # if any deposit transaction missing, having that transaction sent to this worker is responsibility of blockchain system software , not part of ktio software
      
      # if channel || txid is empty return
      return unless channel_key and txid
      
      channel = DepositChannel.find_by_currency(channel_key)
      
      if channel.currency_obj.code == 'erc' || channel.currency_obj.code == 'xyz'  || channel.currency_obj.code == 'abc'  || channel.currency_obj.code == 'p2p'  
        raw = CoinRPC["eth"].eth_getTransactionReceipt(txid)
        Rails.logger.info "DBG:DEPOSIT raw inspect #{raw.inspect}"
        raw.symbolize_keys!
        raw = raw[:logs].first        
        from = raw.dig("topics", 1)
        to = raw.dig("topics", 2)
        from.sub!("0x000000000000000000000000", "")
        to.sub!("0x000000000000000000000000", "")
        amount = (raw.dig("data").to_i(16) / 1e18).to_d
        blockNumber= raw.dig("blockNumber").to_i(16)
        contractAddress= raw.dig("address")
		contractAddressValid = 0
		if channel.currency_obj.code == 'erc' && contractAddress.downcase == '0x680B01788344fC163E869805356b74c2D481Ec17'.downcase
			contractAddressValid=1
		end
		if channel.currency_obj.code == 'p2p' && contractAddress.downcase == '0x941994c9b82D68aD83f6870D98D5239909249025'.downcase
																	 
			contractAddressValid=1
		end
		
		if contractAddressValid==0 
			Rails.logger.info "DBG:DEPOSIT deposit_coin: Returning as invalid transaction as contractAddress #{channel.currency_obj.code} and #{contractAddress} are not related"
		end
        presentBlockNumber = CoinRPC["eth"].eth_blockNumber.to_i(16)    
        return unless from and to and amount and blockNumber and presentBlockNumber  and contractAddressValid==1     
      	Rails.logger.info "DBG:DEPOSIT Amount #{amount} topics1  #{from.inspect} topics2  #{to.inspect} Blocknumbers: #{presentBlockNumber} #{blockNumber} "
      	confirmations =  presentBlockNumber - blockNumber  
        deposit_eth!(channel, txid, 1, from, to, amount, blockNumber, confirmations, raw)     	
      end
      
      if channel.currency_obj.code == 'eth' 
        raw = CoinRPC["eth"].eth_getTransactionByHash(txid)
        #Rails.logger.info "DBG: raw inspect #{raw.inspect}"
        raw.symbolize_keys!
        blockNumber = raw[:blockNumber].to_i(16)        
        from = raw[:from] 
        to = raw[:to]
        to.sub!("0x", "") 
        amount = (raw[:"value"].to_i(16) / 1e18).to_d
        presentBlockNumber = CoinRPC["eth"].eth_blockNumber.to_i(16)    
        return unless from and to and amount and blockNumber and presentBlockNumber        
      	#Rails.logger.info "DBG: Amount #{amount} topics1  #{from.inspect} topics2  #{to.inspect} Blocknumbers: #{presentBlockNumber} #{blockNumber} "
      	confirmations =  presentBlockNumber - blockNumber  
        deposit_eth!(channel, txid, 1, from, to, amount, blockNumber, confirmations, raw)     	
      end
      
      if channel.currency_obj.code == 'btc' || channel.currency_obj.code == 'ltc'   
       # true parameter is to get watchonly address in details   
				Rails.logger.info "DBG:TRACK_CONFIRMS gettransaction trying for txid #{txid} "				
        raw = channel.currency_obj.api.gettransaction(txid, true)        
        #Rails.logger.info "DBG: BTC: raw inspect #{raw.inspect}"
        raw.symbolize_keys!
        raw[:details].each_with_index do |detail, i|
          detail.symbolize_keys!
          deposit!(channel, txid, i, raw, detail)
        end        
      end
	  
	  
	  if  channel.currency_obj.code == 'trx'   
       # true parameter is to get watchonly address in details  
	   Rails.logger.info "DBG1: Entered trx block #{raw.inspect}"
	   
	   
	   rawb = open('https://apilist.tronscan.org/api/block/latest').read 
		rawb = JSON.parse(rawb)
		rawb.symbolize_keys!
		presentBlockNumber = rawb[:number]
	   
		raw = open('https://apilist.tronscan.org/api/transaction-info?hash='+txid).read 
		raw = JSON.parse(raw)
		Rails.logger.info "DBG1: Entered trx block #{raw.inspect}"
		raw.symbolize_keys!
		from = raw[:ownerAddress]
        to = raw[:toAddress]
		contractData=raw[:contractData]
		contractData.symbolize_keys!
	    amount = contractData[:"amount"]
		Rails.logger.info "DBG1: amount #{amount}"
		amount = (amount / 1e6).to_d
        blockNumber = raw[:block]
        confirmations = presentBlockNumber - blockNumber
        Rails.logger.info "DBG1: from #{from} to #{to}  amount #{amount} blockNumber #{blockNumber} presentBlockNumber #{presentBlockNumber} confirmations #{confirmations}"
		deposit_trx!(channel, txid, 1, from, to, amount, blockNumber, confirmations, raw)
              
      end
	  
	  if  channel.currency_obj.code == 'usdt'   
       # true parameter is to get watchonly address in details  
	   Rails.logger.info "DBG1: Entered trx block #{raw.inspect}"
	   
	   
	   rawb = open('https://apilist.tronscan.org/api/block/latest').read 
		rawb = JSON.parse(rawb)
		rawb.symbolize_keys!
		presentBlockNumber = rawb[:number]
	   
		raw = open('https://apilist.tronscan.org/api/transaction-info?hash='+txid).read 
		raw = JSON.parse(raw)
		Rails.logger.info "DBG1: Entered trx block #{raw.inspect}"
		raw.symbolize_keys!
		tokenTransferInfoData=raw[:tokenTransferInfo]
		tokenTransferInfoData.symbolize_keys!
	    from = tokenTransferInfoData[:from_address]
        to = tokenTransferInfoData[:to_address]
		amount = tokenTransferInfoData[:"amount_str"]
		Rails.logger.info "DBG1: amount #{amount}"
		amount = (amount.to_i(16) / 1e6).to_d
        blockNumber = raw[:block]
        confirmations = presentBlockNumber - blockNumber
        Rails.logger.info "DBG1: from #{from} to #{to}  amount #{amount} blockNumber #{blockNumber} presentBlockNumber #{presentBlockNumber} confirmations #{confirmations}"
		deposit_trx!(channel, txid, 1, from, to, amount, blockNumber, confirmations, raw)
              
      end
      
      
      
   end
   
      def deposit_trx!(channel, txid, txout, from, to, amount, blockNumber, confirmations, raw)
      ActiveRecord::Base.transaction do
        address = channel.currency_obj.code + '_' + to
        Rails.logger.info "DBG1: Inside deposit_trx! currency: #{channel.currency_obj.id} function txid: #{txid}, txout: #{txout}, address: #{address}, amount: #{amount} confirmations #{confirmations}"
        unless PaymentAddress.where(currency: channel.currency_obj.id, address: address).first
          Rails.logger.info "DBG1: Deposit address not found, skip. txid: #{txid}, txout: #{txout}, address: #{address}, amount: #{amount}"
          return
        end
        return if PaymentTransaction::Normal.where(txid: txid, txout: txout).first
        tx = PaymentTransaction::Normal.create! \
        txid: txid,
        txout: txout,
        address: address,
        amount: amount,
        confirmations: confirmations,
        receive_at: Time.now.to_datetime,
        currency: channel.currency
		Rails.logger.info "DBG1: tx #{tx.inspect}"
        deposit = channel.kls.create! \
        payment_transaction_id: tx.id,
        txid: tx.txid,
        txout: tx.txout,
        amount: tx.amount,
        member: tx.member,
        account: tx.account,
        currency: tx.currency,
        confirmations: tx.confirmations

        deposit.submit!
        deposit.accept! 
      end
    rescue
      Rails.logger.error "Failed to deposit: #{$!}"
      Rails.logger.error "txid: #{txid}, txout: #{txout}, detail: #{raw.inspect}"
      Rails.logger.error $!.backtrace.join("\n")
    end
   
   def deposit_eth!(channel, txid, txout, from, to, amount, blockNumber, confirmations, raw)
      ActiveRecord::Base.transaction do
        address = channel.currency_obj.code + '_' + to
        #Rails.logger.info "DBG: Inside deposit_eth! currency: #{channel.currency_obj.id} function txid: #{txid}, txout: #{txout}, address: #{address}, amount: #{amount}"
        unless PaymentAddress.where(currency: channel.currency_obj.id, address: address).first
          #Rails.logger.info "DBG: Deposit address not found, skip. txid: #{txid}, txout: #{txout}, address: #{address}, amount: #{amount}"
          return
        end
        return if PaymentTransaction::Normal.where(txid: txid, txout: txout).first
        tx = PaymentTransaction::Normal.create! \
        txid: txid,
        txout: txout,
        address: address,
        amount: 500,
        confirmations: confirmations,
        receive_at: Time.now.to_datetime,
        currency: channel.currency

        deposit = channel.kls.create! \
        payment_transaction_id: tx.id,
        txid: tx.txid,
        txout: tx.txout,
        amount: tx.amount,
        member: tx.member,
        account: tx.account,
        currency: tx.currency,
        confirmations: tx.confirmations

        deposit.submit!
        deposit.accept! 
      end
    rescue
      Rails.logger.error "Failed to deposit: #{$!}"
      Rails.logger.error "txid: #{txid}, txout: #{txout}, detail: #{raw.inspect}"
      Rails.logger.error $!.backtrace.join("\n")
    end




    def deposit!(channel, txid, txout, raw, detail)
      #return if detail[:account] != "payment" || detail[:category] != "receive"
			
			Rails.logger.info "DBG:TRACK_CONFIRMS: deposit!  for txid #{txid} "

      ActiveRecord::Base.transaction do
				Rails.logger.info "DBG:TRACK_CONFIRMS: address check  for txid #{txid} "
        unless PaymentAddress.where(currency: channel.currency_obj.id, address: detail[:address]).first
          #Rails.logger.info "DBG: Deposit address not found, skip. txid: #{txid}, txout: #{txout}, address: #{detail[:address]}, amount: #{detail[:amount]}"
          return
        end
			Rails.logger.info "DBG:TRACK_CONFIRMS: check if exists  for txid #{txid} "
        return if PaymentTransaction::Normal.where(txid: txid, txout: txout).first

        tx = PaymentTransaction::Normal.create! \
        txid: txid,
        txout: txout,
        address: detail[:address],
        amount: detail[:amount].to_s.to_d,
        confirmations: raw[:confirmations],
        receive_at: Time.at(raw[:timereceived]).to_datetime,
        currency: channel.currency

        deposit = channel.kls.create! \
        payment_transaction_id: tx.id,
        txid: tx.txid,
        txout: tx.txout,
        amount: tx.amount,
        member: tx.member,
        account: tx.account,
        currency: tx.currency,
        confirmations: tx.confirmations

        deposit.submit!
        deposit.accept!
      end
    rescue
      Rails.logger.error "Failed to deposit: #{$!}"
      Rails.logger.error "txid: #{txid}, txout: #{txout}, detail: #{detail.inspect}"
      Rails.logger.error $!.backtrace.join("\n")
    end





  end
end
