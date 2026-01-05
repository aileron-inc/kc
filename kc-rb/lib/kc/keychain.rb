require 'ffi'

module Kc
  class Keychain
    SERVICE_NAME = 'kc'

    module CoreFoundation
      extend FFI::Library
      ffi_lib '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation'

      # CFString functions
      attach_function :CFStringCreateWithCString, %i[pointer string uint32], :pointer
      attach_function :CFStringGetCString, %i[pointer pointer long uint32], :bool
      attach_function :CFStringGetLength, [:pointer], :long

      # CFData functions
      attach_function :CFDataCreate, %i[pointer pointer long], :pointer
      attach_function :CFDataGetLength, [:pointer], :long
      attach_function :CFDataGetBytePtr, [:pointer], :pointer

      # CFDictionary functions
      attach_function :CFDictionaryCreateMutable, %i[pointer long pointer pointer], :pointer
      attach_function :CFDictionarySetValue, %i[pointer pointer pointer], :void
      attach_function :CFDictionaryGetValue, %i[pointer pointer], :pointer

      # CFArray functions
      attach_function :CFArrayGetCount, [:pointer], :long
      attach_function :CFArrayGetValueAtIndex, %i[pointer long], :pointer

      # CFNumber functions
      attach_function :CFNumberCreate, %i[pointer int pointer], :pointer
      attach_function :CFBooleanGetValue, [:pointer], :bool

      # CFRelease
      attach_function :CFRelease, [:pointer], :void

      # Constants
      KCFStringEncodingUTF8 = 0x08000100
      KCFNumberSInt32Type = 3

      # Get Boolean constants using symbols
      def self.kCFBooleanTrue
        @kCFBooleanTrue ||= begin
          ptr_ptr = FFI::DynamicLibrary.open(
            '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation',
            FFI::DynamicLibrary::RTLD_LAZY | FFI::DynamicLibrary::RTLD_GLOBAL
          ).find_symbol('kCFBooleanTrue')
          FFI::Pointer.new(:pointer, ptr_ptr.address).read_pointer
        end
      end

      def self.kCFBooleanFalse
        @kCFBooleanFalse ||= begin
          ptr_ptr = FFI::DynamicLibrary.open(
            '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation',
            FFI::DynamicLibrary::RTLD_LAZY | FFI::DynamicLibrary::RTLD_GLOBAL
          ).find_symbol('kCFBooleanFalse')
          FFI::Pointer.new(:pointer, ptr_ptr.address).read_pointer
        end
      end
    end

    module SecurityFramework
      extend FFI::Library
      ffi_lib '/System/Library/Frameworks/Security.framework/Security'

      # Modern SecItem API
      attach_function :SecItemAdd, %i[pointer pointer], :int
      attach_function :SecItemCopyMatching, %i[pointer pointer], :int
      attach_function :SecItemUpdate, %i[pointer pointer], :int
      attach_function :SecItemDelete, [:pointer], :int

      # Error codes
      ErrSecSuccess = 0
      ErrSecItemNotFound = -25_300
      ErrSecDuplicateItem = -25_299

      # Helper to get constant addresses from library
      def self.get_constant(name)
        ptr = FFI::DynamicLibrary.open(
          '/System/Library/Frameworks/Security.framework/Security',
          FFI::DynamicLibrary::RTLD_LAZY | FFI::DynamicLibrary::RTLD_GLOBAL
        ).find_variable(name)
        ptr.read_pointer
      end
    end

    class << self
      # Helper methods for CoreFoundation
      def create_cf_string(str)
        CoreFoundation.CFStringCreateWithCString(nil, str, CoreFoundation::KCFStringEncodingUTF8)
      end

      def create_cf_data(data)
        ptr = FFI::MemoryPointer.from_string(data)
        CoreFoundation.CFDataCreate(nil, ptr, data.bytesize)
      end

      def create_cf_boolean(value)
        value ? CoreFoundation.kCFBooleanTrue : CoreFoundation.kCFBooleanFalse
      end

      def cf_string_to_ruby(cf_string)
        return nil if cf_string.null?

        length = CoreFoundation.CFStringGetLength(cf_string)
        buffer = FFI::MemoryPointer.new(:char, length * 4 + 1)
        if CoreFoundation.CFStringGetCString(cf_string, buffer, buffer.size, CoreFoundation::KCFStringEncodingUTF8)
          buffer.read_string
        end
      end

      def cf_data_to_ruby(cf_data)
        return nil if cf_data.null?

        length = CoreFoundation.CFDataGetLength(cf_data)
        ptr = CoreFoundation.CFDataGetBytePtr(cf_data)
        ptr.read_bytes(length)
      end

      # Get Security framework constants
      def kSecClass
        @kSecClass ||= SecurityFramework.get_constant('kSecClass')
      end

      def kSecClassInternetPassword
        @kSecClassInternetPassword ||= SecurityFramework.get_constant('kSecClassInternetPassword')
      end

      def kSecAttrServer
        @kSecAttrServer ||= SecurityFramework.get_constant('kSecAttrServer')
      end

      def kSecAttrAccount
        @kSecAttrAccount ||= SecurityFramework.get_constant('kSecAttrAccount')
      end

      def kSecAttrProtocol
        @kSecAttrProtocol ||= SecurityFramework.get_constant('kSecAttrProtocol')
      end

      def kSecAttrProtocolHTTPS
        @kSecAttrProtocolHTTPS ||= SecurityFramework.get_constant('kSecAttrProtocolHTTPS')
      end

      def kSecValueData
        @kSecValueData ||= SecurityFramework.get_constant('kSecValueData')
      end

      def kSecReturnData
        @kSecReturnData ||= SecurityFramework.get_constant('kSecReturnData')
      end

      def kSecMatchLimit
        @kSecMatchLimit ||= SecurityFramework.get_constant('kSecMatchLimit')
      end

      def kSecMatchLimitAll
        @kSecMatchLimitAll ||= SecurityFramework.get_constant('kSecMatchLimitAll')
      end

      def kSecReturnAttributes
        @kSecReturnAttributes ||= SecurityFramework.get_constant('kSecReturnAttributes')
      end

      def save(account_name, content)
        # Try to delete existing entry first (update semantics)
        delete(account_name) rescue nil

        # Create query dictionary for Internet Password
        # Note: Internet Passwords are automatically synced via iCloud Keychain when enabled
        query = CoreFoundation.CFDictionaryCreateMutable(nil, 0, nil, nil)

        server_str = create_cf_string(SERVICE_NAME)
        account_str = create_cf_string(account_name)
        data_obj = create_cf_data(content)

        CoreFoundation.CFDictionarySetValue(query, kSecClass, kSecClassInternetPassword)
        CoreFoundation.CFDictionarySetValue(query, kSecAttrServer, server_str)
        CoreFoundation.CFDictionarySetValue(query, kSecAttrAccount, account_str)
        CoreFoundation.CFDictionarySetValue(query, kSecAttrProtocol, kSecAttrProtocolHTTPS)
        CoreFoundation.CFDictionarySetValue(query, kSecValueData, data_obj)

        status = SecurityFramework.SecItemAdd(query, nil)

        # Cleanup
        CoreFoundation.CFRelease(server_str)
        CoreFoundation.CFRelease(account_str)
        CoreFoundation.CFRelease(data_obj)
        CoreFoundation.CFRelease(query)

        unless status == SecurityFramework::ErrSecSuccess
          raise Error, "Failed to save to keychain (status: #{status})"
        end
      end

      def load(account_name)
        # Create query dictionary for Internet Password
        query = CoreFoundation.CFDictionaryCreateMutable(nil, 0, nil, nil)

        server_str = create_cf_string(SERVICE_NAME)
        account_str = create_cf_string(account_name)

        CoreFoundation.CFDictionarySetValue(query, kSecClass, kSecClassInternetPassword)
        CoreFoundation.CFDictionarySetValue(query, kSecAttrServer, server_str)
        CoreFoundation.CFDictionarySetValue(query, kSecAttrAccount, account_str)
        CoreFoundation.CFDictionarySetValue(query, kSecAttrProtocol, kSecAttrProtocolHTTPS)
        CoreFoundation.CFDictionarySetValue(query, kSecReturnData, create_cf_boolean(true))

        result_ptr = FFI::MemoryPointer.new(:pointer)
        status = SecurityFramework.SecItemCopyMatching(query, result_ptr)

        # Cleanup query
        CoreFoundation.CFRelease(server_str)
        CoreFoundation.CFRelease(account_str)
        CoreFoundation.CFRelease(query)

        unless status == SecurityFramework::ErrSecSuccess
          if status == SecurityFramework::ErrSecItemNotFound
            raise Error, "Entry '#{account_name}' not found in keychain"
          else
            raise Error, "Failed to load from keychain (status: #{status})"
          end
        end

        # Extract data
        result = result_ptr.read_pointer
        data = cf_data_to_ruby(result)
        CoreFoundation.CFRelease(result)

        data
      end

      def delete(account_name)
        # Create query dictionary for Internet Password
        query = CoreFoundation.CFDictionaryCreateMutable(nil, 0, nil, nil)

        server_str = create_cf_string(SERVICE_NAME)
        account_str = create_cf_string(account_name)

        CoreFoundation.CFDictionarySetValue(query, kSecClass, kSecClassInternetPassword)
        CoreFoundation.CFDictionarySetValue(query, kSecAttrServer, server_str)
        CoreFoundation.CFDictionarySetValue(query, kSecAttrAccount, account_str)
        CoreFoundation.CFDictionarySetValue(query, kSecAttrProtocol, kSecAttrProtocolHTTPS)

        status = SecurityFramework.SecItemDelete(query)

        # Cleanup
        CoreFoundation.CFRelease(server_str)
        CoreFoundation.CFRelease(account_str)
        CoreFoundation.CFRelease(query)

        unless status == SecurityFramework::ErrSecSuccess
          if status == SecurityFramework::ErrSecItemNotFound
            raise Error, "Entry '#{account_name}' not found in keychain"
          else
            raise Error, "Failed to delete from keychain (status: #{status})"
          end
        end
      end

      def list(prefix = nil)
        # Create query dictionary for Internet Password
        query = CoreFoundation.CFDictionaryCreateMutable(nil, 0, nil, nil)

        server_str = create_cf_string(SERVICE_NAME)

        CoreFoundation.CFDictionarySetValue(query, kSecClass, kSecClassInternetPassword)
        CoreFoundation.CFDictionarySetValue(query, kSecAttrServer, server_str)
        CoreFoundation.CFDictionarySetValue(query, kSecAttrProtocol, kSecAttrProtocolHTTPS)
        CoreFoundation.CFDictionarySetValue(query, kSecMatchLimit, kSecMatchLimitAll)
        CoreFoundation.CFDictionarySetValue(query, kSecReturnAttributes, create_cf_boolean(true))

        result_ptr = FFI::MemoryPointer.new(:pointer)
        status = SecurityFramework.SecItemCopyMatching(query, result_ptr)

        # Cleanup query
        CoreFoundation.CFRelease(server_str)
        CoreFoundation.CFRelease(query)

        if status == SecurityFramework::ErrSecItemNotFound
          return []
        end

        unless status == SecurityFramework::ErrSecSuccess
          raise Error, "Failed to list keychain items (status: #{status})"
        end

        # Parse results
        result = result_ptr.read_pointer
        count = CoreFoundation.CFArrayGetCount(result)
        accounts = []

        count.times do |i|
          item = CoreFoundation.CFArrayGetValueAtIndex(result, i)
          account_cf = CoreFoundation.CFDictionaryGetValue(item, kSecAttrAccount)
          account_name = cf_string_to_ruby(account_cf)

          if account_name && (prefix.nil? || account_name.start_with?(prefix))
            accounts << account_name
          end
        end

        CoreFoundation.CFRelease(result)

        accounts.sort.uniq
      end
    end
  end
end
