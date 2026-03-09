D = Steep::Diagnostic

target :fediverse do
  signature "sig/generated"

  check "lib/fediverse"

  library "base64"
  library "cgi"
  library "json"
  library "openssl"
  library "time"
  library "uri"

  collection_config "rbs_collection.yaml"

  configure_code_diagnostics(D::Ruby.lenient)
end
