module Spree
  class Gateway::PayuController < Spree::BaseController
    skip_before_action :verify_authenticity_token, only: :comeback
    include Spree::Core::ControllerHelpers::Order

    def comeback
      order_id = params.dig(:order, :orderId)
      return head :unprocessable_entity if order_id.nil?

      payment = Spree::Payment.find_by("public_metadata->>'token' = ?", order_id)

      if payment.nil?
        Rails.logger.error "Payment not found for order: #{order_id}"
        head :unprocessable_entity
      else payment.state == 'checkout' &&
        payment.payment_method.verify_transaction(params[:order][:status],
                                                 payment,
                                                 params[:order][:totalAmount],
                                                 params[:order][:currencyCode],
                                                 order_id) &&
        payment.order.update_with_updater!
        head :ok
      end
    end

    # New action to render the PayU India payment form
    def payu_form
      payment = Spree::Payment.find(params[:payment_id])
      order = payment.order
      gateway = payment.payment_method
      payload = gateway.register_order_payload(order, payment, gateway.id)
      @payu_url = gateway.order_url
      @payu_payload = payload
      render 'spree/checkout/payment/payu_form'
    end
  end
end
