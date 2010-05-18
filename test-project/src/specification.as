package
{
  import flash.display.Sprite;
  import flash.events.Event;
  import flash.net.Socket;
  import flash.system.System;

  public class specification extends Sprite
  {
    private const socket : Socket = new Socket;

    public function specification()
    {
      socket.addEventListener(Event.CONNECT, handleConnected)
      socket.connect("localhost", 50002);
    }

    private function handleConnected(event : Event)
    {
      socket.writeUTFBytes("Hello, this is a test.\n");
      socket.writeUTFBytes("done\n");
      socket.flush();
      socket.close();
    }
  }
}
