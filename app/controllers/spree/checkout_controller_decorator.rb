# frozen_string_literal: true

module Spree
  module CheckoutControllerDecorator
    def update
      @previous_state = @order.state

      if @order.update_from_params(params, permitted_checkout_attributes, request.headers.env)
        track_checkout_entered_email
        track_payment_info_entered
        track_checkout_step_completed

        unless params[:do_not_advance]
          @order.temporary_address = !params[:save_user_address]
          unless @order.next
            return if @order.address? && @order.line_items_without_shipping_rates.any? && turbo_stream_request?

            flash[:error] = @order.errors.messages.values.flatten.join("\n")
            redirect_to(spree.checkout_state_path(@order.token, @order.state)) && return
          end

          if @order.completed?
            track_checkout_completed
            last_payment = @order.payments.last
            if last_payment.payment_method.is_a?(Spree::Gateway::Payu)
              redirect_to spree.gateway_payu_form_path(payment_id: last_payment.id)
            else
              redirect_to @order
            end
          else
            redirect_to spree.checkout_state_path(@order.token, @order.state)
          end
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end
end

if ::Spree::CheckoutController
   .included_modules.exclude?(Spree::CheckoutControllerDecorator)
  ::Spree::CheckoutController.prepend Spree::CheckoutControllerDecorator
end
