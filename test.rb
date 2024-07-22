require 'socket'

server = TCPServer.new('0.0.0.0', 8080)

puts "Server is running on port 8080..."

loop do
  client = server.accept

  # Read the request (just to clear the buffer)
  request = ""
  while (line = client.gets) && (line != "\r\n")
    request += line
  end

  # Send HTTP response
  client.print "HTTP/1.1 200 OK\r\n"
  client.print "Content-Type: text/plain\r\n"
  client.print "Content-Length: 2\r\n"
  client.print "\r\n"
  client.print "OK"

  # Close the client connection
  client.close
end
