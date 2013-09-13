%w(omniauth omniauth-github omniauth-bitbucket dm-core dm-sqlite-adapter dm-migrations sinatra haml pry).each { |dependency| require dependency }

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/database.db")

class Service
  include DataMapper::Resource
  property :id,         Serial
  property :servicename,String
  property :username,   String
  property :uid,        String
  property :created_at, DateTime
  property :expires_at, DateTime
  property :token,      String
end

class User
  include DataMapper::Resource
  property :id,         Serial
  property :name,       String
  property :email,      String
  property :created_at, DateTime

  has n, :services
end

DataMapper.finalize
DataMapper.auto_upgrade!

# You'll need to customize the following line. Replace the CLIENT_ID 
#   and CLIENT_SECRET with the values you got from GitHub 
#   (https://github.com/settings/applications/new).
#
# Protip: When setting up your application's credentials at GitHub,
#   the following worked for me for local development:
#   Name: {whatever you want to call your app}
#   URL: http://localhost:4567
#   Callback URL: http://localhost:4567/auth/github/callback
#     That Callback URL should match whatever URL you have below (mine is on line 61).
#       * If you start your server with "ruby {filename.rb}", your URL and Callback URL
#         will have a port of :4567 (so: http://localhost:4567).
#       * If you use 'rackup', you'll have a port of :9292.
#       * If you use Pow, you won't have a port, you'll just use http://{appname}.dev
#
# Don't save your "client ID" and "client secret" values in a publicly-available file.
use OmniAuth::Builder do
  provider :github, "6d6bfc994d8aeddd039d", "849eeae6d47f690210ca4c9648b89c43356b6e11"
  provider :bitbucket, "C8UmGGd5eHFBkh78mE", "6HH7a8QsXn6w7F5AN8XVbNLK9Aedn6kp"
end

enable :sessions

helpers do
  def current_user
    @current_user ||= User.get(session[:user_id]) if session[:user_id]
  end
end

get '/' do
  if current_user
    # The following line just tests to see that it's working.
    #   If you've logged in your first user, '/' should load: "1 ... 1 ... {name} ... {nickname} ... {email}";
    #   You can then remove the following line, start using view templates, etc.
    haml :index
  else
    '<a href="/sign_up">create an account</a> or <a href="/sign_in">sign in with GitHub</a>'
    # if you replace the above line with the following line, 
    #   the user gets signed in automatically. Could be useful. 
    #   Could also break user expectations.
    # redirect '/auth/twitter'
  end
end

get '/auth/:name/callback' do
  auth = request.env["omniauth.auth"]
  user = User.first_or_create({ :email => auth["info"]["email"]}, {
    :name => auth["info"]["name"], 
    :email => auth["info"]["email"], 
    :created_at => Time.now })
  service = Service.first_or_create({ :uid => auth["uid"]}, {
    :uid => auth["uid"],
    :servicename => auth["provider"],
    :username => auth["info"]["nickname"],
    :created_at => Time.now })
  if auth["info"]["nickname"]
    service.username = auth["info"]["nickname"]
  else
    service.username = auth["info"]["name"]
  end

  service.token = auth["credentials"]["token"]
  if auth["credentials"]["expires"]
    service.expires_at = Time.at(auth["credentials"]["expires_at"])
  end


  if user.services.include?(service) == false
    user.services << service
  end
  service.save
  user.save
  session[:user_id] = user.id
  redirect '/'
end

# any of the following routes should work to sign the user in: 
#   /sign_up, /signup, /sign_in, /signin, /log_in, /login
["/sign_in/?", "/signin/?", "/log_in/?", "/login/?", "/sign_up/?", "/signup/?"].each do |path|
  get path do
    redirect '/auth/github'
  end
end

# either /log_out, /logout, /sign_out, or /signout will end the session and log the user out
["/sign_out/?", "/signout/?", "/log_out/?", "/logout/?"].each do |path|
  get path do
    session[:user_id] = nil
    redirect '/'
  end
end
