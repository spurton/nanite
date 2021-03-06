module Nanite
  class Dispatcher
    class << self
      def register(actor_instance)
        (@actors ||= []) << actor_instance
      end
      
      def all_services
        (@actors||[]).map {|a| a.provides }.flatten.uniq
      end
    
      def dispatch_request(req)
        _, actor, meth = req.type.split('/')
        begin
          actor = Object.full_const_get(actor.camel_case)
          actor = @actors.select{|a| actor === a }.first
          res = actor.send(meth, req.payload)
        rescue Exception => e
          res = "#{e.class.name}: #{e.message}\n  #{e.backtrace.join("\n  ")}"
        end
        Nanite::Result.new(req.token, req.reply_to, res) if req.reply_to 
      end    
            
      def handle(packet)
        case packet
        when Nanite::Pong
          Nanite.last_ping = Time.now
        when Nanite::Advertise
          Nanite.last_ping = Time.now
          Nanite.advertise_services
        when Nanite::Request
          result = dispatch_request(packet)
          Nanite.amq.queue(packet.reply_to).publish(Nanite.dump_packet(result)) if packet.reply_to
        when Nanite::Result
          Nanite.reducer.handle_result(packet)
        end
      end
    end    
  end

end