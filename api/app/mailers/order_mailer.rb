class OrderMailer < ApplicationMailer
  default from: "no-reply@sendowl-clone.com"

  def download_link(order, raw_token)
    @order = order
    @product = order.product
    frontend_url = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
    @url  = "#{frontend_url}/download/#{raw_token}"

    mail(to: @order.buyer_email, subject: "Your download link for #{@product.name}")
  end
end
