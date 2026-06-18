# Exists purely to support the Playwright e2e suite (see frontend/tests), which needs to
# read the download link out of the most recently sent email. Only routed in the test env
# (see config/routes.rb), so it is never reachable in development or production.
class TestMailController < ApplicationController
  def latest
    deliveries = ActionMailer::Base.deliveries
    # Scope to a recipient when given, so parallel e2e tests each read *their own*
    # latest email rather than racing on a single global "last delivered" message.
    deliveries = deliveries.select { |m| m.to.include?(params[:to]) } if params[:to].present?
    mail = deliveries.last

    if mail
      render plain: mail.body.encoded
    else
      render plain: "No emails", status: 404
    end
  end
end
