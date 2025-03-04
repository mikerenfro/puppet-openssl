# frozen_string_literal: true

require 'pathname'
Puppet::Type.type(:x509_request).provide(:openssl) do
  desc 'Manages certificate signing requests with OpenSSL'

  commands openssl: 'openssl'

  def self.private_key(resource)
    file = File.read(resource[:private_key])
    case resource[:authentication]
    when :dsa
      OpenSSL::PKey::DSA.new(file, resource[:password])
    when :rsa
      OpenSSL::PKey::RSA.new(file, resource[:password])
    when :ec
      OpenSSL::PKey::EC.new(file, resource[:password])
    else
      raise Puppet::Error,
            "Unknown authentication type '#{resource[:authentication]}'"
    end
  end

  def self.check_private_key(resource)
    request = OpenSSL::X509::Request.new(File.read(resource[:path]))
    priv = private_key(resource)
    request.verify(priv)
  end

  def exists?
    if Pathname.new(resource[:path]).exist?
      return false if resource[:force] && !self.class.check_private_key(resource)

      true
    else
      false
    end
  end

  def create
    cmd_args = [
      'req', '-new',
      '-key', resource[:private_key],
      '-config', resource[:template],
      '-out', resource[:path]
    ]

    if resource[:password]
      cmd_args.push('-passin')
      cmd_args.push("pass:#{resource[:password]}")
    end

    cmd_args.push('-nodes') unless resource[:encrypted]

    openssl(*cmd_args)
  end

  def destroy
    Pathname.new(resource[:path]).delete
  end
end
