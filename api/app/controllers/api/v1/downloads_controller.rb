module Api
  module V1
    class DownloadsController < ApplicationController
      def show
        hashed_token = Digest::SHA256.hexdigest(params[:token])
        @download_link = DownloadLink.find_by(token_hash: hashed_token)

        if @download_link.nil?
          render plain: "Link not found", status: :not_found
          return
        end

        # Return 200 with status flags (not an error code) so the buyer-facing page can
        # render a friendly, specific explanation rather than a raw 4xx. expires_at lets
        # the page tell the buyer exactly when the link lapsed.
        render json: {
          product_name: @download_link.order.product.name,
          remaining_downloads: [ @download_link.order.product.max_download_count - @download_link.download_count, 0 ].max,
          expired: @download_link.expired?,
          limit_reached: @download_link.limit_reached?,
          expires_at: @download_link.expires_at
        }
      end

      def trigger
        hashed_token = Digest::SHA256.hexdigest(params[:token])
        @download_link = DownloadLink.find_by(token_hash: hashed_token)

        if @download_link.nil?
          render plain: "Link not found", status: :not_found
          return
        end

        if @download_link.expired?
          render plain: "Download link expired", status: :forbidden
          return
        end

        if @download_link.limit_reached?
          render plain: "Download limit reached", status: :forbidden
          return
        end

        # Try to safely increment. If it fails, it means limit was hit concurrently
        if @download_link.increment_download!
          product = @download_link.order.product
          render json: { file_url: product.file_placeholder }
        else
          render plain: "Limit reached or link expired concurrently", status: :forbidden
        end
      end
    end
  end
end
