class CayadoRodauthApp < Rodauth::Rails::App
  configure CayadoRodauthMain

  route do |r|
    r.rodauth
  end
end
