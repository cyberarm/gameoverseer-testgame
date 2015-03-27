require "gosu"
# require "gameoverseer-client"
require "renet"
require "multi_json"

class Game < Gosu::Window
  CHAT      = 0
  WORLD     = 1
  HANDSHAKE = 2
  FAULT     = 3

  def initialize
    super(720, 480, false)
    $window = self
    @client = ENet::Connection.new('localhost', 56789, 4, 0, 0)
    @client.on_connection(method(:on_connect))
    @client.on_packet_receive(method(:on_packet))
    @client.on_disconnection(method(:on_disconnect))
    @client.use_compression(true)
    @client.connect(2000)

    data = MultiJson.dump({channel: 'world', mode: 'connect'})
    @client.send_packet(data, true, HANDSHAKE)

    @peers = [] # (fellow clients)
    @player= Player.new
    @tick = 0
    @game_packet = 0

    at_exit do
      @client.disconnect(1500)
    end
  end

  def draw
    @peers.each(&:draw)

    @player.draw
  end

  def update
    @client.update(0)

    @tick = 0 if @tick >= 65

    self.caption = "fps: #{Gosu.fps} - sent: #{@client.total_sent_packets} - received: #{@client.total_received_packets} - UP: #{(((@client.total_sent_data*0.125)/1024)/1024).round(3)}MB - DOWN: #{(@client.total_received_data*0.125/1024/1024).round(3)}MB - P: #{@game_packet}"

    @player.update

    send_position if  @player.peer_id && @player.changed?
    send_position if  @tick >= 64 && @player.changed? != true

    @tick+=1
  end

  def send_position
    data = MultiJson.dump({channel: 'world', mode: 'position_update', data: {x: @player.x, y: @player.y}})
    @client.send_packet(data, false, WORLD)
    @game_packet+=1
  end

  def on_disconnect
    puts "Disconnected!"
  end

  def on_connect
    puts "Connected!"
  end

  def on_packet(data, channel)
    data = MultiJson.load(data)
    case data['mode']
    when 'who_am_i'
      @player.peer_id = data['data']['peer_id']
    when 'world_update'
      peer_id   = data['data']['peer']['peer_id']
      peer_data = data['data']['peer']

      if @player.peer_id != peer_id
        peer = @peers.find {|peer| peer_id == peer.peer_id}
        if peer
          peer.x, peer.y = peer_data['x'], peer_data['y']
        else
          @peers << Player.new(peer_id, peer_data['x'], peer_data['y'])
        end
      end
    when 'peer_disconnected'
      peer_id = data['data']['peer_id']
      peer = @peers.find {|peer| peer_id == peer.peer_id}
      @peers.delete(peer) if peer
    end
  end
end

class Player
  attr_accessor :peer_id, :x, :y, :z, :angle, :color
  def initialize(peer_id = Float::INFINITY, x = 64, y = 64, color = Gosu::Color.rgb(rand(0..255), rand(0..255), rand(0..255)), z = 100)
    @peer_id = peer_id
    @x = x
    @y = y
    @z = z
    @color = color
    @angle = 0
    @changed = false
  end

  def draw
    fill_rect(@x, @y, 64, 64, @color, @z)
  end

  def update
    @angle+=1
    @angle=0 if @angle >= 180
    old_y = self.y
    old_x = self.x
    self.x+=1 if button_down?(Gosu::KbRight) && self.x <= $window.width-63
    self.x-=1 if button_down?(Gosu::KbLeft) && self.x >= 0
    self.y+=1 if button_down?(Gosu::KbDown) && self.y <= $window.height-63
    self.y-=1 if button_down?(Gosu::KbUp) && self.y >= 0

    if old_x == self.x && old_y == self.y
      @changed = false
    else
      @changed = true
    end
  end

  def changed?
    @changed
  end

  def button_down?(id)
    if $window.button_down?(id)
      true
    else
      false
    end
  end

  def fill_rect(x, y, width, height, color, z = 0, mode = :default)
    return $window.draw_quad(x, y, color,
                             x, height+y, color,
                             width+x, height+y, color,
                             width+x, y, color,
                             z, mode)
  end
end

Game.new.show
