# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_ci_search_session',
  :secret      => '56a9ca15ee5f1cd163331877956b43466370049dda60cc3c4c1ccae6a8236148daaf1f10aaca2f76df130ba9bcb7da4fd324ab598ab9c4b81b6f60316548e285'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
