# Lock CORS to the known frontend origin rather than "*". FRONTEND_URL is the same env var
# the mailer uses to build links, so dev and prod stay consistent from a single source.
# (With no auth/cookies today the risk of "*" is low, but allow-listing is the right default
# and avoids a hole the moment authentication is added.)
allowed_origins = ENV.fetch("FRONTEND_URL", "http://localhost:5173")

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins allowed_origins

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ]
  end
end
