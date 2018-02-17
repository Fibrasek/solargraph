require 'thread'
require 'set'

module Solargraph
  module LanguageServer
    # The base language server data provider.
    #
    class Host
      attr_accessor :resolvable
      attr_reader :api_map
  
      def initialize
        @api_map = Solargraph::ApiMap.new
        # @type [Hash<String, Solargraph::ApiMap::Source]
        @file_source = {}
        @semaphore = Mutex.new
        @buffer_semaphore = Mutex.new
        @cancel = []
        @buffer = ''
      end

      def cancel id
        @cancel.push id
      end

      def cancel? id
        @cancel.include? id
      end

      def clear id
        @cancel.delete id
      end

      def start request
        message = Message.select(request['method']).new(self, request)
        message.process
        message
      end

      def read filename
        #text = nil
        #@semaphore.synchronize { text = @files[filename] }
        #text
        source = nil
        @semaphore.synchronize {
          source = @file_source[filename]
        }
        source
      end

      def open filename, text
        #change filename, text
        @semaphore.synchronize {
          @file_source[filename] = Solargraph::ApiMap::Source.virtual(text, filename)
        }
      end

      def change filename, changes
        @semaphore.synchronize {
          #@files[filename] = changes[0]['text']
          changes.each do |change|
            @file_source[filename] = @file_source[filename].synchronize(change)
          end
        }
      end

      def close filename
        @semaphore.synchronize { @file_source.delete filename }
      end

      def queue message
        @buffer_semaphore.synchronize do
          @buffer += message
        end
      end

      def flush
        tmp = nil
        @buffer_semaphore.synchronize do
          tmp = @buffer.clone
          @buffer.clear
        end
        tmp
      end

      def prepare workspace
        @api_map = Solargraph::ApiMap.new(workspace)
      end

      def send_notification method, params
        response = {
          jsonrpc: "2.0",
          method: method,
          params: params
        }
        json = response.to_json
        envelope = "Content-Length: #{json.bytesize}\r\n\r\n#{json}"
        queue envelope
      end
    end
  end
end
