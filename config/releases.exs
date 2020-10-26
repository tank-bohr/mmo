import Config

secret_key_base = System.get_env("SECRET_KEY_BASE")

config :mmo, MmoWeb.Endpoint,
  server: true,
  http: [port: {:system, "PORT"}],
  secret_key_base: secret_key_base,
  url: [host: System.get_env("APP_NAME") <> ".gigalixirapp.com", port: 443]
