package
{
  import flash.display.Sprite;
  import flash.events.Event;
  import flash.net.Socket;
  import flash.system.System;
  import org.asspec.*;

  public class specification extends Sprite implements TestListener
  {
    private const socket : Socket = new Socket;
    private const test : SizedTest = new CompleteMetasuite;

    public function specification()
    {
      socket.addEventListener(Event.CONNECT, handleConnected)
      socket.connect("localhost", 50002);
    }

    private function handleConnected(event : Event)
    {
      socket.writeUTFBytes("Hello, this is a test.\n");      
      socket.writeUTFBytes("plan " + test.size + "\n");

      runTests();

      socket.writeUTFBytes("done\n");
      socket.flush();
      socket.close();
    }

    private function runTests() : void
    { test.run(this); }

    public function testPassed(test : Test) : void
    {
      const name : String = test is NamedTest ? NamedTest(test).name : "";

      socket.writeUTFBytes("passed: " + name + "\n");
    }

    public function testFailed(test : Test, error : Error) : void
    {
      socket.writeUTFBytes("failed: " + getTestName(test) + "\n");
      socket.writeUTFBytes("reason: " + error.message + "\n");
    }

    private function getTestName(test : Test) : String
    { return test is NamedTest ? NamedTest(test).name : ""; }
  }
}
