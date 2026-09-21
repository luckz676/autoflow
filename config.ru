# config.ru - Rack entry point for AutoFlow (Sinatra)
# Render + Puma needs this to know how to load the app

require_relative 'app'

run Sinatra::Application