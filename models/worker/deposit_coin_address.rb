module Worker
  class DepositCoinAddress

    def process(payload, metadata, delivery_info)
      payload.symbolize_keys!

      payment_address = PaymentAddress.find payload[:payment_address_id]
      return if payment_address.address.present?

      
      #make sure the generated address is unqiue for that currency.
      # we took off uniqueness validation clause of payment address table, as same address can be used for all erc tokens.
      # or better put uniqueness validation on combination of address and currency
      currency = payload[:currency]
      if currency == 'eth' || currency == 'erc'  || currency == 'xyz'   || currency == 'abc'   || currency == 'p2p'  
        address = payment_address.account.member.ethdoc.address
        address = currency + '_' + address
        ##Rails.logger.info "DBG: address: #{address}"
      end
      if currency == 'btc'
        address  = payment_address.account.member.btcdoc.address
      end
      if currency == 'ltc'
        address  = payment_address.account.member.ltcdoc.address
      end
	  if currency == 'trx' || currency == 'usdt'
        address  = payment_address.account.member.trxdoc.address
		address = currency + '_' + address
      end
	

      if payment_address.update address: address
        #::Pusher["private-#{payment_address.account.member.sn}"].trigger_async('deposit_address', { type: 'create', attributes: payment_address.as_json})
      end
    end

  end
end
