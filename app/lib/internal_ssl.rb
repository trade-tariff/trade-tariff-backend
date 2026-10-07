# Lets a Faraday connection trust the certificate every *.tariff.internal ECS service
# presents to its peers — a shared, self-signed certificate (see INTERNAL_CA_PEM), not one
# a public certificate authority issued. Without this, calling one of those services over
# HTTPS fails with "certificate verify failed (self-signed certificate)".
#
# Returns {} when no internal CA is configured, so the caller falls back to ordinary
# certificate checking against the system's own trusted CAs.
module InternalSsl
  def self.options
    pem = TradeTariffBackend.internal_ca_pem
    return {} if pem.blank?

    store = OpenSSL::X509::Store.new
    store.set_default_paths
    store.add_cert(OpenSSL::X509::Certificate.new(pem))

    { cert_store: store }
  end
end
