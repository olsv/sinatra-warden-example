require 'sinatra'
require 'sinatra_warden'
require 'data_mapper'
require 'rack/flash'

DataMapper::Logger.new($stdout, :debug)
#DataMapper.setup(:default, 'sqlite::memory')
DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/sample.db")

class User
  include DataMapper::Resource

  property :id, Serial
  property :login, String
  property :password, String

end

DataMapper.finalize
# User.auto_migrate!
#
# User.create(login: 'user1', password: 'user1')
# User.create(login: 'user2', password: 'user2')

Warden::Strategies.add(:password) do
  def valid?
    params['user'] && params['user']['login'] && params['user']['password']
  end

  def authenticate!
    user = User.first login: params['user']['login'], password: params['user']['password']

    if user.nil?
      throw(:warden)
    else
      success!(user)
    end
  end
end



class Application < Sinatra::Base
  register Sinatra::Warden
  enable :sessions

  helpers do
    def link_to(name, path)
      "<a href=\"#{path}\">#{name}</a>"
    end

    def flash_message
      if flash
        "<p>#{flash[:success] || flash[:notice] || flash[:error]}</p>"
      end
    end
  end

  use Rack::Flash

  use Warden::Manager do |config|
    config.serialize_into_session{|user| user.id }
    config.serialize_from_session{|id| User.get(id) }
    config.scope_defaults :default, strategies: [:password], action: 'unauthenticated'
    config.failure_app = self
  end

  get '/' do
    haml :index
  end

  get '/admin' do
    authorize! # require a session for this action
    haml :admin
  end

  get '/dashboard' do
    authorize!('/login') # require session, redirect to '/login' instead of work
    haml :dashboard
  end
end
