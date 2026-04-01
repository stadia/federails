# frozen_string_literal: true

# Preload the W3C identity/v1 JSON-LD context used by Linked Data Signatures.
# This avoids runtime HTTP requests to https://w3id.org/identity/v1 during
# signature verification, improving both performance and test reliability.
#
# Context source: https://w3id.org/identity/v1
# Reference: json-ld-preloaded gem for the registration pattern.

require 'json/ld'

module JSON
  module LD
    class Context
      add_preloaded('http://w3id.org/identity/v1') do # rubocop:disable Metrics/BlockLength
        new(term_definitions: {
              'id'                         => TermDefinition.new('id', id: '@id', simple: true),
              'type'                       => TermDefinition.new('type', id: '@type', simple: true),
              'cred'                       => TermDefinition.new('cred', id: 'https://w3id.org/credentials#', simple: true, prefix: true),
              'dc'                         => TermDefinition.new('dc', id: 'http://purl.org/dc/terms/', simple: true, prefix: true),
              'identity'                   => TermDefinition.new('identity', id: 'https://w3id.org/identity#', simple: true, prefix: true),
              'perm'                       => TermDefinition.new('perm', id: 'https://w3id.org/permissions#', simple: true, prefix: true),
              'ps'                         => TermDefinition.new('ps', id: 'https://w3id.org/payswarm#', simple: true, prefix: true),
              'rdf'                        => TermDefinition.new('rdf', id: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', simple: true, prefix: true),
              'rdfs'                       => TermDefinition.new('rdfs', id: 'http://www.w3.org/2000/01/rdf-schema#', simple: true, prefix: true),
              'sec'                        => TermDefinition.new('sec', id: 'https://w3id.org/security#', simple: true, prefix: true),
              'schema'                     => TermDefinition.new('schema', id: 'http://schema.org/', simple: true, prefix: true),
              'xsd'                        => TermDefinition.new('xsd', id: 'http://www.w3.org/2001/XMLSchema#', simple: true, prefix: true),
              'Group'                      => TermDefinition.new('Group', id: 'https://www.w3.org/ns/activitystreams#Group', simple: true),
              'claim'                      => TermDefinition.new('claim', id: 'https://w3id.org/credentials#claim', type_mapping: '@id'),
              'credential'                 => TermDefinition.new('credential', id: 'https://w3id.org/credentials#credential', type_mapping: '@id'),
              'issued'                     => TermDefinition.new('issued', id: 'https://w3id.org/credentials#issued', type_mapping: 'http://www.w3.org/2001/XMLSchema#dateTime'),
              'issuer'                     => TermDefinition.new('issuer', id: 'https://w3id.org/credentials#issuer', type_mapping: '@id'),
              'recipient'                  => TermDefinition.new('recipient', id: 'https://w3id.org/credentials#recipient', type_mapping: '@id'),
              'Credential'                 => TermDefinition.new('Credential', id: 'https://w3id.org/credentials#Credential', simple: true),
              'CryptographicKeyCredential' => TermDefinition.new('CryptographicKeyCredential', id: 'https://w3id.org/credentials#CryptographicKeyCredential', simple: true),
              'about'                      => TermDefinition.new('about', id: 'http://schema.org/about', type_mapping: '@id'),
              'address'                    => TermDefinition.new('address', id: 'http://schema.org/address', type_mapping: '@id'),
              'addressCountry'             => TermDefinition.new('addressCountry', id: 'http://schema.org/addressCountry', simple: true),
              'addressLocality'            => TermDefinition.new('addressLocality', id: 'http://schema.org/addressLocality', simple: true),
              'addressRegion'              => TermDefinition.new('addressRegion', id: 'http://schema.org/addressRegion', simple: true),
              'comment'                    => TermDefinition.new('comment', id: 'http://www.w3.org/2000/01/rdf-schema#comment', simple: true),
              'created'                    => TermDefinition.new('created', id: 'http://purl.org/dc/terms/created', type_mapping: 'http://www.w3.org/2001/XMLSchema#dateTime'),
              'creator'                    => TermDefinition.new('creator', id: 'http://purl.org/dc/terms/creator', type_mapping: '@id'),
              'description'                => TermDefinition.new('description', id: 'http://schema.org/description', simple: true),
              'email'                      => TermDefinition.new('email', id: 'http://schema.org/email', simple: true),
              'familyName'                 => TermDefinition.new('familyName', id: 'http://schema.org/familyName', simple: true),
              'givenName'                  => TermDefinition.new('givenName', id: 'http://schema.org/givenName', simple: true),
              'image'                      => TermDefinition.new('image', id: 'http://schema.org/image', type_mapping: '@id'),
              'label'                      => TermDefinition.new('label', id: 'http://www.w3.org/2000/01/rdf-schema#label', simple: true),
              'name'                       => TermDefinition.new('name', id: 'http://schema.org/name', simple: true),
              'postalCode'                 => TermDefinition.new('postalCode', id: 'http://schema.org/postalCode', simple: true),
              'streetAddress'              => TermDefinition.new('streetAddress', id: 'http://schema.org/streetAddress', simple: true),
              'title'                      => TermDefinition.new('title', id: 'http://purl.org/dc/terms/title', simple: true),
              'url'                        => TermDefinition.new('url', id: 'http://schema.org/url', type_mapping: '@id'),
              'Person'                     => TermDefinition.new('Person', id: 'http://schema.org/Person', simple: true),
              'PostalAddress'              => TermDefinition.new('PostalAddress', id: 'http://schema.org/PostalAddress', simple: true),
              'Organization'               => TermDefinition.new('Organization', id: 'http://schema.org/Organization', simple: true),
              'identityService'            => TermDefinition.new('identityService', id: 'https://w3id.org/identity#identityService', type_mapping: '@id'),
              'idp'                        => TermDefinition.new('idp', id: 'https://w3id.org/identity#identityProvider', type_mapping: '@id'),
              'IdentityService'            => TermDefinition.new('IdentityService', id: 'https://w3id.org/identity#IdentityService', simple: true),
              'owner'                      => TermDefinition.new('owner', id: 'https://w3id.org/security#owner', type_mapping: '@id'),
              'publicKey'                  => TermDefinition.new('publicKey', id: 'https://w3id.org/security#publicKey', type_mapping: '@id'),
              'publicKeyPem'               => TermDefinition.new('publicKeyPem', id: 'https://w3id.org/security#publicKeyPem', simple: true),
              'PublicKey'                  => TermDefinition.new('PublicKey', id: 'https://w3id.org/security#Key', simple: true),
              'CryptographicKey'           => TermDefinition.new('CryptographicKey', id: 'https://w3id.org/security#Key', simple: true),
              'EncryptedMessage'           => TermDefinition.new('EncryptedMessage', id: 'https://w3id.org/security#EncryptedMessage', simple: true),
              'GraphSignature2012'         => TermDefinition.new('GraphSignature2012', id: 'https://w3id.org/security#GraphSignature2012', simple: true),
              'LinkedDataSignature2015'    => TermDefinition.new('LinkedDataSignature2015', id: 'https://w3id.org/security#LinkedDataSignature2015', simple: true),
              'LinkedDataSignature2016'    => TermDefinition.new('LinkedDataSignature2016', id: 'https://w3id.org/security#LinkedDataSignature2016', simple: true),
              'cipherAlgorithm'            => TermDefinition.new('cipherAlgorithm', id: 'https://w3id.org/security#cipherAlgorithm', simple: true),
              'cipherData'                 => TermDefinition.new('cipherData', id: 'https://w3id.org/security#cipherData', simple: true),
              'cipherKey'                  => TermDefinition.new('cipherKey', id: 'https://w3id.org/security#cipherKey', simple: true),
              'digestAlgorithm'            => TermDefinition.new('digestAlgorithm', id: 'https://w3id.org/security#digestAlgorithm', simple: true),
              'digestValue'                => TermDefinition.new('digestValue', id: 'https://w3id.org/security#digestValue', simple: true),
              'domain'                     => TermDefinition.new('domain', id: 'https://w3id.org/security#domain', simple: true),
              'expires'                    => TermDefinition.new('expires', id: 'https://w3id.org/security#expiration', type_mapping: 'http://www.w3.org/2001/XMLSchema#dateTime'),
              'initializationVector'       => TermDefinition.new('initializationVector', id: 'https://w3id.org/security#initializationVector', simple: true),
              'nonce'                      => TermDefinition.new('nonce', id: 'https://w3id.org/security#nonce', simple: true),
              'normalizationAlgorithm'     => TermDefinition.new('normalizationAlgorithm', id: 'https://w3id.org/security#normalizationAlgorithm', simple: true),
              'password'                   => TermDefinition.new('password', id: 'https://w3id.org/security#password', simple: true),
              'privateKey'                 => TermDefinition.new('privateKey', id: 'https://w3id.org/security#privateKey', type_mapping: '@id'),
              'privateKeyPem'              => TermDefinition.new('privateKeyPem', id: 'https://w3id.org/security#privateKeyPem', simple: true),
              'revoked'                    => TermDefinition.new('revoked', id: 'https://w3id.org/security#revoked', type_mapping: 'http://www.w3.org/2001/XMLSchema#dateTime'),
              'signature'                  => TermDefinition.new('signature', id: 'https://w3id.org/security#signature', simple: true),
              'signatureAlgorithm'         => TermDefinition.new('signatureAlgorithm', id: 'https://w3id.org/security#signingAlgorithm', simple: true),
              'signatureValue'             => TermDefinition.new('signatureValue', id: 'https://w3id.org/security#signatureValue', simple: true),
            })
      end
    end
  end
end
