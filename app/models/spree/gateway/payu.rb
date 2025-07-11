require 'faraday'
require 'bigdecimal'
require 'countries'

module Spree
  class Gateway::Payu < PaymentMethod
    preference :payu_client_id, :string # PayU Key
    preference :payu_client_secret, :string # PayU Salt 32 Bit for hash generation
    preference :test_payu_client_id, :string    # Test Key
    preference :test_payu_client_secret, :string # Test Salt
    #preference :payu_pos_id, :string
    #preference :payu_second_key, :string
    #preference :payu_pay_methods_type, :string
    #preference :payu_pay_methods_value, :string
    #preference :payu_second_key, :string
    preference :test_mode, :boolean, default: false
    preference :return_url, :string, default: "http://localhost:3000"
    preference :return_status_url, :string, default: "http://localhost:3000"
    preference :max_payment_amount, :integer, default: "100000"
    preference :min_payment_amount, :integer, default: "0.1"

    def payment_profiles_supported?
      false
    end

    def source_required?
      false
    end

    def payment_icon_name
      'payu'
    end

    def description_partial_name
      'payu'
    end

    def configuration_guide_partial_name
      'payu'
    end

    def available_for_order?(order)
      return false if preferred_min_payment_amount.present? && order.total <= preferred_min_payment_amount
      return false if preferred_max_payment_amount.present? && order.total >= preferred_max_payment_amount

      true
    end

    def cancel(order_id, *args)
      Rails.logger.debug("Starting cancellation for #{order_id}")

      Rails.logger.debug("Spree order #{order_id} has been canceled.")
      ActiveMerchant::Billing::Response.new(true, 'Spree order has been canceled.')
    end

    def amount(amount)
      (BigDecimal(amount.to_s) * BigDecimal('100')).to_i.to_s
    end

    def credit(credit_cents, payment_id, options)
      order = options[:originator].try(:payment).try(:order)
      payment = options[:originator].try(:payment)
      reimbursement = options[:originator].try(:reimbursement)
      order_number = order.try(:number)
      order_currency = order.try(:currency)

      ActiveMerchant::Billing::Response.new(true, 'Refund successful')
    end

    def order_url
      if preferred_test_mode
        'https://test.payu.in/_payment'
      else
        'https://secure.payu.in/_payment'
      end
    end

    def register_order(order, payment_id, gateway_id)
      return if order.blank? || payment_id.blank? || gateway_id.blank?

      payment = order.payments.find payment_id
      payload = register_order_payload(order, payment, gateway_id)

      conn = Faraday.new(url: order_url) do |faraday|
        faraday.adapter Faraday.default_adapter
      end

      response = conn.post do |req|
        req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        req.body = URI.encode_www_form(payload)
      end

      if response.status == 200
        # For PayU India, response is HTML for redirection, not JSON
        payment.update(public_metadata: { payment_url: order_url })
      else
        Rails.logger.warn("register_order #{order.id}, payment_id: #{payment_id} failed => #{response.inspect}")
        nil
      end
    end

    def current_payu_client_id
      preferred_test_mode ? preferred_test_payu_client_id : preferred_payu_client_id
    end

    def current_payu_client_secret
      preferred_test_mode ? preferred_test_payu_client_secret : preferred_payu_client_secret
    end

    def register_order_payload(order, payment, gateway_id)
      # PayU India requires a hash for authentication
      merchant_key = current_payu_client_id
      salt = current_payu_client_secret
      txnid = "#{order.number}-#{payment.number}"
      # Amount must be a string with two decimal places
      amount = sprintf('%.2f', order.total.to_f)
      productinfo = order.line_items.map(&:name).join(', ')
      firstname = order.billing_address.firstname.presence || 'Test'
      email = order.email.presence || 'test@example.com'
      phone = order.billing_address.phone.presence || '9999999999'
      surl = "#{preferred_return_url}/orders/#{order.number}"
      furl = "#{preferred_return_url}/orders/#{order.number}"
      # 10 udf fields as required by PayU India
      udfs = Array.new(10, '')
      # Hash sequence as per PayU India docs (15 pipes before salt)
      hash_string = [merchant_key, txnid, amount, productinfo, firstname, email, *udfs, salt].join('|')
      hash = Digest::SHA512.hexdigest(hash_string)
      payload = {
        key: merchant_key,
        txnid: txnid,
        amount: amount,
        productinfo: productinfo,
        firstname: firstname,
        email: email,
        phone: phone,
        surl: surl,
        furl: furl,
        hash: hash,
        service_provider: 'payu_paisa',
        udf1: udfs[0], udf2: udfs[1], udf3: udfs[2], udf4: udfs[3], udf5: udfs[4],
        udf6: udfs[5], udf7: udfs[6], udf8: udfs[7], udf9: udfs[8], udf10: udfs[9]
      }
      Rails.logger.info("PayU Payload: #{payload.inspect}")
      payload
    end

    def items_payload(line_items)
      line_items.map do |item|
        {
          quantity: item.quantity,
          unitPrice: amount(item.price),
          name: item.name
        }
      end
    end

    # PayU India does not use OAuth for authentication, instead uses merchant key and salt for hash generation
    # So, we remove the authorize methods and use hash-based authentication in payload

    def verify_url(payu_order_id)
      if preferred_test_mode
        "https://secure.snd.payu.com/api/v2_1/orders/#{payu_order_id}/captures"
      else
        "https://secure.payu.com/api/v2_1/orders/#{payu_order_id}/captures"
      end
    end

    def verify_transaction(status, payment, amount, currency, payu_order_id)
      return false if status.blank? || payment.blank? || amount.blank? || currency.blank? || payu_order_id.blank?
      return true if status == 'PENDING'
      return false if !['WAITING_FOR_CONFIRMATION', 'COMPLETED', 'CANCELED'].include?(status)

      float_amount = (amount.to_f / 100).to_f

      if status == 'WAITING_FOR_CONFIRMATION'
        conn = Faraday.new(url: verify_url(payu_order_id)) do |faraday|
          faraday.adapter Faraday.default_adapter
          faraday.request :authorization, 'Bearer', authorize
        end

        response = conn.post do |req|
          req.headers['Content-Type'] = 'application/json'
        end

        if response.success?
          return true
        else
          Rails.logger.warn("Verify_transaction #{payment.order.id} failed => #{response.inspect}")
          return false
        end
      end

      if payment.can_complete? && status == 'COMPLETED'
        payment.amount = float_amount
        payment.complete
      elsif status == 'CANCELED'
        payment.cancel!
      end

      private_metadata = payment.private_metadata
      private_metadata[:order_id] = payu_order_id
      private_metadata[:currency] = currency
      private_metadata[:amount] = amount
      payment.update(private_metadata: private_metadata)
      true
    end

    def language(country_iso)
      country = ISO3166::Country.new(country_iso)
      country&.languages&.first || 'en'
    end

    def actions
      %w[capture void]
    end

    def can_capture?(payment)
      %w[checkout pending].include?(payment.state)
    end

    def can_void?(payment)
      payment.state != 'void'
    end

    def capture(*)
      simulated_successful_billing_response
    end

    def void(*)
      simulated_successful_billing_response
    end

    private

    def simulated_successful_billing_response
      ActiveMerchant::Billing::Response.new(true, '', {}, {})
    end
  end
end
