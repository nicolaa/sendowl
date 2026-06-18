module Api
  module V1
    class ProductsController < ApplicationController
      def index
        @products = Product.all
        render json: @products
      end

      def show
        @product = Product.find(params[:id])
        render json: @product
      end
    end
  end
end
