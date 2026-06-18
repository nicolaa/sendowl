module Api
  module V1
    class OrdersController < ApplicationController
      def index
        @orders = Order.includes(:download_link, :product).order(created_at: :desc)
        render json: @orders.as_json(include: { product: {}, download_link: {} })
      end

      def create
        @order = Order.new(order_params)

        if @order.save
          # The after_create callback generates the download link
          # Enqueue mailer job
          OrderMailer.download_link(@order, @order.raw_token_for_mailer).deliver_later

          order_json = @order.as_json(include: { product: {}, download_link: {} })
          render json: order_json, status: :created
        else
          render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def resend_link
        @order = Order.find(params[:id])

        if @order.download_link.expired?
          render json: { error: "Link is expired" }, status: :unprocessable_entity
          return
        elsif @order.download_link.limit_reached?
          render json: { error: "Download limit reached" }, status: :unprocessable_entity
          return
        end

        @order.reset_download_link!

        OrderMailer.download_link(@order, @order.raw_token_for_mailer).deliver_later

        order_json = @order.as_json(include: { product: {}, download_link: {} })
        render json: order_json, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Order not found" }, status: :not_found
      end

      private

      def order_params
        params.require(:order).permit(:product_id, :buyer_email)
      end
    end
  end
end
