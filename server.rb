require_relative "../rewrite-gameoverseer/lib/gameoverseer/gameoverseer"

class World < GameOverseer::Service
  def setup
    channel_manager.register_channel('world', self)
    @peers = []
  end

  def process(data)
    data_to_method(data)
  end

  def connect(data)
    message = MultiJson.dump({channel: 'world', mode: 'who_am_i', data: {peer_id: client_id}})
    message_manager.message(client_id, message, true, GameOverseer::ChannelManager::WORLD)
  end

  def position_update(data)
    client = @peers.find do |peer|
      peer[:client_id] == client_id
    end

    @peers << {client_id: client_id, x: 0, y: 0} unless client

    client[:x] = data['data']['x']
    client[:y] = data['data']['y']

    message = MultiJson.dump({channel: 'world', mode: 'world_update', data: {peer: {peer_id: client[:client_id], x: client[:x], y: client[:y]}}})
    message_manager.broadcast(message, true, GameOverseer::ChannelManager::WORLD)
  end

  def client_connected(client_id, ip_address)
    message = MultiJson.dump({channel: 'world', mode: 'who_am_i', data: {peer_id: client_id}})
    message_manager.message(client_id, message, true, GameOverseer::ChannelManager::WORLD)
  end

  def client_disconnected(client_id)
    message = MultiJson.dump({channel: 'world', mode: 'peer_disconnected', data: {peer_id: client_id}})
    message_manager.broadcast(message, true, GameOverseer::ChannelManager::WORLD)
  end

  def version
    "0.7.0b"
  end
end

GameOverseer.activate('localhost', 56789)
