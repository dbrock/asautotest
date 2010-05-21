package
{
  import flash.display.Sprite;
  import flash.events.Event;
  import flash.net.Socket;
  import flash.system.System;
  import org.asspec.*;
  import org.asspec.assertion.*;
  import org.asspec.util.inspection.inspect;

  public class specification extends Sprite implements TestListener
  {
    private const socket : Socket = new Socket;
    private const test : SizedTest = new CompleteMetasuite;

    public function specification()
    {
      socket.addEventListener(Event.CONNECT, handleConnected)
      socket.connect("localhost", 50002);
    }

    private function handleConnected(event : Event) : void
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

    public function handleTestStarted(test : Test) : void
    {}

    public function handleTestPassed(test : Test) : void
    { sendXMLResult(<success test-name={getTestName(test)}/>); }

    public function handleTestFailed(test : Test, error : Error) : void
    {
      var result : XML = <failure test-name={getTestName(test)}/>;

      if (error !== null)
        result.@description = error.message;

      if (error is EqualityAssertionError)
        result.* += getEqualityFailureXML(EqualityAssertionError(error));

      sendXMLResult(result);
    }

    private function getEqualityFailureXML
      (error : EqualityAssertionError) : XML
    {
      return <equality
        expected={inspect(error.expected)}
        actual={inspect(error.actual)}/>
    }

    private function sendXMLResult(xml : XML) : void
    { socket.writeUTFBytes("xml-result: " + serialize(xml) + "\n"); }

    private function serialize(xml : XML) : String
    {
      return xml.toXMLString()
        .replace(/\r/g, "&#13;")
        .replace(/\n/g, "&#10;");
    }

    private function getTestName(test : Test) : String
    { return test is NamedTest ? NamedTest(test).name : ""; }
  }
}
